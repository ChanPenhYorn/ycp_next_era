import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import type { PublicSettings } from "@/lib/types";

export async function Footer({ settings }: { settings: PublicSettings }) {
  const t = await getTranslations("footer");
  const year = new Date().getFullYear();

  return (
    <footer className="mt-12 border-t border-ink-800 bg-ink-950/80">
      <div className="mx-auto grid w-full max-w-6xl gap-8 px-4 py-10 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <h2 className="text-sm font-semibold text-white">{t("about")}</h2>
          <p className="mt-2 text-sm leading-relaxed text-ink-400">{t("aboutText")}</p>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-white">{t("quickLinks")}</h2>
          <ul className="mt-2 space-y-1.5 text-sm text-ink-400">
            <li><Link href="/" className="hover:text-white">{settings.site_name}</Link></li>
            <li><Link href="/products" className="hover:text-white">{t("quickLinks")}</Link></li>
            <li><Link href="/orders" className="hover:text-white">{t("help")}</Link></li>
          </ul>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-white">{t("contact")}</h2>
          <ul className="mt-2 space-y-1.5 text-sm text-ink-400">
            {settings.support_telegram && (
              <li>
                <a href={settings.support_telegram} className="hover:text-white">
                  Telegram
                </a>
              </li>
            )}
            {settings.support_email && (
              <li>
                <a href={`mailto:${settings.support_email}`} className="hover:text-white">
                  {settings.support_email}
                </a>
              </li>
            )}
            <li>Phnom Penh, Cambodia</li>
          </ul>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-white">{t("weAccept")}</h2>
          <div className="mt-2 flex flex-wrap gap-2">
            <span className="chip">ABA KHQR</span>
            <span className="chip">ABA Pay</span>
            <span className="chip">USD / KHR</span>
          </div>
        </div>
      </div>

      <div className="border-t border-ink-800 py-4 text-center text-xs text-ink-400">
        © {year} {settings.site_name}. {t("rights")}
      </div>
    </footer>
  );
}
