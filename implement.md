# MASTER PROMPT — Cambodia Mobile-First Gaming Top-Up Store

## 1. Role and Objective

Act as a Senior Flutter Web Engineer, UI/UX Designer, and Backend Architect.

Build a production-minded, mobile-first digital gaming top-up e-commerce website for customers in Cambodia. The store should have a polished, modern gaming aesthetic and a checkout experience that is fast, simple, trustworthy, and accessible to everyday Cambodian mobile users.

Use Bay2Game as the intended game top-up supplier, Supabase as the backend, and Flutter Web as the frontend.

The experience should feel like a premium digital commerce product rather than a generic admin template or a gaming landing page.

Before implementation:
1. Inspect the existing repository and its architecture.
2. Read the project instructions, `AGENTS.md`, `CLAUDE.md`, and other relevant rules if present.
3. Review Bay2Game's actual API documentation and the available supplier catalog.
4. Create an implementation plan and identify unresolved API, payment, and security requirements.
5. Reuse existing components and dependencies when appropriate. Do not rewrite working code unnecessarily.
6. Never invent supplier endpoints, API fields, game prices, payment integrations, or product availability.

## 2. Target Customers

Primary audience:
- Cambodian customers using Android phones.
- Customers paying in USD or KHR.
- Customers familiar with ABA Mobile, KHQR, and local digital payments.
- Customers purchasing Mobile Legends diamonds, Free Fire diamonds, PUBG Mobile UC, and other games actually supported by the supplier.

Design priorities:
- Mobile usability first.
- Khmer and English language support.
- Clear pricing and fees.
- Simple player-ID entry.
- Fast checkout with minimal typing.
- Clear payment and order status.
- Reliable support when a transaction fails.

## 3. Technology Stack

Frontend:
- Flutter Web
- Dart
- Riverpod for state management
- GoRouter for navigation
- Freezed and json_serializable for models where appropriate
- Responsive reusable widgets
- Flutter localization with Khmer and English support

Backend:
- Supabase PostgreSQL
- Supabase Auth
- Supabase Row Level Security
- Supabase Storage where needed
- Supabase Edge Functions for privileged server-side operations

Supplier:
- Bay2Game REST API, only according to verified documentation
- Supplier order callbacks if officially supported
- Server-side supplier balance and order-status reconciliation

Payments:
- Start with an administrator-verified KHQR workflow if automated merchant verification is not available.
- Add automated payment verification only through a verified payment provider integration.
- Never treat a QR scan, screenshot, or client-side success message as proof of payment.

Deployment:
- Flutter Web hosted on a static hosting provider with HTTPS.
- Supabase managed hosting initially, with self-hosting as a future option.
- Separate development and production configurations.

## 4. Visual Design Direction

Create a premium, modern gaming commerce UI.

Visual characteristics:
- Deep navy or charcoal backgrounds for the main brand surfaces.
- Bright electric blue or violet accents.
- White and soft-gray content surfaces for readability.
- Green only for successful payments and completed orders.
- Amber for processing and warnings.
- Red for failures and destructive actions.
- Rounded cards, subtle shadows, clean typography, and restrained gradients.
- Use actual game logos and licensed product artwork where available.
- Do not use random AI-generated logos or misleading official brand marks.

The design should be energetic without being visually noisy.

Avoid:
- Excessive neon effects.
- Too many gradients.
- Huge hero sections that push products below the fold.
- Desktop-only layouts.
- Tiny text or controls.
- Excessive animations.
- Fake reviews, fake discounts, fake stock counters, or unsupported trust badges.
- Generic dashboard-style storefronts.

Use a consistent design system with spacing, typography, color, border-radius, elevation, and component states defined centrally.

## 5. Mobile Navigation

Implement a mobile-first navigation structure.

Bottom navigation:
1. Home
2. Games
3. Orders
4. Account

Use clear icons and short labels. Keep the navigation visible on small screens where appropriate.

Header:
- Brand logo and name.
- Language selector: ខ្មែរ / EN.
- Wallet or account entry if supported.
- Cart icon only if a cart is genuinely needed for the chosen checkout flow.

On desktop, use a responsive top navigation and wider product grid.

Support common mobile widths starting at 320px. Prevent horizontal overflow and respect device safe areas.

## 6. Home Page

Create the following sections in this order:

### Header
- Brand logo.
- Search entry.
- Language selector.
- Account access.

### Search
Prominent search input with placeholder:
"Search games..."
Khmer equivalent:
"ស្វែងរកហ្គេម..."

Search should filter the real available catalog.

### Popular Games
Show a compact, responsive grid of available games.

Each game card should include:
- Official game artwork.
- Game name.
- Relevant product category.
- Starting price only when a valid current price is available.
- A clear tap target.

Prioritize popular Cambodian gaming titles only when supported by the actual supplier catalog.

### Promotions
Display only real promotions returned by configuration or the backend.

Do not hardcode fictitious discounts or countdown timers.

