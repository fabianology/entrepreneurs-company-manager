-- Synthetic-only authorization and lifecycle checks after migrations 009-014.
-- The fixture's superuser activates a dummy ciphertext solely to exercise
-- the otherwise unavailable delivery path; this is not an activation rollout.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_viewer uuid := '00000000-0000-0000-0000-000000000003';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_company uuid := '10000000-0000-0000-0000-000000000001';
    v_owner_device uuid := '70000000-0000-0000-0000-000000000003';
    v_editor_device uuid := '70000000-0000-0000-0000-000000000001';
    v_wrapped text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_request uuid;
begin
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_wrapped,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrapped),
        v_owner_device, v_confirmation
    );
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_card, 'card', v_editor, 'Editor'),
           (v_card, 'card', v_viewer, 'Viewer');

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    begin
        perform public.miloom_request_resource_secret_access('card', v_card, v_editor_device);
        raise exception 'Staged ciphertext became requestable';
    exception when insufficient_privilege then null;
    end;

    -- Only the fixture owner (not an app RPC) can simulate future activation.
    update public.resource_secret_versions
       set state = 'active', activated_at = now()
     where resource_type = 'card' and resource_id = v_card;
    if not public.miloom_resource_secret_user_eligible(v_editor, 'card', v_card)
       or public.miloom_resource_secret_user_eligible(v_viewer, 'card', v_card) then
        raise exception 'Editor/Viewer secret-role boundary failed';
    end if;
    begin
        perform public.miloom_request_resource_secret_access('card', v_card, v_owner_device);
        raise exception 'Editor used another user device';
    exception when insufficient_privilege then null;
    end;
    v_request := (public.miloom_request_resource_secret_access(
        'card', v_card, v_editor_device
    ) ->> 'request_id')::uuid;
    if v_request is null or (select count(*) from public.miloom_get_resource_secret_for_device(
        'card', v_card, v_editor_device
    )) <> 0 then
        raise exception 'Request exposed a secret before owner approval';
    end if;

    perform set_config('request.jwt.claim.sub', v_viewer::text, true);
    update public.vault_devices
       set status = 'approved', auth_session_id = '80000000-0000-0000-0000-000000000003'
     where id = '70000000-0000-0000-0000-000000000002';
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000003', true);
    begin
        perform public.miloom_request_resource_secret_access('card', v_card,
            '70000000-0000-0000-0000-000000000002');
        raise exception 'Viewer requested a secret';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    if (select count(*) from public.miloom_list_resource_secret_requests(
        v_owner_device, v_confirmation
    )) <> 1 or (select count(*) from public.miloom_get_owner_resource_secret(
        'card', v_card, v_owner_device, v_confirmation
    )) <> 1 then
        raise exception 'Owner could not see exact pending device request';
    end if;
    if (select resource_title from public.miloom_list_resource_secret_requests(
        v_owner_device, v_confirmation
    )) <> 'Card A' or (select company_name from public.miloom_list_resource_secret_requests(
        v_owner_device, v_confirmation
    )) <> 'Company A' then
        raise exception 'Owner review omitted the exact card and company';
    end if;
    if public.miloom_approve_resource_secret_access(
        v_request, v_owner_device, v_confirmation, v_public_key, v_wrapped
    ) ->> 'status' <> 'approved' then
        raise exception 'Owner approval did not finish';
    end if;
    begin
        perform public.miloom_approve_resource_secret_access(
            v_request, v_owner_device, v_confirmation, v_public_key, v_wrapped
        );
        raise exception 'Approval replay created another wrap';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    if (select count(*) from public.miloom_get_resource_secret_for_device(
        'card', v_card, v_editor_device
    )) <> 1 then
        raise exception 'Approved exact device could not fetch encrypted secret';
    end if;
    begin
        perform public.miloom_get_owner_resource_secret(
            'card', v_card, v_editor_device, v_confirmation
        );
        raise exception 'Editor fetched the owner-wrapped resource key';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_get_resource_secret_for_device('card', v_card, v_owner_device);
        raise exception 'Editor fetched with another user device';
    exception when insufficient_privilege then null;
    end;

    -- An overlapping Editor collection must preserve access after the exact
    -- share is removed. Removing the last applicable share locks the key.
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_company, 'all_financials', v_editor, 'Editor');
    delete from public.resource_shares
     where resource_id = v_card and resource_type = 'card' and user_id = v_editor;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> 'active' then
        raise exception 'Independent overlapping share was not preserved';
    end if;
    delete from public.resource_shares
     where resource_id = v_company and resource_type = 'all_financials'
       and user_id = v_editor;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> 'rotation_required'
       or exists (select 1 from public.resource_secret_device_wraps
                   where resource_id = v_card and grant_status = 'active') then
        raise exception 'Final access removal did not lock and revoke wraps';
    end if;
    begin
        perform public.miloom_get_resource_secret_for_device('card', v_card, v_editor_device);
        raise exception 'Revoked Editor could still fetch secret';
    exception when insufficient_privilege then null;
    end;
end;
$$;

do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_service uuid := '20000000-0000-0000-0000-000000000001';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_owner_device uuid := '70000000-0000-0000-0000-000000000003';
    v_editor_device uuid := '70000000-0000-0000-0000-000000000001';
    v_wrapped text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_request uuid;
begin
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_stage_resource_secret(
        'subscription', v_service, 1, 1, v_wrapped,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrapped),
        v_owner_device, v_confirmation
    );
    update public.resource_secret_versions
       set state = 'active', activated_at = now()
     where resource_type = 'subscription' and resource_id = v_service;
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_service, 'subscription', v_editor, 'Editor');
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    v_request := (public.miloom_request_resource_secret_access(
        'subscription', v_service, v_editor_device
    ) ->> 'request_id')::uuid;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_approve_resource_secret_access(
        v_request, v_owner_device, v_confirmation, v_public_key, v_wrapped
    );
    update public.vault_devices set status = 'revoked' where id = v_editor_device;
    if (select state from public.resource_secret_versions
         where resource_type = 'subscription' and resource_id = v_service) <> 'rotation_required'
       or exists (select 1 from public.resource_secret_device_wraps
                   where resource_id = v_service and grant_status = 'active') then
        raise exception 'Recipient device revocation did not lock the secret';
    end if;

    perform public.miloom_stage_resource_secret(
        'institution', v_bank, 1, 1, v_wrapped,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrapped),
        v_owner_device, v_confirmation
    );
    update public.resource_secret_versions
       set state = 'active', activated_at = now()
     where resource_type = 'institution' and resource_id = v_bank;
    update public.account_vaults set current_key_version = 2 where user_id = v_owner;
    if (select state from public.resource_secret_versions
         where resource_type = 'institution' and resource_id = v_bank) <> 'rotation_required' then
        raise exception 'Owner account-key rotation left a resource secret active';
    end if;
end;
$$;
