# Implementation plan — `implement.md` vs. the repo as it stands

Date: 2026-10-15
Status: **M1, M2, M3, M4 and M5a implemented and verified.** M5b, M5c, M6–M8 proposed, not started.

---

## 1. Repository assessment

The repo is **not greenfield**. It is a working Flutter + Supabase storefront already
mid-build, under the brand **Chanpenh**. Baseline check run just now:

```
app: flutter analyze -> No issues found!
git: clean except implement.md (modified)
```

| Layer | Reality |
|---|---|
| Client | Flutter web + Android + iOS, Riverpod, go_router, Khmer-default i18n (`app/lib/l10n/*.arb`), `format.dart` for USD/KHR |
| Data | `app/lib/src/data/` repositories: auth, catalog, orders, payments |
| DB | 7 migrations: schema, RLS, RPC (money logic), wallet/cron/admin, telegram, suppliers, supplier field definitions |
| Server | 9 Edge Functions: payway-init/verify/callback, dev-signin, supplier-sync, supplier-fulfil, telegram-webhook/dispatch |
| Supplier | `_shared/suppliers/bay2game.ts` adapter + `types.ts` interface (getCatalog/balance/order/status) |
| Tests | `app/test/` (3 files), `supabase/tests/run.sh` local Postgres harness (RLS, oversell, wallet, refunds) |
| Tooling | `scripts/` (dev, setup, verify-sandbox, run-app, build-sql-bundle), `.vscode/launch.json`, two `app/config/*.json` envs |

Existing design decisions that **differ from `implement.md`** are deliberate and verified:
prices/stock/coupons resolve in Postgres, the PayWay key lives only in Edge secrets,
and ABA is polled (`check-transaction`) rather than trusted from the `return_url`.

---

## 2. Gap analysis against `implement.md`

Snapshot taken before any work; rows are resolved by the milestones in §4–§6.

| § | Requirement | Repo state | Gap |
|---|---|---|---|
| 5 | Bottom nav **Home / Games / Orders / Account** | 5 tabs incl. **Cart** + **Wallet** | Layout differs (extra tabs) |
| 6 | Header search field, Popular Games, **Promotions**, **How It Works**, Trust/Support | Hero + trust chips + categories + featured/all grids; search is a dialog | Missing How-It-Works, Promotions, dedicated support section |
| 7 | Per-product Player ID / Server ID / Region fields, help dialog, account-verify, manual KHQR | Dynamic buyer fields (`supplier_field_definitions`) collected at checkout; automated PayWay KHQR | Account-verify **not built** (stage 12b `[ ]`); no manual-review KHQR path |
| 7 | Order states incl. `refund_pending` | enum: pending, paid, delivering, delivered, failed, refunded, expired | `refund_pending` absent |
| 9 | `order_events`, `support_tickets`, `supplier_products`, `audit_logs` | has `supplier_skus`, `audit_log`; **no** `order_events`, **no** `support_tickets` | Add status-transition log + support table |
| 11 | Supplier adapter interface | ✅ `SupplierAdapter` + Bay2Game, callbacks/reconcile in `supplier-fulfil` | KAS Play adapter deferred (`12a [ ]`) — out of scope unless asked |
| 12 | Explicit state machine + event log + idempotency | RPC drives states with uniqueness guards; **no event log table** | Add `order_events` |
| 13 | **Admin dashboard** (11 pages, metrics, mobile-friendly) | **Not started** — RPCs exist, no UI | Largest missing chunk (`13 [ ]`) |
| 14 | Named reusable components (GameCard, PriceDisplay, OrderStatusBadge, …) | `product_card`, `status_chip`, `async_value_view`, `khqr_sheet`, `review_sheet` | Partial; rename/extend as needed |
| 15 | Automated tests incl. duplicate callbacks, timeouts, RLS, responsive | DB harness + 3 app tests | Missing callback/idempotency + responsive widget tests |
| 8 | Khmer first-class | ✅ Khmer default, Noto Sans Khmer per README | Verify copy with fluent speaker (human task) |

