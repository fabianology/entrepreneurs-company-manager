-- Event-driven Plaid synchronization. A per-Item lease serializes cursor
-- advancement while requested_at ensures a webhook received during a sync is
-- consumed before the worker releases its claim.

alter table public.plaid_items
    add column if not exists webhook_url text,
    add column if not exists webhook_configured_at timestamptz;

create table if not exists public.plaid_sync_state (
    plaid_item_id uuid primary key references public.plaid_items(id) on delete cascade,
    requested_at timestamptz not null default clock_timestamp(),
    claimed_at timestamptz,
    lease_until timestamptz,
    claim_token uuid,
    updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.plaid_webhook_events (
    id uuid primary key default gen_random_uuid(),
    plaid_item_id uuid references public.plaid_items(id) on delete set null,
    plaid_external_item_id text,
    webhook_type text not null,
    webhook_code text not null,
    environment text,
    body_sha256 text not null,
    status text not null default 'received'
        check (status in ('received', 'processing', 'processed', 'coalesced', 'ignored', 'failed')),
    error_code text,
    error_message text,
    received_at timestamptz not null default clock_timestamp(),
    processed_at timestamptz
);

create index if not exists idx_plaid_webhook_events_item_received
    on public.plaid_webhook_events(plaid_item_id, received_at desc);

create index if not exists idx_plaid_webhook_events_status
    on public.plaid_webhook_events(status, received_at desc);

alter table public.plaid_sync_state enable row level security;
alter table public.plaid_webhook_events enable row level security;

revoke all on table public.plaid_sync_state from public, anon, authenticated;
revoke all on table public.plaid_webhook_events from public, anon, authenticated;
grant all on table public.plaid_sync_state to service_role;
grant all on table public.plaid_webhook_events to service_role;

create or replace function public.claim_plaid_item_sync(
    p_plaid_item_id uuid,
    p_lease_seconds integer default 240
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    claimed_token uuid;
begin
    if p_plaid_item_id is null then
        raise exception 'p_plaid_item_id is required';
    end if;

    insert into public.plaid_sync_state(plaid_item_id, requested_at, updated_at)
    values (p_plaid_item_id, clock_timestamp(), clock_timestamp())
    on conflict (plaid_item_id) do update
        set requested_at = clock_timestamp(),
            updated_at = clock_timestamp();

    update public.plaid_sync_state
       set claimed_at = clock_timestamp(),
           lease_until = clock_timestamp() + make_interval(secs => greatest(30, p_lease_seconds)),
           claim_token = gen_random_uuid(),
           updated_at = clock_timestamp()
     where plaid_item_id = p_plaid_item_id
       and (claim_token is null or lease_until is null or lease_until <= clock_timestamp())
    returning claim_token into claimed_token;

    return claimed_token;
end;
$$;

create or replace function public.continue_plaid_item_sync(
    p_plaid_item_id uuid,
    p_claim_token uuid,
    p_lease_seconds integer default 240
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
    state_row public.plaid_sync_state%rowtype;
begin
    select * into state_row
      from public.plaid_sync_state
     where plaid_item_id = p_plaid_item_id
     for update;

    if state_row.claim_token is distinct from p_claim_token then
        return false;
    end if;

    if state_row.requested_at > state_row.claimed_at then
        update public.plaid_sync_state
           set claimed_at = clock_timestamp(),
               lease_until = clock_timestamp() + make_interval(secs => greatest(30, p_lease_seconds)),
               updated_at = clock_timestamp()
         where plaid_item_id = p_plaid_item_id;
        return true;
    end if;

    update public.plaid_sync_state
       set claim_token = null,
           lease_until = null,
           updated_at = clock_timestamp()
     where plaid_item_id = p_plaid_item_id;
    return false;
end;
$$;

create or replace function public.release_plaid_item_sync(
    p_plaid_item_id uuid,
    p_claim_token uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
    update public.plaid_sync_state
       set claim_token = null,
           lease_until = null,
           updated_at = clock_timestamp()
     where plaid_item_id = p_plaid_item_id
       and claim_token = p_claim_token;
$$;

revoke all on function public.claim_plaid_item_sync(uuid, integer)
    from public, anon, authenticated;
revoke all on function public.continue_plaid_item_sync(uuid, uuid, integer)
    from public, anon, authenticated;
revoke all on function public.release_plaid_item_sync(uuid, uuid)
    from public, anon, authenticated;
grant execute on function public.claim_plaid_item_sync(uuid, integer) to service_role;
grant execute on function public.continue_plaid_item_sync(uuid, uuid, integer) to service_role;
grant execute on function public.release_plaid_item_sync(uuid, uuid) to service_role;

comment on table public.plaid_sync_state is
    'Serializes Plaid cursor advancement and coalesces sync requests received while a worker is active.';
comment on table public.plaid_webhook_events is
    'Privacy-minimized audit ledger for signature-verified Plaid webhook delivery and processing.';
