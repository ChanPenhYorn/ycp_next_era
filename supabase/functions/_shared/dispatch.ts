/**
 * Notification outbox drain. Shared by the dispatcher endpoint and the webhook,
 * so a manual or late delivery is flushed the next time anything runs.
 */
import { adminClient } from "./supabase.ts";
import { sendMessage, telegramConfigured } from "./telegram/client.ts";
import { notificationText } from "./telegram/messages.ts";

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
    const text = notificationText(row.kind, row.payload);
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
