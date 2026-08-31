-- Once an archived Plaid account has been mapped to its replacement, the
-- active Item is authoritative for any exact transaction key that both Items
-- contain. Keep every occurrence from the preferred Item (so legitimate
-- repeated charges survive), and suppress every matching occurrence from
-- older Item generations.

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

    with keyed as (
        select transaction.id,
               transaction.user_id,
               transaction.plaid_item_id,
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
               case when item.status = 'active' then 0 else 1 end as status_priority,
               item.created_at as item_created_at,
               transaction.created_at as transaction_created_at
          from public.plaid_transactions transaction
          join public.plaid_items item on item.id = transaction.plaid_item_id
         where transaction.user_id = p_user_id
           and transaction.canonical_account_id is not null
           and item.status in ('active', 'archived')
    ), preferred_items as (
        select distinct on (
                   keyed.user_id,
                   keyed.canonical_account_id,
                   keyed.date,
                   keyed.amount_key,
                   keyed.currency_key,
                   keyed.merchant_key
               )
               keyed.user_id,
               keyed.canonical_account_id,
               keyed.date,
               keyed.amount_key,
               keyed.currency_key,
               keyed.merchant_key,
               keyed.plaid_item_id,
               keyed.id as winner_id
          from keyed
         order by keyed.user_id,
                  keyed.canonical_account_id,
                  keyed.date,
                  keyed.amount_key,
                  keyed.currency_key,
                  keyed.merchant_key,
                  keyed.status_priority,
                  keyed.item_created_at desc,
                  keyed.transaction_created_at desc,
                  keyed.id
    ), superseded as (
        select keyed.id,
               preferred.winner_id
          from keyed
          join preferred_items preferred
            on preferred.user_id = keyed.user_id
           and preferred.canonical_account_id = keyed.canonical_account_id
           and preferred.date = keyed.date
           and preferred.amount_key = keyed.amount_key
           and preferred.currency_key = keyed.currency_key
           and preferred.merchant_key = keyed.merchant_key
         where keyed.plaid_item_id <> preferred.plaid_item_id
    )
    update public.plaid_transactions transaction
       set is_superseded_duplicate = true,
           superseded_by_transaction_id = superseded.winner_id
      from superseded
     where transaction.id = superseded.id;

    get diagnostics affected = row_count;
    return affected;
end;
$$;

revoke all on function public.reconcile_plaid_transaction_duplicates(uuid)
    from public, anon, authenticated;
grant execute on function public.reconcile_plaid_transaction_duplicates(uuid)
    to service_role;

comment on function public.reconcile_plaid_transaction_duplicates(uuid) is
    'Preserves all occurrences from the preferred Plaid Item and suppresses exact matches from older Item generations.';
