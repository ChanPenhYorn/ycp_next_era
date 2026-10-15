/**
 * dev-signin
 *
 * Sandbox stand-in for the email OTP. The app posts an address and the shared
 * sandbox code; the function hands back a token hash the client exchanges for a
 * real session. Nothing is emailed, so the 2-per-hour mailer budget and the
 * "Confirm your email address" template stay out of the way.
 *
 * The session is a genuine one: the token comes from the admin API, so every RLS
 * policy still applies to it.
 *
 * Hard-disabled unless DEV_OTP is set in the environment. It is set on a local
 * stack only (see supabase/functions/.env), so a stray deploy of this function
 * answers 404 rather than opening a login bypass.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";

const DEV_OTP = Deno.env.get("DEV_OTP") ?? "";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (!DEV_OTP) return json({ error: "not_found" }, 404);

  let body: { email?: string; code?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const email = (body.email ?? "").trim().toLowerCase();
  if (!email) return json({ error: "email_required" }, 400);
  if ((body.code ?? "").trim() !== DEV_OTP) {
    return json({ error: "invalid_code" }, 401);
  }

  const admin = adminClient();

  // generateLink needs the user to exist, and a fresh local database has none.
  // email_confirm is what the hosted project would have done with the link it
  // mailed, so the account ends up in the same state.
  const created = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
  });
  if (created.error && created.error.code !== "email_exists") {
    console.error("dev-signin createUser failed", created.error.message);
    return json({ error: "user_failed", message: created.error.message }, 500);
  }

  const { data, error } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email,
  });
  if (error || !data.properties?.hashed_token) {
    console.error("dev-signin generateLink failed", error?.message);
    return json({ error: "link_failed", message: error?.message }, 500);
  }

  return json({ token_hash: data.properties.hashed_token });
});
