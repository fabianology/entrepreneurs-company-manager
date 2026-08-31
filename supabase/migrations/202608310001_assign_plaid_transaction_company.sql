-- Allow an authenticated owner to correct only the company assignment on one
-- of their Plaid transactions. Keep the privileged implementation outside the
-- exposed public schema and expose a narrow security-invoker wrapper for RPC.

create schema if not exists private;

create or replace function private.assign_plaid_transaction_company(
    p_transaction_id uuid,
    p_company_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := (select auth.uid());
begin
    if v_user_id is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;

    if not exists (
        select 1
          from public.companies c
         where c.id = p_company_id
           and c.user_id = v_user_id
    ) then
        raise exception 'Company is not owned by the authenticated user' using errcode = '42501';
    end if;

    update public.plaid_transactions t
       set company_id = p_company_id
     where t.id = p_transaction_id
       and t.user_id = v_user_id;

    if not found then
        raise exception 'Plaid transaction was not found for the authenticated user' using errcode = 'P0002';
    end if;
end;
$$;

revoke all on function private.assign_plaid_transaction_company(uuid, uuid) from public;
revoke all on function private.assign_plaid_transaction_company(uuid, uuid) from anon;
grant usage on schema private to authenticated;
grant execute on function private.assign_plaid_transaction_company(uuid, uuid) to authenticated;

create or replace function public.assign_plaid_transaction_company(
    p_transaction_id uuid,
    p_company_id uuid
)
returns void
language sql
security invoker
set search_path = ''
as $$
    select private.assign_plaid_transaction_company(p_transaction_id, p_company_id);
$$;

revoke all on function public.assign_plaid_transaction_company(uuid, uuid) from public;
revoke all on function public.assign_plaid_transaction_company(uuid, uuid) from anon;
grant execute on function public.assign_plaid_transaction_company(uuid, uuid) to authenticated;

comment on function public.assign_plaid_transaction_company(uuid, uuid) is
    'Assigns one caller-owned Plaid transaction to one caller-owned company without exposing other transaction fields.';
