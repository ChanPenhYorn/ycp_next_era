/**
 * ABA PayWay shared helpers for Supabase Edge Functions (Deno).
 *
 * Two rules drive this module:
 *  1. The API key never leaves the server. The app only ever sees a QR string.
 *  2. The return_url pushback is unsigned, so it is never trusted on its own;
 *     every settlement decision goes through check-transaction first.
 */

const ENDPOINTS = {
  sandbox: {
    baseUrl: "https://checkout-sandbox.payway.com.kh",
    jsUrl: "https://checkout-sandbox.payway.com.kh/plugins/checkout2-0.js",
  },
  production: {
    baseUrl: "https://checkout.payway.com.kh",
    jsUrl: "https://checkout.payway.com.kh/plugins/checkout2-0.js",
  },
} as const;

export type PaywayEnv = keyof typeof ENDPOINTS;

/**
 * Field order is fixed by ABA. Kept as an array so the hash cannot silently
 * drift when the payload changes.
 */
export const HASH_FIELD_ORDER = [
  "req_time",
  "merchant_id",
  "tran_id",
  "amount",
  "items",
  "shipping",
  "firstname",
  "lastname",
  "email",
  "phone",
  "type",
  "payment_option",
  "return_url",
  "cancel_url",
  "continue_success_url",
  "return_deeplink",
  "currency",
  "custom_fields",
  "return_params",
  "payout",
  "lifetime",
  "additional_params",
  "google_pay_token",
  "skip_success_page",
] as const;

export type PurchaseHashField = (typeof HASH_FIELD_ORDER)[number];

export function paywayConfig() {
  const env = (Deno.env.get("PAYWAY_ENV") ?? "sandbox") as PaywayEnv;
  const endpoints = ENDPOINTS[env] ?? ENDPOINTS.sandbox;
  const merchantId = Deno.env.get("PAYWAY_MERCHANT_ID") ?? "";
  const apiKey = Deno.env.get("PAYWAY_API_KEY") ?? "";

  return {
    env,
    ...endpoints,
    merchantId,
    apiKey,
    isConfigured: Boolean(merchantId && apiKey),
    purchaseUrl: `${endpoints.baseUrl}/api/payment-gateway/v1/payments/purchase`,
    checkUrl: `${endpoints.baseUrl}/api/payment-gateway/v1/payments/check-transaction-2`,
  };
}

/** `YYYYMMDDHHmmss` in UTC, exactly what ABA expects. */
export function paywayReqTime(date: Date = new Date()): string {
  const p = (n: number, width = 2) => String(n).padStart(width, "0");
  return (
    date.getUTCFullYear().toString() +
    p(date.getUTCMonth() + 1) +
    p(date.getUTCDate()) +
    p(date.getUTCHours()) +
    p(date.getUTCMinutes()) +
    p(date.getUTCSeconds())
  );
}

const encoder = new TextEncoder();

