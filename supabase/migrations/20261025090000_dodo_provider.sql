-- Dodo Payments as a second payment provider.
--
-- PayWay settles ABA KHQR in riel-friendly, local rails. Dodo is the card
-- rail: an international Merchant of Record that handles tax and disputes for
-- buyers who cannot scan a KHQR.
--
-- The value is added here on its own. Postgres refuses to use a new enum value
-- in the same transaction that adds it, and each migration file is one
-- transaction; the file that writes 'dodo' rows comes next.
alter type public.payment_provider add value if not exists 'dodo';
