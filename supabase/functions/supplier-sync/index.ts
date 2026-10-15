/**
 * supplier-sync
 *
 * Pulls a supplier catalogue into your own products, variants and
 * supplier_skus, so the storefront can sell their inventory.
 *
 * POST { supplier?: "bay2game", gameCode?: string, limit?: number, offset?: number, dryRun?: boolean }
 *
 * Defaults to a small batch: a full sweep is 200+ games and 200+ product calls,
 * which is unfriendly to a supplier's rate limit and slow to run synchronously.
 * Page through with `offset`: the response's `next_offset` is the value to send
 * next, or null when the catalogue is done. Or sync one game with `gameCode`.
 *
 * Note that synced variants are priced AT COST until staff set a retail price.
 * An unpriced SKU therefore cannot be sold at a loss, only at zero margin.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import type { SupplierAdapter } from "../_shared/suppliers/types.ts";
import { fetchWithTimeout, SupplierError } from "../_shared/suppliers/types.ts";
import { bay2game } from "../_shared/suppliers/bay2game.ts";

const ADAPTERS: Record<string, SupplierAdapter> = {
  bay2game,
};

/**
 * The origin a BROWSER uses to reach Storage, or null when there is not one.
 *
 * Inside the local stack `SUPABASE_URL` is `http://kong:8000`, the
 * compose-network name. `storage.getPublicUrl()` prefixes with exactly that, so
 * the mirrored art was stored as a URL Chrome cannot resolve: the product page
 * stayed blank while the sync reported success.
 *
 * `STORAGE_PUBLIC_URL` overrides it. The name deliberately does not start with
 * `SUPABASE_`, because the CLI drops those keys from the function env file and
 * the override would never arrive. Returning null rather than the internal
 * origin keeps the failure visible: the caller warns instead of writing a URL
 * that cannot load.
 */
export function publicStorageBase(): string | null {
  const explicit = Deno.env.get("STORAGE_PUBLIC_URL");
  if (explicit) return explicit.replace(/\/+$/, "");

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  if (!url || /\/\/kong(:|\/|$)/.test(url)) return null;
  return url.replace(/\/+$/, "");
}

/**
 * Mirrors a supplier image into our own Storage bucket.
 *
 * Not a nicety. Bay2Game serves product art from cdn.camrapidsecure.com, which
 * sends no Access-Control-Allow-Origin header. Flutter web (CanvasKit) loads
 * images with fetch, so those images render fine on Android and iOS but are
 * invisible in a browser. Mirroring also removes the hotlink dependency: the
 * supplier can rename or delete their CDN paths without breaking our catalogue.
 *
 * Returns the public URL, or null to fall back to the original.
 */
export async function mirrorImage(
  admin: ReturnType<typeof adminClient>,
  supplierCode: string,
  gameCode: string,
  sourceUrl: string | null
): Promise<string | null> {
  if (!sourceUrl) return null;

  try {
    const res = await fetchWithTimeout(sourceUrl, {}, 20000);
    if (!res.ok) return null;

    const contentType = res.headers.get("content-type") ?? "image/webp";
    if (!contentType.startsWith("image/")) return null;

    const extension = contentType.includes("png")
      ? "png"
      : contentType.includes("jpeg") || contentType.includes("jpg")
        ? "jpg"
        : contentType.includes("avif")
          ? "avif"
          : "webp";

    const bytes = new Uint8Array(await res.arrayBuffer());
    if (bytes.byteLength === 0) return null;

    const path = `suppliers/${supplierCode}/${gameCode}.${extension}`;
    const { error } = await admin.storage
      .from("product-images")
      .upload(path, bytes, { contentType, upsert: true });

    if (error) return null;

    // Built by hand rather than via getPublicUrl(): that helper prefixes with
    // SUPABASE_URL, which is the internal origin locally. The object path below
    // is the documented public-object route.
    const base = publicStorageBase();
    if (!base) return null;

    return `${base}/storage/v1/object/public/product-images/${path}`;
  } catch {
    // A missing image must never fail a catalogue sync.
    return null;
  }
}

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
    offset?: number;
    dryRun?: boolean;
    mirrorImages?: boolean;
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

  // Mirroring needs an origin the browser can reach. Without one the art falls
  // back to the supplier's CDN, which sends no CORS header, so it renders on
  // mobile and is invisible on Flutter web. Surface that instead of writing a
  // dead URL and leaving the blank cards unexplained.
  const imageWarning =
    !body.dryRun && body.mirrorImages !== false && publicStorageBase() === null
      ? "storage_public_url_unset: mirrored images fall back to the supplier CDN, " +
        "which does not render in a browser. Set STORAGE_PUBLIC_URL in " +
        "supabase/functions/.env, then `supabase stop && supabase start`."
      : null;

  const limit = Math.min(Math.max(body.limit ?? 3, 1), 25);
  const offset = Math.max(Math.floor(body.offset ?? 0), 0);
  const admin = adminClient();
  const results: Array<Record<string, unknown>> = [];
  const skipped: Array<Record<string, unknown>> = [];
  let synced = 0;

  try {
    const allGames = await adapter.games();
    const games = body.gameCode
      ? allGames.filter((game) => game.gameCode === body.gameCode)
      : allGames.slice(offset, offset + limit);
    const nextOffset =
      !body.gameCode && offset + limit < allGames.length ? offset + limit : null;

    if (body.gameCode && games.length === 0) {
      return json({ error: "game_not_found", detail: body.gameCode }, 404);
    }

    for (const game of games) {
      // Skip games whose buyer fields cannot be passed to the supplier. Listing
      // one would mean taking the buyer's money and then refunding them.
      if (!adapter.canFulfil(game.fields)) {
        skipped.push({
          game: game.gameCode,
          name: game.name,
          fields: game.fields,
          reason: "fields_not_supported_by_supplier_order_api",
        });
        continue;
      }

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

        // Mirror into our own bucket so the art also renders on Flutter web,
        // and so we do not depend on the supplier's CDN paths.
        const imageUrl = body.mirrorImages === false
          ? game.imageUrl
          : (await mirrorImage(admin, code, game.gameCode, game.imageUrl)) ??
            game.imageUrl;

        const { data, error } = await admin.rpc("supplier_upsert_catalogue", {
          p_supplier_code: code,
          p_game_code: game.gameCode,
          p_name: game.name,
          p_image_url: imageUrl,
          p_summary: game.summary,
          // Definitions, not bare names: the app renders label_km/label_en and
          // create_order resolves `key`. An adapter with no label metadata
          // still gets a usable field, because the key labels itself.
          p_required_fields: adapter.fieldDefinitions
            ? adapter.fieldDefinitions(game.fields)
            : game.fields.map((key) => ({ key, label_km: key, label_en: key })),
          // The adapter speaks camelCase; the RPC reads snake_case keys off the
          // JSON. Passing the adapter objects straight through left
          // `product_code` null, so every variant insert died on the
          // product_variants.sku not-null constraint and nothing synced.
          //
          // `sort` is the supplier's own order, which is ascending price. It
          // keeps the variant chips on the product page stable.
          p_products: products.map((product, index) => ({
            product_code: product.productCode,
            name: product.name,
            price_usd: product.priceUsd,
            sort: index,
          })),
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
      offset: body.gameCode ? null : offset,
      next_offset: nextOffset,
      processed: games.length,
      synced,
      skipped: skipped.length,
      activated: !body.dryRun && synced > 0,
      dryRun: body.dryRun ?? false,
      skipped_games: skipped,
      ...(imageWarning ? { warning: imageWarning } : {}),
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
