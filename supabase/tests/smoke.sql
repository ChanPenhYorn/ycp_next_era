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
  jsonb_build_object('userid', '123456789', 'serverid', '2001'),
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
  'WELCOME10', jsonb_build_object('userid', '123456789', 'serverid', '2001'), 'coupon_user_limit%');

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
  null, jsonb_build_object('userid', '123456789', 'serverid', '2001'), null, null) as wallet_order;
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

\echo '### 18. wallet top-up funds the wallet through the normal payment path'
reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select public.create_wallet_topup(25.00, 'buyer@example.test') as topup_order;
select id as toid from public.orders order by created_at desc limit 1 \gset
reset role;
select public.mark_order_paid(:'toid', 'payway', 'PW-TOPUP-0001', 'abapay_khqr_deeplink', null, null) as topup_settle;
select kind, amount_usd, balance_after from public.wallet_transactions
 where order_id = :'toid';
select status from public.orders where id = :'toid';

\echo '### 19. top-up limits are enforced'
create or replace function pg_temp.expect_topup_fail(p_amount numeric, p_expect text)
returns text language plpgsql as $$
begin
  perform public.create_wallet_topup(p_amount, null);
  return 'FAIL [topup ' || p_amount || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then return 'PASS [topup ' || p_amount || ']: ' || sqlerrm; end if;
    return 'FAIL [topup ' || p_amount || ']: got "' || sqlerrm || '"';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.expect_topup_fail(0.10, 'topup_below_minimum%');
select pg_temp.expect_topup_fail(999999, 'topup_above_maximum%');

\echo '### 20. supplier worker can see the auto_topup line'
reset role;
select item_id, sku, qty, supplier_code from public.supplier_pending_items(10);

\echo '### 21. fulfilling it closes the order'
select public.supplier_complete_item(
  (select item_id from public.supplier_pending_items(10) limit 1),
  true, 'MLBB-REF-0001', 0.82
) as fulfilled;
select order_no, status, delivered_at is not null as closed
  from public.orders where id = :'oid';

\echo '### 22. a failed supplier line refunds the buyer automatically'
reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb86, 'qty', 1)),
  null, jsonb_build_object('userid', '987654321', 'serverid', '2002'), null, null) as refund_order;
select id as roid from public.orders order by created_at desc limit 1 \gset
reset role;
select public.mark_order_paid(:'roid', 'payway', 'PW-REFUND-0001', 'abapay_khqr_deeplink', null, null) as refund_settle;
select wallet_balance from public.profiles where id = '22222222-2222-2222-2222-222222222222';

select public.supplier_complete_item(
  (select item_id from public.supplier_pending_items(10)
    where order_id = :'roid' limit 1),
  false, 'MLBB-REF-FAILED', 0
) as refunded;

select o.order_no, o.status, oi.delivery_status
  from public.orders o join public.order_items oi on oi.order_id = o.id
 where o.id = :'roid';
select kind, amount_usd, note from public.wallet_transactions
 where order_id = :'roid';

\echo '### 23. a buyer can only review a product they actually received'
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
insert into public.reviews (product_id, user_id, order_id, rating, body)
values (
  (select id from public.products where slug = 'mobile-legends-diamonds'),
  '22222222-2222-2222-2222-222222222222',
  :'oid', 5, 'Delivered in under a minute'
) returning id as review_id, is_approved;

\echo '### 23b. a non-buyer cannot review at all'
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
do $$
begin
  insert into public.reviews (product_id, user_id, order_id, rating, body)
  values (
    (select id from public.products where slug = 'mobile-legends-diamonds'),
    '33333333-3333-3333-3333-333333333333',
    null, 1, 'never bought this'
  );
  raise exception 'FAIL [review_guard]: a non-buyer was able to review';
exception
  when others then
    if sqlerrm like '%row-level security%' or sqlerrm like '%violates%' then
      raise notice 'PASS [review_guard]: blocked';
    else
      raise;
    end if;
