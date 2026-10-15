/**
 * Telegram helpers.
 *
 * The bot token is a server secret. It must never reach the Flutter bundle:
 * anyone holding it can read every message the bot receives and impersonate it.
 */

const TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const API = `https://api.telegram.org/bot${TOKEN}`;

export function telegramConfigured(): boolean {
  return TOKEN.length > 0;
}

export type SendResult = { ok: boolean; error?: string };

/**
 * Messages use Telegram's HTML mode because it only requires escaping three
 * characters, whereas Markdown breaks on product names containing _ or *.
 */
export function escapeHtml(input: string): string {
  return input
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

export async function sendMessage(
  chatId: number | string,
  text: string,
  options: {
    disablePreview?: boolean;
    keyboard?: Array<Array<{ text: string; url?: string }>>;
  } = {}
): Promise<SendResult> {
  if (!telegramConfigured()) {
    return { ok: false, error: "telegram_not_configured" };
  }

  try {
    const res = await fetch(`${API}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text,
        parse_mode: "HTML",
        disable_web_page_preview: options.disablePreview ?? true,
        reply_markup: options.keyboard
          ? { inline_keyboard: options.keyboard }
          : undefined,
      }),
    });

    const payload = (await res.json()) as {
      ok: boolean;
      description?: string;
    };

    return payload.ok ? { ok: true } : { ok: false, error: payload.description };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
}

/** Called once after deploy. Not needed at runtime. */
export async function setWebhook(
  url: string,
  secretToken?: string
): Promise<SendResult> {
  try {
    const res = await fetch(`${API}/setWebhook`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        url,
        secret_token: secretToken,
        allowed_updates: ["message", "callback_query"],
      }),
    });
    const payload = (await res.json()) as { ok: boolean; description?: string };
    return payload.ok ? { ok: true } : { ok: false, error: payload.description };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
}
