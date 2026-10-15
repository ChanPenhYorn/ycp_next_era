/**
 * payway-init
 *
 * Creates a KHQR for a pending order and hands the app nothing but a QR string
 * and a deeplink. The PayWay API key stays here, on the server.
 *
 * POST { orderId: string }
 * -> { tran_id, qr_string, abapay_deeplink, checkout_qr_url, total_usd, expires_at }
 */
import { adminClient, json, preflight, requireUser } from "../_shared/supabase.ts";
import { createPurchase, paywayConfig } from "../_shared/payway.ts";

function qrFromDeeplink(deeplink: string | undefined): string | undefined {
  if (!deeplink) return undefined;
  try {
    return new URL(deeplink).searchParams.get("qrcode") ?? undefined;
  } catch {
    return undefined;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!paywayConfig().isConfigured) {
    return json({ error: "payway_not_configured" }, 503);
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

  if (orderError) return json({ error: "order_lookup_failed", detail: orderError.message }, 500);
  if (!order) return json({ error: "order_not_found" }, 404);
  if (order.status !== "pending") {
    return json({ error: "order_not_pending", status: order.status }, 409);
  }
  if (new Date(order.expires_at).getTime() < Date.now()) {
    return json({ error: "order_expired" }, 409);
  }

  const { data: items } = await auth.client
    .from("order_items")
    .select("product_name, qty, unit_price_usd")
    .eq("order_id", orderId);

  const admin = adminClient();

  // PayWay rejects a reused tran_id, so give every attempt its own suffix.
  const { count } = await admin
    .from("payments")
    .select("id", { count: "exact", head: true })
    .eq("order_id", orderId)
    .eq("provider", "payway");

  const attempt = String((count ?? 0) + 1).padStart(3, "0");
  const tranId = `${order.order_no}${attempt}`.slice(0, 20);

  const lifetimeMinutes = Math.max(
    3,
    Math.ceil((new Date(order.expires_at).getTime() - Date.now()) / 60000)
  );

  const purchase = await createPurchase({
    tranId,
    amountUsd: Number(order.total_usd),
    items: (items ?? []).map((item) => ({
      name: item.product_name,
      quantity: item.qty,
      price: Number(item.unit_price_usd),
    })),
    email: order.contact_email ?? undefined,
    // Native in-app QR: ABA answers with JSON instead of the hosted page.
    paymentOption: "abapay_khqr_deeplink",
    lifetimeMinutes,
  });

  if (!purchase.ok) {
    return json({ error: purchase.reason, detail: purchase.detail }, 502);
  }

  await admin.from("payments").insert({
    order_id: orderId,
    provider: "payway",
    status: "pending",
    amount_usd: Number(order.total_usd),
    provider_ref: tranId,
    payway_method: "abapay_khqr_deeplink",
    raw_payload: purchase.response as unknown as Record<string, unknown>,
  });

  return json({
    tran_id: tranId,
    qr_string: purchase.response.qr_string ?? qrFromDeeplink(purchase.response.abapay_deeplink),
    abapay_deeplink: purchase.response.abapay_deeplink,
    checkout_qr_url: purchase.response.checkout_qr_url,
    total_usd: Number(order.total_usd),
    expires_at: order.expires_at,
  });
});