---

## 3. Unresolved questions (need a decision before building)

1. **Payments: keep automated PayWay, or add the manual admin-verified KHQR of §7?**
   The repo ships automated ABA KHQR (stage 1 `[x]`). §7 asks for a manual
   admin-verified fallback. These are compatible — manual can be the fallback when
   PayWay is not configured — but it is extra work and extra surface. Confirm intent.
2. **Brand.** `implement.md` never names a brand; the repo is **Chanpenh** (`Brand.monogram`,
   `site_name` default `YCP Store`). Keep Chanpenh?
3. **Supplier scope.** §11 names only Bay2Game — already integrated. Confirm KAS Play
   (`12a`) stays out of scope.
4. **Admin surface.** §13 wants a full dashboard. Options: build it inside the same
   Flutter web app under `/admin` (RLS + `admin` role), or a separate lightweight
   admin app. Same app is less to maintain; recommend same app.
5. **Suppliers/contracts (§ "Sourcing").** Business decision, not code. Flagged only.

### Decisions taken (2026-10-15)

1. Payments: **manual admin-verified KHQR as a fallback beside the existing PayWay flow.**
2. First milestone: **M1, schema completions.**
3. Brand: **keep Chanpenh.** Supplier scope: **Bay2Game only**; KAS Play stays out.
4. Admin: **same Flutter app, under `/admin`.**

---

## 4. Proposed milestones (small, reviewable, in dependency order)

Each milestone: change note, files touched, `flutter analyze` + `dart format`, relevant
tests, honest failure report.

- **M1 — Schema completions.** ✅ **DONE 2026-10-15** (see §5).
- **M2 — Storefront alignment (§5, §6).** ✅ **DONE 2026-10-15** (see §6).
- **M3 — Checkout fields (§7).** ✅ **DONE 2026-10-15** (see §7).
- **M4 — Manual KHQR verification (§7, §10).** ✅ **DONE 2026-10-15** (see §8). The
  admin-verified transfer path beside PayWay, plus the staff screen to confirm it.
- **M5 — Admin dashboard (§13).** Protected `/admin` **inside the same Flutter app**.
  Split into three slices when the recon showed it was four independent screens plus
  dead-grant fixes:
  - **M5a — Operations.** ✅ **DONE 2026-10-15** (see §9). Overview, orders, refunds,
    support. The part that makes money and support operable.
  - **M5b — Fulfilment.** Supplier job queue (needs a staff read RPC: the queue table
    is service-role only today), stock intake via `admin_add_stock`, low-stock list.
  - **M5c — Catalogue + settings.** Editing prices and settings needs the missing
    write grants (see §9.5), so it is a migration plus a UI, not just a UI.
- **M6 — Account verification (§7, stage 12b).** "Verify account" button calling the
  supplier's documented player-validation endpoint, per game where supported.
- **M7 — Tests (§15).** Duplicate callbacks, supplier timeouts, ambiguous orders,
  order isolation, Khmer/EN layout, responsive widths at 320/768/1280.
- **M8 — Deploy docs (§17).** Web hosting + HTTPS, dev/prod separation, ops notes.

**Next milestone: M5b or M5c.**

---

## 5. M1 — completed

Delivered: `order_events`, `support_tickets`, `refund_pending`.

