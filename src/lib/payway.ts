import "server-only";
import { createHmac } from "node:crypto";

/**
 * ABA PayWay integration.
 *
 * Two rules drive this file:
 *  1. The hash is HMAC-SHA512 over the exact concatenation of the fields we
 *     send, in ABA's documented order. Any field we add or drop changes it.
 *  2. The return_url pushback is NOT signed. Never trust it on its own; always
 *     confirm with the Check Transaction API before delivering goods.
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
 * Field order is fixed by ABA. Kept as an array rather than an object so the
 * hash cannot silently drift when the payload changes.
 */
const HASH_FIELD_ORDER = [
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

export type PurchasePayload = Partial<Record<PurchaseHashField, string>> & {
  hash: string;
};

export function paywayConfig() {
  const env = (process.env.PAYWAY_ENV ?? "sandbox") as PaywayEnv;
  const endpoints = ENDPOINTS[env] ?? ENDPOINTS.sandbox;
  const merchantId = process.env.PAYWAY_MERCHANT_ID;
  const apiKey = process.env.PAYWAY_API_KEY;

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
  const p = (n: number, w = 2) => String(n).padStart(w, "0");
  return (
    date.getUTCFullYear().toString() +
    p(date.getUTCMonth() + 1) +
    p(date.getUTCDate()) +
    p(date.getUTCHours()) +
    p(date.getUTCMinutes()) +
    p(date.getUTCSeconds())
  );
}

export function hmacSha512Base64(data: string, key: string): string {
  return createHmac("sha512", key).update(data, "utf8").digest("base64");
}

export function buildPurchaseHash(
  fields: Partial<Record<PurchaseHashField, string>>,
  apiKey: string
): string {
  // Missing fields contribute an empty string, matching ABA's PHP samples.
  const concatenated = HASH_FIELD_ORDER.map((key) => fields[key] ?? "").join("");
  return hmacSha512Base64(concatenated, apiKey);
}

export type PurchaseInput = {
  tranId: string;
  amountUsd: number;
  items: Array<{ name: string; quantity: number; price: number }>;
  firstName?: string;
  lastName?: string;
  email?: string;
  phone?: string;
  /** Leave empty to let the buyer pick ABA Pay / cards / KHQR on the hosted page. */
  paymentOption?: string;
  returnUrl: string;
  cancelUrl?: string;
  continueSuccessUrl?: string;
  lifetimeMinutes?: number;
  returnParams?: string;
  customFields?: Record<string, string>;
  reqTime?: string;
};

export function buildPurchasePayload(input: PurchaseInput): {
  purchaseUrl: string;
  jsUrl: string;
  fields: PurchasePayload;
} | null {
  const config = paywayConfig();
  if (!config.isConfigured || !config.merchantId || !config.apiKey) return null;

  // amount is hashed as the same string we send, so format it once.
  const amount = input.amountUsd.toFixed(2);

  const fields: Partial<Record<PurchaseHashField, string>> = {
    req_time: input.reqTime ?? paywayReqTime(),
    merchant_id: config.merchantId,
    tran_id: input.tranId.slice(0, 20),
    amount,
    items: Buffer.from(JSON.stringify(input.items), "utf8").toString("base64"),
    shipping: "0",
    firstname: input.firstName ?? "",
    lastname: input.lastName ?? "",
    email: input.email ?? "",
    phone: input.phone ?? "",
    type: "purchase",
    payment_option: input.paymentOption ?? "",
    return_url: input.returnUrl,
    cancel_url: input.cancelUrl ?? "",
    continue_success_url: input.continueSuccessUrl ?? "",
    return_deeplink: "",
    currency: "USD",
    custom_fields: input.customFields
      ? Buffer.from(JSON.stringify(input.customFields), "utf8").toString("base64")
      : "",
    return_params: input.returnParams ?? "",
    payout: "",
    lifetime: input.lifetimeMinutes ? String(input.lifetimeMinutes) : "",
    additional_params: "",
    google_pay_token: "",
    skip_success_page: "",
  };

  return {
    purchaseUrl: config.purchaseUrl,
    jsUrl: config.jsUrl,
    fields: { ...fields, hash: buildPurchaseHash(fields, config.apiKey) },
  };
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
  if (!config.isConfigured || !config.merchantId || !config.apiKey) {
    return {
      ok: false,
      state: "UNKNOWN",
      tranId,
      amountUsd: null,
      currency: null,
      approvalCode: null,
      transactionDate: null,
      message: "payway_not_configured",
    };
  }

  const reqTime = paywayReqTime();
  const hash = hmacSha512Base64(
    reqTime + config.merchantId + tranId,
    config.apiKey
  );

  let json: unknown;
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
      cache: "no-store",
    });
    json = await res.json();
  } catch {
    return {
      ok: false,
      state: "UNKNOWN",
      tranId,
      amountUsd: null,
      currency: null,
      approvalCode: null,
      transactionDate: null,
      message: "network_error",
    };
  }

  const payload = json as {
    data?: {
      payment_status?: string;
      payment_amount?: number;
      payment_currency?: string;
      apv?: string;
      transaction_date?: string;
    };
    status?: { code?: string | number; message?: string };
  };

  const rawState = payload.data?.payment_status;
  const state: TransactionState =
    rawState === "APPROVED" ||
    rawState === "PRE-AUTH" ||
    rawState === "PENDING" ||
    rawState === "DECLINED" ||
    rawState === "REFUNDED" ||
    rawState === "CANCELLED"
      ? rawState
      : "UNKNOWN";

  return {
    ok: payload.status?.code === "00" || payload.status?.code === 0,
    state,
    tranId,
    amountUsd:
      typeof payload.data?.payment_amount === "number"
        ? payload.data.payment_amount
        : null,
    currency: payload.data?.payment_currency || null,
    approvalCode: payload.data?.apv || null,
    transactionDate: payload.data?.transaction_date ?? null,
    message: payload.status?.message ?? null,
  };
}

/** Verify the callback payload against ABA's own records. */
export async function verifyCallback(body: {
  tran_id?: string;
  apv?: string;
  status?: string | number;
}): Promise<{ verified: boolean; result: TransactionResult | null; reason: string }> {
  if (!body.tran_id) {
    return { verified: false, result: null, reason: "missing_tran_id" };
  }

  const result = await checkTransaction(String(body.tran_id));

  if (result.state !== "APPROVED") {
    return { verified: false, result, reason: `state_${result.state}` };
  }
  // The pushback approval code should match unless the payment was reversed.
  if (body.apv && result.approvalCode && String(body.apv) !== result.approvalCode) {
    return { verified: false, result, reason: "apv_mismatch" };
  }

  return { verified: true, result, reason: "approved" };
}
