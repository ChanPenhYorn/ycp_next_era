import { getLocale, getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { ProductCard } from "@/components/product-card";
import { getCategories, getProducts } from "@/lib/catalog";

export default async function HomePage() {
  const locale = await getLocale();
  const t = await getTranslations("home");
  const tc = await getTranslations("common");

  const [featured, allProducts, categories] = await Promise.all([
    getProducts({ featuredOnly: true, limit: 8 }),
    getProducts({ limit: 12 }),
    getCategories(),
  ]);

  const cardLabels = {
    inStock: tc("inStock"),
    outOfStock: tc("outOfStock"),
    from: tc("from"),
  };

  return (
    <div className="space-y-10">
      <section className="card relative overflow-hidden p-6 sm:p-10">
        <div className="relative z-10 max-w-2xl">
          <span className="chip">ABA KHQR · KHQR</span>
          <h1 className="mt-4 text-2xl font-black leading-snug text-white sm:text-4xl">
            {t("heroTitle")}
          </h1>
          <p className="mt-3 text-sm text-ink-400 sm:text-base">{t("heroSubtitle")}</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/products" className="btn-primary">
              {tc("buyNow")}
            </Link>
            <Link
              href="/products"
              className="rounded-lg border border-ink-700 px-4 py-2.5 text-sm text-ink-200 hover:border-ink-600 hover:text-white"
            >
              {t("categories")}
            </Link>
          </div>
        </div>
      </section>

      <section className="grid gap-3 sm:grid-cols-3">
        {[t("trustInstant"), t("trustPayment"), t("trustSupport")].map((line) => (
          <div key={line} className="card flex items-center gap-3 p-4 text-sm text-ink-200">
            <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-accent-500/15 text-accent-500">
              ✓
            </span>
            {line}
          </div>
        ))}
      </section>

      <section>
        <h2 className="mb-4 text-lg font-bold text-white">{t("categories")}</h2>
        <div className="flex flex-wrap gap-2">
          {categories.map((category) => (
            <Link
              key={category.id}
              href={`/products?category=${category.slug}`}
              className="chip hover:border-brand-500 hover:text-white"
            >
              {locale === "km" ? category.name_km : category.name_en}
            </Link>
          ))}
        </div>
      </section>

      {featured.length > 0 && (
        <section>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-bold text-white">{t("featured")}</h2>
            <Link href="/products" className="text-sm text-brand-400 hover:text-brand-500">
              {t("allProducts")}
            </Link>
          </div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {featured.map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                locale={locale}
                labels={cardLabels}
              />
            ))}
          </div>
        </section>
      )}

      <section>
        <h2 className="mb-4 text-lg font-bold text-white">{t("allProducts")}</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {allProducts.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              locale={locale}
              labels={cardLabels}
            />
          ))}
        </div>
      </section>
    </div>
  );
}
