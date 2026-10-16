-- ============================================================================
-- Supplier tables were unreadable by the staff screens.
--
-- `0002_rls.sql` gave both tables `for all to authenticated using (is_staff())`
-- policies, but never a table privilege. A policy alone grants nothing: the
-- staff catalogue embeds `supplier:suppliers ( code )`, so PostgREST answered
--
--   403 {"code":"42501","hint":"Grant the required privileges to the current
--        role with: GRANT SELECT ON public.suppliers TO authenticated;"}
--
-- and `AdminCataloguePage` showed "something went wrong" with an empty list.
--
-- SELECT only. Nothing in the app writes either table; a supplier is added by
-- code, and the sync worker uses the service key. The `for all` policies stay
-- in place so the grant can be widened the day a screen needs to write.
-- Neither table holds a secret: `suppliers` is code/name/base_url/is_active and
-- `supplier_skus` is a mapping plus cost. Prices and keys live elsewhere.
-- ============================================================================

grant select on public.suppliers to authenticated;
grant select on public.supplier_skus to authenticated;
