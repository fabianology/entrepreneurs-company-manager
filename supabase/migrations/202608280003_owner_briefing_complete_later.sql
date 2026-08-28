-- Owner Briefing Complete Later queue and authenticated canonical refresh.

alter table public.obligations
    add column if not exists deferred_at timestamptz;

update public.obligations
   set deferred_at = coalesce(
       deferred_at,
       snoozed_until - interval '7 days',
       updated_at,
       created_at,
       now()
   )
 where state = 'snoozed'
   and deferred_at is null;

create index if not exists obligations_deferred_age_idx
    on public.obligations (owner_user_id, state, deferred_at);

create or replace function public.refresh_my_miloom_obligations()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception using errcode = '42501', message = 'Authentication required';
    end if;

    perform public.refresh_miloom_obligations(v_user_id);
end;
$$;

revoke all on function public.refresh_my_miloom_obligations() from public;
grant execute on function public.refresh_my_miloom_obligations() to authenticated;
