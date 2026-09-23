-- Run on a fresh disposable foundation fixture after migrations 009-021.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_viewer uuid := '00000000-0000-0000-0000-000000000003';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_owner_device uuid := '70000000-0000-0000-0000-000000000003';
    v_editor_device uuid := '70000000-0000-0000-0000-000000000001';
    v_viewer_device uuid := '70000000-0000-0000-0000-000000000002';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_wrap_new text := replace(encode(convert_to(repeat('y', 60), 'utf8'), 'base64'), E'\n', '');
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_original jsonb := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap);
    v_changed jsonb := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap_new);
    v_request uuid;
begin
    if has_function_privilege('anon',
        'public.miloom_update_resource_secret(text,uuid,integer,jsonb,jsonb,uuid)', 'EXECUTE')
       or not has_function_privilege('authenticated',
        'public.miloom_update_resource_secret(text,uuid,integer,jsonb,jsonb,uuid)', 'EXECUTE') then
        raise exception 'Update RPC has wrong app grants';
    end if;
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_card, 'card', v_editor, 'Editor'),
           (v_card, 'card', v_viewer, 'Viewer');
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_stage_resource_secret('card', v_card, 1, 1, v_wrap,
        v_original, v_owner_device, v_confirmation);
    update public.resource_secret_versions set state = 'active', activated_at = now()
     where resource_type = 'card' and resource_id = v_card;
    if public.miloom_update_resource_secret(
        'card', v_card, 1, v_original, v_changed, v_owner_device
    ) ->> 'status' <> 'updated' then
        raise exception 'Owner active update failed';
    end if;
    begin
        perform public.miloom_update_resource_secret(
            'card', v_card, 1, v_original, v_changed, v_owner_device);
        raise exception 'Stale owner write accepted';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_update_resource_secret(
            'card', v_card, 1, v_changed,
            jsonb_build_object('password', 'plain-text'), v_owner_device);
        raise exception 'Plaintext replacement accepted';
    exception when invalid_parameter_value then null;
    end;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    begin
        perform public.miloom_update_resource_secret(
            'card', v_card, 1, v_changed, v_original, v_editor_device);
        raise exception 'Ungrant editor edited credentials';
    exception when insufficient_privilege then null;
    end;
    v_request := (public.miloom_request_resource_secret_access(
        'card', v_card, v_editor_device) ->> 'request_id')::uuid;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_approve_resource_secret_access(
        v_request, v_owner_device, v_confirmation, v_public_key, v_wrap);
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    if public.miloom_update_resource_secret(
        'card', v_card, 1, v_changed, v_original, v_editor_device
    ) ->> 'status' <> 'updated' then
        raise exception 'Granted editor could not edit exact credential';
    end if;
    if (select encrypted_fields from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> v_original
       or (select count(*) from public.resource_secret_audit_events
           where resource_type = 'card' and resource_id = v_card
             and event_type = 'secret_updated') <> 2 then
        raise exception 'Update did not persist or audit exactly';
    end if;

    perform set_config('request.jwt.claim.sub', v_viewer::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000003', true);
    update public.vault_devices set status = 'approved',
        auth_session_id = '80000000-0000-0000-0000-000000000003'
     where id = v_viewer_device;
    begin
        perform public.miloom_update_resource_secret(
            'card', v_card, 1, v_original, v_changed, v_viewer_device);
        raise exception 'Viewer edited credential';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    delete from public.resource_shares where resource_id = v_card and user_id = v_editor;
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    begin
        perform public.miloom_update_resource_secret(
            'card', v_card, 1, v_original, v_changed, v_editor_device);
        raise exception 'Revoked editor edited credential';
    exception when insufficient_privilege then null;
    end;
end;
$$;
