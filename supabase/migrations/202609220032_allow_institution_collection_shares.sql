-- Align the legacy storage constraint with the already authorized scope in
-- 010/011. This adds only all_institutions, not new roles or inherited access.
begin;
alter table public.resource_shares
    drop constraint if exists resource_shares_resource_type_check;
alter table public.resource_shares
    add constraint resource_shares_resource_type_check check (resource_type in (
        'company', 'all_subscriptions', 'subscription', 'all_documents', 'document',
        'all_financials', 'all_institutions', 'institution', 'card', 'loan'
    ));
commit;
