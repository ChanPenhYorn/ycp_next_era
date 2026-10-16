-- ============================================================================
-- Role management.
--
-- Until now a role changed only by SQL. This adds the in-app path for admins
-- and one bootstrap call that the setup script runs once with the database
-- owner.
--
--   admin_set_role(user, role)  admins only; refuses a self-change, so the
--                               acting admin always stays one; audited
--   admin_find_user(email)      admins only; looks a sign-up up by email
--   admin_list_staff()          admins only; staff and admins
--   bootstrap_admin(email)      NOT granted to any app role. Run by the setup
--                               script as the database owner. Never reachable
--                               from the client, so "first signup wins" is
--                               impossible.
-- ============================================================================

create or replace function public.admin_set_role(
  p_user_id uuid,
  p_role    public.app_role
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old  public.app_role;
  v_name text;
begin
  if not public.is_admin() then raise exception 'not_authorized'; end if;
  if p_role is null then raise exception 'invalid_role'; end if;
  if p_user_id = (select auth.uid()) then raise exception 'cannot_change_own_role'; end if;

  select role, display_name into v_old, v_name
    from public.profiles
   where id = p_user_id
     for update;

  if not found then raise exception 'user_not_found'; end if;

  update public.profiles set role = p_role where id = p_user_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'role_change', 'profile', p_user_id::text,
          jsonb_build_object('from', v_old, 'to', p_role, 'name', v_name));

  return jsonb_build_object('ok', true, 'id', p_user_id, 'role', p_role);
end;
$$;

grant execute on function public.admin_set_role(uuid, public.app_role) to authenticated;

create or replace function public.admin_find_user(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row jsonb;
begin
  if not public.is_admin() then raise exception 'not_authorized'; end if;

  select jsonb_build_object('id', p.id, 'display_name', p.display_name, 'role', p.role)
    into v_row
    from auth.users u
    join public.profiles p on p.id = u.id
   where lower(u.email) = lower(btrim(coalesce(p_email, '')));

  if v_row is null then raise exception 'user_not_found'; end if;
  return v_row;
end;
$$;

grant execute on function public.admin_find_user(text) to authenticated;

create or replace function public.admin_list_staff()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not_authorized'; end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'display_name', p.display_name, 'role', p.role)
                     order by case p.role when 'admin' then 0 else 1 end, p.display_name)
      from public.profiles p
     where p.role in ('staff', 'admin')
  ), '[]'::jsonb);
end;
$$;

grant execute on function public.admin_list_staff() to authenticated;

create or replace function public.bootstrap_admin(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  select u.id into v_id
    from auth.users u
   where lower(u.email) = lower(btrim(coalesce(p_email, '')));

  if v_id is null then raise exception 'user_not_found' using detail = 'sign up first, then run the bootstrap'; end if;

  update public.profiles set role = 'admin' where id = v_id;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values (null, 'bootstrap_admin', 'profile', v_id::text, jsonb_build_object('email', p_email));

  return jsonb_build_object('ok', true, 'id', v_id, 'role', 'admin');
end;
$$;

revoke all on function public.bootstrap_admin(text) from public, anon, authenticated;
