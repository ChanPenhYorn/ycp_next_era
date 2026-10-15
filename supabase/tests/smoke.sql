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

-- ============================================================================
-- order_events, support tickets and the refund states
-- ============================================================================
reset role;

\echo '### 41. every status transition is in the history, in order'
-- :oid went pending -> paid -> delivering -> delivered. Nothing wrote an
-- event by hand; the trigger on public.orders did, which is the point.
select event, from_status, to_status, actor
  from public.order_events where order_id = :'oid' order by id;

\echo '### 42. a repeated settlement does not add a duplicate event'
-- Section 5 settled :oid twice. One transition means one row.
select count(*) as paid_events
  from public.order_events where order_id = :'oid' and to_status = 'paid';

\echo '### 43. the history is append-only for a customer'
set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
do $$
begin
  insert into public.order_events (order_id, to_status, event)
  values ((select id from public.orders order by created_at limit 1), 'paid', 'forged');
  raise exception 'FAIL [order_events]: a customer inserted a history row';
exception
  when others then
    if sqlerrm like '%permission denied%' then
      raise notice 'PASS [order_events]: insert refused';
    else
      raise;
    end if;
end $$;

\echo '### 44. a customer reads only their own order s history'
select count(*) as own_events
  from public.order_events where order_id = :'oid';

select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select count(*) as stranger_events
  from public.order_events where order_id = :'oid';

\echo '### 45. a buyer opens a support ticket against their own order'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_support_ticket(
  'Diamonds did not arrive',
  'Order shows delivered but the ID is empty.',
  :'oid',
  'buyer@example.test'
) as ticket_created;

select id as tid from public.support_tickets order by id desc limit 1 \gset

\echo '### 46. a second ticket seconds later is rate limited'
-- The order id has to come from psql, not from a subquery: RLS correctly hides
-- every order from a stranger, so `select id from orders` would hand the
-- function a NULL and skip the very check under test.
create or replace function pg_temp.expect_support_fail(
  p_order   uuid,
  p_subject text,
  p_expect  text
) returns text
language plpgsql
as $$
begin
  perform public.create_support_ticket(p_subject, 'body', p_order, null);
  return 'FAIL [support ' || p_subject || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then
      return 'PASS [support ' || p_subject || ']: ' || sqlerrm;
    end if;
    return 'FAIL [support ' || p_subject || ']: got "' || sqlerrm || '"';
end $$;

select pg_temp.expect_support_fail(null, 'again', 'ticket_rate_limited%');

\echo '### 47. a ticket cannot be raised against a stranger s order'
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
select pg_temp.expect_support_fail(:'oid', 'not mine', 'order_not_found%');

\echo '### 48. the stranger cannot see the buyer s tickets either'
select count(*) as stranger_tickets
  from public.support_tickets where id = :'tid';

\echo '### 49. staff see it and resolve it'
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;
select public.admin_support_set_status(:'tid', 'resolved', 'Refund offered.', 'high') as staff_resolved;
select subject, status, priority, resolved_at is not null as closed
  from public.support_tickets where id = :'tid';

\echo '### 50. a customer cannot resolve their own ticket'
reset role;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
do $$
begin
  perform public.admin_support_set_status(
    (select id from public.support_tickets order by id desc limit 1), 'closed', null, null);
  raise exception 'FAIL [support]: a customer resolved their own ticket';
exception
  when others then
    if sqlerrm = 'not_authorized' then raise notice 'PASS [support]: staff-only';
    else raise; end if;
end $$;

\echo '### 51. a customer cannot declare a refund either'
do $$
begin
  perform public.admin_order_set_refund_pending((select id from public.orders order by created_at limit 1), 'because');
  raise exception 'FAIL [refund]: a customer set refund_pending';
exception
  when others then
    if sqlerrm = 'not_authorized' then raise notice 'PASS [refund]: staff-only';
    else raise; end if;
end $$;

\echo '### 52. staff move the failed order through refund_pending to refunded'
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;

select public.admin_order_set_refund_pending(:'roid', 'supplier could not deliver') as set_pending;
select status, refund_reason from public.orders where id = :'roid';

