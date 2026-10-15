export type ProductKind = "instant_stock" | "auto_topup" | "manual_setup";

export type RequiredField = {
  key: string;
  label_km: string;
  label_en: string;
  placeholder?: string;
  pattern?: string;
};

export type Category = {
  id: number;
  slug: string;
  name_km: string;
  name_en: string;
  icon_url: string | null;
  sort_order: number;
};

export type Variant = {
  id: number;
  sku: string;
  label_km: string;
  label_en: string;
  price_usd: number;
  compare_at_price_usd: number | null;
  stock_mode: "stock" | "unlimited";
  min_qty: number;
  max_qty: number;
  sort_order: number;
  in_stock: number | null;
};

export type ProductCard = {
  id: number;
  slug: string;
  name_km: string;
  name_en: string;
  summary_km: string | null;
  summary_en: string | null;
  image_url: string | null;
  kind: ProductKind;
  rating_avg: number;
  rating_count: number;
  sold_count: number;
  category: Pick<Category, "slug" | "name_km" | "name_en"> | null;
  min_price_usd: number;
  max_price_usd: number;
  compare_at_price_usd: number | null;
  total_stock: number | null;
  is_sold_out: boolean;
};

export type ProductDetail = ProductCard & {
  description_km: string | null;
  description_en: string | null;
  requires_fields: RequiredField[];
  variants: Variant[];
  category: Category | null;
};

export type Review = {
  id: number;
  rating: number;
  body: string | null;
  created_at: string;
  author_name: string | null;
};

export type OrderStatus =
  | "pending"
  | "paid"
  | "delivering"
  | "delivered"
  | "failed"
  | "refunded"
  | "expired";

export type DeliveryStatus = "pending" | "delivered" | "failed" | "manual_waiting";

export type OrderLine = {
  id: number;
  variant_id: number | null;
  product_name: string;
  variant_label: string;
  unit_price_usd: number;
  qty: number;
  line_total_usd: number;
  delivery_status: DeliveryStatus;
  delivered_at: string | null;
};

export type Order = {
  id: string;
  order_no: string;
  status: OrderStatus;
  currency: string;
  subtotal_usd: number;
  discount_usd: number;
  total_usd: number;
  coupon_code: string | null;
  contact_email: string | null;
  customer_fields: Record<string, string>;
  expires_at: string;
  paid_at: string | null;
  delivered_at: string | null;
  created_at: string;
  items: OrderLine[];
};

export type PublicSettings = {
  site_name: string;
  support_telegram: string | null;
  support_email: string | null;
  usd_to_khr: number;
  order_ttl_minutes: number;
  khqr_account_id: string | null;
  khqr_merchant_name: string | null;
  khqr_merchant_city: string | null;
  is_maintenance: boolean;
};