| Item | Detail |
|---|---|
| Migration | `supabase/migrations/20261015000800_order_events_support.sql` |
| Order history | `order_events` + `private.log_order_status()` trigger on `orders`. Append-only: no client grant to insert/update/delete; the trigger is `security definer`. |
| New state | `order_status` gains `refund_pending`. `orders.refund_reason`, `orders.refunded_at`, `payments.refunded_at`. |
| Refunds | `admin_order_set_refund_pending(uuid, text)` and `admin_order_mark_refunded(uuid, text)`, staff-only. Neither moves money, by design — the automatic path already credits the wallet. |
| Support | `support_tickets` + `create_support_ticket(...)` (own-order only, 5-open cap, 30s rate limit) and `admin_support_set_status(...)`. |
| RLS | Enabled on both new tables; `revoke all from anon, authenticated` then a narrow `select` grant. Customer sees own rows only. |
| Tests | `smoke.sql` sections 41–55: history order, no duplicate on re-settle, insert refused, cross-customer isolation, ticket guards, staff-only refunds, live-order refund refusal, payment marked refunded. |
| Verified | `supabase/tests/run.sh` → all 55 sections pass. Bundle re-applies cleanly under `--single-transaction` (the `ALTER TYPE ... ADD VALUE` constraint). |
| Docs | README notes on the history and the two refund paths. |

Baseline before touching anything: `flutter analyze` → *No issues found!*

---

## 6. M2 — completed (storefront, at the user's request, built on how the real stores do it)

### 6.1 What the real stores do

Researched against **SEA Gamer Mall** (`seagm.com`), which is the platform Cambodian
players already use, and which the local shops mirror. Web search returned nothing in
this environment, so this is read off the live site itself. The patterns worth copying:

| Pattern seen | Adopted? |
|---|---|
| Search field in the top bar / top of the page, not hidden behind an icon | **Yes** — prominent field is the first element on Home |
| "Popular game top-up" grid ordered by units sold, with a compact sold count on each tile | **Yes** — `sold_count` is real and incremented on delivery |
| Denomination tiles carrying a real `-17%` badge | **Yes** — from `compare_at_price_usd` |
| "Exclusive Offers" / coupon blocks | **Partly** — real price reductions only. Coupons stay staff-only in RLS, so no fake "claim" block |
| Per-game required fields, labelled with their own names: MLBB wants **User ID + Zone ID**, as separate inputs each with a `?` help popup | Queued for **M3** (the field machinery already exists) |
| A "Guide" tab: how to top up, and *how to find your User ID and Zone ID*, with screenshots | Queued for **M3** |
| Payment-method logos + LiveChat as trust signals | Kept as text claims only; logo walls would promise methods the store does not accept |
| Sold counts like "4M" and star ratings by default | **Rejected as-is** — ours renders only when the DB actually holds the number |
| Countdown timers, "limited to N per week", fake stock scarcity | **Rejected** — `implement.md` §4 forbids them outright |

Two claims in the existing copy could not be supported — "24/7 delivery" and "24/7
support" — and were removed rather than translated. Reinstating either is a business
decision.

### 6.2 What changed

| Area | Change | File |
|---|---|---|
| Nav | Five tabs → the four `implement.md` §5 names: Home / Games / Orders / Account. Cart stays in the app bar; Wallet moved to Account and gained its own page heading | `ui/widgets/app_shell.dart`, `ui/wallet_page.dart` |
| Home | Rebuilt to §6's order: search → trust row → categories → popular → promotions → how it works → trust and support → all products. The static hero is gone (§4 forbids a hero that pushes products below the fold) | `ui/home_page.dart` |
| Popular | New `popularGamesProvider` ordering by real `sold_count`; falls back to staff-curated `is_featured` when the store has no sales yet, and the heading changes with it | `state/providers.dart`, `data/catalog_repository.dart` |
| Promotions | `promotionsProvider` + `isPromoted()`: only a variant whose compare price beats its live price. Empty list ⇒ section omitted | `state/providers.dart` |
| Cards | Real sold count on the tile footer, compacted (`1.5K`) | `ui/widgets/product_card.dart` |
| Sections | `HowItWorksSection`, `TrustAndSupportSection`, `TrustRow`, `SectionTitle` extracted so they can be pumped at 320px in isolation | `ui/widgets/home_sections.dart` (new) |
| Refund state | `OrderStatus.refundPending` + `statusRefundPending` so a refund agreed but unpaid no longer renders as *Awaiting payment* | `data/models.dart`, `ui/widgets/status_chip.dart` |
| Error copy | Internal error text now debug-only: a PostgREST message can name tables and policies | `ui/widgets/async_value_view.dart` |
| l10n | +19 keys × 2 locales; dead `heroTitle`/`heroSubtitle` removed; `soldCount` takes a pre-compacted string | `l10n/app_en.arb`, `l10n/app_km.arb`, `l10n/generated/*` |