-- The guard runs the other way too: only refund_pending may become refunded,
-- so a live order that is still being delivered cannot be written off.
select public.admin_order_mark_refunded(:'oid', 'not agreed') as refused_on_live_order;
select status from public.orders where id = :'oid';

select public.admin_order_mark_refunded(:'roid', 'ABA reversal 88213') as marked_refunded;
select status, refunded_at is not null as refunded from public.orders where id = :'roid';

\echo '### 53. the settled payment is marked refunded too'
select provider, status, refunded_at is not null as refunded
  from public.payments where order_id = :'roid';

\echo '### 54. the refund transitions are in the order history'
select event, from_status, to_status, actor
  from public.order_events where order_id = :'roid' order by id;

\echo '### 55. schema additions in place'
select
  (select count(*) from public.order_events) as order_events,
  (select count(*) from public.support_tickets) as support_tickets,
  (select count(*) from public.orders where status = 'refund_pending') as still_pending,
  (select count(*) from public.orders where status = 'refunded') as refunded;

\echo '### 56. a buyer field that does not match the catalogue pattern is refused'
-- The app checks this too, but the RPC is reachable on its own and an older
-- build is a normal thing to be running. 'abc' as a game id used to be
-- accepted here: the buyer paid, the supplier rejected it, and the automatic
-- path refunded the wallet for a sale that could never have happened.
select pg_temp.expect_fail(
  'game_id_not_numeric', jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', 'abc', 'serverid', '2001'), 'invalid_fields%');
select pg_temp.expect_fail(
  'server_too_short', jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '20'), 'invalid_fields%');

\echo '### 57. an over-long value is refused before it reaches a supplier'
select pg_temp.expect_fail(
  'game_id_too_long', jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', repeat('9', 200), 'serverid', '2001'), 'invalid_fields%');

\echo '### 58. the same field with a value it expects still creates the order'
-- The gate must refuse the bad value without refusing the good one. This
-- product has unlimited stock, so a successful call is the only outcome that
-- proves the pattern check passed rather than the stock check firing first.
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as valid_id_order;

\echo '### 59. an unusable pattern is no constraint rather than a dead product'
-- A pattern is data: staff or an adapter writes it, so it can be wrong. If a
-- broken one raised, every order for that product would fail and the game
-- would be unsellable over a typo in a validation string.
reset role;
select public.field_pattern_matches('abc', '([unclosed')          as broken_pattern_fails_open,
       public.field_pattern_matches('abc', '^[0-9]+$')            as non_matching,
       public.field_pattern_matches('262856740', '^[0-9]{6,12}$') as matching,
       public.field_pattern_matches('anything', '')               as no_pattern,
       public.field_pattern_matches(null, '^[0-9]+$')             as null_value;


-- ---------------------------------------------------------------------------
-- Manual KHQR fallback (M4). The automated path must keep working, and this
-- path has to move money exactly once, against a reference nobody has used.
-- ---------------------------------------------------------------------------
-- psql does not interpolate a variable inside a string literal, so the order id
-- is passed as an argument rather than built into the SQL text.
create or replace function pg_temp.expect_request_fail(
  p_label text, p_order uuid, p_expect text
) returns text
language plpgsql
as $$
begin
  perform public.request_manual_payment(p_order, null);
  return 'FAIL [' || p_label || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then return 'PASS [' || p_label || ']: ' || sqlerrm; end if;
    return 'FAIL [' || p_label || ']: got "' || sqlerrm || '"';
end $$;

create or replace function pg_temp.expect_confirm_fail(
  p_label text, p_order uuid, p_amount numeric, p_ref text, p_expect text
) returns text
language plpgsql
as $$
begin
  perform public.admin_confirm_manual_payment(p_order, p_amount, p_ref, null);
  return 'FAIL [' || p_label || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then return 'PASS [' || p_label || ']: ' || sqlerrm; end if;
    return 'FAIL [' || p_label || ']: got "' || sqlerrm || '"';
end $$;

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);

