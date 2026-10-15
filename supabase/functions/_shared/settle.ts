/**
 * settle
 *
 * The single place an order becomes paid. Both the app poll and the ABA
 * callback funnel through here so the rules can never diverge.
 *
 * Guarantees:
 *  - ABA is always asked directly (check-transaction), never trusted via pushback.
 *  - The amount must cover the order total.
 *  - mark_order_paid is idempotent, so repeated polls are harmless.
 */
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { checkTransaction } from "../_shared/payway.ts";
import { drainOutbox } from "../_shared/dispatch.ts";

export type SettleOutcome = {
  ok: boolean;
  state: string;
  order_status: string | null;
  reason?: string;
};

export async function settleOrder(
  admin: SupabaseClient,
  orderId: string
): Promise<SettleOutcome> {
  const { data: order, error } = await admin
    .from("orders")
    .select("id, order_no, status, total_usd")
    .eq("id", orderId)
    .maybeSingle();

  if (error || !order) {
    return { ok: false, state: "UNKNOWN", order_status: null, reason: "order_not_found" };
  }

  if (order.status !== "pending" && order.status !== "paid" && order.status !== "delivering") {
    return { ok: false, state: "UNKNOWN", order_status: order.status, reason: "already_final" };
  }

  const { data: payment } = await admin
    .from("payments")
    .select("provider_ref, amount_usd, initiated_at")
    .eq("order_id", orderId)
    .eq("provider", "payway")
    .not("provider_ref", "is", null)
    .order("initiated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!payment?.provider_ref) {
    return { ok: false, state: "UNKNOWN", order_status: order.status, reason: "no_payment" };
  }

  const result = await checkTransaction(payment.provider_ref, {
    expectedAmountUsd: Number(order.total_usd),
    initiatedAtMs: payment.initiated_at
      ? Date.parse(payment.initiated_at)
      : undefined,
  });

  if (result.state !== "APPROVED") {
    return { ok: false, state: result.state, order_status: order.status, reason: "not_approved" };
  }

  // Never deliver on an underpayment.
  const expected = Number(order.total_usd);
  const paid = result.amountUsd ?? 0;
  if (paid + 0.0001 < expected) {
    return {
      ok: false,
      state: result.state,
      order_status: order.status,
      reason: `underpaid:${paid}<${expected}`,
    };
  }

  const { data: settleResult, error: settleError } = await admin.rpc("mark_order_paid", {
    p_order_id: orderId,
    p_provider: "payway",
    p_provider_ref: payment.provider_ref,
    p_payway_method: "abapay_khqr_deeplink",
    p_raw: result as unknown as Record<string, unknown>,
    p_amount_khr: null,
  });

  if (settleError) {
    return {
      ok: false,
      state: result.state,
      order_status: order.status,
      reason: `settle_failed:${settleError.message}`,
    };
  }

  const { data: after } = await admin
    .from("orders")
    .select("status")
    .eq("id", orderId)
    .maybeSingle();

  // Instant orders reach 'delivered' right here, so the buyer's notification is
  // flushed immediately rather than waiting for the next dispatcher run.
  await drainOutbox(5).catch(() => undefined);

  return {
    ok: true,
    state: result.state,
    order_status: after?.status ?? null,
    reason: (settleResult as { status?: string })?.status,
  };
}
