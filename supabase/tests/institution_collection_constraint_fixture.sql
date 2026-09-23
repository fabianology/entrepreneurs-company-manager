-- Reproduce the hosted legacy constraint; the earlier lightweight fixture
-- omitted it and therefore failed to catch the real all_institutions blocker.
alter table public.resource_shares
    add constraint resource_shares_resource_type_check check (resource_type in (
        'company', 'all_subscriptions', 'subscription', 'all_documents', 'document',
        'all_financials', 'institution', 'card', 'loan'
    ));

-- Reproduce the pre-033 SELECT/UPDATE interaction, not just helper calls.
alter table public.institutions enable row level security;
grant usage on schema auth to authenticated;
grant select (id, user_id, company_id), update (name) on public.institutions to authenticated;
create policy legacy_institution_owner_select on public.institutions
    for select to authenticated using (user_id = auth.uid());
create policy miloom_institution_editor_update on public.institutions
    for update to authenticated
    using (public.miloom_can_edit_resource('institution', id, company_id, user_id))
    with check (public.miloom_can_edit_resource('institution', id, company_id, user_id));
