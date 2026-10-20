/**
 * A stand-in for https://api.bay2game.xyz/api.
 *
 * Bay2Game has no sandbox, one live key, and a real wallet balance that starts
 * at zero — so a delivery cannot be tested against them without spending. This
 * answers the same four endpoints with the same shapes, including the lower
 * case `status: "success"` the live API actually returns (the docs claim
 * "SUCCESS"), which is what the adapter must tolerate.
 *
 *   deno run --allow-net --allow-env supabase/tests/fake_bay2game.ts
 *
 * Then point the Edge Functions at it and restart so the CLI bakes the value
 * into the container:
 *
 *   # supabase/functions/.env
 *   BAY2GAME_BASE_URL=http://host.docker.internal:8899
 *
 * `host.docker.internal` is how the functions container reaches this machine;
 * it is already in the container's /etc/hosts as 192.168.65.254.
 *
 * ---------------------------------------------------------------------------
 * REMOVE THAT LINE WHEN YOU ARE DONE. A stub left in place silently marks real
 * orders delivered without topping anybody up. `--keep-alive` does not help you
 * remember; only the line in .env matters.
 * ---------------------------------------------------------------------------
 *
 * Modes, switchable at runtime so one run of the server can cover every branch:
 *
 *   curl -X POST 'http://127.0.0.1:8899/__fake/mode?mode=insufficient_balance'
 *
 *   success               normal delivery
 *   insufficient_balance  FAILED "Insufficient balance..." -> worker retries, never refunds
 *   error                 status error (bad key / unknown game) -> worker holds
 *   duplicate             create_order says "Duplicate reference" while
 *                         check_order reports the order landed -> worker must
 *                         treat it as delivered, not order a second time
 *   timeout               no answer for 30s, past the adapter's 15s budget
 *   http_500              upstream server error
 *   non_json              a body that is not JSON
 *
 * Every request is logged, with the api_key redacted, so you can see exactly
 * what the worker sent.
 */

const PORT = Number(Deno.env.get("FAKE_PORT") ?? 8899);
// The real account has never been funded; mirror that by default so the
// out-of-balance branch is the one you see first.
const START_BALANCE = Number(Deno.env.get("FAKE_BALANCE") ?? 0);

type Mode =
  | "success"
  | "insufficient_balance"
  | "error"
  | "duplicate"
  | "timeout"
  | "http_500"
  | "non_json";

let mode: Mode = (Deno.env.get("FAKE_MODE") as Mode) ?? "success";
let balance = START_BALANCE;

/** References this process has "placed", so check_order can find them. */
const placed = new Map<string, { amount: number; params: Record<string, string> }>();

const PRICES: Record<string, number> = {
  FREEFIRE_GLOBAL_100_Diamonds_Package___Newbie_Offer_1: 0.2,
  FREEFIRE_SGMY_25: 0.23,
  HOK_16: 0.17,
  MLBB_100: 1.5,
  MLBB_500: 7.0,
};

const GAMES = [
  {
    game_code: "mlbb_exclusive",
    name: "Mobile Legends Bang Bang",
    description: "fake catalogue",
    image_url: "https://example.test/mlbb.png",
    game_fields: ["userid", "serverid"],
    products: [
      { product_code: "MLBB_100", name: "100 Diamonds" },
      { product_code: "MLBB_500", name: "500 Diamonds" },
    ],
  },
  {
    game_code: "freefire_global",
    name: "Free Fire Global",
    description: "fake catalogue",
    image_url: "https://example.test/ff.png",
    game_fields: ["userid"],
    products: [
      { product_code: "FREEFIRE_GLOBAL_100_Diamonds_Package___Newbie_Offer_1", name: "100 Diamonds Newbie" },
      { product_code: "FREEFIRE_GLOBAL_110", name: "110 Diamonds" },
    ],
  },
];

const priceOf = (code: string) => PRICES[code] ?? 0.5;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function log(line: string) {
  console.log(`[fake-bay2game] ${line}`);
}

/** The api_key travels as a query parameter, so never print it. */
function redact(url: URL): string {
  const copy = new URL(url.toString());
  if (copy.searchParams.has("api_key")) copy.searchParams.set("api_key", "***");
  return copy.pathname + (copy.searchParams.toString() ? `?${copy.searchParams}` : "");
}

function categories() {
  return {
    status: "success", // lower case, as the live API answers
    total: GAMES.length,
    categories: GAMES.map((game) => ({
      game_code: game.game_code,
      name: game.name,
      description: game.description,
      image_url: game.image_url,
      game_fields: game.game_fields,
    })),
  };
}

