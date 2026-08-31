-- Preserve Plaid's source identifiers while giving replacement Items a stable,
-- recoverable account mapping. This lets reconnected institutions inherit valid
-- history without rewriting or deleting the original Plaid records.

create table if not exists public.plaid_accounts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    plaid_item_id uuid not null references public.plaid_items(id) on delete cascade,
    account_id text not null,
    persistent_account_id text,
    institution_id uuid references public.institutions(id) on delete set null,
    company_id uuid references public.companies(id) on delete set null,
    name text,
    official_name text,
    mask text,
    account_type text,
    subtype text,
    status text not null default 'active',
    canonical_account_id text,
    canonical_institution_id uuid references public.institutions(id) on delete set null,
    canonical_company_id uuid references public.companies(id) on delete set null,
    match_method text,
    first_seen_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    matched_at timestamptz,
    unique (plaid_item_id, account_id)
);

alter table public.plaid_accounts enable row level security;

drop policy if exists "users_read_own_plaid_accounts" on public.plaid_accounts;
create policy "users_read_own_plaid_accounts"
    on public.plaid_accounts for select
    using (auth.uid() = user_id);

grant select on table public.plaid_accounts to authenticated;
grant all on table public.plaid_accounts to service_role;

create index if not exists idx_plaid_accounts_user_item
    on public.plaid_accounts(user_id, plaid_item_id);

create index if not exists idx_plaid_accounts_persistent
    on public.plaid_accounts(user_id, persistent_account_id)
    where persistent_account_id is not null;

create index if not exists idx_plaid_accounts_mask
    on public.plaid_accounts(user_id, mask)
    where mask is not null;

alter table public.plaid_transactions
    add column if not exists persistent_account_id text,
    add column if not exists canonical_account_id text,
    add column if not exists account_match_method text,
    add column if not exists is_superseded_duplicate boolean not null default false,
    add column if not exists superseded_by_transaction_id uuid
        references public.plaid_transactions(id) on delete set null;

-- Existing transactions on a currently active Item already use the preferred
-- account ID. Archived Items are filled only after a high-confidence match.
update public.plaid_transactions transaction
   set canonical_account_id = transaction.account_id,
       account_match_method = coalesce(transaction.account_match_method, 'source')
  from public.plaid_items item
 where item.id = transaction.plaid_item_id
   and item.status = 'active'
   and transaction.canonical_account_id is null;

create index if not exists idx_plaid_transactions_canonical_account
    on public.plaid_transactions(user_id, canonical_account_id, date desc)
    where canonical_account_id is not null and not is_superseded_duplicate;

create index if not exists idx_plaid_transactions_visible
    on public.plaid_transactions(user_id, date desc)
    where not is_superseded_duplicate;

-- Deduplicate only across Item generations. Repeated same-value purchases inside
-- one Item retain their occurrence order, so two legitimate identical charges
-- are not collapsed into one.
create or replace function public.reconcile_plaid_transaction_duplicates(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    affected integer := 0;
begin
    if p_user_id is null then
        raise exception 'p_user_id is required';
    end if;

    update public.plaid_transactions
       set is_superseded_duplicate = false,
           superseded_by_transaction_id = null
     where user_id = p_user_id
       and canonical_account_id is not null;

    with occurrences as (
        select transaction.id,
               transaction.user_id,
               transaction.canonical_account_id,
               transaction.date,
               round(coalesce(transaction.amount, 0)::numeric, 2) as amount_key,
               coalesce(transaction.currency, 'USD') as currency_key,
               regexp_replace(
                   lower(coalesce(nullif(transaction.merchant_name, ''), nullif(transaction.name, ''), 'unknown')),
                   '[^a-z0-9]+',
                   '',
                   'g'
               ) as merchant_key,
               row_number() over (
                   partition by transaction.plaid_item_id,
                                transaction.canonical_account_id,
                                transaction.date,
                                round(coalesce(transaction.amount, 0)::numeric, 2),
                                coalesce(transaction.currency, 'USD'),
                                regexp_replace(
                                    lower(coalesce(nullif(transaction.merchant_name, ''), nullif(transaction.name, ''), 'unknown')),
                                    '[^a-z0-9]+',
                                    '',
                                    'g'
                                )
                   order by transaction.created_at, transaction.id
               ) as occurrence,
               case when item.status = 'active' then 0 else 1 end as status_priority,
               item.created_at as item_created_at,
               transaction.created_at as transaction_created_at
          from public.plaid_transactions transaction
          join public.plaid_items item on item.id = transaction.plaid_item_id
         where transaction.user_id = p_user_id
           and transaction.canonical_account_id is not null
           and item.status in ('active', 'archived')
    ), ranked as (
        select occurrences.*,
               first_value(id) over (
                   partition by user_id,
                                canonical_account_id,
                                date,
                                amount_key,
                                currency_key,
                                merchant_key,
                                occurrence
                   order by status_priority,
                            item_created_at desc,
                            transaction_created_at desc,
                            id
               ) as winner_id,
               row_number() over (
                   partition by user_id,
                                canonical_account_id,
                                date,
                                amount_key,
                                currency_key,
                                merchant_key,
                                occurrence
                   order by status_priority,
                            item_created_at desc,
                            transaction_created_at desc,
                            id
               ) as preference
          from occurrences
    )
    update public.plaid_transactions transaction
       set is_superseded_duplicate = true,
           superseded_by_transaction_id = ranked.winner_id
      from ranked
     where transaction.id = ranked.id
       and ranked.preference > 1
       and ranked.winner_id <> ranked.id;

    get diagnostics affected = row_count;
    return affected;
end;
$$;

revoke all on function public.reconcile_plaid_transaction_duplicates(uuid)
    from public, anon, authenticated;
grant execute on function public.reconcile_plaid_transaction_duplicates(uuid)
    to service_role;

comment on table public.plaid_accounts is
    'Recoverable Plaid account identity snapshots used to reconcile replacement Items.';

comment on column public.plaid_transactions.canonical_account_id is
    'Current app-facing Plaid account ID; account_id remains the immutable source ID.';

comment on column public.plaid_transactions.is_superseded_duplicate is
    'True when the same logical transaction exists on a preferred replacement Item.';