### 6.3 Verification

```
flutter analyze      -> No issues found!
flutter test         -> 42 passed (was 27)
flutter build web    -> ✓ Built build/web
supabase/tests/run.sh -> unchanged by M2 (no DB change); still 55/55
```

New coverage in `app/test/storefront_test.dart`: the discount predicate rejects a
compare price that is not a reduction and rejects sold-out stock; `refund_pending`
does not read as `pending`; unknown status values fall back rather than invent a
state; `HowItWorksSection` renders the three documented steps and the
"never your password" rule at 320px; `TrustAndSupportSection` draws **no** button when
support is unconfigured and **two** that wrap at 320px when it is; no locale still
contains "24/7"; and the two `.arb` files are asserted to carry the same keys, so a
translation can no longer be forgotten.

### 6.4 Honest gaps

- Neither the home page nor checkout has been walked through by hand against the
  running stack. The `[x]` above means analyzer + tests + web build only.
- **Khmer copy is mine and needs a fluent speaker.** `implement.md` §8 says so, and
  the new strings (how-it-works steps, trust block) are customer-facing.
- Promotions are empty on the current demo data, because no variant carries a
  `compare_at_price_usd`. That is the correct behaviour, and it means the section is
  effectively unverified against live data.
- `dart format` reformatted 15 unrelated files (this repo predates the current Dart
  formatter). Those were reverted to keep the diff reviewable; the files that M2
  touches are formatted.

---

## 7. M3 — completed (buyer fields)

### 7.1 What was actually wrong

Research against the reference store turned up a bigger problem than the missing
help affordance. The reference shows a `?` and a screenshot behind every field;
the repo had neither. But while mapping the field path, three real defects
turned up underneath:

| Defect | Consequence |
|---|---|
| `create_order` checked only that a required field was **non-empty**. The `pattern` was applied in the Flutter app and nowhere else (`rpc.sql:247-257`) | A crafted request, or an app build from before a pattern was tightened, sent `userid = 'abc'`. The RPC accepted it, the buyer paid, the supplier rejected the id, and the automatic refund path credited the wallet. The store paid a refund and a support ticket for a sale that could never happen |
| Checkout kept one `String? _fieldError` and passed it as `errorText` to **every** `TextField` on the page | A bad game id painted the same message under the server box, and under the next product's fields too |
| Both pages hardcoded `keyboardType: TextInputType.number` | A field whose pattern allows letters could not be typed into at all |
| The validation was written twice (`product_page.dart`, `checkout_page.dart`) | The two copies had already drifted: one toasted, the other set inline errors |

### 7.2 What changed

| Area | Change | File |
|---|---|---|
| Migration | `create_order` re-created with the pattern and a 64-character cap added to the existing non-empty check. New error `invalid_fields`, `detail` = offending keys. New `public.field_pattern_matches(text, text)`, which treats an unusable pattern as no constraint | `supabase/migrations/20261015000900_field_validation.sql` |
| Shared rule | `fieldProblem`, `compileFieldPattern`, `fieldWantsDigits`, `fieldKeyboardType`, `fieldInputFormatters`, `fieldValueMaxLength` | `core/field_validation.dart` (new) |
| Shared UI | `RequiredFieldsForm`: label + `?` + input + error, used by both pages. Error keyed per field | `ui/widgets/required_fields_form.dart` (new) |
| Help | `FieldHelpDialog` / `showFieldHelp`: catalogue `help_km`/`help_en` first, then copy for a recognised field key, then a general answer. Optional `guide_image_url`. States what a wrong id costs | `ui/widgets/field_help_dialog.dart` (new) |
| Model | `RequiredField` gains optional `helpKm`, `helpEn`, `guideImageUrl`. The jsonb normaliser in migration 700 already passes unknown keys through, so no shape change was needed | `data/models.dart` |
| Checkout | Per-field errors; `missing_fields` / `invalid_fields` from the server are mapped back onto the inputs by key | `ui/checkout_page.dart` |
| Product page | Same form; inline per-field errors instead of a toast | `ui/product_page.dart` |
| l10n | +10 keys × 2 locales | `l10n/app_en.arb`, `l10n/app_km.arb`, generated |

