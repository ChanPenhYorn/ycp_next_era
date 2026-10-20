/**
 * Bay2Game adapter tests. No network: `fetch` is replaced per test, so each
 * case scripts exactly what the supplier answers and checks what we sent.
 *
 *   deno test --allow-env supabase/tests/suppliers/
 *
 * Responses follow https://bay2game.xyz/developer_docs (create_order success
 * "SUCCESS", failure "FAILED" or "ERROR"; check_order status success/failed).
 */
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  bay2game,
  checkOrder,
  FIELD_MAP,
  unsupportedFields,
} from "../../functions/_shared/suppliers/bay2game.ts";
import { SupplierError, type FulfilInput } from "../../functions/_shared/suppliers/types.ts";

Deno.env.set("BAY2GAME_API_KEY", "test-key");

type Reply = { status?: number; body?: unknown; text?: string; networkError?: boolean };
type Call = { path: string; query: URLSearchParams };

const realFetch = globalThis.fetch;

async function withFetch(
  reply: (path: string, query: URLSearchParams) => Reply,
  run: (calls: Call[]) => Promise<void>,
): Promise<void> {
  const calls: Call[] = [];
  globalThis.fetch = (async (input: string | URL | Request) => {
    const url = new URL(String(input));
    const path = url.pathname.replace(/^\/api/, "");
    calls.push({ path, query: url.searchParams });
    const r = reply(path, url.searchParams);
    if (r.networkError) throw new TypeError("connection reset");
    return new Response(r.text ?? JSON.stringify(r.body ?? {}), { status: r.status ?? 200 });
  }) as typeof fetch;
  try {
    await run(calls);
  } finally {
    globalThis.fetch = realFetch;
  }
}

const order = (overrides: Partial<FulfilInput> = {}): FulfilInput => ({
  itemId: 7,
  orderNo: "CP-1001",
  supplierSku: "MLBB_500",
  quantity: 1,
  customerFields: { userid: "262856740", serverid: "3543" },
  ...overrides,
});

const success: Reply = { body: { status: "SUCCESS", amount: 7.0 } };
const failed = (message: string): Reply => ({ body: { status: "FAILED", message } });
const checkSuccess = {
  status: "SUCCESS",
  order: { status: "success", amount: 7.0 },
};
const checkNotFound = { status: "ERROR", message: "Order not found or you don't have permission to view it" };

// ---- catalogue mapping -----------------------------------------------------

Deno.test("field map covers the two keys the docs show", () => {
  assertEquals(FIELD_MAP, { userid: "game_user_id", serverid: "game_zone_id" });
});

Deno.test("canFulfil accepts userid and serverid, refuses a field it cannot send", () => {
  assertEquals(bay2game.canFulfil(["userid", "serverid"]), true);
  assertEquals(bay2game.canFulfil(["userid"]), true);
  assertEquals(bay2game.canFulfil([]), true);
  assertEquals(bay2game.canFulfil(["userid", "character_name"]), false);
  assertEquals(unsupportedFields(["character_name"]), ["character_name"]);
});

Deno.test("fieldDefinitions gives labels and patterns for known keys, bare key otherwise", () => {
  const defs = bay2game.fieldDefinitions!(["userid", "serverid", "mystery"]);
  assertEquals(defs[0].label_en, "Game ID");
  assertEquals(defs[0].pattern, "^[0-9]{6,12}$");
  assertEquals(defs[1].label_en, "Server");
  assertEquals(defs[2], { key: "mystery", label_km: "mystery", label_en: "mystery" });
});

Deno.test("games maps categories, including game_fields", async () => {
  await withFetch(
    () => ({
      body: {
        status: "success",
        categories: [
          {
            game_code: "mlbb_exclusive",
            name: "Mobile Legends Bang Bang",
            description: "d",
            image_url: "https://x/mlbb.png",
            game_fields: ["userid", "serverid"],
          },
          { game_code: "bloodstrike", name: "Blood Strike", game_fields: ["userid"] },
        ],
      },
    }),
    async (calls) => {
      const games = await bay2game.games();
      assertEquals(calls[0].path, "/categories");
      assertEquals(calls[0].query.get("api_key"), "test-key");
      assertEquals(games[0].gameCode, "mlbb_exclusive");
      assertEquals(games[0].fields, ["userid", "serverid"]);
      assertEquals(games[1].summary, "");
      assertEquals(games[1].imageUrl, null);
    },
  );
});

Deno.test("games throws non-retryable when the supplier answers ERROR", async () => {
  await withFetch(
    () => ({ body: { status: "ERROR", message: "api_key is required" } }),
    async () => {
      const error = await assertRejects(() => bay2game.games(), SupplierError);
      assertEquals(error.retryable, false);
      assertEquals(error.message, "categories: api_key is required");
    },
  );
});

