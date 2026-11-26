-- Qualify resource_id: the RETURNS TABLE output parameter has the same name.
-- Preserve owner/device/consent checks and the existing EXECUTE privileges.
begin;

create or replace function public.miloom_list_admin_credential_resources(
    p_grant_id uuid, p_actor_device_id uuid, p_key_confirmation text
)
returns table (resource_type text, resource_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_grant public.admin_credential_devices%rowtype; v_company uuid;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    v_grant := public.miloom_require_admin_credential_device(p_grant_id);
    select rs.resource_id into v_company from public.resource_shares rs where rs.id = v_grant.share_id;
    return query select 'subscription'::text, s.id from public.subscriptions s where s.company_id = v_company and s.user_id = auth.uid()
        union all select 'card', c.id from public.financial_cards c where c.company_id = v_company and c.user_id = auth.uid()
        union all select 'institution', i.id from public.institutions i where i.company_id = v_company and i.user_id = auth.uid();
end;
$$;

notify pgrst, 'reload schema';
commit;
