/**
 * telegram-webhook
 *
 * Receives Telegram updates. Configure with setWebhook (see
 * scripts/set-telegram-webhook.sh) and set TELEGRAM_WEBHOOK_SECRET so only
 * Telegram can post here.
 *
 * Security posture: the chat id is never trusted as an identity. Every read goes
 * through a security-definer function that resolves chat_id -> profile and only
 * returns that profile's own rows.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import { drainOutbox } from "../_shared/dispatch.ts";
import { escapeHtml, sendMessage } from "../_shared/telegram.ts";

type Update = {
  message?: {
    chat: { id: number; type: string };
    from?: { id: number; username?: string; first_name?: string };
    text?: string;
  };
};

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

const STORE_APP_URL = Deno.env.get("STORE_APP_URL") ?? "";

function dashboardKeyboard() {
  return STORE_APP_URL
    ? [[{ text: "🛍 Dashboard · ផ្ទាំងគ្រប់គ្រង", url: STORE_APP_URL }]]
    : undefined;
}

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // Telegram echoes this header when secret_token was given to setWebhook.
  const expected = Deno.env.get("TELEGRAM_WEBHOOK_SECRET");
  if (expected && req.headers.get("x-telegram-bot-api-secret-token") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  let update: Update;
  try {
    update = await req.json();
  } catch {
    return json({ ok: true });
  }

  const message = update.message;
  const text = message?.text?.trim();
  const chatId = message?.chat.id;

  if (!message || !text || chatId === undefined) {
    // Not a text message (join, sticker, edit). Acknowledge so Telegram stops.
    return json({ ok: true });
  }

  const admin = adminClient();

  try {
    const [command, ...args] = text.split(/\s+/);
    const verb = command.toLowerCase().replace(/@\w+$/, "");

    switch (verb) {
      case "/start":
        await handleStart(admin, chatId, args[0], message.from?.username);
        break;
      case "/orders":
        await handleOrders(admin, chatId);
        break;
      case "/order":
        await handleOrder(admin, chatId, args[0]);
        break;
      case "/wallet":
        await handleWallet(admin, chatId);
        break;
      case "/unlink":
        await handleUnlink(admin, chatId);
        break;
      case "/help":
        await sendMessage(chatId, `${HELP_KM}\n\n${HELP_EN}`, { keyboard: dashboardKeyboard() });
        break;
      default:
        await handleUnknown(admin, chatId, text);
    }
  } catch (error) {
    console.error(JSON.stringify({ event: "telegram_error", error: String(error) }));
    await sendMessage(chatId, "🚧 <b>មានបញ្ហា។ សូមព្យាយាមម្ដងទៀត។</b>\n\n🚧 <b>Something went wrong. Please try again.</b>");
  }

  // Any inbound message is a chance to flush late deliveries.
  await drainOutbox();

  return json({ ok: true });
});

async function handleStart(
  admin: ReturnType<typeof adminClient>,
  chatId: number,
  code: string | undefined,
  username: string | undefined
) {
  if (code) {
    const { data } = await admin.rpc("link_telegram", {
      p_code: code,
      p_chat_id: chatId,
      p_username: username ?? null,
    });

    const result = (data ?? {}) as { ok?: boolean; reason?: string };

    if (result.ok) {
      await sendMessage(
        chatId,
        [
          "🎉 <b>ភ្ជាប់គណនីរួចរាល់</b>",
          "ឥឡូវអ្នកអាចមើលការបញ្ជាទិញ និងកូដរបស់អ្នកនៅទីនេះ។",
          "",
          "🎉 <b>Account linked</b>",
          "Your orders and codes are now available here.",
          "",
          HELP_KM,
        ].join("\n"),
        { keyboard: dashboardKeyboard() }
      );
      return;
    }

    await sendMessage(
      chatId,
      result.reason === "code_expired"
        ? "⌛ <b>កូដនេះផុតកំណត់ហើយ</b>\nសូមបង្កើតកូដថ្មីក្នុងកម្មវិធី។\n\n⌛ <b>This code has expired.</b>\nGenerate a new one in the app."
        : "⚠️ <b>កូដមិនត្រឹមត្រូវ</b>\n\n⚠️ <b>That code is not valid.</b>"
    );
    return;
  }

  await sendMessage(
    chatId,
    [
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
    ].join("\n"),
    { keyboard: dashboardKeyboard() }
  );
}

async function handleOrders(admin: ReturnType<typeof adminClient>, chatId: number) {
  const { data } = await admin.rpc("telegram_orders_for_chat", {
    p_chat_id: chatId,
    p_limit: 5,
  });

  const orders = (data ?? []) as Array<{
    order_no: string;
    status: string;
    total_usd: number;
    items: string[];
  }>;

  if (orders.length === 0) {
    await sendMessage(
      chatId,
      "🛒 <b>មិនទាន់មានការបញ្ជាទិញ</b>\n\n🛒 <b>No orders yet.</b>"
    );
    return;
  }

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

  await sendMessage(
    chatId,
    [
      `📦 <b>ការបញ្ជាទិញថ្មីៗ · Recent orders</b>`,
      `<i>${orders.length} latest · ${usd(spent)} total</i>`,
      "",
      histogram.join("\n"),
      "",
      "─────────────",
      lines.join("\n\n"),
      "",
      "🔎 /order &lt;លេខ&gt; · details",
    ].join("\n")
  );
}

async function handleOrder(
  admin: ReturnType<typeof adminClient>,
  chatId: number,
  orderNo: string | undefined
) {
  if (!orderNo) {
    await sendMessage(
      chatId,
      "🔎 <b>សូមផ្ញើលេខការបញ្ជាទិញ</b>\nឧ. <code>/order YP261015ABC123</code>\n\n🔎 <b>Send an order number.</b>\ne.g. <code>/order YP261015ABC123</code>"
    );
    return;
  }

  const { data } = await admin.rpc("telegram_order_by_no", {
    p_chat_id: chatId,
    p_order_no: orderNo,
  });

  const order = data as
    | {
        order_no: string;
        status: string;
        total_usd: number;
        items: Array<{ name: string; qty: number; delivery_status: string; codes: string[] }>;
      }
    | null
    | undefined;

  if (!order) {
    await sendMessage(
      chatId,
      "🔍 <b>រកមិនឃើញការបញ្ជាទិញនេះទេ</b>\n\n🔍 <b>Order not found.</b>"
    );
    return;
  }

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
  await sendMessage(
    chatId,
    [
      `🧾 <b>Order</b> <code>${order.order_no}</code>`,
      `${statusLabel(order.status)}  ·  <b>${usd(order.total_usd)}</b>`,
      ...(trackLine ? [`<code>${trackLine}</code>  ${STATUS[order.status]?.km ?? ""}`] : []),
      "─────────────",
      ...blocks,
    ].join("\n\n")
  );
}

async function handleWallet(admin: ReturnType<typeof adminClient>, chatId: number) {
  const { data } = await admin.rpc("telegram_profile_for_chat", {
    p_chat_id: chatId,
  });

  const profile = data as { wallet_balance: number; coins: number } | null | undefined;

  if (!profile) {
    await sendMessage(
      chatId,
      "🔒 <b>គណនីមិនទាន់ភ្ជាប់</b>\nសូមភ្ជាប់ក្នុងកម្មវិធី Chanpenh។\n\n🔒 <b>Account not linked.</b>\nConnect it in the Chanpenh app."
    );
    return;
  }

  await sendMessage(
    chatId,
    [
      "👛 <b>កាបូបលុយ · Wallet</b>",
      "",
      `💵 សមតុល្យ · Balance   <b>${usd(profile.wallet_balance)}</b>`,
      `🪙 កាក់ · Coins   <b>${profile.coins}</b>`,
    ].join("\n")
  );
}

async function handleUnlink(admin: ReturnType<typeof adminClient>, chatId: number) {
  await admin.rpc("telegram_unlink", { p_chat_id: chatId });
  await sendMessage(
    chatId,
    "🔓 <b>បានផ្ដាច់គណនីរួចរាល់</b>\n\n🔓 <b>Account unlinked.</b>"
  );
}

/** Anything unrecognised is treated as a support request. */
async function handleUnknown(
  admin: ReturnType<typeof adminClient>,
  chatId: number,
  text: string
) {
  const { data } = await admin.rpc("telegram_profile_for_chat", {
    p_chat_id: chatId,
  });

  const linked = data != null;

  await sendMessage(
    chatId,
    [
      "🤔 <b>សូមអភ័យទោស យើងមិនយល់សារនេះទេ</b>",
      "ផ្ញើ /help ដើម្បីមើលពាក្យបញ្ជា។",
      "",
      "🤔 <b>Sorry, I did not understand that.</b>",
      "Send /help for commands.",
    ].join("\n")
  );

  // Forward to the staff chat when one is configured.
  const { data: settings } = await admin
    .from("settings")
    .select("support_telegram_chat_id")
    .maybeSingle();

  const staffChat = settings?.support_telegram_chat_id as number | null | undefined;
  if (!staffChat || staffChat === chatId) return;

  await sendMessage(
    staffChat,
    [
      "📥 <b>សារថ្មីពីអ្នកទិញ · New buyer message</b>",
      `🆔 <code>${chatId}</code>  ·  ${linked ? "🟢 linked" : "⚪️ not linked"}`,
      "─────────────",
      `<blockquote>${escapeHtml(text).slice(0, 800)}</blockquote>`,
    ].join("\n")
  );
}