end $$;

\echo '### 24. approving it moves the product rating and pays the coins'
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.admin_review_set_approved(
  (select id from public.reviews order by id desc limit 1), true, 5) as approved;
select slug, rating_avg, rating_count from public.products
 where slug = 'mobile-legends-diamonds';
select coins, coin_rewarded from public.profiles, public.reviews
 where public.profiles.id = '22222222-2222-2222-2222-222222222222'
   and public.reviews.id = (select id from public.reviews order by id desc limit 1);

\echo '### 25. housekeeping runs as staff'
select public.admin_run_housekeeping() as housekeeping;

\echo '### 26. telegram: the buyer generates a link code'
reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select public.create_telegram_link_code() as link_code;

\echo '### 27. the bot redeems it and the account is linked'
reset role;
select code as tcode from public.telegram_link_codes
 where used_at is null order by created_at desc limit 1 \gset
select public.link_telegram(:'tcode', 555001, 'buyer_kh') as linked;
select telegram_chat_id, telegram_username from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';

\echo '### 28. a code cannot be redeemed twice'
select public.link_telegram(:'tcode', 555002, 'someone_else') as second_attempt;

\echo '### 29. delivery wrote to the outbox before the account was linked'
select kind, status from public.notifications order by id desc limit 3;

\echo '### 30. claiming resolves the chat at send time, so late linking still delivers'
select id as nid from public.notifications where status = 'pending'
 order by id limit 1 \gset
select notification_id, chat_id, kind from public.telegram_claim_notifications(10);
select public.telegram_ack_notification(:'nid', true, null) as acked;
select status, sent_at is not null as sent from public.notifications where id = :'nid';

\echo '### 31. the bot can read back only this chat s own orders'
select public.telegram_profile_for_chat(555001) as profile;
select jsonb_array_length(public.telegram_orders_for_chat(555001, 5)) as own_orders;
select jsonb_array_length(public.telegram_orders_for_chat(999999, 5)) as other_chat_orders;

\echo '### 32. an order lookup returns codes for the owner, nothing for a stranger'
select order_no as ono from public.orders
 where id = :'oid' \gset
select public.telegram_order_by_no(555001, :'ono') as order_for_owner;
select public.telegram_order_by_no(999999, :'ono') as order_for_stranger;

\echo '### 33. unlinking stops the bot answering'
select public.telegram_unlink(555001) as unlinked;
select public.telegram_profile_for_chat(555001) as after_unlink;
select jsonb_array_length(public.telegram_orders_for_chat(555001, 5)) as orders_after_unlink;

\echo '### 34. supplier sync creates products, variants and SKU links'
reset role;
-- Field definitions, the shape supplier-sync sends after the adapter labels
-- them. The stored value must keep key/label_km/label_en: the app renders the
-- labels and create_order resolves the key.
select public.supplier_upsert_catalogue(
  'bay2game', 'mlbb_exclusive', 'Mobile Legends Bang Bang',
  'https://example.test/mlbb.png', 'KH top-up',
  '[{"key":"userid","label_km":"លេខ ID ហ្គេម","label_en":"Game ID","placeholder":"123456789"},
    {"key":"serverid","label_km":"Server","label_en":"Server","placeholder":"2001"}]'::jsonb,
  '[{"product_code":"MLBB_100","name":"100 Diamonds","price_usd":1.50,"sort":1},
    {"product_code":"MLBB_500","name":"500 Diamonds","price_usd":7.00,"sort":2}]'::jsonb
) as synced;

select p.slug, p.kind,
       p.requires_fields,
       -- A bare-string entry would make this null, which is the bug: the app
       -- cannot parse it and create_order skips validation.
       (select count(*) from jsonb_array_elements(p.requires_fields) f
         where f ? 'key') as fields_with_key
  from public.products p where p.slug = 'bay2game-mlbb_exclusive';