### How It Works
Show three short steps:
1. Choose your game and package.
2. Enter your player ID.
3. Pay and track your top-up.

Provide Khmer and English translations.

### Trust and Support
Explain the order process, support contact, refund policy, and delivery expectations using verified business information.

## 7. Game Purchase Flow

Make the game purchase flow the primary conversion path.

### Step 1: Select a Game

Display a dedicated game page with:
- Game artwork and title.
- Available top-up products.
- Region or server information when required.
- Clear instructions before purchase.

### Step 2: Enter Player Information

Show only the fields required by the selected product.

Examples:
- Player ID.
- Server ID where applicable.
- Region or platform where required.

Requirements:
- Clearly label each field.
- Show a practical example of the expected format.
- Validate input before proceeding.
- Provide an explanation for invalid values.
- Include a help dialog showing where to find the Player ID.
- Do not request the player's password.
- Do not assume every game uses the same identifier format.

If the supplier supports account verification, integrate it according to its documentation. Otherwise, clearly ask the customer to verify the entered details before paying.

### Step 3: Select a Package

Display package options as clean, tappable cards.

Each package should include:
- Product quantity or denomination.
- Retail price.
- Currency.
- Delivery type.
- Availability when reliably known.

Use a visually clear selected state.

Show the final payable amount before checkout.

Never invent a price or claim real-time availability without supplier data.

### Step 4: Review Order

Show a clear summary:
- Selected game.
- Selected package.
- Player ID and server ID if applicable.
- Product price.
- Any disclosed fees.
- Total payable.
- Estimated delivery information only when supported.

Require the customer to confirm the player details before placing the order.

### Step 5: Payment

For the initial release:
- Create a pending payment order on the server.
- Display administrator-approved KHQR payment instructions.
- Show the exact amount and unique order reference.
- Explain how payment verification works.
- Display a pending state until payment is verified.
- Provide a way to check order status.

Do not mark an order paid merely because a customer uploads a payment screenshot.

If automated payment verification is not configured, communicate that verification may require manual review.

### Step 6: Delivery and Tracking

Provide a dedicated order result page.

Possible states:
- Awaiting payment.
- Payment verification pending.
- Paid.
- Processing.
- Completed.
- Failed.
- Refund pending.
- Refunded.

Show clear status messages in Khmer and English.

Provide:
- Order reference.
- Game and package.
- Masked player details where appropriate.
- Timestamp.
- Support link.
- Retry or contact-support action where appropriate.

Do not expose supplier credentials, internal errors, or another customer's order information.

## 8. Khmer Localization and Cambodian UX

Khmer must be treated as a first-class language, not an afterthought.

Requirements:
- Use natural, concise Khmer.
- Include a Khmer/English language switch.
- Use a Khmer-capable font such as Noto Sans Khmer.
- Test text wrapping and line height carefully.
- Format prices consistently in USD and optionally KHR.
- Do not silently change currency or apply an undisclosed exchange rate.
- Keep important actions large and easy to tap.
- Avoid forms that require unnecessary personal information.
- Provide clear error messages and next steps.

Example labels:
- Home: ទំព័រដើម
- Games: ហ្គេម
- Orders: ការបញ្ជាទិញ
- Account: គណនី
- Buy now: ទិញឥឡូវនេះ
- Enter Player ID: បញ្ចូល Player ID
- Payment pending: កំពុងរង់ចាំការផ្ទៀងផ្ទាត់ការទូទាត់
- Order successful: ការបញ្ជាទិញជោគជ័យ
- Contact support: ទាក់ទងជំនួយ

Have a fluent Khmer speaker review customer-facing copy before production.

## 9. Supabase Database

Design a normalized, migration-managed schema.

Suggested tables:
- profiles
- categories
- games
- products
- product_variants
- supplier_products
- orders
- order_items
- payments
- supplier_transactions
- order_events
- support_tickets
- audit_logs

Requirements:
- Use UUID primary keys where appropriate.
- Add foreign keys and database constraints.
- Add indexes for common lookups.
- Store monetary amounts using integer minor units or an appropriate exact decimal type, never floating-point arithmetic.
- Snapshot the purchase price and product description into order items.
- Track supplier cost separately from retail price.
- Use explicit order and payment status values.
- Maintain timestamps and audit information.
- Use migrations for every schema change.

Do not create unnecessary tables before the actual workflow is understood.

## 10. Supabase Security

Implement security before integrating live payments.

Requirements:
- Enable and test RLS on all exposed customer tables.
- Customers can only access their own orders and permitted profile information.
- Only authorized administrators can manage catalog items, costs, stock, and refunds.
- Never trust a role or price sent by the client.
- Never expose the Supabase service-role key or supplier API credentials in Flutter Web.
- Store secrets in server-side environment variables or the platform's secret manager.
- Validate all requests on the server.
- Apply rate limiting and abuse controls to sensitive endpoints.
- Validate callback authentication.
- Protect against duplicate payment notifications and duplicate supplier orders.
- Avoid logging passwords, secret keys, or complete license credentials.

