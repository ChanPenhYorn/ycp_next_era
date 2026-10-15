import "server-only";
import { cacheLife, cacheTag } from "next/cache";
import { publicClient } from "./supabase/public";
import type {
  Category,
  ProductCard,
  ProductDetail,
  PublicSettings,
  Review,
  Variant,
} from "./types";

export const CATALOG_TAG = "catalog";

/**
 * Everything below reads through the anon key with no cookies, so the results
 * are request-independent and safe to cache. Admin writes call revalidateTag.
 */

export async function getSettings(): Promise<PublicSettings> {
  "use cache";
  cacheLife("hours");
  cacheTag(CATALOG_TAG);

  const { data } = await publicClient
    .from("public_settings")
    .select(
      "site_name, support_telegram, support_email, usd_to_khr, order_ttl_minutes, khqr_account_id, khqr_merchant_name, khqr_merchant_city, is_maintenance"
    )
    .maybeSingle();

  return (
    data ?? {
      site_name: "YCP Store",
      support_telegram: null,
      support_email: null,
      usd_to_khr: 4100,
      order_ttl_minutes: 15,
      khqr_account_id: null,
      khqr_merchant_name: null,
      khqr_merchant_city: null,
      is_maintenance: false,
    }
  );
}

export async function getCategories(): Promise<Category[]> {
  "use cache";
  cacheLife("hours");
  cacheTag(CATALOG_TAG);

  const { data } = await publicClient
    .from("categories")
    .select("id, slug, name_km, name_en, icon_url, sort_order")
    .order("sort_order");

  return data ?? [];
}

export async function getProducts(options?: {
  categorySlug?: string;
  search?: string;
  featuredOnly?: boolean;
  limit?: number;
}): Promise<ProductCard[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag(CATALOG_TAG);

  const limit = options?.limit ?? 48;

  let query = publicClient
    .from("products")
    .select(
      `id, slug, name_km, name_en, summary_km, summary_en, image_url, kind,
       rating_avg, rating_count, sold_count,
       category:categories ( slug, name_km, name_en ),
       variants:product_variants ( id, price_usd, compare_at_price_usd, stock_mode )`
    )
    .order("sort_order")
    .limit(limit);

  if (options?.featuredOnly) query = query.eq("is_featured", true);
  if (options?.categorySlug) query = query.eq("category.slug", options.categorySlug);
  if (options?.search) {
    const term = options.search.replace(/[%,]/g, " ").trim();
    query = query.or(
      `name_km.ilike.%${term}%,name_en.ilike.%${term}%,slug.ilike.%${term}%`
    );
  }

  const { data, error } = await query;
  if (error || !data) return [];

  const rows = data as unknown as Array<
    Omit<ProductCard, "min_price_usd" | "max_price_usd" | "total_stock" | "is_sold_out"> & {
      variants: Array<{
        id: number;
        price_usd: number;
        compare_at_price_usd: number | null;
        stock_mode: "stock" | "unlimited";
      }>;
    }
  >;

  const allVariantIds = rows.flatMap((r) => r.variants.map((v) => v.id));
  const stockByVariant = await stockForVariants(allVariantIds);

  return rows.map((row) => {
    const prices = row.variants.map((v) => Number(v.price_usd));
    const compares = row.variants
      .map((v) => (v.compare_at_price_usd ? Number(v.compare_at_price_usd) : null))
      .filter((v): v is number => v !== null);

    const stockValues = row.variants.map((v) =>
      v.stock_mode === "unlimited" ? Number.POSITIVE_INFINITY : (stockByVariant[v.id] ?? 0)
    );
    const totalStock = stockValues.every((s) => s === Number.POSITIVE_INFINITY)
      ? null
      : stockValues.reduce((a, b) => a + (Number.isFinite(b) ? b : 0), 0);

    return {
      id: row.id,
      slug: row.slug,
      name_km: row.name_km,
      name_en: row.name_en,
      summary_km: row.summary_km,
      summary_en: row.summary_en,
      image_url: row.image_url,
      kind: row.kind,
      rating_avg: Number(row.rating_avg),
      rating_count: row.rating_count,
      sold_count: row.sold_count,
      category: row.category,
      min_price_usd: prices.length ? Math.min(...prices) : 0,
      max_price_usd: prices.length ? Math.max(...prices) : 0,
      compare_at_price_usd: compares.length ? Math.max(...compares) : null,
      total_stock: totalStock,
      is_sold_out: totalStock !== null && totalStock <= 0,
    };
  });
}

