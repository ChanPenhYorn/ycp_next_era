import "server-only";
import { createClient } from "@supabase/supabase-js";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./env";

/**
 * No cookies, no session. Nothing here depends on the request, so results are
 * safe to hand to `use cache` and ship in the prerendered shell.
 */
export const publicClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
