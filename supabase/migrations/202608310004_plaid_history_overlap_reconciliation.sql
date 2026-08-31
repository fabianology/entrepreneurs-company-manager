-- Archived Plaid access tokens can stop returning account metadata after a
-- reconnect. Recover those generations from exact transaction overlap with
-- the current Item, while retaining conservative ambiguity checks.

-- Seed current account identity from the app's existing Plaid-backed account
-- records so the repair can run immediately after this migration. Nightly sync
-- subsequently refreshes these rows from Plaid's Accounts response.
insert into public.plaid_accounts (
    user_id,
    plaid_item_id,
    account_id,
    persistent_account_id,
    institution_id,
    company_id,
    name,
    mask,
    account_type,
    status,
    canonical_account_id,
    canonical_institution_id,
    canonical_company_id,
    match_method,
    matched_at,
    last_seen_at
)
select item.user_id,
       item.id,
       coalesce(account.value->>'plaid_account_id', account.value->>'id'),
       nullif(account.value->>'persistentAccountId', ''),
       item.institution_id,
       item.company_id,
       nullif(account.value->>'name', ''),
       nullif(account.value->>'last4', ''),
       nullif(account.value->>'type', ''),
       'active',
       coalesce(account.value->>'plaid_account_id', account.value->>'id'),
       item.institution_id,
       item.company_id,
       'source',
       now(),
       now()
  from public.plaid_items item
  join public.institutions institution on institution.id = item.institution_id
  cross join lateral jsonb_array_elements(
      coalesce(institution.accounts_data::jsonb, '[]'::jsonb)
  ) account(value)
 where item.status = 'active'
   and coalesce(account.value->>'plaid_account_id', account.value->>'id') is not null
on conflict (plaid_item_id, account_id) do update
    set persistent_account_id = coalesce(excluded.persistent_account_id, public.plaid_accounts.persistent_account_id),
        institution_id = excluded.institution_id,
        company_id = excluded.company_id,
        name = coalesce(excluded.name, public.plaid_accounts.name),
        mask = coalesce(excluded.mask, public.plaid_accounts.mask),
        account_type = coalesce(excluded.account_type, public.plaid_accounts.account_type),
        status = 'active',
        canonical_account_id = excluded.canonical_account_id,
        canonical_institution_id = excluded.canonical_institution_id,
        canonical_company_id = excluded.canonical_company_id,
        match_method = 'source',
        matched_at = now(),
        last_seen_at = now();

-- Credit accounts live in financial_cards rather than accounts_data. Seed the
-- same identity map so a reconnected single-card institution can inherit its
-- preserved history even when the new Item has not returned transactions yet.
insert into public.plaid_accounts (
    user_id,
    plaid_item_id,
    account_id,
    institution_id,
    company_id,
    name,
    mask,
    account_type,
    status,
    canonical_account_id,
    canonical_institution_id,
    canonical_company_id,
    match_method,
    matched_at,
    last_seen_at
)
select item.user_id,
       item.id,
       card.plaid_account_id,
       item.institution_id,
       item.company_id,
       nullif(card.name, ''),
       nullif(card.last4, ''),
       'credit',
       'active',
       card.plaid_account_id,
       item.institution_id,
       item.company_id,
       'source',
       now(),
       now()
  from public.plaid_items item
  join public.financial_cards card
    on card.user_id = item.user_id
   and card.company_id = item.company_id
   and lower(card.institution_name) = lower(item.institution_name)
 where item.status = 'active'
   and card.plaid_account_id is not null
on conflict (plaid_item_id, account_id) do update
    set institution_id = excluded.institution_id,
        company_id = excluded.company_id,
        name = coalesce(excluded.name, public.plaid_accounts.name),
        mask = coalesce(excluded.mask, public.plaid_accounts.mask),
        account_type = 'credit',
        status = 'active',
        canonical_account_id = excluded.canonical_account_id,
        canonical_institution_id = excluded.canonical_institution_id,
        canonical_company_id = excluded.canonical_company_id,
        match_method = 'source',
        matched_at = now(),
        last_seen_at = now();

