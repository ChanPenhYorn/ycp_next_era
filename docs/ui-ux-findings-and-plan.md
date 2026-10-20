# UI/UX findings and fix plan

Date: 2026-10-16
Scope: `app/lib/src/ui/` (10 customer pages, 10 admin pages, 22 shared widgets), `app/lib/src/core/theme.dart`, `app/lib/src/core/format.dart`.
Constraints agreed with the owner: keep the Chanpenh brand and the dark neon palette; layout, spacing, hierarchy and component structure are open. Design system first, then both surfaces.

Nothing in this document proposes a change to money logic. `create_order`, supplier delivery, the two refund paths and `order_events` stay exactly as they are. This is presentation only.

---

## 1. Measured baseline

These are facts from the current code, not impressions. Each one is the root cause behind several findings later.

| Measure | Value | Why it matters |
|---|---|---|
| Explicit `height:` in inline `TextStyle` | **28 occurrences, 12 distinct values, across 15 files** | `theme.dart` deliberately sets generous line height for Khmer, then 28 inline overrides undo it with Latin-tuned values (1.15–1.35). This is the single largest source of Khmer clipping. |
| `maxLines:` with ellipsis | 18 occurrences | Khmer stacked vowels and tall ascenders get cut mid-cluster. |
| `Semantics` / `semanticLabel` usage | **19, all inside `home_sections.dart` and `home_bento.dart`; zero in any page** | Product tiles, nav, icon buttons, payment status and quantity steppers are unlabelled. |
| Bare `GestureDetector` (no ink, no semantics) | 6 | Tiles look tappable but are invisible to assistive tech. |
| Hardcoded breakpoint literals | 8 sites, 3 values (`900`, `700`, `520`) across 7 files | Pages can drift apart. No shared token. |
| Hardcoded `Color(0x…)` outside `theme.dart` | 5 | Brand drift; `AppColors` is bypassed. |
| `CachedNetworkImage` without `cacheWidth`/`cacheHeight` | 4 of 6 image sites | Full-resolution supplier art decoded into small tiles. |
| Fonts | `google_fonts` only; **no bundled font assets** | Khmer is the default locale, so first paint waits on a network font fetch. FOUT on every cold load, worst on web. |
| Khmer / English ARB parity | 349 / 349 keys — **no gap** | Good news. Do not "fix" this. |

### Contrast ratios (computed, WCAG 2.1)

| Foreground | on `ink950` | on `ink900` | on `ink800` | on `ink700` |
|---|---|---|---|---|
| `ink400` `#7B88A4` | 5.38 ✅ | 5.08 ✅ | 4.36 ⚠️ | **3.65 ❌** |
| `brand` `#5B7CFF` | 5.26 ✅ | 4.97 ✅ | 4.26 ⚠️ | **3.57 ❌** |
| `violet` `#8B5CF6` | 4.52 ✅ | 4.27 ⚠️ | **3.66 ❌** | **3.07 ❌** |
| `ink200` `#C3CBE0` | 11.80 ✅ | 11.14 ✅ | 9.56 ✅ | 8.00 ✅ |
| white on `brand` | — | — | — | **3.64 ❌** |
| `step-number` badge (brand text on brand@0.18 over `ink900`) | — | — | — | **≈2.4 ❌** |

Two concrete failures that hit the primary purchase path:

1. `filledButtonTheme` sets `foregroundColor: Colors.white` on `backgroundColor: AppColors.brand` = **3.64:1**. Button text is 15 px bold, which is below the WCAG "large text" threshold (needs ≥18.66 px bold), so every primary CTA in the app fails AA.
2. `checkout_page.dart:843` paints the brand colour on a brand-tinted badge ≈2.4:1.

---

## 2. Findings

Counts by axis across all three surfaces: **accessibility + contrast 30, perceived performance 28, conversion / operator friction 25, mobile-web parity 17, Khmer typography 23, generic look 13.** Total **136**.

### 2.1 Blocking — fix before any visual polish

