"use client";

import { useLocale } from "next-intl";
import { useParams } from "next/navigation";
import { useTransition } from "react";
import { usePathname, useRouter } from "@/i18n/navigation";
import { routing } from "@/i18n/routing";

const LABELS: Record<string, string> = { km: "ខ្មែរ", en: "EN" };

export function LanguageSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const params = useParams();
  const [pending, startTransition] = useTransition();

  const next = routing.locales.find((l) => l !== locale) ?? locale;

  function switchTo() {
    startTransition(() => {
      router.replace(
        // @ts-expect-error pathname and params are typed loosely by next-intl
        { pathname, params },
        { locale: next }
      );
    });
  }

  return (
    <button
      type="button"
      onClick={switchTo}
      disabled={pending}
      className="rounded-lg border border-ink-700 px-2.5 py-1.5 text-xs font-medium text-ink-200 hover:border-ink-600 hover:text-white disabled:opacity-50"
    >
      {LABELS[next] ?? next.toUpperCase()}
    </button>
  );
}
