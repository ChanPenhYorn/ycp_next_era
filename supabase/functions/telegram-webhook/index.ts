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
  "<b>ជំនួយ</b>",
  "",
  "/orders — បញ្ជីការបញ្ជាទិញថ្មីៗ",
  "/order &lt;លេខ&gt; — មើលកូដ និងស្ថានភាព",
  "/wallet — សមតុល្យកាបូបលុយ",
  "/help — ជំនួយ",
].join("\n");

const HELP_EN = [
  "<b>Commands</b>",
  "",
  "/orders — your recent orders",
  "/order &lt;number&gt; — codes and status",
  "/wallet — wallet balance",
  "/help — this message",
].join("\n");

const STATUS_KM: Record<string, string> = {
  pending: "រង់ចាំទូទាត់",
  paid: "បានទូទាត់",
  delivering: "កំពុងដំណើរការ",
  delivered: "រួចរាល់",
  failed: "បរាជ័យ",
  refunded: "បានសងវិញ",
  expired: "ផុតកំណត់",
};

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
        await sendMessage(chatId, `${HELP_KM}\n\n${HELP_EN}`);
        break;
      default:
        await handleUnknown(admin, chatId, text);
    }
  } catch (error) {
    console.error(JSON.stringify({ event: "telegram_error", error: String(error) }));
    await sendMessage(chatId, "មានបញ្ហា។ សូមព្យាយាមម្ដងទៀត។\nSomething went wrong.");
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
          "✅ <b>ភ្ជាប់គណនីរួចរាល់</b>",
          "ឥឡូវអ្នកអាចមើលការបញ្ជាទិញ និងកូដរបស់អ្នកនៅទីនេះ។",
          "",
          "✅ <b>Account linked</b>",
          "Your orders and codes are now available here.",
          "",
          HELP_KM,
        ].join("\n")
      );
      return;
    }

    await sendMessage(
      chatId,
      result.reason === "code_expired"
        ? "កូដនេះផុតកំណត់ហើយ។ សូមបង្កើតកូដថ្មីក្នុងកម្មវិធី។\nThis code has expired. Generate a new one in the app."
        : "កូដមិនត្រឹមត្រូវ។\nThat code is not valid."
    );
    return;
  }

  await sendMessage(
    chatId,
    [
      "<b>Chanpenh</b> — បញ្ចូលពេជ្រហ្គេម និងកាតឌីជីថលភ្លាមៗ",
      "",
      "ដើម្បីភ្ជាប់គណនី សូមបើកកម្មវិធី Chanpenh រួចចុច «ភ្ជាប់ Telegram»។",
      "បន្ទាប់មកផ្ញើកូដមកទីនេះជាមួយ /start។",
      "",
      "To link your account, open the Chanpenh app and tap Connect Telegram,",
      "then send the code here as /start &lt;code&gt;.",
      "",
      HELP_KM,
    ].join("\n")
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
      "មិនទាន់មានការបញ្ជាទិញ។\nNo orders yet."
    );
    return;
  }

  const lines = orders.map((order) => {
    const status = STATUS_KM[order.status] ?? order.status;
    const items = order.items.join(", ");
    return [
      `<code>${order.order_no}</code> · ${status} · $${Number(order.total_usd).toFixed(2)}`,
      escapeHtml(items),
    ].join("\n");
  });

  await sendMessage(
    chatId,
    [`<b>ការបញ្ជាទិញថ្មីៗ</b>`, "", ...lines, "", "/order &lt;លេខ&gt; ដើម្បីមើលកូដ"].join("\n\n")
  );
}

async function handleOrder(
  admin: ReturnType<typeof adminClient>,
  chatId: number,
  orderNo: string | undefined
) {
  if (!orderNo) {
    await sendMessage(chatId, "សូមផ្ញើលេខការបញ្ជាទិញ។ ឧ. /order YP261015ABC123\nSend an order number.");
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
      "រកមិនឃើញការបញ្ជាទិញនេះទេ។\nOrder not found."
    );
    return;
  }

  const blocks = order.items.map((item) => {
    const header = `${escapeHtml(item.name)} x${item.qty}`;
    if (item.codes.length === 0) {
      // Never print a code for an unpaid or undelivered order.
      const state =
        item.delivery_status === "manual_waiting"
          ? "រង់ចាំបុគ្គលិកដំឡើង"
          : item.delivery_status;
      return `${header}\n<i>${escapeHtml(state)}</i>`;
    }
    const codes = item.codes.map((code) => `<code>${escapeHtml(code)}</code>`).join("\n");
    return `${header}\n${codes}`;
  });

  await sendMessage(
    chatId,
    [
      `<b><code>${order.order_no}</code></b>`,
      `${STATUS_KM[order.status] ?? order.status} · $${Number(order.total_usd).toFixed(2)}`,
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
      "គណនីមិនទាន់ភ្ជាប់។ សូមភ្ជាប់ក្នុងកម្មវិធី Chanpenh។\nAccount not linked."
    );
    return;
  }

  await sendMessage(
    chatId,
    [
      "<b>កាបូបលុយ</b>",
      `សមតុល្យ: <b>$${Number(profile.wallet_balance).toFixed(2)}</b>`,
      `កាក់: ${profile.coins}`,
    ].join("\n")
  );
}

async function handleUnlink(admin: ReturnType<typeof adminClient>, chatId: number) {
  await admin.rpc("telegram_unlink", { p_chat_id: chatId });
  await sendMessage(
    chatId,
    "បានផ្ដាច់គណនីរួចរាល់។\nAccount unlinked."
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
      "សូមអភ័យទោស យើងមិនយល់សារនេះទេ។",
      "ផ្ញើ /help ដើម្បីមើលពាក្យបញ្ជា។",
      "",
      "Sorry, I did not understand that. Send /help for commands.",
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
      "<b>សារថ្មីពីអ្នកទិញ</b>",
      `chat_id: <code>${chatId}</code>`,
      `linked: ${linked ? "yes" : "no"}`,
      "",
      escapeHtml(text).slice(0, 800),
    ].join("\n")
  );
}
