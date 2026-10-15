export function usd(value: number | string): string {
  const n = typeof value === "string" ? Number(value) : value;
  return `$${n.toFixed(2)}`;
}

export function khr(value: number | string, rate: number): string {
  const n = typeof value === "string" ? Number(value) : value;
  return `៛${Math.round(n * rate).toLocaleString("en-US")}`;
}

export function discountPercent(
  price: number,
  compareAt: number | null | undefined
): number | null {
  if (!compareAt || compareAt <= price) return null;
  return Math.round(((compareAt - price) / compareAt) * 100);
}

/** `20250728022056` - PayWay's req_time format, always UTC. */
export function paywayTimestamp(date: Date = new Date()): string {
  const p = (n: number, width = 2) => String(n).padStart(width, "0");
  return (
    date.getUTCFullYear().toString() +
    p(date.getUTCMonth() + 1) +
    p(date.getUTCDate()) +
    p(date.getUTCHours()) +
    p(date.getUTCMinutes()) +
    p(date.getUTCSeconds())
  );
}

/** Order numbers and PayWay tran_ids must stay under 20 characters. */
export function tranIdFromOrder(orderNo: string): string {
  return orderNo.slice(0, 20);
}
