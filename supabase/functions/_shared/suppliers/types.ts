/**
 * Supplier adapter contract.
 *
 * The rest of the system only knows this interface, so adding KAS Play later
 * means writing one file, not changing the order flow. Keys live in Edge
 * Function secrets and never reach the app.
 */

export type SupplierGame = {
  gameCode: string;
  name: string;
  summary: string;
  imageUrl: string | null;
  /** Field names the buyer must supply, e.g. ["userid","serverid"]. */
  fields: string[];
};

export type SupplierProduct = {
  productCode: string;
  name: string;
  priceUsd: number;
};

/**
 * A buyer field as the catalogue stores it.
 *
 * `key` must be the name the supplier's order API expects, because that is what
 * the adapters map through. The labels are ours, so the buyer reads "Game ID"
 * while the supplier receives `userid`.
 */
export type FieldDefinition = {
  key: string;
  label_km: string;
  label_en: string;
  placeholder?: string;
  pattern?: string;
};

export type FulfilInput = {
  itemId: number;
  orderNo: string;
  supplierSku: string;
  quantity: number;
  customerFields: Record<string, string>;
};

/**
 * `retry` exists because some failures are ours, not the buyer's. Running out
 * of supplier balance must never refund a buyer who paid correctly, and must
 * never silently drop the order either.
 */
export type FulfilResult =
  | { outcome: "delivered"; reference: string; costUsd: number | null }
  | { outcome: "retry"; reason: string; retryInMinutes: number; costUsd?: number | null }
  | { outcome: "refund"; reason: string; reference?: string };

export interface SupplierAdapter {
  readonly code: string;
  /** True when the API key is present. */
  configured(): boolean;
  /**
   * Whether this supplier can actually accept an order for a game that needs
   * these buyer fields. A game whose fields cannot be passed through must be
   * excluded from the catalogue, not listed and then refunded.
   */
  canFulfil(fields: string[]): boolean;
  /**
   * Labels for the fields a game declares. Optional: `supplier_upsert_catalogue`
   * falls back to the bare key, so an adapter without metadata still syncs a
   * usable catalogue rather than a string the app cannot parse.
   */
  fieldDefinitions?(fields: string[]): FieldDefinition[];
  games(): Promise<SupplierGame[]>;
  products(gameCode: string): Promise<SupplierProduct[]>;
  fulfil(input: FulfilInput): Promise<FulfilResult>;
}

export class SupplierError extends Error {
  constructor(
    message: string,
    readonly retryable: boolean,
    readonly retryInMinutes = 10
  ) {
    super(message);
  }
}

/** Rejects with a SupplierError after `ms`, so a hung supplier cannot stall the worker. */
export async function fetchWithTimeout(
  url: string,
  init: RequestInit = {},
  ms = 15000
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}
