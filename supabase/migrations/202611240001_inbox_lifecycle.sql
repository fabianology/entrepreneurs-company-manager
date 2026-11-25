-- Retention applies to Inbox delivery and visibility. Source events, invitations,
-- and audit records remain in their original tables.
begin;

alter table public.activity_logs
    add column if not exists inbox_dismissed_at timestamptz;

alter table public.resource_invitations
    add column if not exists inbox_subject text;

-- Live invites already show this title to their recipient. Capture it for the
-- eventual outcome while the invitation is still active.
update public.resource_invitations
set inbox_subject = public.miloom_resource_title(resource_type, resource_id)
where status = 'Pending' and expires_at > now() and inbox_subject is null;

create or replace function public.miloom_capture_inbox_invite_subject()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if new.status = 'Pending' and (tg_op = 'INSERT' or
        new.resource_id is distinct from old.resource_id or
        new.resource_type is distinct from old.resource_type) then
        new.inbox_subject := public.miloom_resource_title(new.resource_type, new.resource_id);
    elsif tg_op = 'UPDATE' then
        new.inbox_subject := old.inbox_subject;
    else
        new.inbox_subject := null;
    end if;
    return new;
end;
$$;

revoke all on function public.miloom_capture_inbox_invite_subject() from public, anon, authenticated;
drop trigger if exists capture_miloom_inbox_invite_subject on public.resource_invitations;
create trigger capture_miloom_inbox_invite_subject
    before insert or update on public.resource_invitations
    for each row execute function public.miloom_capture_inbox_invite_subject();

create index if not exists alert_events_notification_idx
    on public.alert_events (notification_id) where notification_id is not null;
create index if not exists resource_invitations_recipient_inbox_idx
    on public.resource_invitations (lower(email));

create or replace function public.miloom_inbox_time_zone(p_preference text)
returns text
language sql stable set search_path = ''
as $$
    select coalesce((select name from pg_catalog.pg_timezone_names where name = p_preference), 'UTC')
$$;

create or replace function public.miloom_inbox_alert_due_on(
    p_type text, p_resource text, p_body text, p_rule text, p_event_version text
)
returns date
language plpgsql immutable set search_path = ''
as $$
declare
    raw_day text;
begin
    if p_type is distinct from 'portfolio_alert' then return null; end if;
    if p_rule in ('upcoming_payment', 'expiring_item') then
        raw_day := p_event_version;
    elsif p_rule is null then
        raw_day := case p_resource
            when 'subscription' then substring(trim(p_body) from '^.+ is scheduled for ([0-9]{4}-[0-9]{2}-[0-9]{2})[.]$')
            when 'loan' then substring(trim(p_body) from '^.+ has a payment scheduled for ([0-9]{4}-[0-9]{2}-[0-9]{2})[.]$')
            when 'card' then substring(trim(p_body) from '^.+ expires by ([0-9]{4}-[0-9]{2}-[0-9]{2})[.]$')
            when 'document' then substring(trim(p_body) from '^.+ expires by ([0-9]{4}-[0-9]{2}-[0-9]{2})[.]$')
        end;
    end if;
    if raw_day ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then return raw_day::date; end if;
    return null;
exception when invalid_datetime_format or datetime_field_overflow then
    return null;
end;
$$;

