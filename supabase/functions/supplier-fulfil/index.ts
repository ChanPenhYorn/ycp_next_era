/**
 * supplier-fulfil
 *
 * Drains auto_topup lines that are waiting on a supplier. This is the piece
 * that turns "money taken" into "goods delivered".
 *
 * POST { limit?: number }
 *
 * Outcomes map onto three different database calls, and the distinction is the
 * whole point of the exercise:
 *   delivered -> supplier_complete_item(success)  closes the line
 *   refund    -> supplier_complete_item(failure)  returns money to the wallet
 *   retry     -> supplier_note_failure            keeps it pending, backs off
 *
 * A transient failure or an empty supplier balance must never refund a buyer
 * who paid correctly.
 */
import { adminClient, json, preflight } from "../_shared/supabase.ts";
import type { FulfilResult, SupplierAdapter } from "../_shared/suppliers/types.ts";
import { bay2game } from "../_shared/suppliers/bay2game.ts";

const ADAPTERS: Record<string, SupplierAdapter> = {
  bay2game,
};

type PendingItem = {
  item_id: number;
  order_id: string;
  order_no: string;
  variant_id: number;
  sku: string;
  qty: number;
  customer_fields: Record<string, string> | null;
  supplier_code: string | null;
  supplier_sku: string | null;
  cost_usd: number | null;
  attempts: number;
};

export async function runFulfilment(limit = 10): Promise<Record<string, unknown>> {
  const admin = adminClient();

  const { data, error } = await admin.rpc("supplier_pending_items", {
    p_limit: limit,
  });

  if (error || !data) {
    return { error: "claim_failed", detail: error?.message };
  }

  const items = data as PendingItem[];
  const summary = { processed: 0, delivered: 0, refunded: 0, deferred: 0, failed: 0 };

  for (const item of items) {
    summary.processed++;

    const adapter = item.supplier_code ? ADAPTERS[item.supplier_code] : undefined;

    if (!adapter || !adapter.configured() || !item.supplier_sku) {
      // Not something this worker can do: a human has to look at it.
      await admin.rpc("supplier_note_failure", {
        p_item_id: item.item_id,
        p_error: !adapter
          ? `no_adapter_for:${item.supplier_code ?? "unlinked"}`
          : !adapter.configured()
            ? `${adapter.code}_not_configured`
            : "missing_supplier_sku",
        p_retry_in_minutes: 240,
      });
      summary.deferred++;
      continue;
    }

    let result: FulfilResult;
    try {
      result = await adapter.fulfil({
        itemId: item.item_id,
        orderNo: item.order_no,
        supplierSku: item.supplier_sku,
        quantity: item.qty,
        customerFields: item.customer_fields ?? {},
      });
    } catch (error) {
      await admin.rpc("supplier_note_failure", {
        p_item_id: item.item_id,
        p_error: String(error),
        p_retry_in_minutes: 15,
      });
      summary.deferred++;
      continue;
    }

    if (result.outcome === "delivered") {
      const { error: completeError } = await admin.rpc("supplier_complete_item", {
        p_item_id: item.item_id,
        p_success: true,
        p_supplier_ref: result.reference,
        p_cost_usd: result.costUsd ?? item.cost_usd,
      });
      completeError ? summary.failed++ : summary.delivered++;

    } else if (result.outcome === "refund") {
      const { error: refundError } = await admin.rpc("supplier_complete_item", {
        p_item_id: item.item_id,
        p_success: false,
        p_supplier_ref: result.reference ?? `refund:${result.reason}`.slice(0, 200),
        p_cost_usd: null,
      });
      refundError ? summary.failed++ : summary.refunded++;

    } else {
      await admin.rpc("supplier_note_failure", {
        p_item_id: item.item_id,
        p_error: result.reason,
        p_retry_in_minutes: result.retryInMinutes,
      });
      summary.deferred++;
    }
  }

  return { ok: true, ...summary };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const expected = Deno.env.get("SUPPLIER_JOB_SECRET");
  if (expected && req.headers.get("x-job-secret") !== expected) {
    return json({ error: "unauthorized" }, 401);
  }

  let limit = 10;
  try {
    const body = await req.json();
    if (typeof body?.limit === "number") limit = Math.min(Math.max(body.limit, 1), 50);
  } catch {
    // defaults
  }

  return json(await runFulfilment(limit));
});
