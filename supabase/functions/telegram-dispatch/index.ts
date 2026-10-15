/**
 * telegram-dispatch
 *
 * Drains the notification outbox. Safe to call repeatedly and concurrently:
 * `telegram_claim_notifications` hands each row to exactly one caller with
 * `for update skip locked`, and a row left in 'sending' by a dead worker is
 * requeued rather than lost.
 */
import { drainOutbox } from "../_shared/dispatch.ts";
import { json, preflight } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Internal only: nothing should be able to drain the outbox just by finding
  // this URL. When the secret is unset the endpoint still requires the function
  // JWT (see verify_jwt in config.toml).
  const expected = Deno.env.get("TELEGRAM_DISPATCH_SECRET");
  if (expected && req.headers.get("x-dispatch-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  const result = await drainOutbox();
  return json({ ok: true, ...result });
});