select v.sku, v.price_usd, v.cost_usd, ss.supplier_sku
  from public.product_variants v
  join public.supplier_skus ss on ss.variant_id = v.id
 where v.product_id = (select id from public.products where slug = 'bay2game-mlbb_exclusive')
 order by v.sku;

\echo '### 35. re-syncing updates in place instead of duplicating'
-- Bare names on the way in, as an adapter with no label metadata would send
-- them. They must come out as definitions with the key doubling as the label.
select public.supplier_upsert_catalogue(
  'bay2game', 'mlbb_exclusive', 'Mobile Legends Bang Bang',
  'https://example.test/mlbb.png', 'KH top-up', '["userid","serverid"]'::jsonb,
  '[{"product_code":"MLBB_100","name":"100 Diamonds","price_usd":1.55,"sort":1},
    {"product_code":"MLBB_500","name":"500 Diamonds","price_usd":7.10,"sort":2}]'::jsonb
) as resynced;
select count(*) as variants from public.product_variants
 where sku in ('MLBB_100','MLBB_500');
select sku, cost_usd from public.product_variants
 where sku in ('MLBB_100','MLBB_500') order by sku;
select requires_fields as normalised_bare_names
  from public.products where slug = 'bay2game-mlbb_exclusive';

\echo '### 36. a supplier line is only routable once the supplier is active'
-- is_active is seeded false so a key-less supplier is never selected. Sync
-- flips it on, which is what stops "key set, nothing fulfils".
update public.suppliers set is_active = false where code = 'bay2game';
select count(*) as routable_while_inactive
  from public.supplier_pending_items(50) where supplier_code = 'bay2game';

update public.suppliers set is_active = true where code = 'bay2game';

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select public.create_order(
  jsonb_build_array(jsonb_build_object(
    'variant_id', (select id from public.product_variants where sku = 'MLBB_100'), 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '3543'), null, null) as supplier_order;
select id as soid2 from public.orders order by created_at desc limit 1 \gset
reset role;
select public.mark_order_paid(:'soid2', 'payway', 'PW-SUP-0001', 'abapay_khqr_deeplink', null, null) as settled;

select wallet_balance as balance_before from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';

select item_id, supplier_code, supplier_sku, qty, customer_fields, attempts
  from public.supplier_pending_items(50) where order_id = :'soid2';

select item_id as sid from public.supplier_pending_items(50)
 where order_id = :'soid2' limit 1 \gset

\echo '### 37. a transient failure records an attempt and moves no money'
select public.supplier_note_failure(
  :'sid', 'supplier_out_of_balance: Insufficient balance', 60) as noted;

select wallet_balance as balance_after from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';
select supplier_attempts, supplier_last_error, delivery_status
  from public.order_items where id = :'sid';

\echo '### 38. backoff removes it from the queue until the retry window passes'
select count(*) as queued_during_backoff
  from public.supplier_pending_items(50) where order_id = :'soid2';

\echo '### 39. after the attempt limit it escalates to staff, still without refunding'
-- Drive it straight to the limit; the retry window would otherwise hide it.
select public.supplier_note_failure(:'sid', 'still out of balance', 0) as attempt_2;
select public.supplier_note_failure(:'sid', 'still out of balance', 0) as attempt_3;
select public.supplier_note_failure(:'sid', 'still out of balance', 0) as attempt_4;
select public.supplier_note_failure(:'sid', 'still out of balance', 0) as attempt_5;

select supplier_attempts, delivery_status, supplier_last_error
  from public.order_items where id = :'sid';
select wallet_balance as balance_after_escalation from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';

\echo '### 40. final state'
select (select count(*) from public.orders)  as orders,
       (select count(*) from public.order_items) as items,
       (select count(*) from public.payments) as payments,
       (select count(*) from public.wallet_transactions) as wallet_tx,
       (select count(*) from public.reviews) as reviews;
select v.sku, vs.in_stock from public.product_variants v
  join public.variant_stock vs on vs.variant_id = v.id order by v.sku;
