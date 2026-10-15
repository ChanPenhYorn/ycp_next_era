-- ============================================================================
-- Local-only stub that mimics a HOSTED Supabase cron schema.
--
-- On hosted Supabase, cron.job is owned by supabase_admin. The postgres role
-- used by the SQL editor can neither DELETE from it nor necessarily schedule
-- jobs. This stub refuses both, which is what produced:
--
--   ERROR 42501: permission denied for table job
--   SQL: delete from cron.job where jobname in (...)
--
-- Run migrations against this to prove housekeeping scheduling degrades to a
-- notice instead of aborting the whole schema.
-- ============================================================================

create schema if not exists cron;

create table if not exists cron.job (
  jobid   bigint,
  jobname text
);

create or replace function cron.schedule(
  job_name text,
  schedule text,
  command  text
)
returns bigint
language plpgsql
as $$
begin
  raise exception 'permission denied for table job' using errcode = '42501';
end $$;

create or replace function cron.unschedule(job_name text)
returns boolean
language plpgsql
as $$
begin
  raise exception 'permission denied for table job' using errcode = '42501';
end $$;

-- Also refuse direct reads, as the hosted role experiences it.
revoke all on cron.job from public;
