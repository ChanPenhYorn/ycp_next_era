import "server-only";
import { createClient } from "@supabase/supabase-js";
import { requireServiceRoleKey, SUPABASE_URL } from "./env";

/**
 * Bypasses RLS. Only ever use this from route handlers, server actions and
 * jobs: payment settlement, delivery, supplier sync.
 */
export function createAdminSupabase() {
  return createClient(SUPABASE_URL, requireServiceRoleKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
