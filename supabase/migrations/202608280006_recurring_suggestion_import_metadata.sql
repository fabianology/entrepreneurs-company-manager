-- Retain Plaid's merchant website so a detected recurring charge can create a
-- more complete subscription card without requiring manual entry.

alter table public.plaid_transactions
    add column if not exists merchant_website text;
