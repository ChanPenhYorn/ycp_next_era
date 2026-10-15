import Image from "next/image";
import { notFound } from "next/navigation";
import { getLocale, getTranslations } from "next-intl/server";
import { getProductBySlug, getProductReviews } from "@/lib/catalog";
import { discountPercent, usd } from "@/lib/format";
import { BuyPanel } from "@/components/buy-panel";
import type { Metadata } from "next";

type Props = { params: Promise<{ locale: string; slug: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, slug } = await params;
  const product = await getProductBySlug(slug);
  if (!product) return {};

  const name = locale === "km" ? product.name_km : product.name_en;
  const summary =
    (locale === "km" ? product.summary_km : product.summary_en) ?? undefined;

  return { title: name, description: summary };
}

export default async function ProductPage({ params }: Props) {
  const { locale, slug } = await params;
  const [product, t, tc] = await Promise.all([
    getProductBySlug(slug),
    getTranslations("product"),
    getTranslations("common"),
  ]);

  if (!product) notFound();

  const reviews = await getProductReviews(product.id);

  const name = locale === "km" ? product.name_km : product.name_en;
  const description =
    (locale === "km" ? product.description_km : product.description_en) ??
    (locale === "km" ? product.summary_km : product.summary_en);
  const category = product.category
    ? locale === "km"
      ? product.category.name_km
      : product.category.name_en
    : null;
  const off = discountPercent(product.min_price_usd, product.compare_at_price_usd);

  return (
    <div className="space-y-8">
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_360px]">
        <div className="space-y-6">
          <div className="card overflow-hidden">
            <div className="relative aspect-[16/9] bg-ink-850">
              {product.image_url ? (
                <Image
                  src={product.image_url}
                  alt={name}
                  fill
                  sizes="(max-width: 1024px) 100vw, 640px"
                  className="object-cover"
                  priority
                  unoptimized
                />
              ) : (
                <div className="grid h-full place-items-center text-5xl">📦</div>
              )}
              {off !== null && (
                <span className="absolute left-3 top-3 rounded-md bg-danger-500 px-2 py-0.5 text-xs font-bold text-white">
                  -{off}%
                </span>
              )}
            </div>

            <div className="space-y-3 p-5">
              {category && (
                <p className="text-xs uppercase tracking-wide text-ink-400">{category}</p>
              )}
              <h1 className="text-xl font-bold text-white sm:text-2xl">{name}</h1>

              <div className="flex flex-wrap items-center gap-3 text-sm">
                {product.rating_count > 0 && (
                  <span className="text-warn-500">
                    ★ {product.rating_avg.toFixed(1)}
                    <span className="ml-1 text-ink-400">
                      ({product.rating_count})
                    </span>
                  </span>
                )}
                <span className="text-ink-400">
                  {tc("soldCount", { count: product.sold_count })}
                </span>
                {product.is_sold_out ? (
                  <span className="text-danger-500">{tc("outOfStock")}</span>
                ) : (
                  <span className="text-accent-500">✓ {tc("inStock")}</span>
                )}
              </div>

              {description && (
                <div className="whitespace-pre-line border-t border-ink-800 pt-4 text-sm leading-relaxed text-ink-200">
                  {description}
                </div>
              )}
            </div>
          </div>

          <section className="card p-5">
            <h2 className="text-sm font-bold text-white">{t("reviews")}</h2>
            {reviews.length === 0 ? (
              <p className="mt-3 text-sm text-ink-400">{t("noReviews")}</p>
            ) : (
              <ul className="mt-3 space-y-3">
                {reviews.map((review) => (
                  <li key={review.id} className="border-b border-ink-800 pb-3 last:border-0">
                    <div className="flex items-center justify-between">
                      <span className="text-sm text-ink-200">
                        {review.author_name ?? "—"}
                      </span>
                      <span className="text-xs text-warn-500">
                        {"★".repeat(review.rating)}
                      </span>
                    </div>
                    {review.body && (
                      <p className="mt-1 text-sm text-ink-400">{review.body}</p>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>

        <aside className="lg:sticky lg:top-20 lg:self-start">
          <BuyPanel
            productId={product.id}
            slug={product.slug}
            kind={product.kind}
            requiresFields={product.requires_fields}
            variants={product.variants}
            locale={locale}
            labels={{
              quantity: t("quantity"),
              buyNow: tc("buyNow"),
              requiredInfo: t("requiredInfo"),
              deliveryInstant: t("deliveryInstant"),
              deliveryManual: t("deliveryManual"),
              deliveryTime: t("deliveryTime"),
              inStock: tc("inStock"),
              outOfStock: tc("outOfStock"),
            }}
          />
          <p className="mt-3 text-center text-xs text-ink-400">
            {usd(product.min_price_usd)} · ABA KHQR
          </p>
        </aside>
      </div>
    </div>
  );
}