### 7.3 Verification

```
flutter analyze      -> No issues found!
flutter test         -> 62 passed (was 42)
flutter build web    -> ✓ Built build/web
supabase/tests/run.sh -> 59/59
```

New harness sections: **56** a non-matching id and a too-short server are refused
with `invalid_fields`; **57** a 200-character value is refused; **58** the same
field with a value it expects still creates the order (proving the gate refuses
the bad value without refusing the good one); **59** `field_pattern_matches`
returns true for an unparseable pattern, false for a non-matching value, true for
a matching one, true for no pattern and true for null.

New Dart tests (`app/test/field_validation_test.dart`, 20 of them): the empty /
format / length verdicts; an unparseable pattern compiling to null instead of
throwing; a digits-only pattern getting a number pad and an alphanumeric pattern
**not** getting one; the catalogue's help winning over the built-in copy; the
`userid` and `serverid` keys getting their own instructions and an unknown key
getting the general one; and `RequiredFieldsForm` at 320px painting one error
under one field, opening the dialog from `?`, and not overflowing on a long
label.

### 7.4 Honest gaps

- **No screenshots.** The reference puts a screenshot of the game's profile
  screen behind each field. Doing that here would mean shipping a claim about a
  game's UI that cannot be verified from this machine, so the wording carries the
  field and `guide_image_url` renders only when the catalogue has one. The gap is
  real and is the single largest difference from the reference on this screen.
- **Khmer copy is still mine.** The new strings — the help bodies and the warning
  — are customer-facing and need a fluent speaker (`implement.md` §8).
- The gate is verified by the harness; neither page has been walked through
  against the running stack by hand.
- A pattern is still written as free text by staff with no check that it compiles.
  Both sides now fail open, so a bad one costs validation rather than sales, but
  it should be rejected when the catalogue is saved.
- `dart format` was not run over the tree: this repo predates the current
  formatter, and running it rewrote 15 unrelated files in M2.

---

## 8. M4 — completed (manual transfer fallback)

### 8.1 The problem it solves

PayWay needs credentials on the project, and a buyer whose bank app will not open
the deeplink has nowhere to go: the order exists, the QR will not render, and the
previous behaviour was a toast on a checkout page with a pending order behind it.
`payment_provider` already had an unused `'manual'` value, so the schema expected
this path even though nothing implemented it.

### 8.2 What changed