\echo '### 60. asking to pay by transfer keeps the order payable, and moves no money'
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as manual_a;
select id as maid from public.orders order by created_at desc limit 1 \gset

select public.request_manual_payment(:'maid', 'paid from ABA at 10:20') as requested_a;
-- Extended well past the 15-minute TTL, because an instant transfer is not
-- instant, and no payment row is created just by asking.
select o.status,
       o.manual_payment_requested_at is not null as flagged,
       o.expires_at > now() + interval '1 hour' as payable_longer,
       (select count(*) from public.payments where order_id = o.id) as payment_rows
  from public.orders o where o.id = :'maid';
select event, actor, to_status from public.order_events
 where order_id = :'maid' order by id;

\echo '### 61. asking twice keeps the first request, and does not push the expiry out'
select public.request_manual_payment(:'maid') as second_request;
select count(*) as request_events from public.order_events
 where order_id = :'maid' and event = 'manual_payment_requested';

\echo '### 62. a customer cannot confirm a payment'
select pg_temp.expect_confirm_fail('customer_cannot_confirm', :'maid', 1.89, 'ABA-REF-X', 'not_authorized%');

\echo '### 63. staff state the amount, and it must cover the total'
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
-- Staff can read the order, but asking is for the buyer: the RPC must not treat
-- a staff session as the owner.
select pg_temp.expect_request_fail('staff_is_not_the_buyer', :'maid', 'order_not_found%');
select total_usd as total_owed from public.orders where id = :'maid';
select pg_temp.expect_confirm_fail('underpaid', :'maid', 1.00, 'ABA-REF-X', 'manual_underpaid%');
select pg_temp.expect_confirm_fail('no_reference', :'maid', 5.00, '   ', 'manual_reference_required%');
select pg_temp.expect_confirm_fail('zero_amount', :'maid', 0, 'ABA-REF-X', 'amount_required%');

\echo '### 64. one transfer can only settle one order'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as manual_b;
select id as mbid from public.orders order by created_at desc limit 1 \gset
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

select public.admin_confirm_manual_payment(:'mbid', 1.89, 'ABA-REF-1') as confirmed_b;
select pg_temp.expect_confirm_fail('reference_already_used', :'maid', 1.89, 'ABA-REF-1', 'manual_reference_used%');

\echo '### 65. confirming settles once, through the path PayWay uses'
select public.admin_confirm_manual_payment(:'maid', 2.00, 'ABA-REF-2', 'bank app shows 2.00') as confirmed_a;
select status, paid_at is not null as paid from public.orders where id = :'maid';
select provider, status, amount_usd, provider_ref, verified_at is not null as verified
  from public.payments where order_id = :'maid';
-- Delivery is the same hand-off a PayWay settlement performs: an auto_topup line
-- goes to the supplier queue, so the order is past 'pending' but not 'delivered'.
select status as order_status from public.orders where id = :'maid';
select event, actor, from_status, to_status from public.order_events
 where order_id = :'maid' order by id;

\echo '### 66. confirming again is a no-op, not a second delivery'
select public.admin_confirm_manual_payment(:'maid', 1.89, 'ABA-REF-2') as confirmed_again;
select count(*) as payment_rows_for_order from public.payments where order_id = :'maid';
select count(*) as delivery_events from public.order_events
 where order_id = :'maid' and event in ('delivering', 'delivered');
select count(*) as confirm_events from public.order_events
 where order_id = :'maid' and event = 'manual_payment_confirmed';

\echo '### 67. an expired order is not settled by hand'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as manual_c;
select id as mcid from public.orders order by created_at desc limit 1 \gset
reset role;
update public.orders set expires_at = now() - interval '1 minute' where id = :'mcid';
set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select pg_temp.expect_confirm_fail('expired_order_refused', :'mcid', 1.89, 'ABA-REF-3', 'order_expired%');

