-- Persist Plaid transaction enrichment used by cash-flow classification,
-- merchant presentation, recurring detection, and user-reviewed corrections.

alter table public.plaid_transactions
    add column if not exists merchant_website text,
    add column if not exists merchant_logo_url text,
    add column if not exists merchant_entity_id text,
    add column if not exists payment_channel text,
    add column if not exists authorized_date date,
    add column if not exists personal_finance_primary text,
    add column if not exists personal_finance_detailed text,
    add column if not exists personal_finance_confidence text,
    add column if not exists transaction_code text,
    add column if not exists location jsonb,
    add column if not exists counterparties jsonb,
    add column if not exists pending_transaction_id text,
    add column if not exists is_stale_pending_duplicate boolean not null default false,
    add column if not exists posted_transaction_id uuid
        references public.plaid_transactions(id) on delete set null;

create index if not exists idx_plaid_transactions_intelligence_visible
    on public.plaid_transactions(user_id, date desc)
    where not is_superseded_duplicate and not is_stale_pending_duplicate;

create index if not exists idx_plaid_transactions_pending_link
    on public.plaid_transactions(user_id, pending_transaction_id)
    where pending_transaction_id is not null;

-- Plaid normally supplies pending_transaction_id on the posted replacement.
-- Older imported rows predate that field, so a conservative fallback suppresses
-- only stale pending rows with exactly one same-account posted match.
create or replace function public.reconcile_plaid_pending_transactions(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    exact_count integer := 0;
    heuristic_count integer := 0;
begin
    if p_user_id is null then
        raise exception 'p_user_id is required';
    end if;

    update public.plaid_transactions
       set is_stale_pending_duplicate = false,
           posted_transaction_id = null
     where user_id = p_user_id
       and not is_superseded_duplicate;

    with exact_matches as (
        select distinct on (pending.id)
               pending.id as pending_id,
               posted.id as posted_id
          from public.plaid_transactions pending
          join public.plaid_transactions posted
            on posted.user_id = pending.user_id
           and posted.pending_transaction_id = pending.plaid_transaction_id
           and not posted.pending
           and not posted.is_superseded_duplicate
         where pending.user_id = p_user_id
           and pending.pending
           and not pending.is_superseded_duplicate
         order by pending.id, posted.date desc, posted.created_at desc
    )
    update public.plaid_transactions pending
       set is_stale_pending_duplicate = true,
           posted_transaction_id = exact.posted_id
      from exact_matches exact
     where pending.id = exact.pending_id;

    get diagnostics exact_count = row_count;

    with candidates as (
        select pending.id as pending_id,
               posted.id as posted_id,
               count(*) over (partition by pending.id) as candidate_count,
               row_number() over (
                   partition by pending.id
                   order by abs(posted.date - pending.date), posted.created_at desc, posted.id
               ) as candidate_rank
          from public.plaid_transactions pending
          join public.plaid_transactions posted
            on posted.user_id = pending.user_id
           and posted.canonical_account_id = pending.canonical_account_id
           and not posted.pending
           and not posted.is_superseded_duplicate
           and posted.date between pending.date and pending.date + 7
           and round(coalesce(posted.amount, 0)::numeric, 2)
               = round(coalesce(pending.amount, 0)::numeric, 2)
           and regexp_replace(
                   lower(coalesce(nullif(posted.merchant_name, ''), nullif(posted.name, ''), 'unknown')),
                   '[^a-z0-9]+', '', 'g'
               ) = regexp_replace(
                   lower(coalesce(nullif(pending.merchant_name, ''), nullif(pending.name, ''), 'unknown')),
                   '[^a-z0-9]+', '', 'g'
               )
         where pending.user_id = p_user_id
           and pending.pending
           and pending.date < current_date - 7
           and pending.canonical_account_id is not null
           and not pending.is_superseded_duplicate
           and not pending.is_stale_pending_duplicate
    ), unique_matches as (
        select pending_id, posted_id
          from candidates
         where candidate_count = 1
           and candidate_rank = 1
    )
    update public.plaid_transactions pending
       set is_stale_pending_duplicate = true,
           posted_transaction_id = matched.posted_id
      from unique_matches matched
     where pending.id = matched.pending_id;

    get diagnostics heuristic_count = row_count;
    return exact_count + heuristic_count;
end;
$$;

revoke all on function public.reconcile_plaid_pending_transactions(uuid)
    from public, anon, authenticated;
grant execute on function public.reconcile_plaid_pending_transactions(uuid)
    to service_role;

create table if not exists public.plaid_transaction_overrides (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    transaction_id uuid not null references public.plaid_transactions(id) on delete cascade,
    merchant_name text,
    category_primary text,
    category_detailed text,
    flow_override text check (
        flow_override is null or flow_override in ('expense', 'income', 'transfer', 'refund')
    ),
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, transaction_id)
);

alter table public.plaid_transaction_overrides enable row level security;

drop policy if exists "users_manage_own_plaid_transaction_overrides"
    on public.plaid_transaction_overrides;
create policy "users_manage_own_plaid_transaction_overrides"
    on public.plaid_transaction_overrides for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

grant select, insert, update, delete
    on table public.plaid_transaction_overrides to authenticated;
grant all on table public.plaid_transaction_overrides to service_role;

comment on table public.plaid_transaction_overrides is
    'User-reviewed merchant, category, and cash-flow corrections for Plaid transactions.';

comment on column public.plaid_transactions.is_stale_pending_duplicate is
    'True when a pending transaction has been replaced by a posted transaction.';
