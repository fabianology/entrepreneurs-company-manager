create table if not exists public.plaid_transaction_category_rules (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    scope_key text not null check (length(trim(scope_key)) > 0),
    merchant_key text not null check (length(trim(merchant_key)) > 0),
    merchant_name text not null check (length(trim(merchant_name)) > 0),
    category_primary text not null check (length(trim(category_primary)) > 0),
    category_detailed text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, scope_key, merchant_key)
);

alter table public.plaid_transaction_category_rules enable row level security;

drop policy if exists "users_manage_own_plaid_transaction_category_rules"
    on public.plaid_transaction_category_rules;
create policy "users_manage_own_plaid_transaction_category_rules"
    on public.plaid_transaction_category_rules for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

grant select, insert, update, delete
    on table public.plaid_transaction_category_rules to authenticated;
grant all on table public.plaid_transaction_category_rules to service_role;

comment on table public.plaid_transaction_category_rules is
    'User-owned merchant category rules applied after transaction overrides and before Plaid categories.';
comment on column public.plaid_transaction_category_rules.scope_key is
    'Company-scoped key, or unassigned when a transaction has no resolved profile.';
comment on column public.plaid_transaction_category_rules.merchant_key is
    'Normalized Plaid merchant identity used to match future transactions.';