\echo '### 68. asking on a settled order is refused, and a request can be dismissed'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.expect_request_fail('not_pending', :'maid', 'order_not_pending%');
select public.request_manual_payment(:'mcid', 'transfer from ABA 88') as requested_c;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
-- Confirming order A took it out of the queue; asking on order C put one row in.
select count(*) as queue_rows_before_clear from public.staff_manual_payments;
select public.admin_clear_manual_payment_request(:'mcid', 'no transfer received') as cleared_c;
select manual_payment_requested_at is null as cleared from public.orders where id = :'mcid';
select count(*) as queue_rows_after_clear from public.staff_manual_payments;

\echo '### 69. a manual top-up credits the wallet exactly once'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_wallet_topup(25.00, 'buyer@example.test') as manual_topup;
select id as mtid from public.orders order by created_at desc limit 1 \gset
select wallet_balance as before_topup from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.admin_confirm_manual_payment(:'mtid', 25.00, 'ABA-REF-4') as confirmed_topup;
select wallet_balance as after_topup from public.profiles
 where id = '22222222-2222-2222-2222-222222222222';
select status, kind from public.orders where id = :'mtid';

\echo '### 70. the staff queue is not a way around RLS'
-- A staff user puts their OWN order in the queue, then the customer reads the
-- same view. The view is `security_invoker`, so the policies on `orders` decide
-- what each of them sees: the customer's own rows, and nothing of anyone
-- else's. A plain view would have handed the whole table over.
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as manual_d;
select id as mdid from public.orders order by created_at desc limit 1 \gset
select public.request_manual_payment(:'mdid', 'staff order') as requested_d;

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select count(*) as customer_sees_in_queue from public.staff_manual_payments;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
select count(*) as staff_sees_in_queue from public.staff_manual_payments;
select public.admin_clear_manual_payment_request(:'mdid', 'test cleanup') as cleared_d;
select count(*) as queue_rows_at_end from public.staff_manual_payments;


-- ---------------------------------------------------------------------------
-- Staff overview (M5a). The point of these sections is the accounting rule, not
-- the plumbing: money that reached the bank is counted once, a wallet payment is
-- not new money, and a refund is reported beside the receipt rather than netted
-- out of it.
-- ---------------------------------------------------------------------------
create or replace function pg_temp.expect_error(p_label text, p_sql text, p_expect text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'FAIL [' || p_label || ']: no error raised';
exception
  when others then
    if sqlerrm like p_expect then return 'PASS [' || p_label || ']: ' || sqlerrm; end if;
    return 'FAIL [' || p_label || ']: got "' || sqlerrm || '"';
end $$;

\echo '### 71. the overview is staff-only'
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select pg_temp.expect_error(
  'customer_cannot_read_overview',
  'select public.admin_overview()',
  'not_authorized%');
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

\echo '### 72. it reports the store day it is counting, and real rows only'
select public.admin_overview() ->> 'timezone' as timezone,
       (public.admin_overview() ->> 'generated_at') is not null as stamped,
       (public.admin_overview() -> 'orders_pending') is not null as has_queue_counts;

\echo '### 73. a settlement adds its amount to received, exactly once'
select (public.admin_overview() ->> 'received_today_usd')::numeric as received_before,
       (public.admin_overview() ->> 'orders_pending')::int          as pending_before
\gset

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
select public.create_order(
  jsonb_build_array(jsonb_build_object('variant_id', :mlbb172, 'qty', 1)),
  null, jsonb_build_object('userid', '262856740', 'serverid', '2001'), null, null) as overview_order;
select id as ovid from public.orders order by created_at desc limit 1 \gset
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);

select public.admin_confirm_manual_payment(:'ovid', 1.89, 'ABA-REF-OV1') as settled;
-- One order total, no more: the payment row is the money, and the order it pays
-- for must not be added on top of it.
select (public.admin_overview() ->> 'received_today_usd')::numeric - :received_before as received_delta,
       (public.admin_overview() ->> 'orders_pending')::int - :pending_before          as pending_delta,
       (public.admin_overview() ->> 'received_today')::int                             as received_count_today;

\echo '### 74. a refund is reported beside the receipt, not netted out of it'
select (public.admin_overview() ->> 'received_30d_usd')::numeric  as received_30d_before,
       (public.admin_overview() ->> 'refunded_30d_usd')::numeric  as refunded_30d_before,
       (public.admin_overview() ->> 'orders_refund_pending')::int as refund_pending_before
