-- Run after delegated_scope_fixture.sql and migrations 009–011.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_admin uuid := '00000000-0000-0000-0000-000000000002';
    v_viewer uuid := '00000000-0000-0000-0000-000000000003';
    v_company_a uuid := '10000000-0000-0000-0000-000000000001';
    v_company_b uuid := '10000000-0000-0000-0000-000000000002';
    v_bank_a uuid := '30000000-0000-0000-0000-000000000001';
    v_bank_b uuid := '30000000-0000-0000-0000-000000000002';
    v_service uuid := '20000000-0000-0000-0000-000000000001';
    v_access_id uuid;
    v_invitation_id uuid;
    v_result jsonb;
begin
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform public.miloom_share_resource('editor@example.com', 'Admin', v_company_a, 'company');
    perform public.miloom_share_resource('viewer@example.com', 'Viewer', v_company_b, 'company');

    perform set_config('request.jwt.claim.sub', v_admin::text, true);
    if (select count(*) from public.miloom_admin_list_entity_access(v_company_a)) <> 1 then
        raise exception 'Admin did not see its entity access';
    end if;
    begin
        perform public.miloom_admin_list_entity_access(v_company_b);
        raise exception 'Admin listed another entity';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_admin_share_viewer('viewer@example.com', v_bank_b, 'institution');
        raise exception 'Admin shared another entity';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_admin_share_viewer('owner@example.com', v_bank_a, 'institution');
        raise exception 'Admin shared to owner';
    exception when invalid_parameter_value then null;
    end;
    begin
        perform public.miloom_admin_share_viewer('editor@example.com', v_bank_a, 'institution');
        raise exception 'Admin shared to itself';
    exception when invalid_parameter_value then null;
    end;

    v_result := public.miloom_admin_share_viewer('viewer@example.com', v_bank_a, 'institution');
    if v_result ->> 'status' <> 'shared_directly' then
        raise exception 'Admin Viewer direct share failed';
    end if;
    select id into v_access_id from public.resource_shares
     where user_id = v_viewer and resource_id = v_bank_a and role = 'Viewer';
    if v_access_id is null then raise exception 'Viewer share missing'; end if;
    begin
        perform public.miloom_revoke_access(v_access_id, 'direct', 'person');
        raise exception 'Admin called Owner global block';
    exception when SQLSTATE 'P0002' then null;
    end;
    if (select count(*) from public.resource_access_blocks) <> 0 then
        raise exception 'Admin created a global block';
    end if;

    v_result := public.miloom_admin_revoke_viewer(v_access_id, 'direct');
    if (v_result ->> 'removed')::integer <> 1 then
        raise exception 'Admin did not remove exactly one Viewer share';
    end if;
    if exists (select 1 from public.resource_shares
                where user_id = v_viewer and resource_id = v_bank_a)
       or not exists (select 1 from public.resource_shares
                       where user_id = v_viewer and resource_id = v_company_b) then
        raise exception 'resource revoke affected independent entity';
    end if;

    v_result := public.miloom_admin_share_viewer('new@example.com', v_bank_a, 'institution');
    if v_result ->> 'status' <> 'invitation_created' then
        raise exception 'Admin Viewer pending invitation failed';
    end if;
    v_invitation_id := (v_result ->> 'invitation_id')::uuid;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    if not exists (select 1 from public.miloom_list_managed_access()
                    where access_id = v_invitation_id and role = 'Viewer') then
        raise exception 'Owner cannot see Admin-created invitation';
    end if;
    perform public.miloom_revoke_access(v_invitation_id, 'invitation', 'resource');
    if exists (select 1 from public.resource_invitations where id = v_invitation_id) then
        raise exception 'Owner cannot revoke Admin-created invitation';
    end if;

    perform public.miloom_share_resource('viewer@example.com', 'Editor', v_service, 'subscription');
    perform set_config('request.jwt.claim.sub', v_admin::text, true);
    begin
        perform public.miloom_admin_share_viewer('viewer@example.com', v_bank_a, 'institution');
        raise exception 'Admin overrode a higher-role collaborator';
    exception when insufficient_privilege then null;
    end;
    select id into v_access_id from public.resource_shares
     where user_id = v_viewer and resource_id = v_service and role = 'Editor';
    begin
        perform public.miloom_admin_revoke_viewer(v_access_id, 'direct');
        raise exception 'Admin revoked an Editor';
    exception when insufficient_privilege then null;
    end;
    if not exists (select 1 from public.resource_shares where id = v_access_id) then
        raise exception 'Editor share changed';
    end if;

    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    insert into public.resource_access_blocks (owner_user_id, blocked_email, blocked_user_id)
    values (v_owner, 'blocked@example.com', null);
    perform set_config('request.jwt.claim.sub', v_admin::text, true);
    begin
        perform public.miloom_admin_share_viewer('blocked@example.com', v_bank_a, 'institution');
        raise exception 'Admin bypassed owner block';
    exception when insufficient_privilege then null;
    end;

    update public.resource_shares set suspended_at = now()
     where user_id = v_admin and resource_id = v_company_a and role = 'Admin';
    begin
        perform public.miloom_admin_share_viewer('new@example.com', v_bank_a, 'institution');
        raise exception 'Suspended Admin granted access';
    exception when insufficient_privilege then null;
    end;
end;
$$;
