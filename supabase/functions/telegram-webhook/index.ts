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
 *
 * Reply text lives in _shared/telegram/messages.ts; transport in client.ts.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import { drainOutbox } from "../_shared/dispatch.ts";
import { sendMessage } from "../_shared/telegram/client.ts";
import {
  dashboardKeyboard,
  errorText,
  helpText,
  linkFailedText,
  linkedText,
  noOrdersText,
  notLinkedText,
  orderMissingNumberText,
  orderNotFoundText,
  orderText,
  ordersText,
  staffForwardText,
  unknownText,
  unlinkedText,
  walletText,
  welcomeText,
} from "../_shared/telegram/messages.ts";
import type {
  LinkResult,
  OrderDetail,
  OrderSummary,
  Update,
  WalletProfile,
} from "../_shared/telegram/types.ts";

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
        await sendMessage(chatId, helpText(), { keyboard: dashboardKeyboard() });
        break;
      default:
        await handleUnknown(admin, chatId, text);
    }
  } catch (error) {
    console.error(JSON.stringify({ event: "telegram_error", error: String(error) }));
    await sendMessage(chatId, errorText());
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

    const result = (data ?? {}) as LinkResult;

    if (result.ok) {
      await sendMessage(chatId, linkedText(), { keyboard: dashboardKeyboard() });
      return;
    }

    await sendMessage(chatId, linkFailedText(result.reason));
    return;
  }

  await sendMessage(chatId, welcomeText(), { keyboard: dashboardKeyboard() });
}

async function handleOrders(admin: ReturnType<typeof adminClient>, chatId: number) {
  const { data } = await admin.rpc("telegram_orders_for_chat", {
    p_chat_id: chatId,
    p_limit: 5,
  });

  const orders = (data ?? []) as OrderSummary[];

  if (orders.length === 0) {
    await sendMessage(chatId, noOrdersText());
    return;
  }

  await sendMessage(chatId, ordersText(orders));
}

async function handleOrder(
  admin: ReturnType<typeof adminClient>,
  chatId: number,
  orderNo: string | undefined
) {
  if (!orderNo) {
    await sendMessage(chatId, orderMissingNumberText());
    return;
  }

  const { data } = await admin.rpc("telegram_order_by_no", {
    p_chat_id: chatId,
    p_order_no: orderNo,
  });

  const order = data as OrderDetail | null | undefined;

  if (!order) {
    await sendMessage(chatId, orderNotFoundText());
    return;
  }

  await sendMessage(chatId, orderText(order));
}

async function handleWallet(admin: ReturnType<typeof adminClient>, chatId: number) {
  const { data } = await admin.rpc("telegram_profile_for_chat", {
    p_chat_id: chatId,
  });

  const profile = data as WalletProfile | null | undefined;

  if (!profile) {
    await sendMessage(chatId, notLinkedText());
    return;
  }

  await sendMessage(chatId, walletText(profile));
}

async function handleUnlink(admin: ReturnType<typeof adminClient>, chatId: number) {
  await admin.rpc("telegram_unlink", { p_chat_id: chatId });
  await sendMessage(chatId, unlinkedText());
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

  await sendMessage(chatId, unknownText());

  // Forward to the staff chat when one is configured.
  const { data: settings } = await admin
    .from("settings")
    .select("support_telegram_chat_id")
    .maybeSingle();

  const staffChat = settings?.support_telegram_chat_id as number | null | undefined;
  if (!staffChat || staffChat === chatId) return;

  await sendMessage(staffChat, staffForwardText(chatId, linked, text));
}
