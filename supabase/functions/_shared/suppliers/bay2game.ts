/**
 * Bay2Game adapter.
 *
 * Base URL https://api.bay2game.xyz/api
 *
 * Two things about this API shape the code below:
 *
 * 1. The key travels as a QUERY PARAMETER, so it lands in any access log or
 *    proxy trace along the way. This adapter must therefore only ever run
 *    server-side.
 * 2. `/create_order` is not obviously idempotent even though `reference` is
 *    mandatory. On any ambiguous result — timeout, malformed body, duplicate
 *    reference — we ask `/check_order` before deciding, because guessing wrong
 *    means either charging twice or delivering twice.
 */
import {
  fetchWithTimeout,
  SupplierError,
  type FieldDefinition,
  type FulfilInput,
  type FulfilResult,
  type SupplierAdapter,
  type SupplierGame,
  type SupplierProduct,
} from "./types.ts";

const BASE = Deno.env.get("BAY2GAME_BASE_URL") ?? "https://api.bay2game.xyz/api";

/** Their field names map onto their order parameters. */
export const FIELD_MAP: Record<string, string> = {
  userid: "game_user_id",
  serverid: "game_zone_id",
};

/**
 * What the buyer sees for each field this API accepts, keyed the same way as
 * FIELD_MAP. The supplier only gives us names like "userid", so the human
 * labels live here. The patterns match the ones the demo seed uses, so a
 * synced game and a hand-made one validate identically.
 */
const FIELD_LABELS: Record<
  string,
  { km: string; en: string; placeholder?: string; pattern?: string }
> = {
  userid: {
    km: "លេខ ID ហ្គេម",
    en: "Game ID",
    placeholder: "123456789",
    pattern: "^[0-9]{6,12}$",
  },
  serverid: {
    km: "Server",
    en: "Server",
    placeholder: "2001",
    pattern: "^[0-9]{3,6}$",
  },
};

/** Turn the supplier's field names into definitions the catalogue can store. */
export function fieldDefinitions(fields: string[]): FieldDefinition[] {
  return fields.map((key) => {
    const label = FIELD_LABELS[key];
    const definition: FieldDefinition = {
      key,
      label_km: label?.km ?? key,
      label_en: label?.en ?? key,
    };
    if (label?.placeholder) definition.placeholder = label.placeholder;
    if (label?.pattern) definition.pattern = label.pattern;
    return definition;
  });
}

/**
 * Fields a game may declare that this API cannot accept. `create_order` takes
 * only product_code, game_user_id, game_zone_id and reference, so a game
 * wanting a character name cannot be fulfilled even though it is listed.
 * Selling it would mean taking money and then refunding.
 */
export function unsupportedFields(fields: string[]): string[] {
  return fields.filter((field) => !(field in FIELD_MAP));
}

type Bay2Response = {
  status?: string;
  message?: string;
  total?: number;
  categories?: Array<{
    game_code: string;
    name: string;
    description?: string;
    image_url?: string;
    game_fields?: string[];
  }>;
  products?: Array<{
    product_code: string;
    name: string;
    sell_price: number | string;
    status?: string;
  }>;
  amount?: number | string;
  balance_after?: number | string;
  order?: { status?: string; amount?: number | string };
};

function key(): string {
  return Deno.env.get("BAY2GAME_API_KEY") ?? "";
}

async function call(
  path: string,
  params: Record<string, string | undefined>
): Promise<Bay2Response> {
  const apiKey = key();
  if (!apiKey) throw new SupplierError("bay2game_not_configured", false);

  // The key is a query parameter by their design. Never called from a client.
  const url = new URL(`${BASE}${path}`);
  url.searchParams.set("api_key", apiKey);
  for (const [name, value] of Object.entries(params)) {
    if (value !== undefined && value !== "") url.searchParams.set(name, value);
  }

  let res: Response;
  try {
    res = await fetchWithTimeout(url.toString(), { method: "GET" });
  } catch (error) {
    throw new SupplierError(`network: ${error}`, true, 5);
  }

  if (res.status === 429) {
    throw new SupplierError("rate_limited", true, 15);
  }
  if (res.status >= 500) {
    throw new SupplierError(`upstream_${res.status}`, true, 10);
  }
  if (!res.ok) {
    throw new SupplierError(`http_${res.status}`, false);
  }

  const text = await res.text();
  try {
    return JSON.parse(text) as Bay2Response;
  } catch {
    throw new SupplierError(`non_json: ${text.slice(0, 160)}`, true, 5);
  }
}

function toUsd(value: number | string | undefined): number | null {
  if (value === undefined || value === null) return null;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : null;
}

