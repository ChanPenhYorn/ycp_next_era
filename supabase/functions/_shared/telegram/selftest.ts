/**
 * Bot self-test. Read-only: sends nothing to any chat.
 *
 *   TELEGRAM_BOT_TOKEN=... deno run --allow-net --allow-env supabase/functions/_shared/telegram/selftest.ts
 *
 * Checks that the token works, the webhook points where expected, the command
 * menu is set, and every reply builder renders without throwing.
 */
import { telegramConfigured } from "./client.ts";
import {
  dashboardKeyboard,
  errorText,
  helpText,
  linkFailedText,
  linkedText,
  noOrdersText,
  notLinkedText,
  notificationText,
  orderMissingNumberText,
  orderNotFoundText,
  orderText,
  ordersText,
  staffForwardText,
  unknownText,
  unlinkedText,
  walletText,
  welcomeText,
} from "./messages.ts";

if (!telegramConfigured()) {
  console.error("TELEGRAM_BOT_TOKEN is empty.");
  Deno.exit(3);
}

const token = Deno.env.get("TELEGRAM_BOT_TOKEN")!;
const api = `https://api.telegram.org/bot${token}`;

const line = (label: string) => console.log(`\n\u001b[1m${label}\u001b[0m`);

async function call<T>(method: string): Promise<T> {
  const res = await fetch(`${api}/${method}`);
  const payload = (await res.json()) as { ok: boolean; result?: T; description?: string };
  if (!payload.ok) throw new Error(`${method}: ${payload.description}`);
  return payload.result as T;
}

line("1. identity");
const me = await call<{ username: string; first_name: string }>("getMe");
console.log(`   @${me.username} (${me.first_name})`);

line("2. webhook");
const hook = await call<{ url: string; pending_update_count: number; last_error_message?: string }>(
  "getWebhookInfo"
);
console.log(`   url:     ${hook.url || "(none)"}`);
console.log(`   pending: ${hook.pending_update_count}`);
if (hook.last_error_message) console.log(`   last error: ${hook.last_error_message}`);

line("3. command menu");
const commands = await call<Array<{ command: string }>>("getMyCommands");
console.log(`   ${commands.map((c) => "/" + c.command).join("  ") || "(empty)"}`);

line("4. reply builders");
const sample = {
  order_no: "YP261015ABC123",
  status: "delivered",
  total_usd: 12.5,
  items: ["Free Fire 100 <Diamonds>"],
};
const builders: Array<[string, () => string]> = [
  ["welcome", welcomeText],
  ["linked", linkedText],
  ["link expired", () => linkFailedText("code_expired")],
  ["link invalid", () => linkFailedText("code_invalid")],
  ["help", helpText],
  ["no orders", noOrdersText],
  ["orders", () => ordersText([sample])],
  ["order missing number", orderMissingNumberText],
  ["order not found", orderNotFoundText],
  [
    "order",
    () =>
      orderText({
        order_no: sample.order_no,
        status: sample.status,
        total_usd: sample.total_usd,
        items: [{ name: "Free Fire", qty: 1, delivery_status: "delivered", codes: ["ABC-123"] }],
      }),
  ],
  ["wallet", () => walletText({ wallet_balance: 45, coins: 5 })],
  ["not linked", notLinkedText],
  ["unlinked", unlinkedText],
  ["unknown", unknownText],
  ["error", errorText],
  ["staff forward", () => staffForwardText(1, true, "<hi>")],
  ["notification delivered", () => notify("order_delivered")],
  ["notification failed", () => notify("order_failed")],
];

function notify(kind: string): string {
  const text = notificationText(kind, sample);
  if (text === null) throw new Error(`unknown kind ${kind}`);
  return text;
}

let broken = 0;
for (const [name, build] of builders) {
  try {
    build();
    console.log(`   ok    ${name}`);
  } catch (error) {
    broken++;
    console.log(`   FAIL  ${name}: ${error}`);
  }
}

line("5. dashboard button");
console.log(
  dashboardKeyboard()
    ? `   ${dashboardKeyboard()![0][0].url}`
    : "   STORE_APP_URL unset, button hidden"
);

if (broken > 0) Deno.exit(1);
