/**
 * Notification outbox drain. Shared by the dispatcher endpoint and the webhook,
 * so a manual or late delivery is flushed the next time anything runs.
 */
import { adminClient } from "./supabase.ts";
import { sendMessage, telegramConfigured } from "./telegram.ts";

type Claimed = {
  notification_id: number;
  chat_id: number;
  kind: string;
  payload: Record<string, unknown>;
};

export type DrainResult = {
  sent: number;
  failed: number;
  skipped: number;
};

export async function drainOutbox(limit = 20): Promise<DrainResult> {
  if (!telegramConfigured()) {
    return { sent: 0, failed: 0, skipped: 0 };
  }

  const admin = adminClient();
  const { data, error } = await admin.rpc("telegram_claim_notifications", {
    p_limit: limit,
  });

  if (error || !data) {
    return { sent: 0, failed: 0, skipped: 0 };
  }

  let sent = 0;
  let failed = 0;

  for (const row of data as Claimed[]) {
    const text = render(row.kind, row.payload);
    const result = text === null
      ? { ok: false, error: "unknown_kind" }
      : await sendMessage(row.chat_id, text);

    await admin.rpc("telegram_ack_notification", {
      p_id: row.notification_id,
      p_ok: result.ok,
      p_error: result.error ?? null,
    });

    if (result.ok) sent++;
    else failed++;
  }

  return { sent, failed, skipped: 0 };
}

/** Returns null for a kind this build does not know how to render. */
function render(kind: string, payload: Record<string, unknown>): string | null {
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