| Area | Change | File |
|---|---|---|
| Migration | `request_manual_payment` (buyer), `admin_confirm_manual_payment`, `admin_clear_manual_payment_request` (staff), `staff_manual_payments` view, `orders.manual_payment_requested_at` / `manual_payment_note`, `settings.manual_grace_minutes` (default 1440), re-created `public_settings` view | `supabase/migrations/20261015001000_manual_payment.sql` |
| Settlement | **Not re-implemented.** The staff RPC calls the same `mark_order_paid` PayWay calls, with provider `manual` | — |
| Guards | Staff-only; pending + unexpired; `amount_usd >= total_usd` (`manual_underpaid`); reference required; reference already on another order refused (`manual_reference_used`); 3 requests/hour; one request per order | migration §2–3 |
| Buyer UI | `ManualPaymentPanel` on the pending order page, under the QR button: account, name, exact amount, order number as the remark, "I have paid" | `ui/widgets/manual_payment_panel.dart` (new) |
| Staff UI | `/admin`: the transfer queue with the buyer's game id, the amount and the ABA reference, pre-filled with the total; confirm or dismiss with a reason. Reached from Account for staff roles | `ui/admin_page.dart` (new), `core/router.dart`, `ui/account_page.dart` |
| Data | `AdminRepository`, `ManualPaymentRequest`, `manualPaymentRequestsProvider`; `Profile.role` / `isStaff`; `PublicSettings.khqrAccountId` / `khqrMerchantName` / `manualGraceMinutes` (settings the app previously never read) | `data/admin_repository.dart` (new), `data/models.dart`, `data/order_repository.dart`, `data/catalog_repository.dart`, `state/providers.dart` |
| Checkout | On QR-init failure the buyer is sent to the order, where the fallback lives, instead of being left on checkout with a pending order | `ui/checkout_page.dart` |
| l10n | +29 keys × 2 locales | `l10n/app_*.arb`, generated |

### 8.3 Decisions taken

Asked and answered before implementing: **staff verify in a minimal in-app
`/admin` screen now** (M5 grows the rest around it — the RPCs are useless without
somewhere to press confirm); **the buyer is given an account id and merchant name
as text** (there is no static merchant QR in the database, only a per-order one
PayWay generates); **asking to pay by transfer extends `expires_at` by
`manual_grace_minutes`** (otherwise housekeeping cancels at 15 minutes while the
transfer is in flight, and staff later confirm an expired order — money in, order
gone).

### 8.4 Verification

```
flutter analyze        -> No issues found!
flutter test           -> 72 passed (was 62)
flutter build web      -> ✓ Built build/web
supabase/tests/run.sh  -> 70/70
bundle combined.sql    -> applies clean on a fresh PG16, single transaction
```

New harness sections **60–70**: asking keeps the order payable and moves no money
(flag set, expiry pushed past an hour, zero payment rows, one event); asking twice
keeps the first request and does not re-extend; a customer cannot confirm; staff
cannot ask on someone else's order; underpaid, blank-reference and zero-amount are
refused; one reference cannot settle a second order; confirming settles once down
the PayWay path (payment row `manual`/`succeeded`, `paid → delivering`, event
attributed to `staff`); confirming again is a no-op with no second payment row and
no second delivery; an expired order is refused; a settled order cannot be asked
about and a request can be dismissed; a manual top-up credits the wallet exactly
once; and the queue view gives a customer `0` rows while staff see `1`.

New Dart tests (`app/test/manual_payment_test.dart`, 10): both an account and a
name are required before the fallback exists at all; the request timestamp is read
and absent means never asked; a closed window is flagged; only `staff`/`admin`
roles open the staff screens; the panel renders nothing without an account, shows
the account/amount/order number with one, and shows the wait instead of the
button once asked; the admin page gates a customer, says so when empty, and shows
the game id, the note and both actions for a request.

### 8.5 Honest gaps

- **No hand walkthrough.** The RPCs are exercised as an `authenticated` session
  with a JWT claim, which is what PostgREST does, but nobody has clicked the two
  screens against the running stack.
- **A transfer can be confirmed without the buyer ever asking.** That is
  deliberate — a bank alert matching an order number should be actable — but it
  means the queue is a hint, not the full set of transfers staff may confirm.
- **Nobody is notified.** Confirming does not tell the buyer; they see it when
  they open the order. The Telegram outbox exists and could carry it.
- **`chanpenh@aclb` in the demo seed is a placeholder** and the panel will show it as
  a payable account wherever the demo data is loaded.
- Khmer copy on both new screens is mine and needs a fluent speaker
  (`implement.md` §8).

---

## 9. M5a — completed (staff operations)

### 9.1 What it is

`/admin` grew from one screen into a hub plus four screens, all still inside the
Flutter app and still behind one gate:

