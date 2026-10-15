import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, json } from "./http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

// Supabase is migrating from anon/service_role to publishable/secret keys.
// Projects on the new system inject different variable names, so accept both.
const PUBLISHABLE_KEY =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  "";

const SECRET_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SUPABASE_SECRET_KEY") ??
  "";

/** Acts as the caller. All RLS policies apply, so ownership is enforced by Postgres. */
export function userClient(req: Request): SupabaseClient {
  const authorization = req.headers.get("Authorization") ?? "";
  return createClient(SUPABASE_URL, PUBLISHABLE_KEY, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Bypasses RLS. Only for settlement and delivery decisions. */
export function adminClient(): SupabaseClient {
  if (!SECRET_KEY) {
    throw new Error(
      "No secret key in the environment. Set SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY."
    );
  }
  return createClient(SUPABASE_URL, SECRET_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function requireUser(req: Request): Promise<
  | { ok: true; userId: string; client: SupabaseClient }
  | { ok: false; response: Response }
> {
  const client = userClient(req);
  const {
    data: { user },
    error,
  } = await client.auth.getUser();

  if (error || !user) {
    return { ok: false, response: json({ error: "auth_required" }, 401) };
  }
  return { ok: true, userId: user.id, client };
}

export { json, corsHeaders, preflight } from "./http.ts";
