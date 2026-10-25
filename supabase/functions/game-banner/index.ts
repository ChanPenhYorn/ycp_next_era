/**
 * game-banner
 *
 * Resolves the wide spotlight art for one product and stores it in
 * `products.banner_url`.
 *
 * POST { productId: number, url?: string, force?: boolean }
 * -> { banner_url, matched_name, source, width, height }
 *
 * A blank `url` searches IGDB for the product's English name, scores the result
 * against it, and refuses a weak match (`no_banner_found`) rather than putting
 * the wrong game on the front page. An explicit `url` skips IGDB entirely, so
 * staff can still set art when IGDB is not configured or has no entry.
 *
 * The chosen image is mirrored into `product-images/banners/<slug>` before the
 * URL is written: IGDB permits hotlinking, but the mirror keeps the storefront
 * independent of their paths and CORS policy. If the mirror fails the IGDB URL
 * is kept, which still renders; a staff-supplied URL that cannot be fetched is
 * rejected instead of being written untested.
 *
 * Staff-only. The JWT proves someone is signed in; `is_staff()` proves the
 * caller may edit the catalogue. A valid customer token must not be enough.
 */
import {
  adminClient,
  json,
  preflight,
  requireUser,
} from "../_shared/supabase.ts";
import { findBanner, igdbConfigured } from "../_shared/igdb.ts";
import { imageExtension, mirrorBytes } from "../_shared/storage.ts";

type ProductRow = {
  id: number;
  slug: string;
  name_en: string;
  banner_url: string | null;
};

/** Only http(s) is accepted; anything else is a paste mistake or worse. */
function imageUrl(raw: string): string | null {
  try {
    const url = new URL(raw);
    return url.protocol === "http:" || url.protocol === "https:"
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

/**
 * Copies `sourceUrl` into `product-images/banners/` and returns its public URL,
 * or null when it is not a usable image.
 */
async function mirrorBanner(
  admin: ReturnType<typeof adminClient>,
  slug: string,
  sourceUrl: string,
): Promise<string | null> {
  try {
    const res = await fetch(sourceUrl, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) return null;

    const contentType = res.headers.get("content-type");
    const extension = imageExtension(contentType);
    if (!contentType || !extension) return null;

    const bytes = new Uint8Array(await res.arrayBuffer());
    return await mirrorBytes(
      admin,
      `banners/${slug}.${extension}`,
      bytes,
      contentType,
    );
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const auth = await requireUser(req);
  if (!auth.ok) return auth.response;

  const { data: isStaff, error: staffError } = await auth.client.rpc(
    "is_staff",
  );
  if (staffError) {
    return json(
      { error: "staff_check_failed", detail: staffError.message },
      500,
    );
  }
  if (isStaff !== true) return json({ error: "not_authorized" }, 403);

  let body: { productId?: number; url?: string; force?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const productId = Number(body.productId);
  if (!Number.isInteger(productId) || productId <= 0) {
    return json({ error: "product_id_required" }, 400);
  }

  const explicit = typeof body.url === "string" ? body.url.trim() : "";
  const force = body.force === true;

  const admin = adminClient();
  const { data: product, error: productError } = await admin
    .from("products")
    .select("id, slug, name_en, banner_url")
    .eq("id", productId)
    .maybeSingle<ProductRow>();

  if (productError) {
    return json({
      error: "product_lookup_failed",
      detail: productError.message,
    }, 500);
  }
  if (!product) return json({ error: "product_not_found" }, 404);

  /** Writes the resolved URL and answers in the shape the app expects. */
  const save = async (
    bannerUrl: string | null,
    extra: Record<string, unknown>,
  ) => {
    const { error } = await admin
      .from("products")
      .update({ banner_url: bannerUrl })
      .eq("id", productId);
    if (error) {
      return json({ error: "banner_save_failed", detail: error.message }, 500);
    }
    return json({ banner_url: bannerUrl, ...extra });
  };

  if (explicit) {
    const source = imageUrl(explicit);
    if (!source) return json({ error: "invalid_url", detail: explicit }, 400);

    const mirrored = await mirrorBanner(admin, product.slug, source);
    if (!mirrored) {
      return json({ error: "banner_download_failed", detail: source }, 502);
    }
    return await save(mirrored, { source: "manual", matched_name: null });
  }

  // An existing banner is kept unless staff asked to re-resolve. This is what
  // makes the button cheap: a second press without `force` is a no-op.
  if (product.banner_url && !force) {
    return json({
      banner_url: product.banner_url,
      matched_name: null,
      source: "existing",
    });
  }

  if (!igdbConfigured()) {
    return json(
      {
        error: "igdb_not_configured",
        detail:
          "Set IGDB_CLIENT_ID and IGDB_CLIENT_SECRET, or paste an image URL instead.",
      },
      503,
    );
  }

  const candidate = await findBanner(product.name_en);
  if (!candidate) return json({ error: "no_banner_found" }, 404);

  const mirrored = await mirrorBanner(admin, product.slug, candidate.url);
  return await save(mirrored ?? candidate.url, {
    matched_name: candidate.name,
    source: mirrored
      ? `igdb_${candidate.source}`
      : `igdb_${candidate.source}_hotlink`,
    width: candidate.width,
    height: candidate.height,
  });
});
