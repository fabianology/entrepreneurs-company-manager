-- Miloom Pro: entitlement, portfolio-connection, briefing, and usage foundation.
-- This migration is intentionally idempotent so it can be rehearsed safely.

create extension if not exists pgcrypto;

create table if not exists public.user_entitlements (
    user_id uuid primary key references auth.users(id) on delete cascade,
    tier text not null default 'free' check (tier in ('free', 'pro')),
    status text not null default 'expired' check (status in ('trial', 'active', 'grace', 'expired', 'revoked')),
    product_id text,
    original_transaction_id text unique,
    trial_ends_at timestamptz,
    renews_at timestamptz,
    grace_ends_at timestamptz,
    selected_free_company_id uuid,
    selected_free_plaid_item_id text,
    updated_at timestamptz not null default now()
);

create table if not exists public.usage_buckets (
    user_id uuid not null references auth.users(id) on delete cascade,
    period_start date not null,
    ai_actions integer not null default 0 check (ai_actions >= 0),
    voice_seconds integer not null default 0 check (voice_seconds >= 0),
    uploaded_documents integer not null default 0 check (uploaded_documents >= 0),
    updated_at timestamptz not null default now(),
    primary key (user_id, period_start)
);

create table if not exists public.resource_connections (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    source_type text not null,
    source_id uuid not null,
    target_type text not null,
    target_id uuid not null,
    relationship_type text not null check (relationship_type in (
        'belongs_to', 'paid_by', 'connected_account', 'uses_login',
        'document_for', 'shared_with', 'depends_on'
    )),
    origin text not null check (origin in ('direct', 'inferred', 'manual')),
    confidence numeric(4,3) not null default 1 check (confidence between 0 and 1),
    state text not null default 'confirmed' check (state in ('confirmed', 'suggested', 'rejected')),
    inference_key text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (source_id <> target_id or source_type <> target_type)
);

create unique index if not exists resource_connections_unique_edge
    on public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id, relationship_type
    );
create index if not exists resource_connections_source_idx
    on public.resource_connections (owner_user_id, source_type, source_id);
create index if not exists resource_connections_target_idx
    on public.resource_connections (owner_user_id, target_type, target_id);

create table if not exists public.obligations (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    company_id uuid,
    source_type text not null,
    source_id uuid not null,
    kind text not null,
    due_at timestamptz,
    severity text not null default 'info' check (severity in ('info', 'attention', 'urgent')),
    title text not null,
    summary text not null default '',
    action_type text not null default 'open_source',
    state text not null default 'open' check (state in ('open', 'snoozed', 'handled', 'dismissed')),
    snoozed_until timestamptz,
    fingerprint text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (owner_user_id, fingerprint)
);

create index if not exists obligations_open_due_idx
    on public.obligations (owner_user_id, state, due_at);

create table if not exists public.device_push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    token text not null,
    environment text not null default 'development' check (environment in ('development', 'production')),
    updated_at timestamptz not null default now(),
    unique (user_id, token)
);

