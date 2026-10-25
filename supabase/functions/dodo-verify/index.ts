/**
 * dodo-verify
 *
 * Called by the app after the buyer returns from the hosted checkout. It asks
 * Dodo for the truth (session -> payment) and settles the order the moment the
 * payment is succeeded. The webhook is the primary signal; this is what makes
 * the app feel instant and what recovers a missed webhook.
 *
 * POST { orderId: string }
 * -> { ok, state, order_status, reason }
 */
import { adminClient, json, preflight, requireUser } from "../_shared/supabase.ts";
import {
  dodoConfigured,
  retrieveCheckoutSession,
  retrievePayment,
  toSettleState,
} from "../_shared/dodo.ts";
import { settleDodoPayment } from "../_shared/dodo-settle.ts";

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

  // Confirm the caller owns the order before touching settlement.
  const { data: owned } = await auth.client
    .from("orders")
    .select("id, status")
    .eq("id", orderId)
    .maybeSingle();

  if (!owned) return json({ error: "order_not_found" }, 404);

  const admin = adminClient();
  const alreadyPaid =
    owned.status === "paid" ||
    owned.status === "delivering" ||
    owned.status === "delivered";

  const { data: attempt } = await admin
    .from("payments")
    .select("provider_session_id, provider_ref, status")
    .eq("order_id", orderId)
    .eq("provider", "dodo")
    .order("initiated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (alreadyPaid) {
    return json({ ok: true, state: "APPROVED", order_status: owned.status });
  }

  if (!attempt?.provider_session_id) {
    // No card attempt for this order. Nothing to poll; the order stays
    // payable by the methods that do have an attempt.
    return json({
      ok: false,
      state: "UNKNOWN",
      order_status: owned.status,
      reason: "no_payment",
    });
  }

  const session = await retrieveCheckoutSession(attempt.provider_session_id);
  if (!session.ok) {
    return json(
      {
        ok: false,
        state: "PENDING",
        order_status: owned.status,
        reason: session.reason,
      },
      202
    );
  }

  const state = toSettleState(session.data.payment_status);

  if (state !== "APPROVED" && state !== "PENDING") {
    // Terminal failure: keep the staff screen honest about the attempt.
    await admin
      .from("payments")
      .update({ status: "failed" })
      .eq("provider", "dodo")
      .eq("provider_session_id", attempt.provider_session_id)
      .is("provider_ref", null);

    return json(
      { ok: false, state, order_status: owned.status, reason: "not_approved" },
      202
    );
  }

  if (state !== "APPROVED" || !session.data.payment_id) {
    return json(
      { ok: false, state, order_status: owned.status, reason: "not_approved" },
      202
    );
  }

  // Ask for the payment itself: the session says it succeeded, but the amount
  // and currency that settle the order live on the payment.
  const payment = await retrievePayment(session.data.payment_id);
  if (!payment.ok) {
    return json(
      {
        ok: false,
        state: "PENDING",
        order_status: owned.status,
        reason: payment.reason,
      },
      202
    );
  }

  const outcome = await settleDodoPayment(admin, {
    orderId,
    paymentId: payment.data.payment_id,
    totalCents: Number(payment.data.total_amount ?? 0),
    currency: payment.data.currency,
    checkoutSessionId: attempt.provider_session_id,
    paymentMethodType: payment.data.payment_method_type,
    raw: payment.data as unknown as Record<string, unknown>,
  });

  return json(outcome, outcome.ok ? 200 : 202);
});
