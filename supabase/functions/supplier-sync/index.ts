/**
 * supplier-sync
 *
 * Pulls a supplier catalogue into your own products, variants and
 * supplier_skus, so the storefront can sell their inventory.
 *
 * POST { supplier?: "bay2game", gameCode?: string, limit?: number, dryRun?: boolean }
 *
 * Defaults to a small batch: a full sweep is 200+ games and 200+ product calls,
 * which is unfriendly to a supplier's rate limit and slow to run synchronously.
 * Call it repeatedly, or per game.
 *
 * Note that synced variants are priced AT COST until staff set a retail price.
 * An unpriced SKU therefore cannot be sold at a loss, only at zero margin.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import type { SupplierAdapter } from "../_shared/suppliers/types.ts";
import { SupplierError } from "../_shared/suppliers/types.ts";
import { bay2game } from "../_shared/suppliers/bay2game.ts";

const ADAPTERS: Record<string, SupplierAdapter> = {
  bay2game,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("SUPPLIER_JOB_SECRET");
  if (expected && req.headers.get("x-job-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  let body: {
    supplier?: string;
    gameCode?: string;
    limit?: number;
    dryRun?: boolean;
  } = {};
  try {
    body = await req.json();
  } catch {
    // An empty body is fine; defaults apply.
  }

  const code = body.supplier ?? "bay2game";
  const adapter = ADAPTERS[code];
  if (!adapter) {
    return json({ error: "unknown_supplier", detail: code }, 400);
  }
  if (!adapter.configured()) {
    return json(
      {
        error: "supplier_not_configured",
        detail: `${code} has no API key. Set it with 'supabase secrets set'.`,
      },
      503
    );
  }

  const limit = Math.min(Math.max(body.limit ?? 3, 1), 25);
  const admin = adminClient();
  const results: Array<Record<string, unknown>> = [];
  let synced = 0;

  try {
    const allGames = await adapter.games();
    const games = body.gameCode
      ? allGames.filter((game) => game.gameCode === body.gameCode)
      : allGames.slice(0, limit);

    if (body.gameCode && games.length === 0) {
      return json({ error: "game_not_found", detail: body.gameCode }, 404);
    }

    for (const game of games) {
      try {
        const products = await adapter.products(game.gameCode);

        if (body.dryRun) {
          results.push({
            game: game.gameCode,
            name: game.name,
            fields: game.fields,
            products: products.length,
            sample: products.slice(0, 3),
          });
          continue;
        }

        const { data, error } = await admin.rpc("supplier_upsert_catalogue", {
          p_supplier_code: code,
          p_game_code: game.gameCode,
          p_name: game.name,
          p_image_url: game.imageUrl,
          p_summary: game.summary,
          p_required_fields: game.fields,
          p_products: products,
        });

        if (error) {
          results.push({ game: game.gameCode, error: error.message });
        } else {
          results.push({ game: game.gameCode, ...(data as object) });
          synced++;
        }
      } catch (error) {
        results.push({
          game: game.gameCode,
          error: error instanceof SupplierError ? error.message : String(error),
        });
      }
    }

    // Activating on success removes a footgun: set the API key, sync, then
    // wonder why nothing fulfils because is_active was still false.
    if (!body.dryRun && synced > 0) {
      await admin
        .from("suppliers")
        .update({ is_active: true })
        .eq("code", code);
    }

    return json({
      ok: true,
      supplier: code,
      total_games_available: allGames.length,
      processed: games.length,
      synced,
      activated: !body.dryRun && synced > 0,
      dryRun: body.dryRun ?? false,
      results,
    });
  } catch (error) {
    return json(
      {
        error: "sync_failed",
        detail: error instanceof SupplierError ? error.message : String(error),
      },
      502
    );
  }
});