create table if not exists public.product_events (
    id bigint generated always as identity primary key,
    user_id uuid references auth.users(id) on delete set null,
    event_name text not null,
    source text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

alter table if exists public.subscriptions
    add column if not exists next_renewal_at timestamptz;
alter table if exists public.financial_cards
    add column if not exists expires_at timestamptz;
alter table if exists public.loans
    add column if not exists next_payment_at timestamptz;
alter table if exists public.company_documents
    add column if not exists expires_at timestamptz,
    add column if not exists renewal_metadata jsonb not null default '{}'::jsonb;
alter table if exists public.user_preferences
    add column if not exists briefing_weekday smallint not null default 1 check (briefing_weekday between 1 and 7),
    add column if not exists briefing_time time not null default '08:00',
    add column if not exists timezone text not null default 'UTC',
    add column if not exists weekly_briefing_enabled boolean not null default true,
    add column if not exists critical_alerts_enabled boolean not null default true;

alter table public.user_entitlements enable row level security;
alter table public.usage_buckets enable row level security;
alter table public.resource_connections enable row level security;
alter table public.obligations enable row level security;
alter table public.device_push_tokens enable row level security;
alter table public.product_events enable row level security;

drop policy if exists "Users read own entitlement" on public.user_entitlements;
create policy "Users read own entitlement" on public.user_entitlements
    for select using (user_id = auth.uid());

drop policy if exists "Users read own usage" on public.usage_buckets;
create policy "Users read own usage" on public.usage_buckets
    for select using (user_id = auth.uid());

drop policy if exists "Users manage own connections" on public.resource_connections;
create policy "Users manage own connections" on public.resource_connections
    for all using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

drop policy if exists "Users read own obligations" on public.obligations;
create policy "Users read own obligations" on public.obligations
    for select using (owner_user_id = auth.uid());
drop policy if exists "Users update own obligations" on public.obligations;
create policy "Users update own obligations" on public.obligations
    for update using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

drop policy if exists "Users manage own push tokens" on public.device_push_tokens;
create policy "Users manage own push tokens" on public.device_push_tokens
    for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users insert own product events" on public.product_events;
create policy "Users insert own product events" on public.product_events
    for insert with check (user_id = auth.uid());

create or replace function public.miloom_effective_tier(p_user_id uuid default auth.uid())
returns text
language sql
stable
security definer
set search_path = public
as $$
    select case
        when exists (
            select 1 from public.user_entitlements e
            where e.user_id = p_user_id
              and e.tier = 'pro'
              and (
                  e.status in ('trial', 'active')
                  or (e.status = 'grace' and coalesce(e.grace_ends_at, now()) >= now())
              )
        ) then 'pro'
        else 'free'
    end;
$$;

create or replace function public.get_miloom_access_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
    v_entitlement public.user_entitlements%rowtype;
    v_usage public.usage_buckets%rowtype;
begin
    if v_user is null then
        raise exception 'Authentication required';
    end if;

    select * into v_entitlement from public.user_entitlements where user_id = v_user;
    select * into v_usage
      from public.usage_buckets
     where user_id = v_user
       and period_start = date_trunc('month', now())::date;

    return jsonb_build_object(
        'tier', public.miloom_effective_tier(v_user),
        'status', coalesce(v_entitlement.status, 'expired'),
        'product_id', v_entitlement.product_id,
        'trial_ends_at', v_entitlement.trial_ends_at,
        'renews_at', v_entitlement.renews_at,
        'grace_ends_at', v_entitlement.grace_ends_at,
        'selected_free_company_id', v_entitlement.selected_free_company_id,
        'selected_free_plaid_item_id', v_entitlement.selected_free_plaid_item_id,
        'ai_actions', coalesce(v_usage.ai_actions, 0),
        'voice_seconds', coalesce(v_usage.voice_seconds, 0),
        'limits', case when public.miloom_effective_tier(v_user) = 'pro'
            then jsonb_build_object('companies', -1, 'plaid_items', 10, 'guests', 3, 'documents', 500, 'ai_actions', 300, 'voice_seconds', 3600)
            else jsonb_build_object('companies', 1, 'plaid_items', 1, 'guests', 0, 'documents', 20, 'ai_actions', 5, 'voice_seconds', 300)
        end
    );
end;
$$;

create or replace function public.consume_miloom_usage(p_kind text, p_amount integer default 1)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user uuid := auth.uid();
    v_tier text;
    v_limit integer;
    v_used integer;
    v_period date := date_trunc('month', now())::date;
begin
    if v_user is null or p_amount <= 0 then
        raise exception 'Invalid usage request';
    end if;
    if p_kind not in ('ai_actions', 'voice_seconds') then
        raise exception 'Unsupported usage kind';
    end if;

    v_tier := public.miloom_effective_tier(v_user);
    v_limit := case
        when p_kind = 'ai_actions' and v_tier = 'pro' then 300
        when p_kind = 'ai_actions' then 5
        when p_kind = 'voice_seconds' and v_tier = 'pro' then 3600
        else 300
    end;

    insert into public.usage_buckets(user_id, period_start)
    values (v_user, v_period)
    on conflict (user_id, period_start) do nothing;

    execute format('select %I from public.usage_buckets where user_id = $1 and period_start = $2 for update', p_kind)
       into v_used using v_user, v_period;

    if v_used + p_amount > v_limit then
        return jsonb_build_object('allowed', false, 'used', v_used, 'limit', v_limit);
    end if;

    execute format('update public.usage_buckets set %I = %I + $1, updated_at = now() where user_id = $2 and period_start = $3', p_kind, p_kind)
      using p_amount, v_user, v_period;

    return jsonb_build_object('allowed', true, 'used', v_used + p_amount, 'limit', v_limit);
end;
$$;

create or replace function public.enforce_miloom_company_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.miloom_effective_tier(new.user_id) = 'free'
       and (select count(*) from public.companies where user_id = new.user_id) >= 1 then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:company';
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_miloom_company_limit on public.companies;
create trigger enforce_miloom_company_limit
before insert on public.companies
for each row execute function public.enforce_miloom_company_limit();

create or replace function public.enforce_miloom_document_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_limit integer;
begin
    v_limit := case when public.miloom_effective_tier(new.user_id) = 'pro' then 500 else 20 end;
    if new.url is not null
       and (select count(*) from public.company_documents where user_id = new.user_id and url is not null and id <> new.id) >= v_limit then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:documents';
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_miloom_document_limit on public.company_documents;
create trigger enforce_miloom_document_limit
before insert or update of url on public.company_documents
for each row execute function public.enforce_miloom_document_limit();

grant execute on function public.get_miloom_access_snapshot() to authenticated;
grant execute on function public.consume_miloom_usage(text, integer) to authenticated;
