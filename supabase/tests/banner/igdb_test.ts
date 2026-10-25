/**
 * IGDB banner selection tests. No network: the pure helpers are exercised
 * directly, which is where the wrong-game risk lives.
 *
 *   deno test --allow-env supabase/tests/banner/
 */
import { assertEquals, assert } from "jsr:@std/assert@1";
import {
  MIN_NAME_SCORE,
  nameScore,
  nameTokens,
  pickArtwork,
} from "../../functions/_shared/igdb.ts";

Deno.test("tokens drop punctuation and single letters", () => {
  assertEquals(nameTokens("Free Fire: Global!"), ["free", "fire", "global"]);
  assertEquals(nameTokens("PUBG Mobile"), ["pubg", "mobile"]);
  assertEquals(nameTokens("   "), []);
});

Deno.test("a catalogue suffix still matches the shorter IGDB title", () => {
  // The supplier says "Free Fire Global"; IGDB says "Free Fire".
  assert(nameScore("Free Fire Global", "Free Fire") >= MIN_NAME_SCORE);
  assert(
    nameScore("Mobile Legends", "Mobile Legends: Bang Bang") >= MIN_NAME_SCORE
  );
});

Deno.test("an exact name scores 1", () => {
  assertEquals(nameScore("Mobile Legends", "Mobile Legends"), 1);
});

Deno.test("a different game scores below the threshold", () => {
  assert(nameScore("Free Fire", "Mobile Legends") < MIN_NAME_SCORE);
  assert(nameScore("Honor of Kings", "Blood Strike") < MIN_NAME_SCORE);
});

Deno.test("key art wins over screenshots and the square cover", () => {
  const picked = pickArtwork({
    name: "Free Fire",
    artworks: [{ image_id: "art", width: 1920, height: 1080 }],
    screenshots: [{ image_id: "shot", width: 1920, height: 1080 }],
    cover: { image_id: "cover", width: 512, height: 512 },
  });
  assertEquals(picked?.source, "artwork");
  assertEquals(picked?.url.endsWith("/art.jpg"), true);
});

Deno.test("a portrait-only artwork is skipped for a wide screenshot", () => {
  const picked = pickArtwork({
    name: "Free Fire",
    artworks: [{ image_id: "tall", width: 600, height: 1000 }],
    screenshots: [{ image_id: "wide", width: 1600, height: 900 }],
  });
  assertEquals(picked?.source, "screenshot");
});

Deno.test("the cover is the last resort", () => {
  const picked = pickArtwork({
    name: "Free Fire",
    cover: { image_id: "cover", width: 512, height: 512 },
  });
  assertEquals(picked?.source, "cover");
});

Deno.test("no images means no candidate", () => {
  assertEquals(pickArtwork({ name: "Free Fire" }), null);
});