| Screen | Question it answers |
|---|---|
| `/admin` | What is waiting for a person, and what money actually moved |
| `/admin/orders` | Every order, filtered by status, searchable by order number |
| `/admin/orders/:id` | One order: lines and their supplier state, payments, history, the two refund steps |
| `/admin/refunds` | Refunds agreed but not yet reversed |
| `/admin/support` | Tickets, with status, priority and an internal note |
| `/admin/transfers` | M4's bank-transfer queue, moved here unchanged |

### 9.2 The one rule the overview follows

A dashboard is where numbers get invented, so the migration states what it will
not do: every figure is a row count or a payment sum, and:

- **Money into the bank** is summed from `payments` with provider
  `payway`/`khqr_direct`/`manual`. Summing `orders.total_usd` instead would count
  one barrel of money twice: a wallet top-up **and** the purchase it later paid
  for both carry a total.
- **Wallet spend** is reported separately, because it is not new money.
- **Refunds are never netted off received.** A refunded payment still counts as
  having arrived; netting it out of the window it arrived in silently rewrites
  history. The two figures read as gross and returns, which is what reconciles
  against a statement.
- **"Today" is a Phnom Penh day.** `now()` is UTC and the store is not, so the
  boundary is computed in the store's timezone and the timezone is returned with
  the numbers so the screen can say which day it means.

No growth rate, no "active users", no conversion figure. They would all have to
be invented.

### 9.3 What changed

| Area | Change | File |
|---|---|---|
| Migration | `admin_overview()` — staff-only, `security definer`, counts + sums as above | `supabase/migrations/20261015001100_admin_overview.sql` |
| Migration | `admin_support_set_status` re-created: a note-only call no longer wipes `resolved_at` (§9.4) | `supabase/migrations/20261015001200_support_note_fix.sql` |
| Data | `AdminOverview`, `AdminOrderSummary`, `AdminOrderItem`, `AdminPaymentRow`, `AdminOrderEvent`, `AdminOrderDetail`, `SupportTicket` | `data/models.dart` |
| Data | `overview()`, `orders()`, `orderDetail()`, `setRefundPending()`, `markRefunded()`, `resolveItem()`, `supportTickets()`, `setSupportStatus()` | `data/admin_repository.dart` |
| State | `adminOverviewProvider`, `adminOrdersProvider` (family), `adminRefundQueueProvider`, `adminOrderDetailProvider`, `adminTicketsProvider` | `state/providers.dart` |
| UI | `AdminGate`, `AdminHeader`, `AdminSection`, `AdminStat`, `AdminTile`, `AdminChipRow`, `AdminEmpty`, `askAdminText`, `adminStamp` | `ui/widgets/admin_widgets.dart` (new) |
| UI | Hub, orders list, order detail, refunds, support | `ui/admin_page.dart`, `ui/admin_orders_page.dart`, `ui/admin_order_detail_page.dart`, `ui/admin_refunds_page.dart`, `ui/admin_support_page.dart` |
| UI | M4's queue moved out of the hub | `ui/admin_transfers_page.dart` |
| Router | Five routes under `/admin`; the redirect protects the whole prefix, not the exact path | `core/router.dart` |
| Account | The staff entry reads "Staff" instead of naming one of its screens | `ui/account_page.dart` |
| l10n | +43 keys × 2 locales | `l10n/app_*.arb`, generated |

### 9.4 A bug in an M1 function, found while building the screen

`admin_support_set_status` coalesces every parameter so a caller can update one
field. But `resolved_at` was written unconditionally:

```sql
resolved_at = case when p_status in ('resolved','closed') then now() else null end
```

With `p_status = null` — which the signature explicitly allows — that evaluates
to null. Saving a note on a resolved ticket **erased when it was resolved**, and
`resolved_at` exists for exactly one reason. The re-created function only touches
it when a status is actually being set. Harness §75 pins it: status, priority and
`resolved_at` all survive a note-only call.

### 9.5 A defect the recon found and M5a did not fix

