-- Local rehearsal only: match the hosted loan/payment columns and legacy policies.
alter table public.loans
    add column role text default 'Borrower', add column lender text,
    add column principal_amount numeric default 1000, add column remaining_balance numeric default 1000,
    add column interest_type text default 'Percentage', add column interest_rate numeric default 0,
    add column term text default '10 months', add column term_years integer default 0,
    add column term_months integer default 10, add column schedule_frequency text default 'Monthly',
    add column monthly_payment numeric default 100, add column start_date timestamptz default now(),
    add column maturity_date timestamptz, add column paid_off_date timestamptz,
    add column status text default 'Active', add column notes text, add column plaid_account_id text,
    add column next_payment_at timestamptz;
create table public.loan_payments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    loan_id uuid not null references public.loans(id) on delete cascade,
    date timestamptz default now(), amount numeric default 0, source text
);
alter table public.loan_payments enable row level security;
create policy legacy_payment_select on public.loan_payments for select using (auth.uid() = user_id);
create policy legacy_payment_insert on public.loan_payments for insert with check (auth.uid() = user_id);
create policy legacy_payment_update on public.loan_payments for update using (auth.uid() = user_id);
create policy legacy_payment_delete on public.loan_payments for delete using (auth.uid() = user_id);
grant usage on schema auth, public to authenticated, anon;
grant select, insert, update, delete on public.loans, public.loan_payments to authenticated;
