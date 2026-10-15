"use client";

import { useState } from "react";
import { Link, useRouter } from "@/i18n/navigation";
import { createBrowserSupabase } from "@/lib/supabase/client";

export function UserMenu({
  email,
  labels,
}: {
  email: string;
  labels: { account: string; orders: string; logout: string };
}) {
  const [open, setOpen] = useState(false);
  const router = useRouter();

  async function signOut() {
    const supabase = createBrowserSupabase();
    await supabase.auth.signOut();
    setOpen(false);
    router.refresh();
  }

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="grid h-9 w-9 place-items-center rounded-full border border-ink-700 bg-ink-850 text-sm font-semibold text-white"
        aria-label={labels.account}
      >
        {email.slice(0, 1).toUpperCase()}
      </button>

      {open && (
        <div className="absolute right-0 mt-2 w-52 card p-1.5 shadow-xl">
          <p className="truncate px-3 py-2 text-xs text-ink-400">{email}</p>
          <Link
            href="/orders"
            onClick={() => setOpen(false)}
            className="block rounded-lg px-3 py-2 text-sm hover:bg-ink-800"
          >
            {labels.orders}
          </Link>
          <button
            type="button"
            onClick={signOut}
            className="block w-full rounded-lg px-3 py-2 text-left text-sm text-danger-500 hover:bg-ink-800"
          >
            {labels.logout}
          </button>
        </div>
      )}
    </div>
  );
}
