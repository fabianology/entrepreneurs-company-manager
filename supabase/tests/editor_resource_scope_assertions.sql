-- Disposable DB only, after current migrations and editor scope guard.
-- Harness seeds one legacy company Editor and pending invitation BEFORE guard.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_viewer uuid := '00000000-0000-0000-0000-000000000003';
    v_company uuid := '10000000-0000-0000-0000-000000000001';
    v_type text;
    v_id uuid;
begin
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    begin
        perform public.miloom_share_resource('editor@example.com','Editor',v_company,'company');
        raise exception 'New direct company Editor accepted';
    exception when invalid_parameter_value then null;
    end;
    begin
        perform public.miloom_share_resource('new-scope@example.com','Editor',v_company,'company');
        raise exception 'New pending company Editor invitation accepted';
    exception when invalid_parameter_value then null;
    end;
    if exists(select 1 from public.resource_shares where user_id=v_editor and resource_type='company' and role='Editor')
       or exists(select 1 from public.resource_invitations where email='new-scope@example.com') then
        raise exception 'Rejected grants left authorization rows';
    end if;
    foreach v_type in array array['all_institutions','all_financials','all_subscriptions','all_documents',
        'institution','card','loan','subscription','document'] loop
        v_id := case v_type
            when 'institution' then '30000000-0000-0000-0000-000000000001'::uuid
            when 'card' then '40000000-0000-0000-0000-000000000001'::uuid
            when 'loan' then '50000000-0000-0000-0000-000000000001'::uuid
            when 'subscription' then '20000000-0000-0000-0000-000000000001'::uuid
            when 'document' then '60000000-0000-0000-0000-000000000001'::uuid
            else v_company end;
        if public.miloom_share_resource('editor@example.com','Editor',v_id,v_type)->>'status' <> 'shared_directly' then
            raise exception 'Supported scoped Editor failed: %',v_type;
        end if;
    end loop;
    perform public.miloom_share_resource('editor@example.com','Viewer',v_company,'company');
    begin
        update public.resource_shares set role='Editor' where user_id=v_editor and resource_type='company';
        raise exception 'Existing Viewer elevated to company Editor';
    exception when invalid_parameter_value then null;
    end;
    -- Existing legacy rows are not silently changed by installing the guard.
    if not exists(select 1 from public.resource_shares where user_id=v_viewer and resource_type='company' and role='Editor') then
        raise exception 'Legacy company Editor silently removed';
    end if;
    update public.resource_shares set sender_display_name='Legacy metadata only'
     where user_id=v_viewer and resource_type='company';
    update public.resource_shares set suspended_at=now()
     where user_id=v_viewer and resource_type='company';
    begin
        update public.resource_shares set suspended_at=null where user_id=v_viewer and resource_type='company';
        raise exception 'Legacy company Editor reactivated';
    exception when invalid_parameter_value then null;
    end;
    begin
        update public.resource_invitations set status='Accepted' where email='legacy-scope@example.com';
        raise exception 'Legacy company Editor invitation accepted';
    exception when invalid_parameter_value then null;
    end;
    update public.resource_invitations set status='Revoked' where email='legacy-scope@example.com';
    if has_function_privilege('authenticated','public.miloom_guard_editor_resource_scope()','EXECUTE')
       or has_function_privilege('anon','public.miloom_guard_editor_resource_scope()','EXECUTE') then
        raise exception 'Internal scope trigger function exposed';
    end if;
end;
$$;
