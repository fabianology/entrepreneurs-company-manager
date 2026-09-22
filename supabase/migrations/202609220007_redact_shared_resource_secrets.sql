-- Add caller-checked, owner-complete and collaborator-redacted read functions.
-- This additive migration does not revoke legacy table reads. Deploy the
-- compatible app before the separate grant-lockdown migration 008.

begin;

create or replace function public.miloom_can_read_resource(
    p_resource_type text,
    p_resource_id uuid,
    p_company_id uuid,
    p_owner_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select p_owner_user_id = (select auth.uid())
        or exists (
            select 1
              from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.suspended_at is null
               and (
                    (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                    or (rs.resource_type = 'company' and rs.resource_id = p_company_id)
                    or (
                        rs.resource_id = p_company_id
                        and rs.resource_type = case lower(p_resource_type)
                            when 'subscription' then 'all_subscriptions'
                            when 'institution' then 'all_financials'
                            when 'card' then 'all_financials'
                            else '__none__'
                        end
                    )
               )
        );
$$;

revoke all on function public.miloom_can_read_resource(text, uuid, uuid, uuid) from public, anon;
grant execute on function public.miloom_can_read_resource(text, uuid, uuid, uuid) to authenticated;

create or replace function public.miloom_redact_institution_accounts(p_accounts jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
    select coalesce(
        jsonb_agg(
            account
                - 'accountNumber' - 'routingNumber' - 'wireRoutingNumber'
                - 'account_number' - 'routing_number' - 'wire_routing_number'
            order by position
        ),
        '[]'::jsonb
    )
      from jsonb_array_elements(
          case when jsonb_typeof(p_accounts) = 'array' then p_accounts else '[]'::jsonb end
      ) with ordinality as account_row(account, position);
$$;

revoke all on function public.miloom_redact_institution_accounts(jsonb) from public, anon;
grant execute on function public.miloom_redact_institution_accounts(jsonb) to authenticated;

create or replace function public.miloom_visible_subscriptions()
returns setof public.subscriptions
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_record public.subscriptions%rowtype;
begin
    if v_actor is null then return; end if;
    for v_record in
        select s.*
          from public.subscriptions s
         where public.miloom_can_read_resource('subscription', s.id, s.company_id, s.user_id)
    loop
        if v_record.user_id <> v_actor then
            v_record.login_id := null;
            v_record.password := null;
            v_record.two_factor_auth := 'None';
            v_record.recovery_method := null;
        end if;
        return next v_record;
    end loop;
end;
$$;

create or replace function public.miloom_visible_financial_cards()
returns setof public.financial_cards
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_record public.financial_cards%rowtype;
begin
    if v_actor is null then return; end if;
    for v_record in
        select c.*
          from public.financial_cards c
         where public.miloom_can_read_resource('card', c.id, c.company_id, c.user_id)
    loop
        if v_record.user_id <> v_actor then
            v_record.login := null;
            v_record.password := null;
            v_record.card_number := null;
            v_record.expiry := null;
        end if;
        return next v_record;
    end loop;
end;
$$;

create or replace function public.miloom_visible_institutions()
returns setof public.institutions
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_record public.institutions%rowtype;
begin
    if v_actor is null then return; end if;
    for v_record in
        select i.*
          from public.institutions i
         where public.miloom_can_read_resource('institution', i.id, i.company_id, i.user_id)
    loop
        if v_record.user_id <> v_actor then
            v_record.login_url := null;
            v_record.username := null;
            v_record.email := null;
            v_record.password := null;
            v_record.two_factor := null;
            v_record.accounts_data := public.miloom_redact_institution_accounts(v_record.accounts_data);
        end if;
        return next v_record;
    end loop;
end;
$$;

revoke all on function public.miloom_visible_subscriptions() from public, anon;
revoke all on function public.miloom_visible_financial_cards() from public, anon;
revoke all on function public.miloom_visible_institutions() from public, anon;
grant execute on function public.miloom_visible_subscriptions() to authenticated;
grant execute on function public.miloom_visible_financial_cards() to authenticated;
grant execute on function public.miloom_visible_institutions() to authenticated;

-- Migration 006 preserved the bank credential fields on Editor writes but
-- missed the login URL. A redacted Editor record must not clear that URL.
create or replace function public.miloom_guard_shared_institution_secrets()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'UPDATE' and (select auth.uid()) is distinct from old.user_id then
        new.user_id := old.user_id;
        new.company_id := old.company_id;
        new.login_url := old.login_url;
        new.username := old.username;
        new.email := old.email;
        new.password := old.password;
        new.two_factor := old.two_factor;
        new.accounts_data := old.accounts_data;
    elsif tg_op = 'INSERT' and (select auth.uid()) is distinct from new.user_id then
        new.login_url := null;
        new.username := null;
        new.email := null;
        new.password := null;
        new.two_factor := null;
        new.accounts_data := '[]';
    end if;
    return new;
end;
$$;

notify pgrst, 'reload schema';

commit;
