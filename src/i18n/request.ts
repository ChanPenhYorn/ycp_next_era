import { getRequestConfig } from "next-intl/server";
import { hasLocale } from "next-intl";
import { notFound } from "next/navigation";
import * as rootParams from "next/root-params";
import { routing } from "./routing";

export default getRequestConfig(async ({ locale }) => {
  // An explicit locale (getTranslations({locale})) wins over the segment.
  if (!locale) {
    const paramValue = await rootParams.locale();
    if (hasLocale(routing.locales, paramValue)) {
      locale = paramValue;
    } else {
      notFound();
    }
  }

  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
    timeZone: "Asia/Phnom_Penh",
    formats: {
      number: {
        usd: { style: "currency", currency: "USD", maximumFractionDigits: 2 },
        khr: { style: "currency", currency: "KHR", maximumFractionDigits: 0 },
      },
    },
  };
});
