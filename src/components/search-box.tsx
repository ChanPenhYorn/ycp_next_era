"use client";

import { useRouter } from "@/i18n/navigation";
import { useState } from "react";

export function SearchBox({ placeholder }: { placeholder: string }) {
  const router = useRouter();
  const [value, setValue] = useState("");

  return (
    <form
      role="search"
      onSubmit={(event) => {
        event.preventDefault();
        const term = value.trim();
        router.push(term ? `/products?q=${encodeURIComponent(term)}` : "/products");
      }}
      className="relative"
    >
      <input
        type="search"
        name="q"
        value={value}
        onChange={(event) => setValue(event.target.value)}
        placeholder={placeholder}
        className="w-full rounded-xl border border-ink-800 bg-ink-900 px-3 py-2 text-sm text-white placeholder:text-ink-400 focus:border-brand-500 focus:outline-none"
      />
    </form>
  );
}
