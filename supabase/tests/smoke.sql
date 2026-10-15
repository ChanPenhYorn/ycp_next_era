-- ============================================================================
-- End-to-end smoke test. Run as a superuser; it switches into the
-- `authenticated` role wherever RLS needs to apply.
--
--   docker exec -i ycp-pg psql -U postgres -d ycp -v ON_ERROR_STOP=1 -f - \
--     < supabase/tests/smoke.sql
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

-- Helper: assert that create_order raises an error matching a pattern.
-- Lives in pg_temp so psql variables can be passed as arguments.
create or replace function pg_temp.expect_fail(
  p_label  text,
  p_items  jsonb,
  p_coupon text,
  p_fields jsonb,
  p_expect text
) returns text
language plpgsql
as $$
begin
  perform public.create_order(p_items, p_coupon, p_fields, null, null);
  return 'FAIL [' || p_label || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then
      return 'PASS [' || p_label || ']: ' || sqlerrm;
    end if;
    return 'FAIL [' || p_label || ']: got "' || sqlerrm || '"';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

select id as mlbb86  from public.product_variants where sku = 'MLBB-86'  \gset
select id as mlbb172 from public.product_variants where sku = 'MLBB-172' \gset
select id as steam5  from public.product_variants where sku = 'STEAM-5'  \gset

\echo '### 1. catalogue + live stock are publicly readable'
select p.slug, v.sku, v.price_usd, vs.in_stock
  from public.products p
  join public.product_variants v on v.product_id = p.id
  join public.variant_stock vs on vs.variant_id = v.id
 order by v.sku;

\echo '### 2. buyer creates an order: 2x MLBB-86 + 1x STEAM-5 with WELCOME10'
select public.create_order(
  jsonb_build_array(
    jsonb_build_object('variant_id', :mlbb86, 'qty', 2),
    jsonb_build_object('variant_id', :steam5, 'qty', 1)
  ),
  'WELCOME10',
  jsonb_build_object('game_id', '123456789', 'server_id', '2001'),
  'buyer@example.test',
  'please deliver fast'
) as created_order;

select id as oid from public.orders order by created_at desc limit 1 \gset

\echo '### 3. totals computed server-side (expect subtotal 7.48, discount 0.75, total 6.73)'
select order_no, status, subtotal_usd, discount_usd, total_usd, coupon_code
  from public.orders where id = :'oid';
select product_name, variant_label, qty, unit_price_usd, line_total_usd, delivery_status
  from public.order_items where order_id = :'oid' order by id;

\echo '### 4. paying from an empty wallet must be refused'
select public.pay_order_with_wallet(:'oid') as wallet_attempt;

\echo '### 5. service role settles the payment, twice (idempotency)'
reset role;
select public.mark_order_paid(:'oid', 'payway', 'PW-TEST-0001', 'khqr',
         '{"tran_id":"PW-TEST-0001"}'::jsonb, 27588) as settle_first;
select public.mark_order_paid(:'oid', 'payway', 'PW-TEST-0001', 'khqr',
         '{"tran_id":"PW-TEST-0001"}'::jsonb, 27588) as settle_again;
select count(*) as payment_rows_for_order from public.payments where order_id = :'oid';

\echo '### 6. delivery split: Steam delivered instantly, MLBB waits for the supplier worker'
select o.order_no, o.status, o.paid_at is not null as paid, o.delivered_at is not null as fully_delivered
  from public.orders o where o.id = :'oid';
select product_name, delivery_status from public.order_items where order_id = :'oid' order by id;

\echo '### 7. steam stock dropped 3 -> 2, coupon counted once'
select v.sku, vs.in_stock from public.product_variants v
  join public.variant_stock vs on vs.variant_id = v.id where v.sku = 'STEAM-5';
select code, used_count from public.coupons;
select count(*) as coupon_redemptions from public.coupon_redemptions;

\echo '### 8. buyer reveals the order and gets the decrypted code'
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select jsonb_pretty(public.reveal_order(:'oid')) as revealed;

\echo '### 9. buyer sees only their own order'
select count(*) as visible_orders from public.orders;

