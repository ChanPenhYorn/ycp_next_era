-- ============================================================================
-- One bug in `admin_support_set_status`, found while building the staff Support
-- screen: `resolved_at` was written on every call, not only when the status
-- changed.
--
--     resolved_at = case when p_status in ('resolved','closed')
--                        then now() else null end
--
-- The parameters are `coalesce`d on purpose so a caller can update one field —
-- the signature documents `p_status` as optional. But with `p_status = null`
-- that expression evaluates to null, so saving a note on a resolved ticket
-- silently wiped the time it was resolved. The history then says the ticket was
-- resolved and does not say when, which is the one thing resolved_at is for.
--
-- The re-created function only touches `resolved_at` when a status is actually
-- being set. A note-only call leaves the resolution time alone.
-- ============================================================================

create or replace function public.admin_support_set_status(
  p_ticket_id bigint,
  p_status    text,
  p_note      text default null,
  p_priority  text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_staff() then
    raise exception 'not_authorized';
  end if;

  update public.support_tickets
     set status      = coalesce(p_status, status),
         priority    = coalesce(p_priority, priority),
         admin_note  = coalesce(p_note, admin_note),
         assigned_to = (select auth.uid()),
         -- Null status means "not talking about the status": keep whatever
         -- resolution time is already recorded.
         resolved_at = case
                         when p_status in ('resolved', 'closed') then now()
                         when p_status is null then resolved_at
                         else null
                       end
   where id = p_ticket_id;

  if not found then
    raise exception 'ticket_not_found';
  end if;

  insert into public.audit_log (actor_id, action, entity, entity_id, detail)
  values ((select auth.uid()), 'support_ticket_status', 'support_ticket', p_ticket_id::text,
          jsonb_build_object('status', p_status, 'priority', p_priority));
end;
$$;

grant execute on function public.admin_support_set_status(bigint, text, text, text) to authenticated;