| # | Location | Problem |
|---|---|---|
| B1 | `theme.dart:201-213` | Primary CTA text is white on `#5B7CFF` = 3.64:1. Every "Pay", "Confirm", "Sign in" button fails AA. |
| B2 | `admin_transfers_page.dart:197` | "Confirm payment" moves an order to paid on **one tap**, no confirmation, no echo of the amount. Money-affecting. |
| B3 | `admin_staff_page.dart:241` | A single ChoiceChip tap changes a member's **role**, with no confirmation and no undo. |
| B4 | `admin_refunds_page.dart:143` | The refund dialog confirms without showing the order number or the USD amount. Money-affecting and irreversible from this UI. |
| B5 | `admin_order_detail_page.dart:387` | "Mark failed" is the lowest-emphasis `TextButton`, beside "Mark delivered", with no confirmation — though failing a line needs a refund decision. |
| B6 | `admin_transfers_page.dart:203` | "Dismiss request" (drops the buyer's claim) sits at the same size as Confirm, separated only by font weight. |
| B7 | `checkout_page.dart:843` | Step badge ≈2.4:1 contrast. |
| B8 | `admin_orders_page.dart:98` + `supabase_admin_repository.dart:75` | Order query silently caps at 60 rows. No count, no paging. An operator cannot see or reach older orders. |
| B9 | `khqr_sheet.dart:149` | Payment status has no live region, so a screen-reader user never hears "paid" or "expired". |
| B10 | `khqr_sheet.dart:58` | `Timer.periodic(1s)` calls `setState` on the whole sheet: the QR image and buttons rebuild 60×/min. |

### 2.2 Accessibility and contrast (30 findings)

**No semantics anywhere in pages.** The 19 `Semantics` uses live only in the two home widgets.

- `product_card.dart:52` — product tile is a bare `GestureDetector`; announced as nothing. → `Semantics(button: true)`.
- `home_bento.dart:44, 348`, `home_sections.dart:513` — same pattern for spotlight, buy-again and category pills.
- `home_sections.dart:27` — `SectionTitle` is a plain `Text`, so headings are not exposed as headers. → `Semantics(header: true)`.
- `product_page.dart:533, 470` — icon-only add-to-cart and quantity steppers with no label. → `tooltip` + `semanticLabel`.
- `product_page.dart:671` — rating rendered as `'★' * n`; screen reader reads star glyphs. → `Semantics(label: '$n out of 5')`.
- `cart_page.dart:133` — quantity steppers icon-only.
- `required_fields_form.dart:88` — help button constrained to 30×30, under the 44×44 minimum.
- `auth_page.dart:1098` — terms `Checkbox` in a 24 px box; `auth_page.dart:1127` — error banner is not a live region.
- `order_detail_page.dart:341` — copy-code button at `visualDensity: compact`, under 44×44, no tooltip.
- `admin_orders_page.dart:65` — clear-search icon button has no tooltip, unlike the rest of the console.
- `wallet_page.dart:144` — quick-amount chips ~32 px tall.
- `admin_catalogue_page.dart:239` — variant edit row ~28 px tall.
- `admin_catalogue_page.dart:111` — show/hide `Switch` has no semantic label.
- `admin_widgets.dart:196` — `AdminStat` sets its `InkWell` with no label; label and value read as one unlabelled block.

**State conveyed by colour only** (fails WCAG 1.4.1):

- `order_progress.dart:92` — done/current/pending differ only by colour, no label.
- `admin_page.dart:57` — refund-pending, transfers and manual-waiting counts differ only by the warn colour. → add a textual "needs attention" marker.
- `product_page.dart:410` — sold-out tiles dimmed to `Opacity(0.45)`, dropping `ink200` under AA and conveying the state by styling alone.
- `admin_widgets.dart:196` — urgency signalled by colour only.

**Contrast elsewhere:** `ink400` on `ink700` = 3.65 (nav/chip labels on raised surfaces); `brand` on `ink800` = 4.26; `violet` on `ink800` = 3.66.

### 2.3 Perceived performance (28 findings)

**Home is fully eager.** `home_page.dart:63` is a `ListView(children: [...])` with seven `ref.watch` calls at the top of the build (`home_page.dart:42`), so every section, spotlight, skeleton and three grids build at first frame, and any one provider update rebuilds the entire tree.

- `home_page.dart:195` and `catalog_page.dart:159` — `GridView.builder` with `shrinkWrap: true` + `NeverScrollableScrollPhysics` inside an outer scrollable. Every tile is laid out, and the catalogue re-measures on each keystroke. → `SliverGrid`.
- `home_bento.dart:53` — four spotlight slides each carry `AppGlow(blur: 40)`: four large blurred shadows in the scroll path.
- `home_bento.dart:53` — a `BoxShadow(blurRadius: 48)` ~~on the first scroll item~~ and four `AppGlow(blur: 40)` shadows on the paged spotlight slides, so five large blurred shadows live in the scroll path. **Partly resolved:** the hero's `blurRadius: 48` went with the hero in §7. The four per-slide glows remain, and now compete with the blurred backdrop.
- ~~`home_sections.dart:310, 427` — two `AnimatedBuilder`s repainting a gradient sweep and two radial orbs on a 7 s loop, with no `RepaintBoundary`, running even offscreen.~~ **Resolved in §7** — deleted with `HomeHero`, along with `_Orb` and `_ShinePill`.
- `home_bento.dart:537` — the ticker calls `setState` on pointer enter/exit while a `Ticker` already calls `jumpTo` each frame.
- `product_card.dart:43` — hover calls `setState` on the whole tile, rebuilding the image and text subtree on every pointer-move boundary.
- `product_card.dart:39` — `StaggeredEntrance` starts every tile at `opacity: 0` with up to a 400 ms delay, so above-the-fold tiles are blank until the animation fires.
- `motion.dart` — `StaggeredEntrance` and `PressScale` never check `MediaQuery.disableAnimations`.
- `product_card.dart:101`, `home_bento.dart:59`, `product_page.dart:609`, `search_field.dart:165` — images decoded at full resolution.
- `search_field.dart:165` — `Image.network` (no disk cache), re-decoding on every keystroke.
- `khqr_sheet.dart:58` — see B10.
- `product_page.dart:143` — picking a denomination calls page-level `setState`, rebuilding gallery, description, variant grid and reviews.
- `wallet_page.dart:184`, `order_detail_page.dart:80` — ledger and order lines built eagerly in a `Column`.
- Admin: `admin_orders_page.dart:98`, `admin_refunds_page.dart:56`, `admin_support_page.dart:71`, `admin_supplier_queue_page.dart:54`, `admin_catalogue_page.dart:54`, `admin_transfers_page.dart:46` — all eager `Column`-of-cards, no lazy building.
- Admin `onRefresh` returns as soon as `invalidate()` is called, in **six** pages (`admin_page.dart:29`, `admin_refunds_page.dart:36`, `admin_catalogue_page.dart:34`, `admin_supplier_queue_page.dart:34`, `admin_staff_page.dart:47`, `admin_transfers_page.dart:31`) — the spinner hides before the refetch finishes.
- `admin_orders_page.dart:96` — changing a filter swaps the provider family key, so the table drops to a skeleton on every chip tap.
- `admin_support_page.dart:194` — every keystroke in a note calls `setState` on the whole page.
- `admin_order_detail_page.dart:27` — one action invalidates four providers including the whole `adminOrdersProvider` family.
- No in-button progress indicator for long admin actions: `admin_transfers_page.dart:197`, `admin_staff_page.dart:82`.
- **Fonts.** `google_fonts` fetches Noto Sans Khmer at runtime. Khmer is the default locale, so the first paint of every cold load blocks on that fetch and then reflows.

### 2.4 Conversion friction — storefront (7 findings)

- `product_page.dart:56` — a missing product renders `noProducts` centred, with no back action. Soft dead end.
- `home_bento.dart:561` — "trending" rows show rank, name and sold count but have **no `onTap`**; the strip advertises games a buyer cannot open.
- `catalog_page.dart:90` — the clear-search button reads `_search.text`, but nothing listens to the controller, so the X never appears while typing.
- `search_field.dart:110` — an autocomplete term with no matches renders `SizedBox.shrink()`; the user gets no signal and may think search is broken.
- `search_field.dart:138` — the result price is built by hand as `'\$${…}'`, bypassing `money()`. Currency can drift.
- `catalog_page.dart:114` — no sort and no price filter; category chips and search only.
- `product_page.dart:520` — the buy-bar total is `maxLines: 1` + ellipsis, so a large total truncates the number the buyer must confirm.

### 2.5 Operator friction — admin (12 findings)

- `admin_order_detail_page.dart:345` — raw enum words (`manual_waiting`, `pending`) printed into the UI.
- `admin_order_detail_page.dart:470` — the timeline prints raw event and actor strings (`order_status_changed · system`).
- `admin_page.dart:125` — `data.timezone` shown verbatim as `Asia/Phnom_Penh`.
- `admin_transfers_page.dart:76` — the amount field pre-fills a bare `12.50` with no currency marker, so staff can type Riel into a USD input.
- `admin_orders_page.dart:75` — status filter and search live only in local state, never in the route; leaving and returning resets the queue.
- `admin_support_page.dart:216` — a closed ticket has no reopen action; a mistaken close is terminal.
- `admin_supplier_queue_page.dart:135` — supplier code and `N ×` attempt count rendered unlabelled in a dot-joined string.
- `admin_catalogue_page.dart:117` — slug, supplier code and shown/hidden joined with `·` into one grey line.
- `khqr_sheet.dart:180` — dismissing the QR sheet is a `TextButton` labelled `cart`. Exit is ambiguous.
- `checkout_page.dart:390` — the top-up button labels the amount with the current balance, not the shortfall.
- `checkout_page.dart:383` — when the balance is unknown the pay button shows "loading" with no spinner: a dead end.
- `auth_page.dart:494` — validation only fires on submit; `review_sheet.dart:51` — `_rating` defaults to 5, biasing every review.

### 2.6 Mobile / web parity (17 findings)

- Eight hardcoded breakpoints in three values across seven files: `home_page.dart:69`, `catalog_page.dart:82`, `checkout_page.dart:143`, `app_shell.dart:32`, `home_sections.dart:289`, `store_footer.dart:20` (all `900`); `home_bento.dart:24, 42` (`700`); `product_page.dart:331` (`520`).
- `search_field.dart:126` — the result panel hardcodes `width: 360`; on a 320/360 dp phone it overflows the viewport edge.
- `khqr_sheet.dart:141` — QR fixed at 232 px, can overflow narrow sheets.
- `checkout_page.dart:225` — coupon Apply is a fixed 100×52 box that clips the Khmer label.
- `home_bento.dart:339` — `BuyAgainRow` pins a 210 px card and 74 px row, clipping the two-line Khmer name block.
- Hover-only affordances never appear on touch: `product_card.dart:41`, `home_sections.dart:513`.
- Admin fixed widths: `admin_order_detail_page.dart:179` (110 px label) and `:462` (118 px event); `admin_catalogue_page.dart:249` (three un-`Expanded` money Texts overflow ~360 px phones); `admin_staff_page.dart:67` (email + Find in one unwrapping `Row`); `admin_transfers_page.dart:194` (Confirm + Dismiss never stack).
- `admin_widgets.dart:333` — filter chips scroll horizontally with no edge fade, scrollbar or hint.

### 2.7 Khmer typography (23 findings)

Theme sets generous metrics; 28 inline overrides undo them. All values below are Latin-tuned:

- Headings: `home_sections.dart:341` (`letterSpacing: -1.2`) overlaps Khmer clusters — negative tracking must be disabled for `km`. (Its `height: 1.15` went in §7 with the hero.) Same at `home_bento.dart:119`.
- `product_card.dart:186` (`1.3`), `product_page.dart:417` (`maxLines: 1` inside an ~89 px tile), `orders_page.dart:74`, `wallet_page.dart:317`, `order_progress.dart:62, 65`.
- Admin: `admin_transfers_page.dart:168`, `admin_refunds_page.dart:130`, `admin_supplier_queue_page.dart:150`, `admin_support_page.dart:161` all hardcode `height: 1.4`, overriding the theme's Khmer-tuned line box. `admin_order_detail_page.dart:374` pins `1.35`.
- `admin_widgets.dart:403` — refund reason capped at `maxLines: 3`; `admin_support_page.dart:192` — note field capped at 2.
- `manual_payment_panel.dart:217`, `auth_page.dart:432` — `Row` members not wrapped in `Flexible`.
- `product_card.dart:163` — category is `.toUpperCase()` with `letterSpacing: 0.7`; a Latin-only treatment that adds fake gaps to Khmer.
- `home_bento.dart:128` — "from" and the amount are two separate `Text`s, so Khmer and Latin baselines do not align with the price.

**Number and currency formatting is not locale-aware** (`format.dart`):

- `money()` is pinned to `en_US` with `$`, and `riel()` mixes the Khmer `៛` symbol with Latin digits via an `en_US` formatter.
- `admin_widgets.dart:368` — `adminStamp` emits Latin digits with ISO ordering, while other Khmer strings use Khmer numerals (`៧ ថ្ងៃចុងក្រោយ`). Two numeral systems in one screen.
- `orders_page.dart:110` — `_formatDate` hand-pads Latin digits, ignoring locale.
- Admin money columns show `$12.50` beside Khmer labels with no KHR equivalent, and `admin_catalogue_page.dart:249` has three separate `Text`s that never align. → one right-aligned money column with tabular figures.
- `auth_page.dart:198, 249` — hardcoded English "Show"/"Hide" tooltips on a Khmer-first UI.

### 2.8 Generic look (13 findings)

- **Admin is nine copies of one page.** Every list page is `AdminGate → ListView → AdminHeader → AsyncValueView → Column-of-cards` (`admin_refunds_page.dart:89`, `admin_supplier_queue_page.dart:89`, `admin_support_page.dart:111`, `admin_transfers_page.dart:94`, `admin_staff_page.dart:212`, `admin_catalogue_page.dart:87`, `admin_orders_page.dart:126`). Dense rows for orders, action-first for transfers, a table for catalogue.
- `admin_transfers_page.dart:94` — the card decoration block (margin 12, padding 14, `ink900`/`ink800`, radius 14) is copy-pasted inline in seven pages instead of using the shared `AdminSection`; borders and padding have already drifted.
- `admin_page.dart:135` — the hub lists the same destinations twice, as `AdminStat` and as `AdminTile`.
- `admin_widgets.dart:357` — `AdminEmpty` renders a bare left-aligned 12.5 px grey sentence while the rest of the app uses the centred `EmptyState`.
- `checkout_page.dart:313` — every section is the same numbered `_Panel`; a flat stepper with no visual hierarchy.
- `wallet_page.dart:74` — decorative gradient with no semantic link to balance state. (`home_bento.dart:53`'s violet glow now competes with the blurred backdrop added in §7 rather than with the hero's gradient.)
- `home_sections.dart` — `TrustRow`'s three identical pills carried no hierarchy; **moved into `HomeIntroBand` in §7**, where they still render as three identical pills. The hierarchy fix is still owed, and now also applies to the band's heading/action row.
- `home_page.dart:163` — "All products" `SectionTitle` passes the same string as both title and trailing button.
- `admin_support_page.dart:197` — the note field's `helperText` repeats the note already rendered at line 164.
- `home_bento.dart:618` — `_RankChip` applies the brand/violet gradient plus glow to the top three ranks, competing with the spotlight's identical gradient in the same viewport.

---

## 3. Fix plan

Design-system first, so both surfaces inherit. Each phase ends with the same gate: `flutter analyze` clean, `dart format`, `flutter test` green, and the Khmer locale checked by eye on a 360 dp viewport.

### Phase 0 — tokens and guardrails (no visual redesign yet) — **DONE**

Goal: make every later fix a one-line change instead of a search.

Status: implemented and verified. `flutter analyze` clean, `flutter test` 169 passing.
See §6 for what was built and the two deviations from this plan.

1. **`theme.dart` — fix the contrast failure.** Added `AppColors.onBrand = ink950`
   (5.26:1) and used it for filled buttons and `colorScheme.onPrimary`. Added
   `AppColors.ink300 = #93A0BA` for muted text on raised surfaces (4.93:1 on
   `ink700`, where `ink400` is 3.65:1) and raised the disabled foreground to it.
   `violet` moved `#8B5CF6` → `#9B7BFF` (4.93:1 on `ink800`, was 3.66:1).
2. **`theme.dart` — added `AppBreakpoints`.** `phone` 600, `tablet` 700,
   `wide` 900, `expanded` 1200, plus `isWide`/`isPhone` and `columnsFor` for
   deriving a column count from a tile's minimum width. The 8 literals are not
   replaced yet — that is Phase 5.
3. **`theme.dart` — added `AppSpace`** (4 / 8 / 12 / 16 / 24 / 32 / 48).
4. **`theme.dart` — locale-aware line heights.** `AppTheme.lineHeight(km, latin)`
   adds 0.4 for Khmer; every heading, body and label style now goes through it,
   and negative `letterSpacing` is disabled for `km`. Removed the 6 inline
   overrides that were tighter than the Khmer floor (≤ 1.35). Added `AppType`
   (`caption`/`label`/`bodySmall`/`body`/`bodyStrong`/`title`) so call sites stop
   inventing styles.
5. **`format.dart` — `Money`.** `Money.usd`, `Money.khr`, `Money.both`,
   `Money.tabular`. `money()` and `riel()` are kept as thin wrappers so the 46
   existing call sites are untouched. Digits stay Latin in both currencies by
   decision: that is what the Cambodian market quotes, and mixing numeral systems
   inside money is what made admin rows read as two systems. Fixed the hand-built
   price string in `search_field.dart`.
6. **Fonts bundled.** 11 subsetted statics in `app/assets/google_fonts/`, 1.2 MB
   total, declared as a pubspec asset. `google_fonts` resolves them from the
   bundle before it ever reaches the network.
7. **Added the missing primitives** in `app/lib/src/ui/widgets/`: `TapTarget`,
   `MoneyText` + `MoneyRow`, `ConfirmAction`. A fourth, `SectionHeading`, was
   added and then **deleted**: `SectionTitle` in `home_sections.dart` already
   filled that role with 6 call sites, and shipping both would have left two
   components doing one job. `SectionTitle` is the one that should gain
   `Semantics(header: true)`, and that is now a Phase 2 item rather than a
   Phase 0 one.
8. **Guardrail tests.** `test/theme_contrast_test.dart` and
   `test/theme_tokens_test.dart`: every text token against every surface it is
   used on, the button foreground against its own fill, the font assets actually
   resolving through `rootBundle`, Khmer line heights ≥ 1.5 and never tracked in,
   the breakpoint/space scales, and a source scan that fails if any inline
   `height:` below 1.4 reappears in `lib/src/ui`.

**Exit criteria, as met:** contrast tests green; no inline `height:` below 1.4 in
`lib/src/ui`; fonts bundled and verified; `AppBreakpoints` and `AppSpace` defined
and consumed by the guardrail tests. The plan originally said "no inline `height:`
at all" — narrowed deliberately, see §6.

### Phase 0b — adopt the tokens (not yet done)

Phase 0 defines the tokens; nothing outside `theme.dart` reads them yet except the
new primitives. The adoption pass is mechanical and belongs with Phase 5:

- Replace the 8 hardcoded breakpoints with `AppBreakpoints`.
- Move card padding and section rhythm onto `AppSpace`.
- Convert prices to `MoneyText` / `Money.both` where the buyer quotes in riel.
- Convert raw `TextStyle`s to `AppType` where the size matches a named step.
- Remove the remaining inline `height:` overrides above 1.4 (harmless today, but
  they are the reason the Khmer floor has to be enforced by a test).


### Phase 1 — blocking defects (B1–B10) — **DONE**

`flutter analyze` clean, 175 tests passing (was 170).

- **B1** button contrast — landed in Phase 0.
- **B2** `admin_transfers_page.dart` — confirming a transfer now goes through
  `confirmAction`, which reads the order number and the amount being settled back
  to the operator before it commits.
- **B3** `admin_staff_page.dart` — changing a role is confirmed, naming the
  account and the new role. The role labels are now one shared function
  (`_roleLabel`) so the chips and the confirmation cannot disagree.
- **B4** `admin_refunds_page.dart` — `askAdminText` gained a `details` slot, and
  the refund dialog now shows the order number, the USD total and
  `adminRefundNote` ("recording a refund here does not move money") above the
  reference field.
- **B5** `admin_order_detail_page.dart` — "Mark failed" is danger-toned and
  confirmed with `adminResolveFailedBody`, which states that the buyer is not
  refunded by it. "Mark delivered" is unchanged.
- **B6** `admin_transfers_page.dart` — confirm and dismiss are no longer the same
  shape: confirm is a full-width `FilledButton`, dismiss is a danger-toned
  `TextButton` below it. The reason dialog names the order, and its submit button
  is disabled until a reason is typed — which the `_humanise` comment had already
  claimed the code did.
- **B7** `checkout_page.dart` — the step badge is a solid brand fill with
  `onBrand` text (5.26:1) instead of brand on a brand tint (≈2.4:1).
- **B8** `admin_orders_page.dart` + `AdminOrderQuery` — the 60-row ceiling is
  visible and escapable: the list states how many rows are shown and offers
  "Show more", which raises the query limit. Previously the list simply ended,
  which reads as "that is all of them".
- **B9** `khqr_sheet.dart` — the payment status is a `Semantics(liveRegion: true)`,
  so expiry is announced instead of silently closing the sheet.
- **B10** `khqr_sheet.dart` — the once-a-second `setState` is replaced by a
  `ValueNotifier<Duration>` read through a `ValueListenableBuilder`, so the
  countdown no longer rebuilds the QR image and every button 60 times a minute.

New tests in `test/manual_payment_test.dart`: confirming a transfer reads the
order and amount back; cancelling reaches no repository (the absence of a
snackbar is the proof, since a real call would fail loudly in a widget test);
dismissing stays disabled until a reason is typed.

**Nine new l10n keys** were added to both ARB files for this:
`adminConfirmPaymentNote`, `adminDismissNote`, `adminSetRoleTitle`,
`adminSetRoleBody`, `adminResolveFailedTitle`, `adminResolveFailedBody`,
`adminTicketCloseTitle`, `adminTicketCloseBody`, `adminShowingCount`.
The Khmer strings mirror the vocabulary already in `app_km.arb` and **still need a
native read-through** — see the existing human task in `PLAN.md`.

**B3's exit criterion is only half met.** The confirmation gate is in place, but
`admin_staff_page.dart` still has no *undo*: the only way back from a wrong role is
to set another role. Noted rather than built, because the database refuses a
self-change and there is no role history to revert to.


### Phase 2 — accessibility sweep (30 findings)

Drive it from the `TapTarget` primitive so the fix is structural, not per-site.

- Wrap every tile/pill in `Semantics(button: true)` with a label: `product_card.dart:52`, `home_bento.dart:44, 348`, `home_sections.dart:513`.
- `Semantics(header: true)` on `SectionTitle`.
- Label every icon-only control: `product_page.dart:470, 533`, `cart_page.dart:133`, `order_detail_page.dart:341`, `admin_orders_page.dart:65`.
- Labels for non-text signals: `product_page.dart:671` (rating), `order_progress.dart:92` (state), `admin_widgets.dart:196` (stat).
- Enforce 44×44: `required_fields_form.dart:88`, `auth_page.dart:1098`, `wallet_page.dart:144`, `admin_catalogue_page.dart:239`.
- Stop encoding state in colour alone: `admin_page.dart:57`, `product_page.dart:410`, `admin_widgets.dart:196`.
- Add a live region to `auth_page.dart:1127`.

Exit criteria: zero unlabelled interactive widgets; `flutter analyze` clean; manual screen-reader pass on home → product → cart → checkout.

### Phase 3 — perceived performance (28 findings)

Ordered by user-visible impact:

1. Fonts bundled (Phase 0) — removes the cold-load reflow.
2. `home_page.dart:63` → `CustomScrollView` with slivers; split the seven `ref.watch` calls into per-section `ConsumerWidget`s; `home_page.dart:195` and `catalog_page.dart:159` → `SliverGrid`.
3. `cacheWidth`/`cacheHeight` at all six image sites; `search_field.dart:165` → `CachedNetworkImage`.
4. `RepaintBoundary` + visibility-gated controllers ~~at `home_sections.dart:310, 427`~~ (done for the hero in §7; the remaining animated surfaces are the ticker and the spotlight backdrop); reduce blur on the four per-slide `AppGlow`s (`home_bento.dart:53`); move the ticker pause state to a `ValueNotifier` (`home_bento.dart:537`).
5. Scope local state: `product_page.dart:143` (denomination/qty to a notifier), `product_card.dart:43` (hover to a leaf), `admin_support_page.dart:194`.
6. Admin lists → builders in the six pages; `admin_orders_page.dart:96` → keep previous rows while reloading; the six `onRefresh` handlers → await the refetch.
7. In-button progress for long admin actions.
8. Respect `MediaQuery.disableAnimations` in `motion.dart`.

Exit criteria: home renders its first screen without building the offscreen grids; no full-page rebuild on a keystroke; refresh spinners stay up for the real work.

### Phase 4 — conversion and operator friction (25 findings)

Storefront:

- Trending rows tappable (`home_bento.dart:561`).
- Missing-product page gets an action and its own copy (`product_page.dart:56`).
- Fix the dead clear-search button (`catalog_page.dart:90`) and the silent empty autocomplete (`search_field.dart:110`).
- Add sort and price filter (`catalog_page.dart:114`).
- Buy-bar total uses `FittedBox`, never ellipsis (`product_page.dart:520`).
- Checkout: label the shortfall, not the balance (`:390`); a real progress state, not a dead "loading" (`:383`); validate as the user types (`auth_page.dart:494`); require an explicit rating (`review_sheet.dart:51`); relabel the QR dismiss (`khqr_sheet.dart:180`).

Admin:

- Localise the raw enums and event strings (`admin_order_detail_page.dart:345, 470`), the timezone (`admin_page.dart:125`), and the unlabelled dot-joined strings (`admin_catalogue_page.dart:117`, `admin_supplier_queue_page.dart:135`).
- Put filters and search in the route (`admin_orders_page.dart:75`).
- Add reopen (`admin_support_page.dart:216`).
- Currency affix and validation on the amount field (`admin_transfers_page.dart:76`).

Exit criteria: every screen has an obvious next action; no raw enum or ISO value reaches a user.

### Phase 5 — mobile / web parity (17 findings)

- Consume `AppBreakpoints` everywhere; delete the literals.
- Fix `search_field.dart:126` (360 px panel) and `khqr_sheet.dart:141` (232 px QR).
- Derive grid columns from tile min-width, not a magic number (`product_page.dart:331`).
- Press-state equivalents for the hover-only affordances (`product_card.dart:41`, `home_sections.dart:513`).
- Let fixed-size admin blocks wrap or stack: `admin_order_detail_page.dart:179, 462`, `admin_catalogue_page.dart:249`, `admin_staff_page.dart:67`, `admin_transfers_page.dart:194`, `home_bento.dart:339`.
- Edge fade or scrollbar on the admin filter chips (`admin_widgets.dart:333`).

Exit criteria: no horizontal overflow at 320, 360, 768, 1024 and 1440 dp, in both locales.

### Phase 6 — Khmer typography and visual hierarchy (23 + 13 findings)

- With the inline `height:` overrides gone, walk every screen under `km` at 360 dp and fix the remaining `maxLines`/`Flexible` sites listed in §2.7.
- Disable uppercase and negative tracking for `km` (`product_card.dart:163` uppercase+tracking, `home_bento.dart:119`'s spotlight title at `letterSpacing: -0.8`). The hero's `-1.2` went with the hero in §7; the band heading inherits the theme, which already zeroes tracking for `km`.
- Merge split Khmer/Latin `Text` pairs into single `TextSpan`s (`home_bento.dart:128`).
- Consolidate admin money into one right-aligned tabular column.
- Then, and only then, hierarchy: give admin real layout variety per task (dense rows for orders, action-first for transfers, a table for catalogue), replace the seven copy-pasted card decorations with `AdminSection`, make `AdminEmpty` use `EmptyState`, and reserve glow and gradient for state rather than decoration.

Exit criteria: a Khmer-first storefront where no string is clipped at 360 dp, and admin pages that are distinguishable from one another at a glance.

---

## 4. Suggested sequencing

Phases are independent enough to interleave, but the cheap wins are worth taking first:

| Order | Phase | Rough size | Payoff |
|---|---|---|---|
| 1 | Phase 0 (tokens, fonts, `AppColors.onBrand`) | medium, touches few files | Unblocks everything; fixes AA app-wide; removes cold-load reflow |
| 2 | Phase 1 (blocking) | small | Money safety and the payment-announcement hole |
| 3 | Phase 3 item 2 (home slivers) | medium | Largest perceived-performance win in the app |
| 4 | Phase 2 (accessibility) | large but mechanical | Structural via `TapTarget` |
| 5 | Phase 4 (conversion) | medium | Taps-to-paid and operator throughput |
| 6 | Phase 5 (parity) | medium | Removes the pixel breakages |
| 7 | Phase 6 (Khmer + hierarchy) | large, judgment-heavy | The part that stops it looking generic |

## 5. Not in scope

- Any change to money logic, RPCs, RLS, Edge Functions or supplier adapters.
- The `site_name` runtime setting and the Chanpenh brand identity.
- Khmer and English ARB parity — already 349/349, no action needed.
- Automated golden screenshots for every page. Worth adding in Phase 0 for the design-system widgets only; per-page goldens are a separate decision.

---

## 6. Phase 0 as built — deltas from the plan above

Three things did not go as written, and two of them are worth knowing about.

### 6.1 The line-height criterion was narrowed, deliberately

The plan said "delete all 28 inline `height:` values". Only **6** were removed:
the ones at or below 1.35, which are below what Khmer needs and were the actual
clipping cause. The 22 between 1.4 and 1.7 are *looser* than the new Khmer floor,
so they clip nothing and rewriting them is churn with no defect behind it.

The guardrail therefore bans any inline `height:` **below 1.4** rather than
banning the property outright. That is a rule that stays true as the code changes,
instead of one that fails the moment someone needs a deliberate tight line box.
Adopting `AppType` widely (§Phase 0b) is what will eventually remove the rest.

### 6.2 Removing a line height caused a real layout regression

`home_bento.dart`'s spotlight card had a **fixed** height, because the `PageView`
around it must be bounded. Letting the game name use the new Khmer line box made
the title taller than the panel and the card overflowed by 2 px — caught by
`spotlight_carousel_test.dart`, which is exactly what it is there for.

The fix was not to re-tighten the text:

- The title is now wrapped in `Flexible`, so a long name can never overflow the
  panel again — it ellipsises instead.
- `spotlightHeight` gives the panel back the height Khmer's line box costs
  (`+40` wide, `+26` narrow). Latin is unchanged; Khmer keeps its full two-line
  name instead of trading a clipped vowel for a clipped name.

Expect more of this. Every remaining inline line height sits inside a fixed-size
box, and each one will surface the same way: grow the box, or make the child
flexible, never re-tighten the text.

### 6.3 Fonts: subsetted statics, not whole family files

`google_fonts` resolves a family and weight by finding an asset whose path *ends
with* `<Family>-<Weight>` (`NotoSansKhmer-Bold`), verified against the resolved
version, 8.2.1. Straight family files would have been roughly 5 MB for the 11
faces the theme asks for.

Instead the three Google Fonts variable files were instantiated at each needed
weight with `fontTools.varLib.instancer`, then subset to the Khmer block, Khmer
symbols, Basic Latin, Latin-1, general punctuation, currency, arrows, symbols and
variation selectors. Result: **11 files, 1.2 MB**.

Consequences worth stating:

- Static instances, not a variable font, so **rendering is byte-identical to the
  runtime fetch it replaces**. Flutter's variable-font handling requires
  `fontVariations` rather than `fontWeight` in places, and getting that subtly
  wrong would have left the whole app rendering every weight as Regular.
- `w600` and `w800` now have **real** faces. Today they were approximated against
  the 400/500/700 that `google_fonts` happened to have loaded. So SemiBold and
  ExtraBold text will look slightly different — that is the intent of the code
  finally being honoured, not a regression.
- Subsetting cannot introduce tofu for Khmer: the entire Khmer block
  (U+1780–U+17FF) and Khmer symbols are retained, and anything outside the kept
  ranges falls back to the system font, which is what happens today for glyphs
  Noto Sans Khmer does not have anyway (`★`, `→`, `✓` are absent from the source
  font and were never serving from it).
- A test fails if the fonts exceed 2 MB or if any expected asset stops resolving
  through `rootBundle`.

### 6.4 The pre-existing failure was fixed by someone else

`test/manual_payment_test.dart:118` was failing before any change here: a literal
`expires_at: '2026-10-16T09:00:00Z'` had passed into the past, so `isExpired` was
true and the `isFalse` assertion failed. While Phase 0 was in progress that fixture
was changed to a relative `DateTime.now().add(4h)`, which is the right fix, and the
suite went fully green. Not written here; recorded so the history is not confusing.

Full suite at the end of Phase 0: **170 passing, 0 failing.**

### 6.5 Note for whoever is editing this tree

Two files were being edited concurrently while Phase 0 was in progress:
`app/lib/src/ui/widgets/search_field.dart` (`Image.network` →
`CachedNetworkImage` appeared in the working tree without being written here) and
`app/test/manual_payment_test.dart`. The first briefly produced a phantom analyze
error from a half-saved file.

Both changes coexist with Phase 0's, but the tree carries unrelated uncommitted
work, so Phase 0 was **not** committed. Phase 0's own changes are:

- modified: `app/lib/src/core/theme.dart`, `app/lib/src/core/format.dart`,
  `app/pubspec.yaml`, `app/lib/src/ui/widgets/search_field.dart`,
  `app/lib/src/ui/widgets/home_bento.dart`,
  `app/lib/src/ui/widgets/home_sections.dart`,
  `app/lib/src/ui/widgets/order_progress.dart`,
  `app/lib/src/ui/widgets/product_card.dart`,
  `app/lib/src/ui/admin_order_detail_page.dart`, `app/lib/src/ui/auth_page.dart`
- added: `app/assets/google_fonts/` (11 files),
  `app/lib/src/ui/widgets/{tap_target,money_text,confirm_action}.dart`,
  `app/test/{theme_contrast_test,theme_tokens_test}.dart`,
  `docs/ui-ux-findings-and-plan.md`

---

## 7. Banner change — one anchor instead of two empty panels

Done after Phase 0, on the owner's call. `flutter analyze` clean, 170 tests
passing.

### The two causes were different

**The hero had no image at all.** `HomeHero` (`home_sections.dart`) was a
full-width gradient panel containing a pill, a heading, a subtitle and a button,
all `crossAxisAlignment: start` inside a box up to 1140px wide. The copy filled
roughly 40% of it, so the right ~60% was bare gradient with a single `_Orb`
parked at `right: -60`. Nothing was ever meant to be there.

**The spotlight had art but framed it badly.** `BoxFit.contain` with
`alignment: centerRight` draws the art at its intrinsic aspect ratio pinned right,
which left the middle third dead, and the scrim is a full-panel left-to-right
gradient (`stops: [0, 0.45, 1]`) so it darkened that dead space too. The comment
at the old `fit:` line records that `cover` had already been tried and reverted for
cropping the art.

So the page opened with **two stacked wide panels, both mostly empty**, before the
first game tile. That was the real defect, not one banner.

### What changed

- `HomeHero`, `_HomeHeroState`, `_ShinePill`, `_Orb` and `TrustRow` are deleted —
  236 lines out of `home_sections.dart`.
- `HomeIntroBand` replaces them: one slim band holding the pitch, the "Browse
  games" action opposite it, and the three trust claims underneath. Nothing is
  orphaned — `heroTitle` becomes the band heading, `heroCta` its action,
  `heroSubtitle` its supporting line, and `trustInstant`, which the hero also
  showed, now appears once in the claim row instead of twice.
- The heading and the action share a row while there is room (`>= 520px` of band
  width) and stack below that. The action sitting opposite the heading is what
  keeps the band from having the hero's empty right half.
- `SpotlightTile` gets `_BlurredArt`: the same image, `BoxFit.cover`,
  `ImageFiltered` at `sigma 26` and dimmed to 0.55, behind the crisp `contain`
  art. Cover supplies the coverage, `contain` keeps the art uncropped, so neither
  of the two earlier failures comes back. It is scaled 1.15 before the blur so the
  filtered edge cannot bleed in as a dark rim.
- The crisp art's placeholder and error states are now transparent
  (`SizedBox.shrink`) instead of `ink850`, so a loading or broken image shows the
  backdrop rather than a flat block that covers it.
- Both spotlight images now pass `memCacheWidth` derived from the shell's 1140px
  cap, closing the "decodes supplier art at source resolution" finding for this
  panel.

### Two things this fixed for free

- The hero's 7-second orb loop is gone. That was a Phase 3 finding on its own:
  two large radial gradients repainting every frame behind an `AnimatedBuilder`
  with no `RepaintBoundary`, running even off screen.
- The overflow class that broke the first attempt: `_TrustPill`'s `Row` could not
  shrink a bare `Text` below its intrinsic width, so at 320px a claim overflowed.
  The label is now `Flexible`, which matters more for Khmer, where every claim is
  longer. This is the same defect the audit lists for every unwrapped `Row` in
  §2.7, so expect the identical fix at those sites.

### Still to eyeball

`storefront_test.dart` proves the band lays out at 320px and paints its promise
and action, and the full suite is green.

### The blurred backdrop was built, reviewed, and removed

It shipped, was looked at in the Khmer locale, and was taken back out. The reason
is specific and worth recording.

The spotlight is a **paging carousel**: it auto-advances every 6 s with a 420 ms
slide animation. Before the change, both slides' non-art area was a flat gradient,
so the boundary between two slides was invisible. A per-slide blurred backdrop gave
each slide its own texture, and two different blurs meeting with no blend read as a
**hard vertical seam** during every transition — a defect the old design could not
have. `_BlurredArt` and its dim layer are gone.

What was kept from that work: `memCacheWidth` on the spotlight art, the
`spotlightHeight` Khmer allowance, the `Flexible` title, and the whole
`HomeIntroBand` replacement of the hero. The spotlight's empty middle third is
back and is still listed in §2.8.

A shared, carousel-level backdrop would avoid the seam, but that is a different
design and is not queued.

### Spotlight art has no fallback — new finding

`ProductArtFallback` (`product_art.dart`) draws the product's own name on the house
gradient when there is no art or the art will not load. It is used by
`product_card.dart`, `product_page.dart`, `search_field.dart` and `BuyAgainRow` —
**but not by `SpotlightTile`, which is the largest art slot in the app.**

Consequences on the most valuable panel on the page:

- A product with no `imageUrl` renders the gradient and the copy and nothing else,
  so the right half is empty. That is the original complaint, reachable again for
  any product that has no mirrored art.
- A broken URL paints a flat `ink850` rectangle, which does not match the panel
  gradient either side of it.

Not changed here, deliberately: the spotlight already prints the product name in
its own copy, so the fallback's stated purpose ("draws the product's own name") is
already met by the panel, and what a big empty art slot *should* look like is a
design call — the same kind that was just rejected once. Restoring `ProductArtFallback`
there, or sizing the art slot, are both options and neither is queued.

Relevant context from `AGENTS.md`: synced supplier art keeps the supplier's own
square or portrait shape, while the spotlight panel is roughly 5:1. A square
image cannot fill a 5:1 band, whatever the fit — which is the structural reason
this panel has dead space at all. (An earlier build padded art onto a 4:3 canvas;
that was reverted because the padding shrank the art behind letterbox bars.)


Not done, deliberately out of scope: the decorative violet `AppGlow` on the
spotlight (still competing with the panel gradient — Phase 3 + Phase 6),
`SectionTitle` gaining `Semantics(header: true)` (Phase 2), and the hero's old
`home_page.dart:163` duplicate-label issue (Phase 6).