export async function hmacSha512Base64(
  data: string,
  key: string
): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    encoder.encode(key),
    { name: "HMAC", hash: "SHA-512" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("HMAC", cryptoKey, encoder.encode(data));

  let binary = "";
  for (const byte of new Uint8Array(signature)) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

export async function buildPurchaseHash(
  fields: Partial<Record<PurchaseHashField, string>>,
  apiKey: string
): Promise<string> {
  // Missing fields contribute an empty string, matching ABA's PHP samples.
  const concatenated = HASH_FIELD_ORDER.map((key) => fields[key] ?? "").join("");
  return await hmacSha512Base64(concatenated, apiKey);
}

export type PurchaseItem = { name: string; quantity: number; price: number };

export type PurchaseRequest = {
  tranId: string;
  amountUsd: number;
  items: PurchaseItem[];
  email?: string;
  firstName?: string;
  lastName?: string;
  phone?: string;
  /** Leave empty to let ABA pick; or force a method. */
  paymentOption?: string;
  returnUrl?: string;
  cancelUrl?: string;
  lifetimeMinutes?: number;
  customFields?: Record<string, string>;
};

export function buildPurchaseFields(
  request: PurchaseRequest,
  merchantId: string
): Promise<Record<PurchaseHashField, string>> {
  const fields: Record<PurchaseHashField, string> = {
    req_time: paywayReqTime(),
    merchant_id: merchantId,
    tran_id: request.tranId.slice(0, 20),
    // Hashed as the exact string we send, so format it once.
    amount: request.amountUsd.toFixed(2),
    items: btoa(JSON.stringify(request.items)),
    shipping: "0",
    firstname: request.firstName ?? "",
    lastname: request.lastName ?? "",
    email: request.email ?? "",
    phone: request.phone ?? "",
    type: "purchase",
    payment_option: request.paymentOption ?? "",
    return_url: request.returnUrl ?? "",
    cancel_url: request.cancelUrl ?? "",
    continue_success_url: "",
    return_deeplink: "",
    currency: "USD",
    custom_fields: request.customFields
      ? btoa(JSON.stringify(request.customFields))
      : "",
    return_params: "",
    payout: "",
    lifetime: request.lifetimeMinutes ? String(request.lifetimeMinutes) : "",
    additional_params: "",
    google_pay_token: "",
    skip_success_page: "",
  };

  return Promise.resolve(fields);
}

export type PurchaseResponse = {
  status: { code: string | number; message?: string; tran_id?: string };
  qr_string?: string;
  abapay_deeplink?: string;
  checkout_qr_url?: string;
};

/**
 * Calls the Purchase API. With payment_option=abapay_khqr_deeplink ABA responds
 * with JSON (qr_string + deeplink) instead of the hosted HTML page, which is
 * what a native app wants.
 */
export async function createPurchase(
  request: PurchaseRequest
): Promise<
  | { ok: true; response: PurchaseResponse; fields: Record<PurchaseHashField, string> }
  | { ok: false; reason: string; detail?: unknown }
> {
  const config = paywayConfig();
  if (!config.isConfigured) {
    return { ok: false, reason: "payway_not_configured" };
  }

  const fields = await buildPurchaseFields(request, config.merchantId);
  const hash = await buildPurchaseHash(fields, config.apiKey);

  const form = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    form.append(key, value);
  }
  form.append("hash", hash);

  let payload: unknown;
  try {
    const res = await fetch(config.purchaseUrl, { method: "POST", body: form });
    const text = await res.text();
    try {
      payload = JSON.parse(text);
    } catch {
      // Hosted-view mode answers with HTML instead of JSON.
      return { ok: false, reason: "non_json_response", detail: text.slice(0, 300) };
    }
  } catch (error) {
    return { ok: false, reason: "network_error", detail: String(error) };
  }

  const response = payload as PurchaseResponse;
  const code = String(response.status?.code ?? "");
  if (code !== "00" && code !== "0") {
    return { ok: false, reason: "payway_rejected", detail: response };
  }

  return { ok: true, response, fields };
}

export type TransactionState =
  | "APPROVED"
  | "PRE-AUTH"
  | "PENDING"
  | "DECLINED"
  | "REFUNDED"
  | "CANCELLED"
  | "UNKNOWN";

export type TransactionResult = {
  ok: boolean;
  state: TransactionState;
  tranId: string;
  amountUsd: number | null;
  currency: string | null;
  approvalCode: string | null;
  transactionDate: string | null;
  message: string | null;
};

/** Server-to-server truth. This is what unlocks delivery. */
export async function checkTransaction(tranId: string): Promise<TransactionResult> {
  const config = paywayConfig();
  const blank = (reason: string): TransactionResult => ({
    ok: false,
    state: "UNKNOWN",
    tranId,
    amountUsd: null,
    currency: null,
    approvalCode: null,
    transactionDate: null,
    message: reason,
  });

  if (!config.isConfigured) return blank("payway_not_configured");

  const reqTime = paywayReqTime();
  const hash = await hmacSha512Base64(
    reqTime + config.merchantId + tranId,
    config.apiKey
  );

  let payload: {
    data?: {
      payment_status?: string;
      payment_amount?: number;
      payment_currency?: string;
      apv?: string;
      transaction_date?: string;
    };
    status?: { code?: string | number; message?: string };
  };

  try {
    const res = await fetch(config.checkUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        req_time: reqTime,
        merchant_id: config.merchantId,
        tran_id: tranId,
        hash,
      }),
    });
    payload = await res.json();
  } catch {
    return blank("network_error");
  }

  const raw = payload.data?.payment_status;
  const state: TransactionState =
    raw === "APPROVED" ||
    raw === "PRE-AUTH" ||
    raw === "PENDING" ||
    raw === "DECLINED" ||
    raw === "REFUNDED" ||
    raw === "CANCELLED"
      ? raw
      : "UNKNOWN";

  return {
    ok: String(payload.status?.code ?? "") === "00",
    state,
    tranId,
    amountUsd:
      typeof payload.data?.payment_amount === "number"
        ? payload.data.payment_amount
        : null,
    currency: payload.data?.payment_currency ?? null,
    approvalCode: payload.data?.apv ?? null,
    transactionDate: payload.data?.transaction_date ?? null,
    message: payload.status?.message ?? null,
  };
}
