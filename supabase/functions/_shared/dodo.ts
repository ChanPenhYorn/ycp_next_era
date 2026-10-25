/**
 * Dodo Payments client for the card rail.
 *
 * PayWay/ABA stays the local KHQR path; Dodo is the Merchant of Record for
 * cards. Two rules from the rest of this codebase still apply:
 *
 *  - The API key never leaves the server. The app only ever sees a
 *    `checkout_url`.
 *  - The browser redirect is never proof of payment. Only a verified webhook
 *    (or a server-side retrieve of the payment) settles an order.
 *
 * The amount is dynamic: one Pay What You Want product carries the store's
 * cart, and each session passes the exact order total in cents. Creating a
 * Dodo product per SKU would duplicate the catalogue and drift.
 *
 * Base URLs: https://test.dodopayments.com and https://live.dodopayments.com.
 * The environment defaults to test mode, so a missing variable can never
 * quietly charge a real card.
 */

const TEST_BASE = "https://test.dodopayments.com";
const LIVE_BASE = "https://live.dodopayments.com";

export type DodoEnvironment = "test_mode" | "live_mode";

export type DodoConfig = {
  apiKey: string;
  environment: DodoEnvironment;
  baseUrl: string;
  productId: string;
};

export function dodoEnvironment(): DodoEnvironment {
  return Deno.env.get("DODO_PAYMENTS_ENVIRONMENT") === "live_mode"
    ? "live_mode"
    : "test_mode";
}

export function dodoConfig(): DodoConfig | null {
  const apiKey = Deno.env.get("DODO_PAYMENTS_API_KEY") ?? "";
  const productId = Deno.env.get("DODO_PRODUCT_ID") ?? "";
  if (!apiKey || !productId) return null;

  const environment = dodoEnvironment();
  return {
    apiKey,
    environment,
    baseUrl: environment === "live_mode" ? LIVE_BASE : TEST_BASE,
    productId,
  };
}

export function dodoConfigured(): boolean {
  return dodoConfig() !== null;
}

export function dodoWebhookConfigured(): boolean {
  return Boolean(Deno.env.get("DODO_PAYMENTS_WEBHOOK_KEY"));
}

/** USD as Postgres stores it -> the integer cents every payment API expects. */
export function usdToCents(usd: number): number {
  return Math.round(Number(usd) * 100);
}

type FetchOptions = {
  method: "GET" | "POST";
  path: string;
  body?: unknown;
};

type DodoResult<T> =
  | { ok: true; data: T }
  | { ok: false; reason: string; detail?: unknown };

async function call<T>(
  config: DodoConfig,
  { method, path, body }: FetchOptions
): Promise<DodoResult<T>> {
  let response: Response;
  try {
    response = await fetch(`${config.baseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${config.apiKey}`,
        "Content-Type": "application/json",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(20000),
    });
  } catch (error) {
    return { ok: false, reason: "dodo_unreachable", detail: String(error) };
  }

  const text = await response.text();
  let parsed: unknown = null;
  try {
    parsed = text ? JSON.parse(text) : null;
  } catch {
    parsed = text;
  }

  if (!response.ok) {
    return {
      ok: false,
      reason: `dodo_http_${response.status}`,
      detail: parsed,
    };
  }

  return { ok: true, data: parsed as T };
}

export type CheckoutSession = {
  session_id: string;
  checkout_url?: string;
};

export type CheckoutSessionStatus = {
  id: string;
  payment_id?: string;
  payment_status?: string;
  customer_email?: string;
};

export type DodoPayment = {
  payment_id: string;
  status?: string;
  total_amount?: number;
  currency?: string;
  checkout_session_id?: string;
  payment_method_type?: string;
  metadata?: Record<string, unknown>;
  [key: string]: unknown;
};

export type CreateCheckoutInput = {
  /** Order total in cents. The Dodo product is Pay What You Want. */
  amountCents: number;
  orderId: string;
  orderNo: string;
  email?: string;
  returnUrl: string;
  cancelUrl?: string;
};

/**
 * Creates a hosted checkout session for one order.
 *
 * Discount codes are disabled at the Dodo layer on purpose: the coupon has
 * already been applied by `create_order` in Postgres and is baked into
 * `amountCents`. Letting the buyer add another code would charge a different
 * amount than the order, and the settlement check would refuse it.
 */
export async function createCheckoutSession(
  input: CreateCheckoutInput
): Promise<DodoResult<CheckoutSession>> {
  const config = dodoConfig();
  if (!config) return { ok: false, reason: "dodo_not_configured" };

  return await call<CheckoutSession>(config, {
    method: "POST",
    path: "/checkouts",
    body: {
      product_cart: [
        {
          product_id: config.productId,
          quantity: 1,
          amount: input.amountCents,
        },
      ],
      customer: input.email ? { email: input.email } : undefined,
      // Pin the charge currency to the one the catalogue is priced in. With
      // Adaptive Currency on, omitting this would bill in the buyer's local
      // currency and the amount check would be comparing apples to riel.
      billing_currency: "USD",
      metadata: {
        order_id: input.orderId,
        order_no: input.orderNo,
      },
      return_url: input.returnUrl,
      cancel_url: input.cancelUrl,
      customization: { theme: "dark", show_order_details: true },
      feature_flags: {
        allow_discount_code: false,
        allow_currency_selection: false,
      },
    },
  });
}

