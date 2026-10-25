/**
 * IGDB client for the `game-banner` function.
 *
 * IGDB (https://api-docs.igdb.com) is the game database behind Twitch. It has
 * the thing a supplier catalogue lacks: wide key art. Bay2Game ships one square
 * image per game, which is right for a card and wrong for the home spotlight.
 *
 * Auth is a Twitch app (`IGDB_CLIENT_ID` + `IGDB_CLIENT_SECRET`) exchanged for
 * an app access token. The token lasts ~60 days; it is cached in module scope,
 * which survives warm invocations, and re-fetched when it nears expiry.
 *
 * Nothing here trusts the search result blindly: the caller may be looking for
 * "Free Fire" and IGDB may rank "Free Fire MAX" first. `nameScore` rates a
 * candidate against the catalogue name, and a weak match is reported as none
 * rather than pasted onto the storefront as the wrong game.
 */

const TOKEN_URL = "https://id.twitch.tv/oauth2/token";
const API_URL = "https://api.igdb.com/v4";
const IMAGE_BASE = "https://images.igdb.com/igdb/image/upload";

/** A banner candidate, before it is mirrored. */
export type BannerCandidate = {
  /** IGDB's own name for the game, so staff can see what was matched. */
  name: string;
  url: string;
  source: "artwork" | "screenshot" | "cover";
  width: number;
  height: number;
};

type IgdbImage = { image_id?: string; width?: number; height?: number };

type IgdbGame = {
  name?: string;
  artworks?: IgdbImage[];
  screenshots?: IgdbImage[];
  cover?: IgdbImage;
  alternative_names?: Array<{ name?: string }>;
};

let cachedToken: { value: string; expiresAt: number } | null = null;

export function igdbConfigured(): boolean {
  return Boolean(
    Deno.env.get("IGDB_CLIENT_ID") && Deno.env.get("IGDB_CLIENT_SECRET")
  );
}

async function accessToken(): Promise<string | null> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 60_000) {
    return cachedToken.value;
  }

  const clientId = Deno.env.get("IGDB_CLIENT_ID");
  const clientSecret = Deno.env.get("IGDB_CLIENT_SECRET");
  if (!clientId || !clientSecret) return null;

  const url = new URL(TOKEN_URL);
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("client_secret", clientSecret);
  url.searchParams.set("grant_type", "client_credentials");

  try {
    const res = await fetch(url, {
      method: "POST",
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as {
      access_token?: string;
      expires_in?: number;
    };
    if (!data.access_token) return null;

    cachedToken = {
      value: data.access_token,
      expiresAt: now + (data.expires_in ?? 3600) * 1000,
    };
    return cachedToken.value;
  } catch {
    return null;
  }
}

/** Lowercase word tokens, punctuation dropped. `Free Fire: Global` -> 2 words. */
export function nameTokens(raw: string): string[] {
  return raw
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter((word) => word.length > 1);
}

/**
 * How well `candidate` matches `wanted`, from 0 to 1.
 *
 * Containment counts almost as much as equality: the catalogue says
 * "Free Fire Global" while IGDB says "Free Fire", and those are the same game.
 * Jaccard keeps a longer, unrelated title from scoring high just because it
 * shares one word.
 */
export function nameScore(wanted: string, candidate: string): number {
  const a = new Set(nameTokens(wanted));
  const b = new Set(nameTokens(candidate));
  if (a.size === 0 || b.size === 0) return 0;

  let shared = 0;
  for (const word of a) if (b.has(word)) shared += 1;

  const containment = shared / Math.min(a.size, b.size);
  const jaccard = shared / (a.size + b.size - shared);
  return Math.max(jaccard, containment * 0.9);
}

/** A candidate is only used when it actually looks like the same game. */
export const MIN_NAME_SCORE = 0.75;

function imageUrl(imageId: string, size: string): string {
  return `${IMAGE_BASE}/${size}/${imageId}.jpg`;
}

function area(image: IgdbImage): number {
  return (image.width ?? 0) * (image.height ?? 0);
}

function aspect(image: IgdbImage): number {
  const height = image.height ?? 0;
  return height > 0 ? (image.width ?? 0) / height : 0;
}

/**
 * Picks the widest good-looking image on a game.
 *
 * Key art first (`artworks`): it is the publisher's own banner, usually with
 * the logo. Screenshots are the fallback, and the square cover the last resort
 * so a game still gets *something*.
 */
export function pickArtwork(game: IgdbGame): BannerCandidate | null {
  const name = game.name ?? "";

  const choose = (
    images: IgdbImage[] | undefined,
    source: BannerCandidate["source"],
    size: string
  ): BannerCandidate | null => {
    const usable = (images ?? []).filter(
      (image) => image.image_id && aspect(image) >= 1.3 && area(image) > 0
    );
    if (usable.length === 0) return null;

    usable.sort((a, b) => area(b) - area(a));
    const best = usable[0];
    return {
      name,
      url: imageUrl(best.image_id!, size),
      source,
      width: best.width ?? 0,
      height: best.height ?? 0,
    };
  };

  return (
    choose(game.artworks, "artwork", "t_1080p") ??
    choose(game.screenshots, "screenshot", "t_1080p") ??
    (game.cover?.image_id
      ? {
          name,
          url: imageUrl(game.cover.image_id, "t_cover_big_2x"),
          source: "cover" as const,
          width: game.cover.width ?? 0,
          height: game.cover.height ?? 0,
        }
      : null)
  );
}

/**
 * Finds banner art for a catalogue name, or null when IGDB is not configured,
 * unreachable, or has no convincing match.
 *
 * Pass `igdbId` (from a previous response) to pin an exact game and skip the
 * fuzzy match.
 */
export async function findBanner(
  name: string,
  igdbId?: number
): Promise<BannerCandidate | null> {
  const clientId = Deno.env.get("IGDB_CLIENT_ID");
  const token = await accessToken();
  if (!clientId || !token) return null;

  const body = igdbId
    ? `where id = ${Math.trunc(igdbId)};
       fields name, artworks.image_id, artworks.width, artworks.height,
              screenshots.image_id, screenshots.width, screenshots.height,
              cover.image_id, cover.width, cover.height;
       limit 1;`
    : `search "${name.replace(/["\\]/g, " ")}";
       fields name, artworks.image_id, artworks.width, artworks.height,
              screenshots.image_id, screenshots.width, screenshots.height,
              cover.image_id, cover.width, cover.height;
       limit 10;`;

  let games: IgdbGame[];
  try {
    const res = await fetch(`${API_URL}/games`, {
      method: "POST",
      headers: {
        "Client-ID": clientId,
        Authorization: `Bearer ${token}`,
        "Content-Type": "text/plain",
      },
      body,
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return null;
    games = (await res.json()) as IgdbGame[];
  } catch {
    return null;
  }

  if (!Array.isArray(games) || games.length === 0) return null;

  // Highest name score wins; ties keep IGDB's own ranking, which uses its
  // popularity signal.
  let best: { game: IgdbGame; score: number } | null = null;
  for (const game of games) {
    const score = igdbId ? 1 : nameScore(name, game.name ?? "");
    if (!best || score > best.score) best = { game, score };
  }

  if (!best || best.score < MIN_NAME_SCORE) return null;
  return pickArtwork(best.game);
}
