import type { Metadata } from "next";
import { Inter, Noto_Sans_Khmer } from "next/font/google";
import { NextIntlClientProvider } from "next-intl";
import { getTranslations } from "next-intl/server";
import { notFound } from "next/navigation";
import { hasLocale } from "next-intl";
import { Suspense } from "react";
import { routing } from "@/i18n/routing";
import { Header } from "@/components/header";
import { HeaderUser } from "@/components/header-user";
import { Footer } from "@/components/footer";
import { getSettings } from "@/lib/catalog";
import "../globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });
const khmer = Noto_Sans_Khmer({
  subsets: ["khmer"],
  variable: "--font-khmer",
  display: "swap",
});

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "home" });

  return {
    title: {
      default: `${t("heroTitle")} | YCP Store`,
      template: "%s | YCP Store",
    },
    description: t("heroSubtitle"),
  };
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }

  const settings = await getSettings();

  return (
    <html
      lang={locale}
      className={`${inter.variable} ${khmer.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col">
        <NextIntlClientProvider>
          <Header
            siteName={settings.site_name}
            userSlot={
              <Suspense fallback={<div className="skeleton h-9 w-20" />}>
                <HeaderUser />
              </Suspense>
            }
          />
          <main className="flex-1 mx-auto w-full max-w-6xl px-4 py-6">{children}</main>
          <Footer settings={settings} />
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