export async function retrieveCheckoutSession(
  sessionId: string
): Promise<DodoResult<CheckoutSessionStatus>> {
  const config = dodoConfig();
  if (!config) return { ok: false, reason: "dodo_not_configured" };

  return await call<CheckoutSessionStatus>(config, {
    method: "GET",
    path: `/checkouts/${encodeURIComponent(sessionId)}`,
  });
}

export async function retrievePayment(
  paymentId: string
): Promise<DodoResult<DodoPayment>> {
  const config = dodoConfig();
  if (!config) return { ok: false, reason: "dodo_not_configured" };

  return await call<DodoPayment>(config, {
    method: "GET",
    path: `/payments/${encodeURIComponent(paymentId)}`,
  });
}

// ---------------------------------------------------------------------------
// Webhook verification (Standard Webhooks)
//
// Dodo signs `webhook-id.webhook-timestamp.raw_body` with HMAC-SHA256 and sends
// the base64 digest in `webhook-signature`. The signing key is the dashboard
// secret after its `whsec_` prefix, base64-decoded.
//
// This is implemented here rather than pulled from a package so the Edge
// runtime needs no extra dependency. The exact signed string is the part
// people get wrong; it is spelled out above and covered by a test with a
// known secret.
// ---------------------------------------------------------------------------

export type DodoEvent = {
  type: string;
  timestamp?: string;
  data?: DodoPayment & {
    payment_id?: string;
    total_amount?: number;
    currency?: string;
    metadata?: Record<string, unknown>;
  };
};

export type VerifyResult =
  | { ok: true; event: DodoEvent }
  | { ok: false; reason: string };

function base64Bytes(value: string): Uint8Array<ArrayBuffer> | null {
  try {
    const binary = atob(value);
    const bytes = new Uint8Array(new ArrayBuffer(binary.length));
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

function signingKey(secret: string): Uint8Array<ArrayBuffer> | null {
  const stripped = secret.startsWith("whsec_") ? secret.slice(6) : secret;
  return base64Bytes(stripped);
}

function equalBytes(a: Uint8Array<ArrayBufferLike>, b: Uint8Array<ArrayBufferLike>): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function verifyWebhook(
  rawBody: string,
  headers: Headers,
  secret: string,
  nowMs = Date.now(),
  toleranceSeconds = 300
): Promise<VerifyResult> {
  const id = headers.get("webhook-id");
  const timestamp = headers.get("webhook-timestamp");
  const signature = headers.get("webhook-signature");

  if (!id || !timestamp || !signature) {
    return { ok: false, reason: "missing_headers" };
  }

  const sentAt = Number(timestamp);
  if (!Number.isFinite(sentAt)) return { ok: false, reason: "bad_timestamp" };

  const skew = Math.abs(nowMs / 1000 - sentAt);
  if (skew > toleranceSeconds) return { ok: false, reason: "stale_timestamp" };

  const key = signingKey(secret);
  if (!key) return { ok: false, reason: "bad_secret" };

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      cryptoKey,
      new TextEncoder().encode(`${id}.${timestamp}.${rawBody}`)
    )
  );

  // A header may carry more than one signature, space separated, and each is
  // prefixed with its scheme. Only v1 is HMAC-SHA256.
  const candidates = signature
    .split(" ")
    .map((part) => part.trim())
    .filter((part) => part.startsWith("v1,"))
    .map((part) => base64Bytes(part.slice(3)))
    .filter((bytes): bytes is Uint8Array<ArrayBuffer> => bytes !== null);

  if (!candidates.some((candidate) => equalBytes(candidate, digest))) {
    return { ok: false, reason: "bad_signature" };
  }

  let event: DodoEvent;
  try {
    event = JSON.parse(rawBody) as DodoEvent;
  } catch {
    return { ok: false, reason: "invalid_json" };
  }

  if (!event || typeof event.type !== "string") {
    return { ok: false, reason: "invalid_event" };
  }

  return { ok: true, event };
}

/** Dodo's intent status -> the vocabulary the app already polls. */
export function toSettleState(status: string | undefined): string {
  switch ((status ?? "").toLowerCase()) {
    case "succeeded":
      return "APPROVED";
    case "failed":
      return "DECLINED";
    case "cancelled":
    case "canceled":
      return "CANCELLED";
    case "expired":
      return "EXPIRED";
    default:
      return "PENDING";
  }
}