Deno.test("products drops inactive items and parses string prices", async () => {
  await withFetch(
    () => ({
      body: {
        status: "SUCCESS",
        products: [
          { product_code: "MLBB_100", name: "100 Diamonds", sell_price: "1.50", status: "active" },
          { product_code: "MLBB_500", name: "500 Diamonds", sell_price: 7, status: "active" },
          { product_code: "MLBB_OLD", name: "Retired", sell_price: 3, status: "inactive" },
        ],
      },
    }),
    async (calls) => {
      const products = await bay2game.products("mlbb_exclusive");
      assertEquals(calls[0].query.get("game_code"), "mlbb_exclusive");
      assertEquals(products.map((p) => p.productCode), ["MLBB_100", "MLBB_500"]);
      assertEquals(products[0].priceUsd, 1.5);
      assertEquals(products[1].priceUsd, 7);
    },
  );
});

// ---- fulfilment ------------------------------------------------------------

Deno.test("fulfil delivers and sends mapped params with a stable reference", async () => {
  await withFetch(
    () => success,
    async (calls) => {
      const result = await bay2game.fulfil(order());
      assertEquals(result, { outcome: "delivered", reference: "CP-1001-7", costUsd: 7 });
      const q = calls[0].query;
      assertEquals(calls[0].path, "/create_order");
      assertEquals(q.get("product_code"), "MLBB_500");
      assertEquals(q.get("game_user_id"), "262856740");
      assertEquals(q.get("game_zone_id"), "3543");
      assertEquals(q.get("reference"), "CP-1001-7");
    },
  );
});

Deno.test("declares that it cannot take a line quantity", () => {
  // /create_order has no quantity parameter, so the catalogue caps every
  // synced variant at one unit. If this ever flips to true without the API
  // gaining a quantity parameter, a line for two would be delivered once.
  assertEquals(bay2game.supportsQuantity, false);
});

Deno.test("fulfil sends one unit and never a quantity parameter", async () => {
  await withFetch(
    () => success,
    async (calls) => {
      // A quantity of two cannot be expressed by this API. The catalogue is
      // what stops such a line existing; this asserts the adapter does not
      // silently pretend a second unit was ordered.
      await bay2game.fulfil(order({ quantity: 2 }));
      assertEquals(calls.length, 1);
      assertEquals(calls[0].path, "/create_order");
      assertEquals(calls[0].query.has("quantity"), false);
      assertEquals(calls[0].query.has("qty"), false);
    },
  );
});

Deno.test("fulfil accepts lowercase success from create_order", async () => {
  await withFetch(
    () => ({ body: { status: "success", amount: "7.00" } }),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "delivered");
    },
  );
});

Deno.test("fulfil omits game_zone_id for a game with no server field", async () => {
  await withFetch(
    () => success,
    async (calls) => {
      await bay2game.fulfil(order({ customerFields: { userid: "123456789" } }));
      assertEquals(calls[0].query.has("game_zone_id"), false);
    },
  );
});

Deno.test("fulfil refuses unmapped fields without placing an order", async () => {
  await withFetch(
    () => success,
    async (calls) => {
      const result = await bay2game.fulfil(
        order({ customerFields: { userid: "1", character_name: "x" } }),
      );
      assertEquals(result, {
        outcome: "refund",
        reason: "unmapped_customer_fields: character_name",
      });
      assertEquals(calls.length, 0);
    },
  );
});

Deno.test("fulfil refuses when the player id is missing", async () => {
  await withFetch(
    () => success,
    async (calls) => {
      const result = await bay2game.fulfil(order({ customerFields: { serverid: "3543" } }));
      assertEquals(result, { outcome: "refund", reason: "missing_game_user_id" });
      assertEquals(calls.length, 0);
    },
  );
});

Deno.test("fulfil retries on insufficient supplier balance, never refunds", async () => {
  await withFetch(
    () => failed("Insufficient balance. Required: 7.00, Available: 5.50"),
    async (calls) => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") {
        assertEquals(result.retryInMinutes, 60);
        assertEquals(result.reason.startsWith("supplier_out_of_balance"), true);
      }
      assertEquals(calls.some((c) => c.path === "/check_order"), false);
    },
  );
});

Deno.test("fulfil refunds on FAILED when check_order confirms no order", async () => {
  await withFetch(
    (path) => (path === "/check_order" ? { body: checkNotFound } : failed("Product unavailable")),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result, {
        outcome: "refund",
        reason: "Product unavailable",
        reference: "CP-1001-7",
      });
    },
  );
});

Deno.test("fulfil delivers on FAILED when check_order shows the order landed", async () => {
  await withFetch(
    (path) => (path === "/check_order" ? { body: checkSuccess } : failed("Duplicate reference")),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result, { outcome: "delivered", reference: "CP-1001-7", costUsd: 7 });
    },
  );
});

Deno.test("fulfil holds on ERROR and never refunds a paid order", async () => {
  await withFetch(
    (path) =>
      path === "/check_order"
        ? { body: checkNotFound }
        : { body: { status: "ERROR", message: "Invalid API key or user not active" } },
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") {
        assertEquals(result.reason, "supplier_error: Invalid API key or user not active");
        assertEquals(result.retryInMinutes, 60);
      }
    },
  );
});

