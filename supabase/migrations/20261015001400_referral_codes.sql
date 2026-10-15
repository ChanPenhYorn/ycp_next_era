-- ============================================================================
-- Referral attribution.
--
-- `profiles.referral_code` has been generated since the first migration, and
-- `profiles.referred_by` has existed just as long, but nothing ever wrote it:
-- the column was decorative. This adds the one server-side call that fills it,
-- so the signup form can accept a friend's code.
--
-- Every rule lives here, not in the app, because the app is not the authority:
--   * the code must belong to an existing, unblocked profile
--   * nobody refers themselves
--   * first code wins; a later call is a no-op, so a UI retry cannot
--     re-attribute an account to somebody else
--
-- No coins or wallet credit move here. Rewarding a referrer is a campaign
-- decision (rate, cap, when it pays) and belongs in its own migration once ops
-- pick one, rather than being invented at signup time.
-- ============================================================================

create or replace function public.apply_referral_code(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user  uuid := (select auth.uid());
  v_code  text := upper(trim(coalesce(p_code, '')));
  v_owner uuid;
begin
  if v_user is null then raise exception 'auth_required'; end if;
  if v_code = '' then raise exception 'referral_code_required'; end if;

  select p.id into v_owner
    from public.profiles p
   where p.referral_code = v_code
     and p.is_blocked is false;

  if v_owner is null then raise exception 'referral_code_unknown'; end if;
  if v_owner = v_user then raise exception 'referral_code_self'; end if;

  update public.profiles
     set referred_by = v_owner
   where id = v_user
     and referred_by is null;
end;
$$;

grant execute on function public.apply_referral_code(text) to authenticated;
