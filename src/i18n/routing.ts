import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["km", "en"],
  defaultLocale: "km",
  // Khmer is the default, so URLs stay clean at "/" and English lives at "/en".
  localePrefix: "as-needed",
});

export type Locale = (typeof routing.locales)[number];