Deno.test("fulfil delivers on ERROR when check_order shows the order landed", async () => {
  await withFetch(
    (path) =>
      path === "/check_order"
        ? { body: checkSuccess }
        : { body: { status: "ERROR", message: "Duplicate reference" } },
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "delivered");
    },
  );
});

Deno.test("fulfil retries when the network drops and check_order cannot reach the supplier", async () => {
  await withFetch(
    () => ({ networkError: true }),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") assertEquals(result.retryInMinutes, 5);
    },
  );
});

Deno.test("fulfil delivers after a dropped response when check_order shows it landed", async () => {
  await withFetch(
    (path) => (path === "/check_order" ? { body: checkSuccess } : { status: 503 }),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "delivered");
    },
  );
});

Deno.test("fulfil maps 429 to a retry with a 15-minute backoff", async () => {
  await withFetch(
    (path) => (path === "/check_order" ? { body: checkNotFound } : { status: 429 }),
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") {
        assertEquals(result.reason, "rate_limited");
        assertEquals(result.retryInMinutes, 15);
      }
    },
  );
});

Deno.test("fulfil throws on a 4xx HTTP error so the worker notes it for staff", async () => {
  await withFetch(
    () => ({ status: 401 }),
    async () => {
      const error = await assertRejects(() => bay2game.fulfil(order()), SupplierError);
      assertEquals(error.message, "http_401");
      assertEquals(error.retryable, false);
    },
  );
});

Deno.test("fulfil reads the 402 body: an unfunded wallet is a balance problem, not a mystery", async () => {
  // Verified against the live API on 2026-10-16: an empty wallet answers
  // HTTP 402 with the message in the body. Classifying that as a generic 4xx
  // hid the reason from staff and retried on the wrong cadence.
  await withFetch(
    (path) =>
      path === "/check_order"
        ? {
          body: {
            status: "error",
            message: "Order not found or you don't have permission to view it",
          },
        }
        : {
          status: 402,
          text: JSON.stringify({
            status: "FAILED",
            message: "Insufficient balance. Required: 0.20, Available: 0.00",
          }),
        },
    async (calls) => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") {
        assertEquals(result.retryInMinutes, 60);
        assertEquals(
          result.reason,
          "supplier_out_of_balance: Insufficient balance. Required: 0.20, Available: 0.00",
        );
      }
      // One attempt only: this must never refund, and never order twice.
      assertEquals(calls.filter((c) => c.path === "/create_order").length, 1);
      assertEquals(calls.filter((c) => c.path === "/check_order").length, 1);
    },
  );

  // A body that is not JSON means the same thing and must not become a 4xx.
  await withFetch(
    (path) =>
      path === "/check_order"
        ? { body: { status: "error", message: "not found" } }
        : { status: 402, text: "<html>payment required</html>" },
    async () => {
      const result = await bay2game.fulfil(order());
      assertEquals(result.outcome, "retry");
      if (result.outcome === "retry") {
        assertEquals(
          result.reason,
          "supplier_out_of_balance: insufficient supplier balance",
        );
        assertEquals(result.retryInMinutes, 60);
      }
    },
  );
});

Deno.test("fulfil throws bay2game_not_configured when the key is absent", async () => {
  Deno.env.delete("BAY2GAME_API_KEY");
  try {
    assertEquals(bay2game.configured(), false);
    const error = await assertRejects(() => bay2game.fulfil(order()), SupplierError);
    assertEquals(error.message, "bay2game_not_configured");
  } finally {
    Deno.env.set("BAY2GAME_API_KEY", "test-key");
  }
});

// ---- reconciliation --------------------------------------------------------

Deno.test("checkOrder reports delivered only when both status fields say success", async () => {
  await withFetch(
    () => ({ body: { status: "SUCCESS", order: { status: "failed", amount: 7 } } }),
    async () => {
      const result = await checkOrder("CP-1001-7");
      assertEquals(result.delivered, false);
    },
  );
  await withFetch(
    () => ({ body: checkSuccess }),
    async () => {
      const result = await checkOrder("CP-1001-7");
      assertEquals(result.delivered, true);
      assertEquals(result.amountUsd, 7);
    },
  );
});

Deno.test("checkOrder accepts the lowercase status the live API actually returns", async () => {
  // Verified against https://api.bay2game.xyz/api on 2026-10-16: every
  // endpoint answers `status: "success"` in lower case, while the docs show
  // "SUCCESS". A literal comparison here is silently always false, which turns
  // the ambiguity guard into a no-op and lets a landed order be placed again.
  await withFetch(
    () => ({ body: { status: "success", order: { status: "success", amount: 0.23 } } }),
    async () => {
      const result = await checkOrder("YP261015-42");
      assertEquals(result.delivered, true);
      assertEquals(result.amountUsd, 0.23);
    },
  );

  // The error shape is lowercase too: an unknown reference must not read as
  // delivered.
  await withFetch(
    () => ({
      body: { status: "error", message: "Order not found or you don't have permission to view it" },
    }),
    async () => {
      const result = await checkOrder("YP261015-43");
      assertEquals(result.delivered, false);
    },
  );
});
