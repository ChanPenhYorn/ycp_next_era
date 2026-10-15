import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { LanguageSwitcher } from "./language-switcher";
import { SearchBox } from "./search-box";

export async function Header({
  siteName,
  userSlot,
}: {
  siteName: string;
  userSlot: React.ReactNode;
}) {
  const t = await getTranslations("common");

  return (
    <header className="sticky top-0 z-40 border-b border-ink-800/80 bg-ink-950/85 backdrop-blur">
      <div className="mx-auto flex w-full max-w-6xl items-center gap-3 px-4 py-3">
        <Link href="/" className="flex items-center gap-2 shrink-0">
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-brand-500 text-sm font-black text-white">
            YC
          </span>
          <span className="hidden text-sm font-semibold text-white sm:block">
            {siteName}
          </span>
        </Link>

        <div className="min-w-0 flex-1">
          <SearchBox placeholder={t("search")} />
        </div>

        <nav className="flex items-center gap-2 shrink-0">
          <LanguageSwitcher />
          <Link
            href="/products"
            className="hidden rounded-lg px-3 py-2 text-sm text-ink-200 hover:text-white sm:block"
          >
            {t("all")}
          </Link>
          {userSlot}
        </nav>
      </div>
    </header>
  );
}
