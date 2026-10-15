import { Suspense } from "react";
import { getLocale, getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { ProductCard } from "@/components/product-card";
import { getCategories, getProducts } from "@/lib/catalog";

type Props = {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ category?: string; q?: string }>;
};

export default function ProductsPage({ searchParams }: Props) {
  // searchParams is request-dependent, so the listing streams behind Suspense
  // while the shell (heading, category chips) ships statically.
  return (
    <div className="space-y-6">
      <ProductsHeading />
      <Suspense fallback={<ProductsSkeleton />}>
        <ProductGrid searchParams={searchParams} />
      </Suspense>
    </div>
  );
}

async function ProductsHeading() {
  const t = await getTranslations("home");
  const categories = await getCategories();

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-bold text-white">{t("allProducts")}</h1>
      <div className="flex flex-wrap gap-2">
        <Link href="/products" className="chip hover:border-brand-500 hover:text-white">
          {t("categories")}
        </Link>
        {categories.map((category) => (
          <Link
            key={category.id}
            href={`/products?category=${category.slug}`}
            className="chip hover:border-brand-500 hover:text-white"
          >
            {category.slug}
          </Link>
        ))}
      </div>
    </div>
  );
}

async function ProductGrid({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; q?: string }>;
}) {
  const [locale, tc, { category, q }] = await Promise.all([
    getLocale(),
    getTranslations("common"),
    searchParams,
  ]);

  const products = await getProducts({ categorySlug: category, search: q, limit: 48 });

  if (products.length === 0) {
    return <p className="card p-8 text-center text-sm text-ink-400">{tc("outOfStock")}</p>;
  }

  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
      {products.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          locale={locale}
          labels={{ inStock: tc("inStock"), outOfStock: tc("outOfStock"), from: tc("from") }}
        />
      ))}
    </div>
  );
}

function ProductsSkeleton() {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
      {Array.from({ length: 8 }).map((_, index) => (
        <div key={index} className="card overflow-hidden">
          <div className="skeleton aspect-[4/3] rounded-none" />
          <div className="space-y-2 p-3">
            <div className="skeleton h-3 w-16" />
            <div className="skeleton h-3 w-full" />
            <div className="skeleton h-4 w-12" />
          </div>
        </div>
      ))}
    </div>
  );
}