create or replace function public.miloom_inbox_context()
returns jsonb
language sql stable security definer set search_path = ''
as $$
    with viewer as (
        select u.id, lower(u.email) as email, u.email_confirmed_at,
               public.miloom_inbox_time_zone(p.timezone) as time_zone
        from auth.users u left join public.user_preferences p on p.user_id = u.id
        where u.id = (select auth.uid())
    ), invitation_history as (
        select ri.id, ri.resource_type, ri.inbox_subject as resource_title, ri.role,
               lower(ri.sender_email) as inviter_email,
               case ri.status when 'Accepted' then 'accepted'
                              when 'Declined' then 'declined' else 'expired' end as outcome,
               case ri.status when 'Accepted' then ri.accepted_at
                              when 'Declined' then ri.declined_at else ri.expires_at end as occurred_at
        from viewer v
        join public.resource_invitations ri on lower(ri.email) = v.email
        where v.email_confirmed_at is not null
          and (ri.status in ('Accepted', 'Declined', 'Expired')
            or (ri.status = 'Pending' and ri.expires_at <= now()))
          and not exists (
              select 1 from public.resource_access_blocks b
              where b.owner_user_id = public.miloom_resource_owner(ri.resource_type, ri.resource_id)
                and (lower(b.blocked_email) = v.email or b.blocked_user_id = v.id)
          )
    )
    select jsonb_build_object(
        'time_zone', v.time_zone,
        'alerts', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', n.id, 'rule_type', e.rule_type, 'severity', e.severity,
                'due_on', public.miloom_inbox_alert_due_on(n.notification_type, n.resource_type, n.body, e.rule_type, e.event_version)
            ))
            from public.app_notifications n
            left join public.alert_events e on e.notification_id = n.id and e.user_id = v.id
            where n.user_id = v.id
        ), '[]'::jsonb),
        'invite_history', coalesce((
            select jsonb_agg(to_jsonb(i) order by i.occurred_at desc, i.id)
            from invitation_history i
            where (i.occurred_at at time zone v.time_zone)::date >= (now() at time zone v.time_zone)::date - 14
        ), '[]'::jsonb)
    )
    from viewer v
$$;

create or replace function public.miloom_inbox_activity()
returns setof public.activity_logs
language sql stable security definer set search_path = ''
as $$
    select a.*
    from public.activity_logs a
    left join public.user_preferences p on p.user_id = a.user_id
    cross join lateral (select public.miloom_inbox_time_zone(p.timezone) as name) tz
    where a.user_id = (select auth.uid())
      and a.inbox_dismissed_at is null
      and (a.created_at at time zone tz.name)::date >= (now() at time zone tz.name)::date - 14
    order by a.created_at desc, a.id
$$;

create or replace function public.miloom_dismiss_inbox_activity(p_activity_id uuid)
returns void
language sql security definer set search_path = ''
as $$
    update public.activity_logs
    set inbox_dismissed_at = now()
    where id = p_activity_id and user_id = (select auth.uid()) and inbox_dismissed_at is null
$$;

create or replace function public.miloom_purge_expired_inbox_alerts()
returns integer
language sql security definer set search_path = ''
as $$
    with expired as (
        select n.id
        from public.app_notifications n
        left join public.user_preferences p on p.user_id = n.user_id
        left join public.alert_events e on e.notification_id = n.id and e.user_id = n.user_id
        cross join lateral (select public.miloom_inbox_time_zone(p.timezone) as name) tz
        where coalesce(
            public.miloom_inbox_alert_due_on(n.notification_type, n.resource_type, n.body, e.rule_type, e.event_version),
            (n.created_at at time zone tz.name)::date
        ) < (now() at time zone tz.name)::date - 14
    ), deleted as (
        delete from public.app_notifications n using expired e where n.id = e.id returning n.id
    )
    select count(*)::integer from deleted
$$;

revoke all on function public.miloom_inbox_time_zone(text) from public, anon, authenticated;
revoke all on function public.miloom_inbox_alert_due_on(text,text,text,text,text) from public, anon, authenticated;
revoke all on function public.miloom_inbox_context() from public, anon, authenticated;
revoke all on function public.miloom_inbox_activity() from public, anon, authenticated;
revoke all on function public.miloom_dismiss_inbox_activity(uuid) from public, anon, authenticated;
revoke all on function public.miloom_purge_expired_inbox_alerts() from public, anon, authenticated;
grant execute on function public.miloom_inbox_context() to authenticated;
grant execute on function public.miloom_inbox_activity() to authenticated;
grant execute on function public.miloom_dismiss_inbox_activity(uuid) to authenticated;
grant execute on function public.miloom_purge_expired_inbox_alerts() to service_role;

-- Supabase environments with cron run this hourly so local calendar cutoffs
-- are applied even when the app is closed.
do $$
begin
    if to_regnamespace('cron') is not null then
        perform cron.schedule('miloom-inbox-retention', '17 * * * *',
            'select public.miloom_purge_expired_inbox_alerts()');
    end if;
end
$$;

commit;
