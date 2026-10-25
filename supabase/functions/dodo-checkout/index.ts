/**
 * dodo-checkout
 *
 * Opens a hosted Dodo card checkout for a pending order and hands the app
 * nothing but a URL. The Dodo API key stays here, on the server.
 *
 * The amount is recomputed from `orders.total_usd`, never read from the
 * request. One Pay What You Want product carries the whole catalogue; the
 * session passes the exact order total in cents.
 *
 * POST { orderId: string }
 * -> { session_id, checkout_url, total_usd, expires_at }
 */
import { adminClient, json, preflight, requireUser } from "../_shared/supabase.ts";
import { isLocalRuntime } from "../_shared/payway.ts";
import {
  createCheckoutSession,
  dodoConfigured,
  usdToCents,
} from "../_shared/dodo.ts";

/** The app's own origin, so a return lands back where the buyer started. */
function returnBase(req: Request): string | null {
  const origin = req.headers.get("origin");
  const browserOrigin = origin && /^https?:\/\//.test(origin)
    ? origin.replace(/\/+$/, "")
    : null;

  // On a local stack the app runs on localhost, while STORE_APP_URL points at
  // the hosted store. Following it would send a local tester to production
  // after paying a test card.
  if (isLocalRuntime() && browserOrigin) return browserOrigin;

  const configured = (Deno.env.get("STORE_APP_URL") ?? "").trim();
  if (configured) return configured.replace(/\/+$/, "");

  return browserOrigin;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!dodoConfigured()) {
    return json({ error: "dodo_not_configured" }, 503);
  }

  const auth = await requireUser(req);
  if (!auth.ok) return auth.response;

  let orderId: string | undefined;
  try {
    ({ orderId } = await req.json());
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!orderId) return json({ error: "order_id_required" }, 400);

  // RLS guarantees the caller can only read their own order.
  const { data: order, error: orderError } = await auth.client
    .from("orders")
    .select("id, order_no, status, total_usd, expires_at, contact_email")
    .eq("id", orderId)
    .maybeSingle();

  if (orderError) {
    return json({ error: "order_lookup_failed", detail: orderError.message }, 500);
  }
  if (!order) return json({ error: "order_not_found" }, 404);
  if (order.status !== "pending") {
    return json({ error: "order_not_pending", status: order.status }, 409);
  }
  if (new Date(order.expires_at).getTime() < Date.now()) {
    return json({ error: "order_expired" }, 409);
  }

  const base = returnBase(req);
  if (!base) return json({ error: "store_url_not_configured" }, 503);

  const returnUrl = `${base}/orders/${orderId}`;
  const amountCents = usdToCents(Number(order.total_usd));

  const session = await createCheckoutSession({
    amountCents,
    orderId,
    orderNo: order.order_no,
    email: order.contact_email ?? undefined,
    returnUrl,
    cancelUrl: `${returnUrl}?checkout=cancelled`,
  });

  if (!session.ok) {
    return json({ error: session.reason, detail: session.detail }, 502);
  }
  if (!session.data.checkout_url) {
    return json({ error: "checkout_url_missing" }, 502);
  }

  const admin = adminClient();

  // One row per attempt. `provider_ref` stays null until Dodo mints a payment
  // id; the webhook or the poll fills it in when the buyer pays.
  const { error: insertError } = await admin.from("payments").insert({
    order_id: orderId,
    provider: "dodo",
    status: "pending",
    amount_usd: Number(order.total_usd),
    provider_session_id: session.data.session_id,
    raw_payload: session.data as unknown as Record<string, unknown>,
  });

  if (insertError) {
    // The checkout exists on Dodo's side but we cannot track it. Refuse rather
    // than send the buyer to a payment no webhook can match to an order.
    return json(
      { error: "payment_record_failed", detail: insertError.message },
      500
    );
  }

  return json({
    session_id: session.data.session_id,
    checkout_url: session.data.checkout_url,
    total_usd: Number(order.total_usd),
    expires_at: order.expires_at,
  });
});
