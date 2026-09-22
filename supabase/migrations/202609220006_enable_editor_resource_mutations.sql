-- Give Editor/Admin shares their documented mutation capability while keeping
-- owner-only credential fields immutable to collaborators.

begin;

create or replace function public.miloom_can_edit_resource(
    p_resource_type text,
    p_resource_id uuid,
    p_company_id uuid,
    p_owner_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select
        p_owner_user_id = (select auth.uid())
        or exists (
            select 1
              from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.suspended_at is null
               and rs.role in ('Editor', 'Admin')
               and (
                    (rs.resource_type = 'company' and rs.resource_id = p_company_id)
                    or (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                    or (
                        rs.resource_id = p_company_id
                        and rs.resource_type = case lower(p_resource_type)
                            when 'subscription' then 'all_subscriptions'
                            when 'institution' then 'all_financials'
                            when 'card' then 'all_financials'
                            when 'loan' then 'all_financials'
                            when 'document' then 'all_documents'
                            else '__none__'
                        end
                    )
               )
        );
$$;

revoke all on function public.miloom_can_edit_resource(text, uuid, uuid, uuid) from public, anon;
grant execute on function public.miloom_can_edit_resource(text, uuid, uuid, uuid) to authenticated;

-- Company Editors may update company presentation data, but ownership cannot
-- be transferred through a row update.
create or replace function public.miloom_preserve_shared_company_owner()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if (select auth.uid()) is distinct from old.user_id then
        new.user_id := old.user_id;
    end if;
    return new;
end;
$$;

drop trigger if exists miloom_preserve_shared_company_owner on public.companies;
create trigger miloom_preserve_shared_company_owner
before update on public.companies
for each row execute function public.miloom_preserve_shared_company_owner();

drop policy if exists miloom_company_editor_update on public.companies;
create policy miloom_company_editor_update
on public.companies for update to authenticated
using (public.miloom_can_edit_resource('company', id, id, user_id))
with check (public.miloom_can_edit_resource('company', id, id, user_id));

-- Subscription collaborators can edit business metadata, but never the
-- owner's login, password, 2FA, or recovery data. The same guard also strips
-- credentials from records inserted by collaborators.
create or replace function public.miloom_guard_shared_subscription_secrets()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'UPDATE' and (select auth.uid()) is distinct from old.user_id then
        new.user_id := old.user_id;
        new.company_id := old.company_id;
        new.login_id := old.login_id;
        new.password := old.password;
        new.two_factor_auth := old.two_factor_auth;
        new.recovery_method := old.recovery_method;
    elsif tg_op = 'INSERT' and (select auth.uid()) is distinct from new.user_id then
        new.login_id := null;
        new.password := null;
        new.two_factor_auth := 'None';
        new.recovery_method := null;
    end if;
    return new;
end;
$$;

drop trigger if exists miloom_guard_shared_subscription_secrets on public.subscriptions;
create trigger miloom_guard_shared_subscription_secrets
before insert or update on public.subscriptions
for each row execute function public.miloom_guard_shared_subscription_secrets();

drop policy if exists miloom_subscription_editor_insert on public.subscriptions;
drop policy if exists miloom_subscription_editor_update on public.subscriptions;
drop policy if exists miloom_subscription_editor_delete on public.subscriptions;
create policy miloom_subscription_editor_insert
on public.subscriptions for insert to authenticated
with check (public.miloom_can_edit_resource('subscription', id, company_id, user_id));
create policy miloom_subscription_editor_update
on public.subscriptions for update to authenticated
using (public.miloom_can_edit_resource('subscription', id, company_id, user_id))
with check (public.miloom_can_edit_resource('subscription', id, company_id, user_id));
create policy miloom_subscription_editor_delete
on public.subscriptions for delete to authenticated
using (public.miloom_can_edit_resource('subscription', id, company_id, user_id));

-- Financial card edits preserve all full credential material. Last-four,
-- balances, limits and other shared business metadata remain editable.
create or replace function public.miloom_guard_shared_card_secrets()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'UPDATE' and (select auth.uid()) is distinct from old.user_id then
        new.user_id := old.user_id;
        new.company_id := old.company_id;
        new.login := old.login;
        new.password := old.password;
        new.card_number := old.card_number;
        new.expiry := old.expiry;
    elsif tg_op = 'INSERT' and (select auth.uid()) is distinct from new.user_id then
        new.login := null;
        new.password := null;
        new.card_number := null;
        new.expiry := null;
    end if;
    return new;
end;
$$;

drop trigger if exists miloom_guard_shared_card_secrets on public.financial_cards;
create trigger miloom_guard_shared_card_secrets
before insert or update on public.financial_cards
for each row execute function public.miloom_guard_shared_card_secrets();

drop policy if exists miloom_card_editor_insert on public.financial_cards;
drop policy if exists miloom_card_editor_update on public.financial_cards;
drop policy if exists miloom_card_editor_delete on public.financial_cards;
create policy miloom_card_editor_insert
on public.financial_cards for insert to authenticated
with check (public.miloom_can_edit_resource('card', id, company_id, user_id));
create policy miloom_card_editor_update
on public.financial_cards for update to authenticated
using (public.miloom_can_edit_resource('card', id, company_id, user_id))
with check (public.miloom_can_edit_resource('card', id, company_id, user_id));
create policy miloom_card_editor_delete
on public.financial_cards for delete to authenticated
using (public.miloom_can_edit_resource('card', id, company_id, user_id));

-- Bank login details and the account payload (which contains account/routing
-- numbers) are owner-only. Editors may still change safe institution metadata.
create or replace function public.miloom_guard_shared_institution_secrets()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'UPDATE' and (select auth.uid()) is distinct from old.user_id then
        new.user_id := old.user_id;
        new.company_id := old.company_id;
        new.username := old.username;
        new.email := old.email;
        new.password := old.password;
        new.two_factor := old.two_factor;
        new.accounts_data := old.accounts_data;
    elsif tg_op = 'INSERT' and (select auth.uid()) is distinct from new.user_id then
        new.username := null;
        new.email := null;
        new.password := null;
        new.two_factor := null;
        new.accounts_data := '[]';
    end if;
    return new;
end;
$$;

drop trigger if exists miloom_guard_shared_institution_secrets on public.institutions;
create trigger miloom_guard_shared_institution_secrets
before insert or update on public.institutions
for each row execute function public.miloom_guard_shared_institution_secrets();

drop policy if exists miloom_institution_editor_insert on public.institutions;
drop policy if exists miloom_institution_editor_update on public.institutions;
drop policy if exists miloom_institution_editor_delete on public.institutions;
create policy miloom_institution_editor_insert
on public.institutions for insert to authenticated
with check (public.miloom_can_edit_resource('institution', id, company_id, user_id));
create policy miloom_institution_editor_update
on public.institutions for update to authenticated
using (public.miloom_can_edit_resource('institution', id, company_id, user_id))
with check (public.miloom_can_edit_resource('institution', id, company_id, user_id));
create policy miloom_institution_editor_delete
on public.institutions for delete to authenticated
using (public.miloom_can_edit_resource('institution', id, company_id, user_id));

drop policy if exists miloom_loan_editor_insert on public.loans;
drop policy if exists miloom_loan_editor_update on public.loans;
drop policy if exists miloom_loan_editor_delete on public.loans;
create policy miloom_loan_editor_insert
on public.loans for insert to authenticated
with check (public.miloom_can_edit_resource('loan', id, company_id, user_id));
create policy miloom_loan_editor_update
on public.loans for update to authenticated
using (public.miloom_can_edit_resource('loan', id, company_id, user_id))
with check (public.miloom_can_edit_resource('loan', id, company_id, user_id));
create policy miloom_loan_editor_delete
on public.loans for delete to authenticated
using (public.miloom_can_edit_resource('loan', id, company_id, user_id));

drop policy if exists miloom_document_editor_insert on public.company_documents;
drop policy if exists miloom_document_editor_update on public.company_documents;
drop policy if exists miloom_document_editor_delete on public.company_documents;
create policy miloom_document_editor_insert
on public.company_documents for insert to authenticated
with check (public.miloom_can_edit_resource('document', id, company_id, user_id));
create policy miloom_document_editor_update
on public.company_documents for update to authenticated
using (public.miloom_can_edit_resource('document', id, company_id, user_id))
with check (public.miloom_can_edit_resource('document', id, company_id, user_id));
create policy miloom_document_editor_delete
on public.company_documents for delete to authenticated
using (public.miloom_can_edit_resource('document', id, company_id, user_id));

notify pgrst, 'reload schema';

commit;