\echo '### 10. a stranger can neither see nor reveal that order'
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select count(*) as stranger_visible_orders from public.orders;
select case
         when (select count(*) from public.orders) = 0 then 'PASS [rls]: stranger sees 0 orders'
         else 'FAIL [rls]: stranger sees orders'
       end as rls_check;
do $$
begin
  perform public.reveal_order((select id from public.orders order by created_at desc limit 1));
  raise exception 'FAIL: a stranger was able to reveal the order';
exception
  when others then
    if sqlerrm = 'not_authorized' then raise notice 'PASS [reveal]: stranger blocked';
    else raise; end if;
end $$;

\echo '### 11. validation guards'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.expect_fail(
  'oversell', jsonb_build_array(jsonb_build_object('variant_id', :steam5, 'qty', 3)),
  null, '{}'::jsonb, 'out_of_stock%');
select pg_temp.expect_fail(
  'max_qty', jsonb_build_array(jsonb_build_object('variant_id', :steam5, 'qty', 9)),
  null, '{}'::jsonb, 'qty_out_of_range%');
select pg_temp.expect_fail(
  'required_fields', jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, '{}'::jsonb, 'missing_fields%');
select pg_temp.expect_fail(
  'empty_cart', '[]'::jsonb, null, '{}'::jsonb, 'empty_cart%');
select pg_temp.expect_fail(
  'reuse_coupon', jsonb_build_array(jsonb_build_object('variant_id', :mlbb86, 'qty', 2)),
  'WELCOME10', jsonb_build_object('game_id', '123456789', 'server_id', '2001'), 'coupon_user_limit%');

\echo '### 12. coupon preview endpoint'
select public.validate_coupon('NOPE', 10)      as unknown_coupon;
select public.validate_coupon('WELCOME10', 10) as already_used_coupon;

\echo '### 13. wallet top-up, then pay from balance'
reset role;
select private.credit_wallet('22222222-2222-2222-2222-222222222222', 20.00, 'topup', null, 'test credit') as new_balance;
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb86, 'qty', 1)),
  null, jsonb_build_object('game_id', '123456789', 'server_id', '2001'), null, null) as wallet_order;
select id as woid from public.orders order by created_at desc limit 1 \gset
select public.pay_order_with_wallet(:'woid') as wallet_pay;
select wallet_balance from public.profiles where id = '22222222-2222-2222-2222-222222222222';
select kind, amount_usd, balance_after from public.wallet_transactions
 where user_id = '22222222-2222-2222-2222-222222222222' order by id;

\echo '### 14. short stock pick rolls back cleanly and queues the item for manual delivery'
reset role;
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :steam5, 'qty', 2)),
  null, '{}'::jsonb, null, null) as short_order;
reset role;
-- Sneak one code out of the vault behind create_order:s back.
update private.stock_items set status = 'void'
 where id = (select id from private.stock_items where status = 'available' limit 1);
select id as soid from public.orders order by created_at desc limit 1 \gset
select public.mark_order_paid(:'soid', 'payway', 'PW-TEST-0002', 'khqr', null, null) as settle_short;
select oi.qty, oi.delivery_status, o.status
  from public.order_items oi join public.orders o on o.id = oi.order_id
 where oi.order_id = :'soid';

\echo '### 15. nothing was stranded: stock is back to available after the rollback'
select v.sku, vs.in_stock from public.product_variants v
  join public.variant_stock vs on vs.variant_id = v.id where v.sku = 'STEAM-5';
select status, count(*) from private.stock_items group by status order by status;

\echo '### 16. staff resolves the manual item and the order closes'
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.admin_resolve_item(
  (select id from public.order_items where order_id = :'soid' order by id limit 1), 'delivered') as resolved;
select order_no, status, delivered_at is not null as closed from public.orders where id = :'soid';

\echo '### 17. expiry sweep'
select public.expire_stale_orders() as expired_orders;

\echo '### 18. final state'
select (select count(*) from public.orders)  as orders,
       (select count(*) from public.order_items) as items,
       (select count(*) from public.payments) as payments,
       (select count(*) from public.wallet_transactions) as wallet_tx,
       (select count(*) from public.reviews) as reviews;
select v.sku, vs.in_stock from public.product_variants v
  join public.variant_stock vs on vs.variant_id = v.id order by v.sku;
