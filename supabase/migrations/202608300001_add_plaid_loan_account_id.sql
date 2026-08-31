-- Preserve the Plaid account identifier for imported loans so recurring syncs
-- can update balances and liability terms without relying on names or masks.

alter table public.loans
    add column if not exists plaid_account_id text;

create index if not exists idx_loans_plaid_account_id
    on public.loans(plaid_account_id)
    where plaid_account_id is not null;
