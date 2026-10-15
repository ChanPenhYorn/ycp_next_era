/**
 * payway-verify
 *
 * Called by the app while the KHQR sheet is open. Polls ABA, and settles the
 * order the moment the payment is APPROVED.
 *
 * POST { orderId: string }
 * -> { ok, state, order_status, reason }
 */
import { adminClient, json, preflight, requireUser } from "../_shared/supabase.ts";
import { settleOrder } from "../_shared/settle.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

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
    .select("id")
    .eq("id", orderId)
    .maybeSingle();

  if (!owned) return json({ error: "order_not_found" }, 404);

  const outcome = await settleOrder(adminClient(), orderId);
  return json(outcome, outcome.ok ? 200 : 202);
});