function products(gameCode: string) {
  const game = GAMES.find((g) => g.game_code === gameCode);
  if (!game) return { status: "error", message: "Game not found" };
  return {
    status: "success",
    game: { game_code: game.game_code, name: game.name, game_fields: game.game_fields },
    products: game.products.map((p, index) => ({
      id: index + 1,
      product_code: p.product_code,
      name: p.name,
      sell_price: priceOf(p.product_code),
      status: "active",
      supplier_type: "fake",
    })),
  };
}

function createOrder(q: URLSearchParams) {
  const productCode = q.get("product_code") ?? "";
  const reference = q.get("reference") ?? "";
  const amount = priceOf(productCode);

  if (mode === "error") {
    return json({ status: "error", message: "Invalid API key or user not active" });
  }
  if (mode === "http_500") {
    return json({ status: "error", message: "upstream exploded" }, 500);
  }
  if (mode === "duplicate") {
    // A reference that already landed: their answer to placing it again. The
    // adapter must ask check_order and, finding it delivered, stop there.
    placed.set(reference, { amount, params: Object.fromEntries(q) });
    return json({ status: "FAILED", message: "Duplicate reference", reference });
  }

  // The live account has no money, so this is the first thing a real run
  // meets. Fund it with `?balance=` on the control endpoint to get past.
  if (mode === "insufficient_balance" || balance < amount) {
    return json({
      status: "FAILED",
      message: `Insufficient balance. Required: ${amount.toFixed(2)}, Available: ${balance.toFixed(2)}`,
      reference,
    });
  }

  placed.set(reference, { amount, params: Object.fromEntries(q) });
  const before = balance;
  balance = Math.round((balance - amount) * 100) / 100;
  return json({
    status: "success",
    message: "Successful Orders",
    reference,
    product_name: productCode,
    game_user_id: q.get("game_user_id"),
    game_zone_id: q.get("game_zone_id"),
    amount,
    balance_before: before,
    balance_after: balance,
  });
}

function checkOrder(q: URLSearchParams) {
  const reference = q.get("reference") ?? "";
  const order = placed.get(reference);
  if (!order) {
    return json({
      status: "error",
      message: "Order not found or you don't have permission to view it",
    });
  }
  return json({
    status: "success",
    order: {
      transaction_id: reference,
      amount: order.amount,
      status: "success",
      game_user_id: order.params.game_user_id,
      product_code: order.params.product_code,
    },
  });
}

async function handle(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const q = url.searchParams;

  // Control surface: not part of the real API, and never called by the worker.
  if (url.pathname === "/__fake/mode") {
    const wanted = q.get("mode") as Mode | null;
    if (wanted) mode = wanted;
    if (q.has("balance")) balance = Number(q.get("balance"));
    log(`mode=${mode} balance=${balance}`);
    return json({ ok: true, mode, balance, placed: [...placed.keys()] });
  }
  if (url.pathname === "/__fake/state") {
    return json({ mode, balance, placed: [...placed.keys()] });
  }

  log(`${req.method} ${redact(url)}  [mode=${mode}]`);

  const path = url.pathname.replace(/^\/api/, "");

  if (req.method !== "GET") return json({ status: "error", message: "method not allowed" }, 405);

  if (path === "/profile") {
    return json({
      status: "success",
      user: {
        id: 1,
        username: "fake-reseller",
        balance,
        status: "active",
        role: "reseller",
        total_orders: placed.size,
      },
    });
  }
  if (path === "/categories") return json(categories());
  if (path === "/products") return json(products(q.get("game_code") ?? ""));

  if (path === "/create_order") {
    // A slow answer is the point of this mode: it must look like a lost
    // response, not a rejection.
    if (mode === "timeout") await new Promise((r) => setTimeout(r, 30_000));
    if (mode === "non_json") {
      return new Response("<html>gateway said no</html>", { status: 200 });
    }
    return createOrder(q);
  }

  if (path === "/check_order") return checkOrder(q);

  return json({ status: "error", message: `unknown endpoint ${path}` }, 404);
}

log("================================================================");
log(`FAKE supplier on http://127.0.0.1:${PORT}/api  (${GAMES.length} games, balance ${balance})`);
log("No game is topped up. Any order this 'delivers' is a lie.");
log(`Point BAY2GAME_BASE_URL at http://host.docker.internal:${PORT} and`);
log("REMOVE IT from supabase/functions/.env when the test is over.");
log("================================================================");

Deno.serve({ port: PORT, hostname: "0.0.0.0" }, handle);
