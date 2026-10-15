/**
 * Live adapter self-test. Read-only: never places an order.
 *
 *   deno run --allow-net --allow-env supabase/functions/_shared/suppliers/selftest.ts bay2game
 *
 * Worth running before a sync, because supplier APIs drift from their docs.
 * This one caught a casing difference: the documentation shows "SUCCESS" but
 * the live API returns "success".
 */
import { bay2game } from "./bay2game.ts";
import type { SupplierAdapter } from "./types.ts";

const ADAPTERS: Record<string, SupplierAdapter> = { bay2game };

const code = Deno.args[0] ?? "bay2game";
const adapter = ADAPTERS[code];

if (!adapter) {
  console.error(`unknown supplier "${code}". Known: ${Object.keys(ADAPTERS).join(", ")}`);
  Deno.exit(2);
}

const line = (label: string) => console.log(`\n\u001b[1m${label}\u001b[0m`);

if (!adapter.configured()) {
  console.error(
    `${code} has no API key. Set ${code.toUpperCase()}_API_KEY in the environment.`
  );
  Deno.exit(3);
}

line(`1. catalogue (${code})`);
const games = await adapter.games();
console.log(`   ${games.length} games`);

const withFields = games.filter((g) => g.fields.length > 0);
console.log(`   ${withFields.length} need buyer input, ${games.length - withFields.length} need none`);

const fieldShapes = new Map<string, number>();
for (const game of games) {
  const shape = game.fields.join("+") || "(none)";
  fieldShapes.set(shape, (fieldShapes.get(shape) ?? 0) + 1);
}
for (const [shape, count] of [...fieldShapes].sort((a, b) => b[1] - a[1])) {
  console.log(`   fields=${shape.padEnd(20)} ${count} games`);
}

line("2. sample games");
for (const game of games.slice(0, 5)) {
  console.log(`   ${game.gameCode.padEnd(24)} ${game.name}`);
}

// Pick something Cambodia-relevant when it exists.
const target =
  games.find((g) => /mlbb_exclusive|freefire_sgmy/.test(g.gameCode)) ?? games[0];

line(`3. products for ${target.gameCode} (${target.name})`);
console.log(`   fields the buyer must supply: [${target.fields.join(", ")}]`);

const products = await adapter.products(target.gameCode);
console.log(`   ${products.length} products`);

const cheapest = [...products].sort((a, b) => a.priceUsd - b.priceUsd)[0];
const dearest = [...products].sort((a, b) => b.priceUsd - a.priceUsd)[0];
console.log(`   cheapest: ${cheapest.productCode} ${cheapest.name} $${cheapest.priceUsd}`);
console.log(`   dearest:  ${dearest.productCode} ${dearest.name} $${dearest.priceUsd}`);

line("4. sellable vs listed");
const sellable = games.filter((g) => adapter.canFulfil(g.fields));
const blocked = games.filter((g) => !adapter.canFulfil(g.fields));
console.log(`   ${sellable.length} games this order API can actually accept`);
if (blocked.length > 0) {
  console.log(`   \u001b[33m!\u001b[0m ${blocked.length} must be excluded at sync time:`);
  for (const game of blocked.slice(0, 5)) {
    console.log(`     ${game.gameCode.padEnd(24)} needs [${game.fields.join(", ")}]`);
  }
}

line("5. parsing sanity");
const priced = products.filter((p) => p.priceUsd > 0);
console.log(`   ${priced.length}/${products.length} parsed with a price > 0`);
const zeroPriced = products.filter((p) => p.priceUsd === 0);
if (zeroPriced.length > 0) {
  console.log(
    `   \u001b[33m!\u001b[0m ${zeroPriced.length} parsed as $0.00 — check the field mapping: ` +
      zeroPriced.slice(0, 3).map((p) => p.productCode).join(", ")
  );
}

line("OK");
console.log("   adapter parses live responses. No order was placed.");
