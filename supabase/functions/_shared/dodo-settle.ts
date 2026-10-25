/**
 * The single place a Dodo payment settles an order.
 *
 * `dodo-verify` (app poll) and `dodo-webhook` (Dodo push) both funnel through
 * here, exactly as the PayWay paths share `settleOrder`, so the rules cannot
 * diverge:
 *
 *  - the payment must be addressed to a real order (metadata.order_id),
 *  - the currency must be the one the catalogue prices in,
 *  - the amount must cover the order total,
 *  - `mark_order_paid` is idempotent, so duplicate webhooks are harmless.
 *
 * The browser return_url is never an input here.
 */
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { drainOutbox } from "./dispatch.ts";
import { usdToCents } from "./dodo.ts";

export type DodoSettleOutcome = {
  ok: boolean;
  state: string;
  order_status: string | null;
  reason?: string;
};

export type DodoPaymentFacts = {
  orderId: string;
  paymentId: string;
  /** Amount in the smallest currency unit, as Dodo reports it. */
  totalCents: number;
  currency?: string;
  checkoutSessionId?: string;
  paymentMethodType?: string;
  raw?: Record<string, unknown>;
};

export async function settleDodoPayment(
  admin: SupabaseClient,
  facts: DodoPaymentFacts
): Promise<DodoSettleOutcome> {
  const { data: order, error } = await admin
    .from("orders")
    .select("id, status, total_usd")
    .eq("id", facts.orderId)
    .maybeSingle();

  if (error || !order) {
    return {
      ok: false,
      state: "UNKNOWN",
      order_status: null,
      reason: "order_not_found",
    };
  }

  if (
    order.status !== "pending" &&
    order.status !== "paid" &&
    order.status !== "delivering"
  ) {
    return {
      ok: false,
      state: "UNKNOWN",
      order_status: order.status,
      reason: "already_final",
    };
  }

  const currency = (facts.currency ?? "").toUpperCase();
  if (currency && currency !== "USD") {
    return {
      ok: false,
      state: "UNKNOWN",
      order_status: order.status,
      reason: `currency_mismatch:${currency}`,
    };
  }

  const expected = usdToCents(Number(order.total_usd));
  if (facts.totalCents + 0 < expected) {
    return {
      ok: false,
      state: "APPROVED",
      order_status: order.status,
      reason: `underpaid:${facts.totalCents}<${expected}`,
    };
  }

  const { data: settleResult, error: settleError } = await admin.rpc(
    "mark_order_paid",
    {
      p_order_id: facts.orderId,
      p_provider: "dodo",
      p_provider_ref: facts.paymentId,
      p_payway_method: facts.paymentMethodType ?? "card",
      p_raw: facts.raw ?? null,
      p_amount_khr: null,
    }
  );

  if (settleError) {
    return {
      ok: false,
      state: "APPROVED",
      order_status: order.status,
      reason: `settle_failed:${settleError.message}`,
    };
  }

  // The pending row created when the session was opened carries the session id
  // but no payment id. `mark_order_paid` upserts the settled row under
  // `provider_ref`, so the initiation row is now noise in the staff screen.
  // Remove it only after settlement succeeded: a failure above must leave the
  // attempt visible.
  if (facts.checkoutSessionId) {
    await admin
      .from("payments")
      .delete()
      .eq("provider", "dodo")
      .eq("provider_session_id", facts.checkoutSessionId)
      .is("provider_ref", null);
  }

  const { data: after } = await admin
    .from("orders")
    .select("status")
    .eq("id", facts.orderId)
    .maybeSingle();

  // Instant orders reach 'delivered' right here; flush the buyer notification
  // rather than waiting for the next dispatcher run.
  await drainOutbox(5).catch(() => undefined);

  return {
    ok: true,
    state: "APPROVED",
    order_status: after?.status ?? null,
    reason: (settleResult as { status?: string })?.status,
  };
}