\gset

select public.admin_order_set_refund_pending(:'ovid', 'supplier could not deliver') as flagged;
select (public.admin_overview() ->> 'orders_refund_pending')::int - :refund_pending_before as refund_pending_delta;
select public.admin_order_mark_refunded(:'ovid', 'EXT-REF-1') as refunded;
select (public.admin_overview() ->> 'received_30d_usd')::numeric - :received_30d_before as received_unchanged_by_refund,
       (public.admin_overview() ->> 'refunded_30d_usd')::numeric - :refunded_30d_before as refunded_delta,
       (public.admin_overview() ->> 'orders_refund_pending')::int                          as refund_pending_now;

\echo '### 75. a note on a resolved ticket keeps its resolution time'
-- `admin_support_set_status` coalesces every parameter so a caller can update
-- one field. Before this was fixed, `resolved_at = case when p_status in
-- ('resolved','closed') then now() else null end` evaluated to null on a
-- note-only call, silently erasing when the ticket was resolved.
select status as t_status, priority as t_priority, resolved_at as t_resolved
  from public.support_tickets where id = :'tid' \gset
select public.admin_support_set_status(:'tid', null, 'Called the buyer back.', null) as noted;
select status = :'t_status' as status_kept,
       priority = :'t_priority' as priority_kept,
       resolved_at = :'t_resolved' as resolved_at_kept,
       admin_note
  from public.support_tickets where id = :'tid';

\echo '### 76. a re-sync moves an unpriced SKU to the new cost and keeps a staff price'
reset role;
-- PT_A is never repriced, so its price is its cost and must follow the supplier.
-- PT_B is repriced by staff, so the re-sync must leave its price alone.
select public.supplier_upsert_catalogue(
  'bay2game', 'pricetest', 'Price Test', null, null, '["userid"]'::jsonb,
  '[{"product_code":"PT_A","name":"A","price_usd":5.00,"sort":1},
    {"product_code":"PT_B","name":"B","price_usd":5.00,"sort":2}]'::jsonb
) as first_sync;
update public.product_variants set price_usd = 9.99 where sku = 'PT_B';
select public.supplier_upsert_catalogue(
  'bay2game', 'pricetest', 'Price Test', null, null, '["userid"]'::jsonb,
  '[{"product_code":"PT_A","name":"A","price_usd":5.50,"sort":1},
    {"product_code":"PT_B","name":"B","price_usd":6.00,"sort":2}]'::jsonb
) as second_sync;
do $$
declare
  v_a record;
  v_b record;
begin
  select price_usd, cost_usd into v_a from public.product_variants where sku = 'PT_A';
  select price_usd, cost_usd into v_b from public.product_variants where sku = 'PT_B';
  if v_a.price_usd <> 5.50 or v_a.cost_usd <> 5.50 then
    raise exception 'FAIL [price_follows_cost]: unpriced SKU price % cost %', v_a.price_usd, v_a.cost_usd;
  end if;
  if v_b.price_usd <> 9.99 or v_b.cost_usd <> 6.00 then
    raise exception 'FAIL [price_follows_cost]: staff price overwritten, price % cost %', v_b.price_usd, v_b.cost_usd;
  end if;
end $$;
select 'price_follows_cost ok' as result;

\echo '### 77. only staff show or hide a product, and the change is audited'
reset role;
select id as pid from public.products where slug = 'bay2game-pricetest' \gset
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select pg_temp.expect_error(
  'customer_cannot_hide_product',
  format('select public.admin_product_set_active(%s, false)', :'pid'),
  'not_authorized%');
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;
select public.admin_product_set_active(:'pid'::bigint, false) ->> 'is_active' as hidden_by_staff;
reset role;
select set_config('harness.pid', :'pid', false);
do $$
begin
  if (select is_active from public.products where id = current_setting('harness.pid')::bigint) then
    raise exception 'FAIL [product_hidden]: product still active';
  end if;
  if not exists (select 1 from public.audit_log
                  where action = 'product_set_active' and entity_id = current_setting('harness.pid')) then
    raise exception 'FAIL [product_audit]: no audit row for the change';
  end if;
  raise notice 'PASS [product_visibility]: hidden by staff and audited';
