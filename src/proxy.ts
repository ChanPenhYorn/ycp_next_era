import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";

// Next.js 16 renamed middleware.ts to proxy.ts.
export default createMiddleware(routing);

export const config = {
  // Everything except /api, /_next, /_vercel and files with an extension.
  matcher: "/((?!api|_next|_vercel|.*\\..*).*)",
};
