/**
 * dodo-webhook
 *
 * Dodo pushes payment events here. The signature is verified against the raw
 * body before anything is read; a redirect through return_url is never enough
 * to settle an order.
 *
 * Configure in Developer -> Webhooks with at least `payment.succeeded`:
 *   https://<project-ref>.supabase.co/functions/v1/dodo-webhook
 *
 * Delivery is at-least-once, so the handler is idempotent:
 *  - `mark_order_paid` upserts on (provider, provider_ref);
 *  - an order already paid returns without moving money again.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import { dodoWebhookConfigured, verifyWebhook } from "../_shared/dodo.ts";
import { settleDodoPayment } from "../_shared/dodo-settle.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("DODO_PAYMENTS_WEBHOOK_KEY") ?? "";
  if (!dodoWebhookConfigured() || !secret) {
    // Not configured: refusing is correct. A 2xx would silently drop events.
    return json({ error: "webhook_not_configured" }, 503);
  }

  // Signature verification needs the exact bytes Dodo sent.
  const raw = await req.text();
  const verified = await verifyWebhook(raw, req.headers, secret);

  if (!verified.ok) {
    console.warn(
      JSON.stringify({ event: "dodo_webhook_rejected", reason: verified.reason })
    );
    return json({ error: "invalid_signature", reason: verified.reason }, 401);
  }

  const event = verified.event;
  const data = (event.data ?? {}) as NonNullable<typeof event.data>;
  const admin = adminClient();

  if (event.type === "payment.succeeded") {
    const metadata = (data.metadata ?? {}) as Record<string, unknown>;
    const orderId = typeof metadata.order_id === "string"
      ? metadata.order_id
      : null;
    const paymentId = typeof data.payment_id === "string"
      ? data.payment_id
      : null;

    if (!orderId || !paymentId) {
      // Valid signature but not a payment this store can address. Acknowledge
      // so Dodo stops retrying; there is nothing to fix on our side.
      console.warn(
        JSON.stringify({
          event: "dodo_webhook_unaddressable",
          type: event.type,
          payment_id: paymentId,
          order_id: orderId,
        })
      );
      return json({ received: true, ignored: "no_order_id" }, 200);
    }

    const outcome = await settleDodoPayment(admin, {
      orderId,
      paymentId,
      totalCents: Number(data.total_amount ?? 0),
      currency: data.currency,
      checkoutSessionId: data.checkout_session_id,
      paymentMethodType: data.payment_method_type,
      raw: data as unknown as Record<string, unknown>,
    });

    console.log(
      JSON.stringify({
        event: "dodo_payment_succeeded",
        order_id: orderId,
        payment_id: paymentId,
        outcome,
      })
    );

    // A settlement error is worth retrying; a refused amount or currency is
    // permanent and repeating it would only burn retries.
    if (outcome.reason?.startsWith("settle_failed")) {
      return json(outcome, 500);
    }

    return json({ received: true, outcome }, 200);
  }

  if (event.type === "payment.failed" || event.type === "payment.cancelled") {
    if (data.checkout_session_id) {
      await admin
        .from("payments")
        .update({ status: "failed" })
        .eq("provider", "dodo")
        .eq("provider_session_id", data.checkout_session_id)
        .is("provider_ref", null);
    }
    return json({ received: true, ignored: event.type }, 200);
  }

  // Subscriptions, refunds and disputes are not part of this store yet. Ack so
  // Dodo does not retry, and leave a line for whoever adds them.
  console.log(
    JSON.stringify({ event: "dodo_webhook_ignored", type: event.type })
  );
  return json({ received: true, ignored: event.type }, 200);
});