create or replace function public.reconcile_plaid_history_by_overlap(
    p_user_id uuid,
    p_current_item_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    current_item record;
    account_match record;
    matched_accounts integer := 0;
begin
    select item.id,
           item.institution_id,
           item.company_id,
           item.plaid_institution_id
      into current_item
      from public.plaid_items item
     where item.id = p_current_item_id
       and item.user_id = p_user_id
       and item.status = 'active';

    if current_item.id is null then
        raise exception 'Active Plaid Item was not found';
    end if;

    for account_match in
        with current_accounts as (
            select account.account_id
              from public.plaid_accounts account
             where account.user_id = p_user_id
               and account.plaid_item_id = p_current_item_id
               and account.status = 'active'
        ), archived_items as (
            select item.id
              from public.plaid_items item
             where item.user_id = p_user_id
               and item.company_id = current_item.company_id
               and item.plaid_institution_id = current_item.plaid_institution_id
               and item.status = 'archived'
               and item.error_code = 'SUPERSEDED_CONNECTION'
        ), current_occurrences as (
            select transaction.account_id,
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
                       partition by transaction.account_id,
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
                   ) as occurrence
              from public.plaid_transactions transaction
              join current_accounts account on account.account_id = transaction.account_id
             where transaction.user_id = p_user_id
               and transaction.plaid_item_id = p_current_item_id
        ), archived_occurrences as (
            select transaction.plaid_item_id,
                   transaction.account_id,
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
                                    transaction.account_id,
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
                   ) as occurrence
              from public.plaid_transactions transaction
              join archived_items item on item.id = transaction.plaid_item_id
             where transaction.user_id = p_user_id
        ), overlap_counts as (
            select archived.plaid_item_id,
                   archived.account_id as archived_account_id,
                   current.account_id as current_account_id,
                   count(*) as overlap_count
              from archived_occurrences archived
              join current_occurrences current
                on current.date = archived.date
               and current.amount_key = archived.amount_key
               and current.currency_key = archived.currency_key
               and current.merchant_key = archived.merchant_key
               and current.occurrence = archived.occurrence
             group by archived.plaid_item_id,
                      archived.account_id,
                      current.account_id
        ), ranked_overlap as (
            select overlap.*,
                   row_number() over (
                       partition by overlap.plaid_item_id, overlap.archived_account_id
                       order by overlap.overlap_count desc, overlap.current_account_id
                   ) as match_rank,
                   lead(overlap.overlap_count, 1, 0) over (
                       partition by overlap.plaid_item_id, overlap.archived_account_id
                       order by overlap.overlap_count desc, overlap.current_account_id
                   ) as runner_up_count
              from overlap_counts overlap
        ), overlap_matches as (
            select overlap.plaid_item_id,
                   overlap.archived_account_id,
                   overlap.current_account_id,
                   'transaction_overlap'::text as match_method,
                   1 as match_priority
              from ranked_overlap overlap
             where overlap.match_rank = 1
               and overlap.overlap_count >= 2
               and overlap.overlap_count > overlap.runner_up_count
        ), singleton_matches as (
            select archived.plaid_item_id,
                   archived.account_id as archived_account_id,
                   current.account_id as current_account_id,
                   'singleton_account'::text as match_method,
                   2 as match_priority
              from (
                  select transaction.plaid_item_id,
                         min(transaction.account_id) as account_id
                    from public.plaid_transactions transaction
                    join archived_items item on item.id = transaction.plaid_item_id
                   where transaction.user_id = p_user_id
                   group by transaction.plaid_item_id
                  having count(distinct transaction.account_id) = 1
              ) archived
              cross join (
                  select min(account_id) as account_id
                    from current_accounts
                  having count(*) = 1
              ) current
        ), candidates as (
            select * from overlap_matches
            union all
            select * from singleton_matches
        )
        select distinct on (candidate.plaid_item_id, candidate.archived_account_id)
               candidate.plaid_item_id,
               candidate.archived_account_id,
               candidate.current_account_id,
               candidate.match_method
          from candidates candidate
         order by candidate.plaid_item_id,
                  candidate.archived_account_id,
                  candidate.match_priority
    loop
        insert into public.plaid_accounts (
            user_id,
            plaid_item_id,
            account_id,
            company_id,
            status,
            canonical_account_id,
            canonical_institution_id,
            canonical_company_id,
            match_method,
            matched_at,
            last_seen_at
        ) values (
            p_user_id,
            account_match.plaid_item_id,
            account_match.archived_account_id,
            current_item.company_id,
            'archived',
            account_match.current_account_id,
            current_item.institution_id,
            current_item.company_id,
            account_match.match_method,
            now(),
            now()
        )
        on conflict (plaid_item_id, account_id) do update
            set canonical_account_id = excluded.canonical_account_id,
                canonical_institution_id = excluded.canonical_institution_id,
                canonical_company_id = excluded.canonical_company_id,
                match_method = excluded.match_method,
                matched_at = excluded.matched_at,
                last_seen_at = excluded.last_seen_at;

        update public.plaid_transactions transaction
           set canonical_account_id = account_match.current_account_id,
               account_match_method = account_match.match_method,
               institution_id = current_item.institution_id,
               company_id = current_item.company_id,
               is_superseded_duplicate = false,
               superseded_by_transaction_id = null
         where transaction.user_id = p_user_id
           and transaction.plaid_item_id = account_match.plaid_item_id
           and transaction.account_id = account_match.archived_account_id;

        matched_accounts := matched_accounts + 1;
    end loop;

    return matched_accounts;
end;
$$;

revoke all on function public.reconcile_plaid_history_by_overlap(uuid, uuid)
    from public, anon, authenticated;
grant execute on function public.reconcile_plaid_history_by_overlap(uuid, uuid)
    to service_role;

comment on function public.reconcile_plaid_history_by_overlap(uuid, uuid) is
    'Maps superseded Plaid account history to a current Item using unique exact transaction overlap or a single-account fallback.';
