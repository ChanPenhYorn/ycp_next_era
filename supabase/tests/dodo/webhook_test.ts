/**
 * Dodo webhook verification tests. No network: the signature helper is the
 * only thing that decides whether a payment is trusted, so it is exercised
 * directly with a known secret.
 *
 *   deno test --allow-env supabase/tests/dodo/
 */
import { assertEquals } from "jsr:@std/assert@1";
import { toSettleState, usdToCents, verifyWebhook } from "../../functions/_shared/dodo.ts";

const SECRET = "whsec_dGVzdC1zZWNyZXQ="; // base64("test-secret")

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function sign(
  id: string,
  timestamp: string,
  body: string,
  secret = SECRET
): Promise<string> {
  const raw = secret.startsWith("whsec_") ? secret.slice(6) : secret;
  const keyBytes = Uint8Array.from(atob(raw), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`${id}.${timestamp}.${body}`)
    )
  );
  return `v1,${base64(digest)}`;
}

function headers(values: Record<string, string>): Headers {
  const h = new Headers();
  for (const [key, value] of Object.entries(values)) h.set(key, value);
  return h;
}

const NOW_MS = 1_764_000_000_000;
const NOW = String(NOW_MS / 1000);
const BODY = JSON.stringify({
  type: "payment.succeeded",
  data: { payment_id: "pay_1", total_amount: 1200, currency: "USD" },
});

Deno.test("accepts a correctly signed body", async () => {
  const signature = await sign("evt_1", NOW, BODY);
  const result = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": NOW,
      "webhook-signature": signature,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.event.type, "payment.succeeded");
    assertEquals(result.event.data?.payment_id, "pay_1");
  }
});

Deno.test("rejects a tampered body", async () => {
  const signature = await sign("evt_1", NOW, BODY);
  const tampered = BODY.replace("1200", "100");

  const result = await verifyWebhook(
    tampered,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": NOW,
      "webhook-signature": signature,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(result, { ok: false, reason: "bad_signature" });
});

Deno.test("signs the id and timestamp, not only the body", async () => {
  const signature = await sign("evt_1", NOW, BODY);

  const otherId = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_2",
      "webhook-timestamp": NOW,
      "webhook-signature": signature,
    }),
    SECRET,
    NOW_MS
  );
  const otherTime = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": String(Number(NOW) + 1),
      "webhook-signature": signature,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(otherId.ok, false);
  assertEquals(otherTime.ok, false);
});

Deno.test("rejects a replay outside the tolerance window", async () => {
  const old = String(Number(NOW) - 600);
  const signature = await sign("evt_1", old, BODY);

  const result = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": old,
      "webhook-signature": signature,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(result, { ok: false, reason: "stale_timestamp" });
});

Deno.test("accepts one valid signature among several", async () => {
  const valid = await sign("evt_1", NOW, BODY);
  const header = `v1,AAAA ${valid}`;

  const result = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": NOW,
      "webhook-signature": header,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(result.ok, true);
});

Deno.test("ignores signatures from other schemes", async () => {
  const valid = await sign("evt_1", NOW, BODY);
  const header = valid.replace("v1,", "v2,");

  const result = await verifyWebhook(
    BODY,
    headers({
      "webhook-id": "evt_1",
      "webhook-timestamp": NOW,
      "webhook-signature": header,
    }),
    SECRET,
    NOW_MS
  );

  assertEquals(result, { ok: false, reason: "bad_signature" });
});

Deno.test("missing headers are refused, not treated as unsigned", async () => {
  const result = await verifyWebhook(BODY, headers({}), SECRET, NOW_MS);
  assertEquals(result, { ok: false, reason: "missing_headers" });
});

Deno.test("maps Dodo statuses onto the app's vocabulary", () => {
  assertEquals(toSettleState("succeeded"), "APPROVED");
  assertEquals(toSettleState("failed"), "DECLINED");
  assertEquals(toSettleState("cancelled"), "CANCELLED");
  assertEquals(toSettleState("processing"), "PENDING");
  assertEquals(toSettleState(undefined), "PENDING");
});

Deno.test("converts dollars to cents without float drift", () => {
  assertEquals(usdToCents(4.35), 435);
  assertEquals(usdToCents(0.1 + 0.2), 30);
  assertEquals(usdToCents(19.99), 1999);
});
