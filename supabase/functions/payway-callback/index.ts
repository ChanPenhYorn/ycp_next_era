/**
 * payway-callback
 *
 * The return_url pushback from ABA. It is unsigned, so its only job is to tell
 * us *which* order to look at. The decision to deliver comes from
 * check-transaction inside settleOrder.
 *
 * Configure this URL in the PayWay merchant profile:
 *   https://<project-ref>.supabase.co/functions/v1/payway-callback
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import { settleOrder } from "../_shared/settle.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: { tran_id?: string; apv?: string; status?: string | number };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (!body.tran_id) return json({ error: "missing_tran_id" }, 400);

  const admin = adminClient();

  // tran_id is ours: "<order_no><attempt>".
  const { data: payment } = await admin
    .from("payments")
    .select("order_id, provider_ref")
    .eq("provider", "payway")
    .eq("provider_ref", String(body.tran_id))
    .maybeSingle();

  if (!payment) {
    // Unknown tran_id: acknowledge so ABA stops retrying, but change nothing.
    return json({ ok: false, reason: "unknown_tran_id" }, 200);
  }

  const outcome = await settleOrder(admin, payment.order_id);

  console.log(
    JSON.stringify({
      event: "payway_callback",
      tran_id: body.tran_id,
      pushback_status: body.status,
      apv: body.apv,
      outcome,
    })
  );

  // Always 200: a non-2xx makes ABA retry the pushback.
  return json(outcome, 200);
});
