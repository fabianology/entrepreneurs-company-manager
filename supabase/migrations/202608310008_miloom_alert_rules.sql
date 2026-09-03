-- Phase 5.2: user-owned alert rules and privacy-preserving in-app alert events.
-- Evaluation runs with the service role after a successful data sync. This
-- migration does not send push notifications.

alter table if exists public.user_preferences
    add column if not exists briefing_weekday smallint not null default 1
        check (briefing_weekday between 1 and 7),
    add column if not exists briefing_time time not null default '08:00',
    add column if not exists timezone text not null default 'UTC',
    add column if not exists weekly_briefing_enabled boolean not null default false,
    add column if not exists critical_alerts_enabled boolean not null default false;

-- Push delivery remains opt-in for new preference rows. Existing explicit user
-- values are preserved.
alter table if exists public.user_preferences
    alter column weekly_briefing_enabled set default false,
    alter column critical_alerts_enabled set default false;

alter table if exists public.subscriptions
    add column if not exists next_renewal_at timestamptz;

alter table if exists public.financial_cards
    add column if not exists expires_at timestamptz;

alter table if exists public.loans
    add column if not exists next_payment_at timestamptz;

alter table if exists public.company_documents
    add column if not exists expires_at timestamptz,
    add column if not exists renewal_metadata jsonb not null default '{}'::jsonb;

create table if not exists public.alert_rules (
    user_id uuid not null references auth.users(id) on delete cascade,
    rule_type text not null check (rule_type in (
        'large_transaction',
        'possible_duplicate',
        'unusual_spending',
        'balance_change',
        'upcoming_payment',
        'expiring_item',
        'disconnected_institution'
    )),
    enabled boolean not null default true,
    threshold_amount numeric,
    threshold_percent numeric,
    lookback_days integer check (lookback_days is null or lookback_days between 1 and 365),
    lead_days integer check (lead_days is null or lead_days between 1 and 365),
    config jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default clock_timestamp(),
    updated_at timestamptz not null default clock_timestamp(),
    primary key (user_id, rule_type)
);

create table if not exists public.alert_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    rule_type text not null,
    source_type text not null,
    source_id uuid not null,
    event_version text not null,
    severity text not null default 'attention'
        check (severity in ('info', 'attention', 'urgent')),
    title text not null,
    body text not null,
    fingerprint text not null,
    notification_id uuid references public.app_notifications(id) on delete set null,
    created_at timestamptz not null default clock_timestamp(),
    acknowledged_at timestamptz,
    dismissed_at timestamptz,
    unique (user_id, fingerprint)
);

create index if not exists alert_events_user_created_idx
    on public.alert_events(user_id, created_at desc);

create index if not exists alert_events_open_idx
    on public.alert_events(user_id, created_at desc)
    where acknowledged_at is null and dismissed_at is null;

create table if not exists public.alert_balance_snapshots (
    user_id uuid not null references auth.users(id) on delete cascade,
    institution_id uuid not null references public.institutions(id) on delete cascade,
    account_id text not null,
    balance numeric not null,
    currency text not null default 'USD',
    observed_at timestamptz not null default clock_timestamp(),
    primary key (user_id, institution_id, account_id)
);

alter table public.alert_rules enable row level security;
alter table public.alert_events enable row level security;
alter table public.alert_balance_snapshots enable row level security;

drop policy if exists "Users manage own alert rules" on public.alert_rules;
create policy "Users manage own alert rules" on public.alert_rules
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users read own alert events" on public.alert_events;
create policy "Users read own alert events" on public.alert_events
    for select using (user_id = auth.uid());

drop policy if exists "Users update own alert events" on public.alert_events;
create policy "Users update own alert events" on public.alert_events
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke all on table public.alert_balance_snapshots from public, anon, authenticated;
grant select, insert, update, delete on table public.alert_rules to authenticated;
grant select, update on table public.alert_events to authenticated;
grant all on table public.alert_rules to service_role;
grant all on table public.alert_events to service_role;
grant all on table public.alert_balance_snapshots to service_role;

create or replace function public.touch_miloom_alert_rule()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at := clock_timestamp();
    return new;
end;
$$;

drop trigger if exists touch_miloom_alert_rule on public.alert_rules;
create trigger touch_miloom_alert_rule
before update on public.alert_rules
for each row execute function public.touch_miloom_alert_rule();

-- Seed conservative defaults for current users. New users are seeded lazily by
-- the evaluator so auth creation never depends on this feature.
insert into public.alert_rules (
    user_id, rule_type, enabled, threshold_amount,
    threshold_percent, lookback_days, lead_days, config
)
select users.id, defaults.rule_type, defaults.enabled, defaults.threshold_amount,
       defaults.threshold_percent, defaults.lookback_days, defaults.lead_days,
       defaults.config
  from auth.users users
 cross join (values
    ('large_transaction', true, 1000::numeric, null::numeric, 3, null::integer, '{}'::jsonb),
    ('possible_duplicate', true, null::numeric, null::numeric, 3, null::integer, '{}'::jsonb),
    ('unusual_spending', false, 250::numeric, null::numeric, 90, null::integer,
        '{"minimum_history":10,"multiplier":3}'::jsonb),
    ('balance_change', false, 500::numeric, 25::numeric, null::integer, null::integer, '{}'::jsonb),
    ('upcoming_payment', true, null::numeric, null::numeric, null::integer, 7, '{}'::jsonb),
    ('expiring_item', true, null::numeric, null::numeric, null::integer, 30, '{}'::jsonb),
    ('disconnected_institution', true, null::numeric, null::numeric, null::integer, null::integer, '{}'::jsonb)
) as defaults(
    rule_type, enabled, threshold_amount, threshold_percent,
    lookback_days, lead_days, config
)
on conflict (user_id, rule_type) do nothing;

-- Event creation and notification creation are atomic. A duplicate fingerprint
-- returns null and never creates a second notification.
create or replace function public.record_miloom_alert_event(
    p_user_id uuid,
    p_rule_type text,
    p_source_type text,
    p_source_id uuid,
    p_event_version text,
    p_severity text,
    p_title text,
    p_body text,
    p_fingerprint text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    event_id uuid;
    created_notification_id uuid;
begin
    if p_user_id is null or p_source_id is null or p_fingerprint is null then
        raise exception 'Alert event identity is required';
    end if;

    insert into public.alert_events (
        user_id, rule_type, source_type, source_id, event_version,
        severity, title, body, fingerprint
    ) values (
        p_user_id, p_rule_type, p_source_type, p_source_id, p_event_version,
        p_severity, p_title, p_body, p_fingerprint
    )
    on conflict (user_id, fingerprint) do nothing
    returning id into event_id;

    if event_id is null then
        return null;
    end if;

    insert into public.app_notifications (
        user_id, notification_type, title, body,
        resource_id, resource_type, is_read
    ) values (
        p_user_id, 'portfolio_alert', p_title, p_body,
        p_source_id, p_source_type, false
    )
    returning id into created_notification_id;

    update public.alert_events
       set notification_id = created_notification_id
     where id = event_id;

    return event_id;
end;
$$;

revoke all on function public.record_miloom_alert_event(
    uuid, text, text, uuid, text, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.record_miloom_alert_event(
    uuid, text, text, uuid, text, text, text, text, text
) to service_role;

comment on table public.alert_rules is
    'User-owned category switches and thresholds for server-evaluated portfolio alerts.';
comment on table public.alert_events is
    'Deduplicated private alert events; push delivery is intentionally handled separately.';
comment on table public.alert_balance_snapshots is
    'Service-only prior account balances used to evaluate opt-in balance-change alerts.';
