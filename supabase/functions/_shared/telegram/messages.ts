/**
 * Everything the bot says, in Khmer first then English.
 *
 * Messages use Telegram's HTML mode because it only requires escaping three
 * characters, whereas Markdown breaks on product names containing _ or *.
 * Builders return strings; they never send. Sending is client.ts's job.
 */
import type { Keyboard, OrderDetail, OrderSummary, WalletProfile } from "./types.ts";

export function escapeHtml(input: string): string {
  return input
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

const STORE_APP_URL = Deno.env.get("STORE_APP_URL") ?? "";

/** Omitted entirely when STORE_APP_URL is unset, so the bot never shows a dead button. */
export function dashboardKeyboard(): Keyboard | undefined {
  return STORE_APP_URL
    ? [[{ text: "🛍 Dashboard · ផ្ទាំងគ្រប់គ្រង", url: STORE_APP_URL }]]
    : undefined;
}

const HELP_KM = [
  "🛍 <b>ជំនួយ</b>",
  "",
  "📦 /orders · ការបញ្ជាទិញ",
  "🔎 /order &lt;លេខ&gt; · កូដ និងស្ថានភាព",
  "👛 /wallet · កាបូបលុយ",
  "💬 /help · ជំនួយ",
].join("\n");

const HELP_EN = [
  "🛍 <b>Commands</b>",
  "",
  "📦 /orders · your recent orders",
  "🔎 /order &lt;number&gt; · codes and status",
  "👛 /wallet · wallet balance",
  "💬 /help · this message",
].join("\n");

const STATUS: Record<string, { icon: string; km: string; en: string }> = {
  pending: { icon: "⏳", km: "រង់ចាំទូទាត់", en: "Awaiting payment" },
  paid: { icon: "💳", km: "បានទូទាត់", en: "Paid" },
  delivering: { icon: "🚚", km: "កំពុងដំណើរការ", en: "Delivering" },
  delivered: { icon: "✅", km: "រួចរាល់", en: "Delivered" },
  failed: { icon: "❌", km: "បរាជ័យ", en: "Failed" },
  refunded: { icon: "↩️", km: "បានសងវិញ", en: "Refunded" },
  expired: { icon: "⌛", km: "ផុតកំណត់", en: "Expired" },
};

const FLOW = ["paid", "delivering", "delivered"];

function statusLabel(status: string): string {
  const s = STATUS[status];
  return s ? `${s.icon} ${s.en}` : escapeHtml(status);
}

/** Four-step track: ▰ reached, ▱ still ahead. Terminal failure states show no track. */
function track(status: string): string {
  const steps = ["pending", ...FLOW];
  const at = steps.indexOf(status);
  if (at < 0) return "";
  return "▰".repeat(at + 1) + "▱".repeat(steps.length - at - 1);
}

function usd(value: number | string): string {
  return `$${Number(value).toFixed(2)}`;
}

/** Horizontal bar scaled to the largest count, so the widest row is always 10 cells. */
function bar(count: number, max: number): string {
  const cells = max === 0 ? 0 : Math.max(1, Math.round((count / max) * 10));
  return "█".repeat(cells);
}

export function welcomeText(): string {
  return [
    "💎 <b>Chanpenh</b> · បញ្ចូលពេជ្រហ្គេម និងកាតឌីជីថលភ្លាមៗ",
    "",
    "🔗 <b>ភ្ជាប់គណនី</b>",
    "បើកកម្មវិធី Chanpenh រួចចុច «ភ្ជាប់ Telegram»។",
    "បន្ទាប់មកផ្ញើកូដមកទីនេះជាមួយ /start។",
    "",
    "🔗 <b>Link your account</b>",
    "Open the Chanpenh app, tap Connect Telegram,",
    "then send the code here as /start &lt;code&gt;.",
    "",
    HELP_KM,
  ].join("\n");
}

export function linkedText(): string {
  return [
    "🎉 <b>ភ្ជាប់គណនីរួចរាល់</b>",
    "ឥឡូវអ្នកអាចមើលការបញ្ជាទិញ និងកូដរបស់អ្នកនៅទីនេះ។",
    "",
    "🎉 <b>Account linked</b>",
    "Your orders and codes are now available here.",
    "",
    HELP_KM,
  ].join("\n");
}

export function linkFailedText(reason: string | undefined): string {
  return reason === "code_expired"
    ? "⌛ <b>កូដនេះផុតកំណត់ហើយ</b>\nសូមបង្កើតកូដថ្មីក្នុងកម្មវិធី។\n\n⌛ <b>This code has expired.</b>\nGenerate a new one in the app."
    : "⚠️ <b>កូដមិនត្រឹមត្រូវ</b>\n\n⚠️ <b>That code is not valid.</b>";
}

export function helpText(): string {
  return `${HELP_KM}\n\n${HELP_EN}`;
}

export function noOrdersText(): string {
  return "🛒 <b>មិនទាន់មានការបញ្ជាទិញ</b>\n\n🛒 <b>No orders yet.</b>";
}

export function ordersText(orders: OrderSummary[]): string {
  const counts = new Map<string, number>();
  let spent = 0;
  for (const order of orders) {
    counts.set(order.status, (counts.get(order.status) ?? 0) + 1);
    spent += Number(order.total_usd);
  }
  const max = Math.max(...counts.values());
  const histogram = [...counts.entries()].map(([status, count]) => {
    const s = STATUS[status];
    return `${s?.icon ?? "•"} ${bar(count, max)} ${count}`;
  });

  const lines = orders.map((order) => {
    const items = order.items.map(escapeHtml).join(", ");
    return [
      `${statusLabel(order.status)}  ·  <b>${usd(order.total_usd)}</b>`,
      `<code>${order.order_no}</code>`,
      `<i>${items}</i>`,
    ].join("\n");
  });

  return [
    `📦 <b>ការបញ្ជាទិញថ្មីៗ · Recent orders</b>`,
    `<i>${orders.length} latest · ${usd(spent)} total</i>`,
    "",
    histogram.join("\n"),
    "",
    "─────────────",
    lines.join("\n\n"),
    "",
    "🔎 /order &lt;លេខ&gt; · details",
  ].join("\n");
}

export function orderMissingNumberText(): string {
  return "🔎 <b>សូមផ្ញើលេខការបញ្ជាទិញ</b>\nឧ. <code>/order YP261015ABC123</code>\n\n🔎 <b>Send an order number.</b>\ne.g. <code>/order YP261015ABC123</code>";
}

export function orderNotFoundText(): string {
  return "🔍 <b>រកមិនឃើញការបញ្ជាទិញនេះទេ</b>\n\n🔍 <b>Order not found.</b>";
}

export function orderText(order: OrderDetail): string {
  const blocks = order.items.map((item) => {
    const header = `🎮 <b>${escapeHtml(item.name)}</b>  ×${item.qty}`;
    if (item.codes.length === 0) {
      // Never print a code for an unpaid or undelivered order.
      const state =
        item.delivery_status === "manual_waiting"
          ? "🛠 រង់ចាំបុគ្គលិកដំឡើង · Waiting for staff"
          : `⏳ ${escapeHtml(item.delivery_status)}`;
      return `${header}\n<i>${state}</i>`;
    }
    const codes = item.codes.map((code) => `🔑 <code>${escapeHtml(code)}</code>`).join("\n");
    return `${header}\n${codes}`;
  });

  const trackLine = track(order.status);
  return [
    `🧾 <b>Order</b> <code>${order.order_no}</code>`,
    `${statusLabel(order.status)}  ·  <b>${usd(order.total_usd)}</b>`,
    ...(trackLine ? [`<code>${trackLine}</code>  ${STATUS[order.status]?.km ?? ""}`] : []),
    "─────────────",
    ...blocks,
  ].join("\n\n");
}

export function notLinkedText(): string {
  return "🔒 <b>គណនីមិនទាន់ភ្ជាប់</b>\nសូមភ្ជាប់ក្នុងកម្មវិធី Chanpenh។\n\n🔒 <b>Account not linked.</b>\nConnect it in the Chanpenh app.";
}

export function walletText(profile: WalletProfile): string {
  return [
    "👛 <b>កាបូបលុយ · Wallet</b>",
    "",
    `💵 សមតុល្យ · Balance   <b>${usd(profile.wallet_balance)}</b>`,
    `🪙 កាក់ · Coins   <b>${profile.coins}</b>`,
  ].join("\n");
}

export function unlinkedText(): string {
  return "🔓 <b>បានផ្ដាច់គណនីរួចរាល់</b>\n\n🔓 <b>Account unlinked.</b>";
}

export function unknownText(): string {
  return [
    "🤔 <b>សូមអភ័យទោស យើងមិនយល់សារនេះទេ</b>",
    "ផ្ញើ /help ដើម្បីមើលពាក្យបញ្ជា។",
    "",
    "🤔 <b>Sorry, I did not understand that.</b>",
    "Send /help for commands.",
  ].join("\n");
}

export function errorText(): string {
  return "🚧 <b>មានបញ្ហា។ សូមព្យាយាមម្ដងទៀត។</b>\n\n🚧 <b>Something went wrong. Please try again.</b>";
}

/** Support request forwarded to the staff chat. */
export function staffForwardText(chatId: number, linked: boolean, text: string): string {
  return [
    "📥 <b>សារថ្មីពីអ្នកទិញ · New buyer message</b>",
    `🆔 <code>${chatId}</code>  ·  ${linked ? "🟢 linked" : "⚪️ not linked"}`,
    "─────────────",
    `<blockquote>${escapeHtml(text).slice(0, 800)}</blockquote>`,
  ].join("\n");
}

/** Outbox notifications. Returns null for a kind this build does not know how to render. */
export function notificationText(kind: string, payload: Record<string, unknown>): string | null {
  const orderNo = String(payload.order_no ?? "");
  const total = Number(payload.total_usd ?? 0).toFixed(2);

  switch (kind) {
    case "order_delivered":
      return [
        "✅ <b>ការបញ្ជាទិញរបស់អ្នករួចរាល់</b>",
        `🧾 <code>${orderNo}</code>  ·  <b>$${total}</b>`,
        "<code>▰▰▰▰</code>  រួចរាល់ · Delivered",
        "",
        "🔎 /orders · មើលកូដ · see your codes",
        "",
        "✅ <b>Your order is ready</b>",
      ].join("\n");

    case "order_failed":
      return [
        "⚠️ <b>យើងមិនអាចដឹកជញ្ជូនការបញ្ជាទិញនេះបានទេ</b>",
        `🧾 <code>${orderNo}</code>  ·  <b>$${total}</b>`,
        "↩️ ប្រាក់បានបង្វិលចូលកាបូបលុយរួចរាល់។",
        "",
        "⚠️ <b>We could not deliver this order.</b>",
        "↩️ The amount has been refunded to your wallet.",
      ].join("\n");

    default:
      return null;
  }
}