Several staff policies are **dead**: they exist, but no table grant reaches
`authenticated`, so nobody can read the table they protect.

| Policy that does nothing | Table |
|---|---|
| `audit_staff_read` | `audit_log` |
| `suppliers_staff_all`, `supplier_skus_staff_all` | `suppliers`, `supplier_skus` |
| `settings_admin_all`, `coupons_staff_all` | `settings`, `coupons`, `coupon_redemptions` |

Separately, products/variants/categories have `*_admin_all` policies but **no
INSERT/UPDATE/DELETE grant**, so the catalogue cannot be written through
PostgREST at all. M5a did not need any of these: every table it reads
(`orders`, `order_items`, `payments`, `order_events`, `support_tickets`) has a
real grant, and every write is an existing definer RPC. They are recorded here so
M5b/M5c do not rediscover them as surprises.

### 9.6 Verification

```
flutter analyze        -> No issues found!
flutter test           -> 91 passed (was 72)
flutter build web      -> ✓ Built build/web
supabase/tests/run.sh  -> 75/75
bundle combined.sql    -> 3859 lines, applies clean on a fresh PG16, single transaction
```

New harness sections **71–75**: the overview is staff-only (a customer gets
`not_authorized`); it reports the store timezone it is counting and real counts;
one settlement adds **exactly one** order total to `received_today_usd` and one
row to `received_today`; a refund leaves `received_30d_usd` untouched, adds the
total to `refunded_30d_usd`, returns `orders_refund_pending` to zero; and a note
on a resolved ticket keeps status, priority and resolution time.

New Dart tests (`app/test/admin_ops_test.dart`, 19): every overview figure maps
and a missing one is zero rather than a guess; an order row carries status, kind,
line count and the transfer flag; the detail view joins items, payments and
history and keeps the supplier's own error text; a ticket is open only while
open/in progress and reads its order number through the FK; the order filter
compares by value so Riverpod caches one result per filter; and per screen —
a customer gets the gate and no figures or rows on the hub and the order list,
staff see the queues with real money formatted from payments, the order row with
its filters, an empty result says so, a pending refund shows its reason and the
record action, a ticket shows its state and actions, the detail shows the line,
the payment (in the database's own words), the history, and offers *record* on a
`refund_pending` order and *agree* on a paid one, while an expired order offers
neither refund action.

### 9.7 Honest gaps

- **No hand walkthrough.** The RPCs run as an `authenticated` session with a JWT
  claim, which is what PostgREST does, but nobody has clicked these five screens
  against the running stack.
- **`orders` has no index on `order_no` for the search path**, and the list pulls
  up to 60 rows with an embedded line count. Fine at this size, and worth a
  `pg_trgm` index or a paged RPC before the table is large.
- **The order search is a `ilike` on the order number only.** Searching by buyer,
  contact or game id would need a different query; none is offered rather than one
  that is wrong.
- **`resolveItem` is offered on every undelivered line**, including ones a
  supplier worker is still retrying. Marking a line delivered by hand while the
  worker holds it is a real race the screen does not prevent — the database has no
  lock for it either.
- **Support has no reply channel.** A ticket can be triaged but not answered in
  the app; staff use the `contact` field outside it.
- **Refunds record a reference but do not require one** (the RPC defaults to
  null). The screen asks for it and explains why; it does not refuse.
- Khmer copy on all new screens is mine and needs a fluent speaker
  (`implement.md` §8).
- **The Khmer product name is still `សេឡា` (Sela)** in `Brand.nameKm` and
  `app_km.arb`, while the English name and the Android/iOS identities are already
  `Chanpenh`. Guessing a Khmer transliteration would be inventing a brand name, so
  it is left as it is: someone who knows the intended spelling should set both.

---

## 10. What I will do next

**M5b** — supplier job queue and stock intake. **M5c** — catalogue and settings
editing, which begins with the missing grants (§9.5). **M6** — the "verify
account" supplier check. `implement.md` §17: one milestone, then report and stop.
