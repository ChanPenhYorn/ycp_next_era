import Image from "next/image";
import { Link } from "@/i18n/navigation";
import { discountPercent, usd } from "@/lib/format";
import type { ProductCard as ProductCardType } from "@/lib/types";

export function ProductCard({
  product,
  locale,
  labels,
}: {
  product: ProductCardType;
  locale: string;
  labels: { inStock: string; outOfStock: string; from: string };
}) {
  const name = locale === "km" ? product.name_km : product.name_en;
  const category = product.category
    ? locale === "km"
      ? product.category.name_km
      : product.category.name_en
    : null;
  const off = discountPercent(product.min_price_usd, product.compare_at_price_usd);
  const multiPrice = product.max_price_usd > product.min_price_usd;

  return (
    <Link href={`/products/${product.slug}`} className="group block">
      <article className="card overflow-hidden transition-colors group-hover:border-brand-500/60">
        <div className="relative aspect-[4/3] overflow-hidden bg-ink-850">
          {product.image_url ? (
            <Image
              src={product.image_url}
              alt={name}
              fill
              sizes="(max-width: 640px) 50vw, 220px"
              className="object-cover transition-transform duration-300 group-hover:scale-[1.04]"
              unoptimized
            />
          ) : (
            <div className="grid h-full place-items-center text-3xl">📦</div>
          )}

          {off !== null && (
            <span className="absolute left-2 top-2 rounded-md bg-danger-500 px-1.5 py-0.5 text-[11px] font-bold text-white">
              -{off}%
            </span>
          )}
          {product.is_sold_out && (
            <span className="absolute right-2 top-2 rounded-md bg-ink-950/85 px-1.5 py-0.5 text-[11px] font-semibold text-ink-200">
              {labels.outOfStock}
            </span>
          )}
        </div>

        <div className="p-3">
          {category && (
            <p className="truncate text-[11px] uppercase tracking-wide text-ink-400">
              {category}
            </p>
          )}
          <h3 className="mt-1 line-clamp-2 text-sm font-semibold text-white">{name}</h3>

          <div className="mt-2 flex items-end justify-between gap-2">
            <div>
              {multiPrice && (
                <span className="mr-1 text-[11px] text-ink-400">{labels.from}</span>
              )}
              <span className="text-base font-bold text-white">
                {usd(product.min_price_usd)}
              </span>
              {product.compare_at_price_usd &&
                product.compare_at_price_usd > product.min_price_usd && (
                  <span className="ml-1.5 text-xs text-ink-400 line-through">
                    {usd(product.compare_at_price_usd)}
                  </span>
                )}
            </div>

            {product.rating_count > 0 && (
              <span className="text-[11px] text-warn-500">
                ★ {product.rating_avg.toFixed(1)}
                <span className="ml-1 text-ink-400">({product.rating_count})</span>
              </span>
            )}
          </div>

          <p className="mt-1.5 text-[11px] text-accent-500">
            {product.is_sold_out ? labels.outOfStock : `✓ ${labels.inStock}`}
          </p>
        </div>
      </article>
    </Link>
  );
}