Administrative privileges must be enforced by trusted server-side authorization and database policies.

## 11. Bay2Game Integration

First inspect the official Bay2Game documentation available to the account.

Implement a supplier adapter so the application is not tightly coupled to one supplier.

Example conceptual interface:

- getCatalog()
- getProductDetails()
- getBalance()
- createTopUpOrder()
- getOrderStatus()
- handleSupplierCallback()

Use actual endpoint paths, field names, authentication, and status values from verified documentation.

Do not assume all products have the same request payload.

If the supplier provides callbacks:
- Authenticate callbacks using the documented mechanism.
- Validate supplier order references.
- Make event processing idempotent.
- Persist events before acknowledging them where appropriate.
- Handle repeated and out-of-order notifications.
- Reconcile unresolved orders using the supplier's status API.

If API credentials are unavailable, implement a mock supplier for local development and clearly mark the integration as incomplete.

## 12. Order and Payment Reliability

Implement an explicit state machine.

Example:
pending_payment → paid → processing → completed

Alternative failure paths:
pending_payment → expired
processing → failed
failed → refund_pending → refunded

Rules:
- Only trusted server-side verification can mark a payment as paid.
- A supplier order must not be created before payment is verified, unless the supplier's documented reservation workflow requires otherwise.
- Use idempotency keys and database uniqueness constraints.
- Do not create multiple top-ups when a request times out.
- Reconcile ambiguous supplier results before retrying.
- Record all status transitions in an order event log.
- Never promise automatic refunds unless the refund process is implemented.

## 13. Admin Dashboard

Create a responsive, protected admin area.

Pages:
- Overview.
- Games and categories.
- Product packages.
- Supplier products and stock.
- Orders.
- Payment verification.
- Failed deliveries.
- Refunds.
- Customers.
- Support tickets.
- Reports and settings.

Overview metrics:
- Total orders.
- Verified revenue.
- Supplier costs.
- Gross profit.
- Pending payments.
- Failed deliveries.

Calculate financial metrics from trusted database records. Clearly distinguish revenue, gross profit, and net profit.

Admin tables should work on mobile without forcing users to scroll through enormous desktop tables.

## 14. UI Components

Build reusable components for:
- GameCard.
- ProductPackageCard.
- PlayerIdForm.
- PriceDisplay.
- PrimaryButton.
- LoadingSkeleton.
- EmptyState.
- ErrorState.
- OrderStatusBadge.
- PaymentInstructionCard.
- OrderSummary.
- LanguageSwitcher.
- ConfirmationDialog.
- SupportAction.

Every interactive component must have loading, disabled, success, error, and appropriate accessibility states.

Use consistent typography and spacing. Avoid duplicating components across features.

## 15. Testing

Implement tests for:
- Product selection.
- Player ID validation.
- Currency formatting.
- Order totals.
- Order state transitions.
- RLS permissions.
- Payment verification.
- Duplicate callbacks.
- Supplier API timeouts.
- Failed and ambiguous supplier orders.
- Customer order isolation.
- Khmer and English layouts.
- Responsive behavior at mobile, tablet, and desktop widths.

Use mocked supplier responses for automated tests.

Do not test production payments with real money during routine development.

## 16. Performance and Accessibility

Requirements:
- Minimize unnecessary Flutter rebuilds.
- Use appropriately sized product images.
- Lazy-load catalog content where useful.
- Avoid loading every product image on the initial screen.
- Provide semantic labels and keyboard accessibility.
- Maintain readable contrast and large mobile tap targets.
- Handle network interruptions gracefully.
- Avoid placing critical information exclusively inside animations or tooltips.

## 17. Required Deliverables

Work in small, reviewable stages.

First deliver:
1. Repository assessment.
2. Architecture proposal.
3. Page and navigation plan.
4. Database schema proposal.
5. Supplier integration assumptions and unresolved questions.
6. Development milestones.

After approval, implement:
1. Design system and responsive storefront.
2. Sample catalog and purchase UI.
3. Supabase schema and authentication.
4. Admin dashboard.
5. Order creation and manual payment verification.
6. Bay2Game sandbox or verified API integration.
7. Supplier callback and order reconciliation.
8. Automated tests and deployment documentation.

For every stage:
- Explain what changed.
- List files created or modified.
- Run relevant formatting, analysis, and tests.
- Report failures honestly.
- Do not claim an API or payment flow works without testing it.
- Preserve existing project conventions.

## Definition of Done

The first production-ready milestone is complete when a customer can browse available products on a mobile phone, select a package, enter valid player information, create an order, complete a verified payment, and track fulfillment without exposing credentials or another customer's data.

Prioritize correctness, usability, security, and maintainability over adding more features.

Begin by inspecting the repository and preparing the implementation plan. Do not start a large implementation until the plan and unresolved integration requirements are clear.