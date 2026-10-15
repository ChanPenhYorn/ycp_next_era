import { getSessionUser } from "@/lib/supabase/server";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { UserMenu } from "./user-menu";

/**
 * Reads cookies() through the Supabase server client, so it is a runtime
 * component. The layout renders it inside <Suspense>.
 */
export async function HeaderUser() {
  const t = await getTranslations("common");
  const user = await getSessionUser();

  if (!user) {
    return (
      <Link href="/login" className="btn-primary text-sm">
        {t("login")}
      </Link>
    );
  }

  return (
    <UserMenu
      email={user.email ?? ""}
      labels={{
        account: t("account"),
        orders: t("orders"),
        logout: t("logout"),
      }}
    />
  );
}
