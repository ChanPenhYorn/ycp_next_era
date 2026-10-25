/**
 * Storage helpers shared by the functions that write product art.
 *
 * Two rules they encode:
 *
 * 1. Public URLs are built from `STORAGE_PUBLIC_URL`, not `SUPABASE_URL`.
 *    Locally `SUPABASE_URL` is `http://kong:8000`, the compose-network name,
 *    which no browser can resolve. Without the override the mirrored art was
 *    stored with a URL Chrome could not load and the page stayed blank.
 * 2. Art is always mirrored into `product-images`. Supplier CDNs and IGDB send
 *    no `Access-Control-Allow-Origin`, and Flutter web loads images with
 *    `fetch`, so a hotlinked image renders on mobile and disappears in a
 *    browser. The mirror also removes the dependency on a third party's paths.
 */
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

/** The origin a BROWSER uses to reach Storage, or null when there is none. */
export function publicStorageBase(): string | null {
  const explicit = Deno.env.get("STORAGE_PUBLIC_URL");
  if (explicit) return explicit.replace(/\/+$/, "");

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  if (!url || /\/\/kong(:|\/|$)/.test(url)) return null;
  return url.replace(/\/+$/, "");
}

const EXTENSIONS: Array<[string, string]> = [
  ["png", "png"],
  ["jpeg", "jpg"],
  ["jpg", "jpg"],
  ["avif", "avif"],
  ["webp", "webp"],
];

/** File extension for an image content type, or null when it is not an image. */
export function imageExtension(contentType: string | null): string | null {
  if (!contentType || !contentType.startsWith("image/")) return null;
  for (const [needle, extension] of EXTENSIONS) {
    if (contentType.includes(needle)) return extension;
  }
  return null;
}

/** Uploads bytes to `product-images` and returns the public URL, or null. */
export async function mirrorBytes(
  admin: SupabaseClient,
  path: string,
  bytes: Uint8Array,
  contentType: string
): Promise<string | null> {
  if (bytes.byteLength === 0) return null;

  const { error } = await admin.storage
    .from("product-images")
    .upload(path, bytes, { contentType, upsert: true });
  if (error) return null;

  const base = publicStorageBase();
  if (!base) return null;
  return `${base}/storage/v1/object/public/product-images/${path}`;
}

/** Downloads `sourceUrl` into `product-images/<path>`; null on any failure. */
export async function mirrorFromUrl(
  admin: SupabaseClient,
  path: string,
  sourceUrl: string,
  timeoutMs = 20000
): Promise<string | null> {
  try {
    const res = await fetch(sourceUrl, { signal: AbortSignal.timeout(timeoutMs) });
    if (!res.ok) return null;

    const contentType = res.headers.get("content-type");
    if (!imageExtension(contentType)) return null;

    const bytes = new Uint8Array(await res.arrayBuffer());
    return await mirrorBytes(admin, path, bytes, contentType!);
  } catch {
    // A missing image must never fail a catalogue sync or a banner fetch.
    return null;
  }
}

/**
 * Mirrors a supplier's game art under `suppliers/<supplierCode>/<gameCode>`.
 *
 * Returns the public URL, or null to fall back to the original.
 */
export async function mirrorImage(
  admin: SupabaseClient,
  supplierCode: string,
  gameCode: string,
  sourceUrl: string | null
): Promise<string | null> {
  if (!sourceUrl) return null;

  const probe = await fetch(sourceUrl, {
    signal: AbortSignal.timeout(20000),
  }).catch(() => null);
  if (!probe || !probe.ok) return null;

  const contentType = probe.headers.get("content-type");
  const extension = imageExtension(contentType);
  if (!extension) return null;

  const bytes = new Uint8Array(await probe.arrayBuffer());
  return mirrorBytes(
    admin,
    `suppliers/${supplierCode}/${gameCode}.${extension}`,
    bytes,
    contentType!
  );
}