/** Their status field is inconsistently cased: docs say "SUCCESS", the live API returns "success". */
function isSuccess(status: string | undefined): boolean {
  return (status ?? "").toLowerCase() === "success";
}

export const bay2game: SupplierAdapter = {
  code: "bay2game",

  configured: () => key().length > 0,

  canFulfil: (fields: string[]) => unsupportedFields(fields).length === 0,

  fieldDefinitions,

  async games(): Promise<SupplierGame[]> {
    const data = await call("/categories", {});
    if (!isSuccess(data.status)) {
      throw new SupplierError(`categories: ${data.message ?? data.status}`, false);
    }

    return (data.categories ?? []).map((category) => ({
      gameCode: category.game_code,
      name: category.name,
      summary: category.description ?? "",
      imageUrl: category.image_url ?? null,
      fields: category.game_fields ?? [],
    }));
  },

  async products(gameCode: string): Promise<SupplierProduct[]> {
    const data = await call("/products", { game_code: gameCode });
    if (!isSuccess(data.status)) {
      throw new SupplierError(`products: ${data.message ?? data.status}`, false);
    }

    return (data.products ?? [])
      // Some games legitimately declare no fields, so an empty list is fine.
      .filter((product) => (product.status ?? "active") === "active")
      .map((product) => ({
        productCode: product.product_code,
        name: product.name,
        priceUsd: toUsd(product.sell_price) ?? 0,
      }));
  },

  async fulfil(input: FulfilInput): Promise<FulfilResult> {
    // Stable per order line, so a retry cannot create a second order.
    const reference = `${input.orderNo}-${input.itemId}`;
    const params: Record<string, string | undefined> = {
      product_code: input.supplierSku,
      reference,
    };

    const unmapped: string[] = [];
    for (const [field, value] of Object.entries(input.customerFields)) {
      const target = FIELD_MAP[field];
      if (!target) {
        unmapped.push(field);
        continue;
      }
      params[target] = value;
    }
    if (unmapped.length > 0) {
      // Their order endpoint ignores unknown fields, so submitting would place
      // an order with a missing player id. Refuse instead. This is what fires
      // when a product's requires_fields keys do not match FIELD_MAP.
      return {
        outcome: "refund",
        reason: `unmapped_customer_fields: ${unmapped.join(",")}`,
      };
    }

    if (!params.game_user_id) {
      return { outcome: "refund", reason: "missing_game_user_id" };
    }

    let created: Bay2Response;
    try {
      created = await call("/create_order", params);
    } catch (error) {
      if (error instanceof SupplierError && error.retryable) {
        // Ambiguous: the order may exist. Ask before retrying.
        const settled = await checkOrder(reference).catch(() => null);
        if (settled?.delivered) {
          return { outcome: "delivered", reference, costUsd: settled.amountUsd };
        }
        return {
          outcome: "retry",
          reason: error.message,
          retryInMinutes: error.retryInMinutes,
        };
      }
      throw error;
    }

    const status = (created.status ?? "").toUpperCase();

    if (status === "SUCCESS") {
      return {
        outcome: "delivered",
        reference,
        costUsd: toUsd(created.amount),
      };
    }

    const message = created.message ?? "unknown_failure";

    // Out of balance is our problem: retry with a long backoff and let
    // supplier_note_failure escalate to staff after the attempt limit.
    if (/insufficient balance/i.test(message)) {
      return {
        outcome: "retry",
        reason: `supplier_out_of_balance: ${message}`,
        retryInMinutes: 60,
      };
    }

    // "Duplicate reference" means a previous attempt landed.
    const settled = await checkOrder(reference).catch(() => null);
    if (settled?.delivered) {
      return { outcome: "delivered", reference, costUsd: settled.amountUsd };
    }

    // ERROR is a request-level failure (bad key, unknown game or product).
    // It says nothing about the buyer's order, so hold it for a retry and
    // staff review rather than refunding a correctly paid order.
    if (status === "ERROR") {
      return {
        outcome: "retry",
        reason: `supplier_error: ${message}`,
        retryInMinutes: 60,
      };
    }

    return { outcome: "refund", reason: message, reference };
  },
};

/**
 * Resolves an ambiguous order. Not part of the adapter interface because not
 * every supplier offers an equivalent lookup.
 */
export async function checkOrder(
  reference: string
): Promise<{ delivered: boolean; amountUsd: number | null; raw: Bay2Response }> {
  const data = await call("/check_order", { reference });
  const orderStatus = (data.order?.status ?? "").toLowerCase();
  return {
    delivered: data.status === "SUCCESS" && orderStatus === "success",
    amountUsd: toUsd(data.order?.amount),
    raw: data,
  };
}