export async function getProductBySlug(slug: string): Promise<ProductDetail | null> {
  "use cache";
  cacheLife("minutes");
  cacheTag(CATALOG_TAG);

  const { data, error } = await publicClient
    .from("products")
    .select(
      `id, slug, name_km, name_en, summary_km, summary_en, description_km, description_en,
       image_url, kind, requires_fields, rating_avg, rating_count, sold_count,
       category:categories ( id, slug, name_km, name_en, icon_url, sort_order )`
    )
    .eq("slug", slug)
    .maybeSingle();

  if (error || !data) return null;

  const { data: variantRows } = await publicClient
    .from("product_variants")
    .select(
      "id, sku, label_km, label_en, price_usd, compare_at_price_usd, stock_mode, min_qty, max_qty, sort_order"
    )
    .eq("product_id", data.id)
    .order("sort_order");

  const variants = (variantRows ?? []) as unknown as Variant[];
  const stockByVariant = await stockForVariants(variants.map((v) => v.id));

  const withStock: Variant[] = variants.map((v) => ({
    ...v,
    price_usd: Number(v.price_usd),
    compare_at_price_usd: v.compare_at_price_usd
      ? Number(v.compare_at_price_usd)
      : null,
    in_stock: v.stock_mode === "unlimited" ? null : (stockByVariant[v.id] ?? 0),
  }));

  const prices = withStock.map((v) => v.price_usd);
  const compares = withStock
    .map((v) => v.compare_at_price_usd)
    .filter((v): v is number => v !== null);
  const totalStock = withStock.every((v) => v.stock_mode === "unlimited")
    ? null
    : withStock.reduce((a, v) => a + (v.in_stock ?? 0), 0);

  return {
    ...(data as unknown as ProductDetail),
    rating_avg: Number(data.rating_avg),
    requires_fields: (data.requires_fields ?? []) as ProductDetail["requires_fields"],
    variants: withStock,
    min_price_usd: prices.length ? Math.min(...prices) : 0,
    max_price_usd: prices.length ? Math.max(...prices) : 0,
    compare_at_price_usd: compares.length ? Math.max(...compares) : null,
    total_stock: totalStock,
    is_sold_out: totalStock !== null && totalStock <= 0,
  };
}

export async function getProductReviews(productId: number): Promise<Review[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag(CATALOG_TAG);

  const { data } = await publicClient
    .from("reviews")
    .select("id, rating, body, created_at, author:profile_names ( display_name )")
    .eq("product_id", productId)
    .eq("is_approved", true)
    .order("created_at", { ascending: false })
    .limit(20);

  type Row = { id: number; rating: number; body: string | null; created_at: string; author: { display_name: string | null } | null };
  return ((data ?? []) as unknown as Row[]).map((r) => ({
    id: r.id,
    rating: r.rating,
    body: r.body,
    created_at: r.created_at,
    author_name: r.author?.display_name ?? null,
  }));
}

async function stockForVariants(variantIds: number[]): Promise<Record<number, number>> {
  "use cache";
  cacheLife("seconds");
  cacheTag(CATALOG_TAG);

  if (variantIds.length === 0) return {};

  const { data } = await publicClient
    .from("variant_stock")
    .select("variant_id, in_stock")
    .in("variant_id", variantIds);

  const out: Record<number, number> = {};
  for (const row of (data ?? []) as Array<{ variant_id: number; in_stock: number | null }>) {
    out[row.variant_id] = row.in_stock ?? 0;
  }
  return out;
}