end $$;
select public.admin_product_set_active(:'pid'::bigint, true) ->> 'is_active' as shown_again;

\echo '### 78. a price must be above zero and must not sell below supplier cost'
select id as pt_a from public.product_variants where sku = 'PT_A' \gset
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select pg_temp.expect_error(
  'customer_cannot_set_price',
  format('select public.admin_variant_set_price(%s, 9.00)', :'pt_a'),
  'not_authorized%');
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;
select pg_temp.expect_error(
  'zero_price_refused',
  format('select public.admin_variant_set_price(%s, 0)', :'pt_a'),
  'invalid_price%');
select pg_temp.expect_error(
  'below_cost_refused',
  format('select public.admin_variant_set_price(%s, 5.00)', :'pt_a'),
  'price_below_cost%');
select public.admin_variant_set_price(:'pt_a'::bigint, 7.50) ->> 'price_usd' as price_set;
reset role;
select set_config('harness.pt_a', :'pt_a', false);
do $$
begin
  if (select price_usd from public.product_variants where id = current_setting('harness.pt_a')::bigint) <> 7.50 then
    raise exception 'FAIL [price_saved]: price not stored';
  end if;
  if not exists (select 1 from public.audit_log
                  where action = 'variant_set_price' and entity_id = current_setting('harness.pt_a')) then
    raise exception 'FAIL [price_audit]: no audit row for the price';
  end if;
  raise notice 'PASS [price_guard]: zero and below-cost refused, valid price stored and audited';
end $$;

\echo '### 79. the supplier queue lists stuck lines, manual ones first, and is staff-only'
reset role;
select id as q_manual from public.order_items order by id limit 1 offset 0 \gset
select id as q_retry from public.order_items order by id limit 1 offset 1 \gset
select id as q_done from public.order_items order by id limit 1 offset 2 \gset
update public.order_items
   set delivery_status = 'manual_waiting', supplier_attempts = 5,
       supplier_last_error = 'supplier_error: Invalid API key'
 where id = :'q_manual';
update public.order_items
   set delivery_status = 'pending', supplier_attempts = 1
 where id = :'q_retry';
update public.order_items set delivery_status = 'delivered' where id = :'q_done';

select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', false);
set role authenticated;
select pg_temp.expect_error(
  'customer_cannot_read_queue',
  'select public.admin_supplier_queue(50)',
  'not_authorized%');
reset role;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;
select public.admin_supplier_queue(50) as queue;
reset role;
select set_config('harness.q_manual', :'q_manual', false), set_config('harness.q_retry', :'q_retry', false), set_config('harness.q_done', :'q_done', false);
do $$
declare
  v_queue jsonb;
  v_first jsonb;
  v_ids   bigint[];
begin
  select public.admin_supplier_queue(50) into v_queue;
  select array_agg((x ->> 'item_id')::bigint order by ordinality), jsonb_agg(x) -> 0
    into v_ids, v_first
    from jsonb_array_elements(v_queue) with ordinality as t(x, ordinality);
  if not (current_setting('harness.q_manual')::bigint = any(v_ids) and current_setting('harness.q_retry')::bigint = any(v_ids)) then
    raise exception 'FAIL [queue_lists_stuck]: stuck lines missing';
  end if;
  if current_setting('harness.q_done')::bigint = any(v_ids) then
    raise exception 'FAIL [queue_excludes_done]: a delivered line is in the queue';
  end if;
  if v_first ->> 'state' <> 'manual_waiting' or (v_first ->> 'item_id')::bigint <> current_setting('harness.q_manual')::bigint then
    raise exception 'FAIL [queue_order]: a manual line is not first';
  end if;
  raise notice 'PASS [supplier_queue]: stuck lines listed, delivered excluded, manual first';
end $$;
