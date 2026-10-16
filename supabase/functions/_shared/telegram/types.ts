/**
 * Telegram Bot API types and the shapes the bot reads back from Postgres.
 *
 * The RPC shapes mirror the functions in supabase/migrations/20261015000500_telegram.sql.
 * Changing one means changing the other.
 */

export type Update = {
  message?: {
    chat: { id: number; type: string };
    from?: { id: number; username?: string; first_name?: string };
    text?: string;
  };
};

export type Keyboard = Array<Array<{ text: string; url?: string }>>;

export type SendOptions = {
  disablePreview?: boolean;
  keyboard?: Keyboard;
};

export type SendResult = { ok: boolean; error?: string };

export type OrderSummary = {
  order_no: string;
  status: string;
  total_usd: number;
  items: string[];
};

export type OrderDetail = {
  order_no: string;
  status: string;
  total_usd: number;
  items: Array<{
    name: string;
    qty: number;
    delivery_status: string;
    codes: string[];
  }>;
};

export type WalletProfile = {
  wallet_balance: number;
  coins: number;
};

export type LinkResult = {
  ok?: boolean;
  reason?: string;
};
