-- Allow reversible exclusions from personal transaction analysis.
-- Original Plaid transactions and bank-reported balances remain unchanged.
begin;

alter table public.plaid_transaction_overrides
    drop constraint if exists plaid_transaction_overrides_flow_override_check;

alter table public.plaid_transaction_overrides
    add constraint plaid_transaction_overrides_flow_override_check
    check (
        flow_override is null
        or flow_override in ('expense', 'income', 'transfer', 'refund', 'ignored')
    );

commit;
