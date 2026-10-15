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
  // Never fetched: both createPurchase and checkTransaction short-circuit before
  // any request when the stub is on. The host is deliberately unresolvable so a
  // mistake surfaces immediately instead of reaching ABA.
  stub: {
    baseUrl: "http://payway-stub.invalid",
    jsUrl: "",
  },
} as const;

export type PaywayEnv = keyof typeof ENDPOINTS;

/**
 * True inside a local Supabase stack. The stub is only allowed here, because the
 * alternative is a hosted project handing out approvals for money it never
 * received. The CLI runs functions with SUPABASE_URL=http://kong:8000.
 */
export function isLocalRuntime(): boolean {
  let host = "";
  try {
    host = new URL(Deno.env.get("SUPABASE_URL") ?? "").hostname;
  } catch {
    return false;
  }
  return (
    host === "kong" ||
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "::1" ||
    host === "host.docker.internal"
  );
}

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
  const requested = (Deno.env.get("PAYWAY_ENV") ?? "sandbox") as PaywayEnv;
  const merchantId = Deno.env.get("PAYWAY_MERCHANT_ID") ?? "";
  const apiKey = Deno.env.get("PAYWAY_API_KEY") ?? "";

  // The stub stands in for ABA so the checkout flow can be exercised without
  // credentials. It only engages on a local stack: on anything else the name is
  // ignored and the call falls back to a real environment, which then reports
  // payway_not_configured rather than approving money nobody sent.
  const stubRequested = requested === "stub";
  const isStub = stubRequested && isLocalRuntime();
  if (stubRequested && !isStub) {
    console.error(
      "PAYWAY_ENV=stub ignored: this is not a local stack. Payments stay unconfigured."
    );
  }

  const env = isStub ? "stub" : stubRequested ? "sandbox" : requested;
  const endpoints = ENDPOINTS[env] ?? ENDPOINTS.sandbox;

  return {
    env,
    ...endpoints,
    merchantId: isStub ? "stub" : merchantId,
    apiKey: isStub ? "stub" : apiKey,
    isStub,
    isConfigured: isStub || Boolean(merchantId && apiKey),
    purchaseUrl: `${endpoints.baseUrl}/api/payment-gateway/v1/payments/purchase`,
    checkUrl: `${endpoints.baseUrl}/api/payment-gateway/v1/payments/check-transaction-2`,
  };
}

/**
 * A QR string the widget can render, and a deeplink that resolves nowhere. It
 * says STUB on purpose: scanning it must never look like a real payable code.
 */
function stubPurchaseResponse(
  request: PurchaseRequest,
  merchantId: string
): PurchaseResponse {
  const tranId = request.tranId.slice(0, 20);
  const amount = request.amountUsd.toFixed(2);
  return {
    status: { code: "00", message: "stub approval", tran_id: tranId },
    qr_string: `STUB-KHQR|${merchantId}|${tranId}|${amount}USD`,
    abapay_deeplink: `abapay://stub?tran=${encodeURIComponent(tranId)}`,
    checkout_qr_url: `${ENDPOINTS.stub.baseUrl}/checkout/${encodeURIComponent(tranId)}`,
  };
}

/**
 * What ABA would have reported.
 *
 * PAYWAY_STUB_STATE picks the verdict, PAYWAY_STUB_UNDERPAY short-changes the
 * amount (which is how the underpayment guard gets exercised without a second
 * merchant account), and PAYWAY_STUB_SETTLE_SECONDS holds the answer at PENDING
 * first. That last one matters: a real QR waits for a human to scan it, and
 * without the wait the sheet flashes open and shut, which makes the payment
 * screen impossible to look at.
 */
function stubTransaction(
  tranId: string,
  context: TransactionContext
): TransactionResult {
  const verdict = (Deno.env.get("PAYWAY_STUB_STATE") ?? "APPROVED")
    .toUpperCase() as TransactionState;
  const settleSeconds = Number(
    Deno.env.get("PAYWAY_STUB_SETTLE_SECONDS") ?? "6"
  );
  const underpay = (Deno.env.get("PAYWAY_STUB_UNDERPAY") ?? "") !== "";

  // No initiation time (a hand-made request) means the wait is already over, so
  // the answer stays deterministic when there is nothing to wait for.
  const elapsedSeconds = context.initiatedAtMs == null
    ? Number.POSITIVE_INFINITY
    : (Date.now() - context.initiatedAtMs) / 1000;

  const waiting =
    Number.isFinite(settleSeconds) && elapsedSeconds < settleSeconds;
  const state: TransactionState = waiting ? "PENDING" : verdict;

  const amountUsd = context.expectedAmountUsd == null
    ? null
    : underpay
      ? Number((context.expectedAmountUsd * 0.9).toFixed(2))
      : context.expectedAmountUsd;

  return {
    ok: state === "APPROVED",
    state,
    tranId,
    amountUsd,
    currency: "USD",
    approvalCode: state === "APPROVED" ? `STUB-${tranId.slice(-6)}` : null,
    transactionDate: new Date().toISOString(),
    message: "stub",
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

/**
 * base64 of the UTF-8 bytes, not of the UTF-16 code units.
 *
 * `btoa` throws `InvalidCharacterError` on anything outside Latin-1, and every
 * Khmer product name is outside it: order_items.product_name is
 * products.name_km. That made payway-init answer 500 on every order, in every
 * environment, until the field was exercised.
 *
 * ABA's PHP samples use base64_encode, which is byte-level, so UTF-8 is also the
 * encoding their side expects.
 */
function base64Utf8(value: string): string {
  let binary = "";
  for (const byte of new TextEncoder().encode(value)) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

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
    items: base64Utf8(JSON.stringify(request.items)),
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
      ? base64Utf8(JSON.stringify(request.customFields))
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

  if (config.isStub) {
    // Real fields and a real hash are built anyway, so the request that would
    // have been sent is still visible in the logs when debugging the adapter.
    return {
      ok: true,
      response: stubPurchaseResponse(request, config.merchantId),
      fields: await buildPurchaseFields(request, config.merchantId),
    };
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

/**
 * What the stub needs and a real environment ignores.
 */
export type TransactionContext = {
  /** Echoed back so the underpayment guard still has something to compare. */
  expectedAmountUsd?: number;
  /** When the payment row was created, so the stub can fake a scanning delay. */
  initiatedAtMs?: number;
};

/**
 * Server-to-server truth. This is what unlocks delivery.
 *
 * [context] is only read by the stub. A real environment ignores it entirely:
 * the amount always comes from ABA's answer, never from us.
 */
export async function checkTransaction(
  tranId: string,
  context: TransactionContext = {}
): Promise<TransactionResult> {
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

  if (config.isStub) return stubTransaction(tranId, context);
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
