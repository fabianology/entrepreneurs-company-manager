-- Run after migration 018 and cutover assertions in a disposable database.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrap text := replace(encode(convert_to(repeat('z', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_fields jsonb := jsonb_build_object('password',
        'miloom-resource:v1:2:' || replace(encode(convert_to(repeat('z', 60), 'utf8'), 'base64'), E'\n', ''));
begin
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    update public.resource_secret_versions
       set encrypted_fields = encrypted_fields || jsonb_build_object(
           'login', 'miloom-resource:v1:1:' || v_wrap
       )
     where resource_type = 'card' and resource_id = v_card and key_version = 1;
    update public.resource_secret_versions
       set state = 'rotation_required'
     where resource_type = 'card' and resource_id = v_card and key_version = 1;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 1)
       <> 'rotation_required' then
        raise exception 'Old card key was not locked';
    end if;
    if (select count(*) from public.miloom_list_owner_locked_resource_secrets(
        v_device, v_confirmation
    )) <> 1 then
        raise exception 'Owner could not list the exact locked resource';
    end if;
    if (select count(*) from public.miloom_get_owner_resource_secret_version(
        'card', v_card, 1, v_device, v_confirmation
    )) <> 1 then
        raise exception 'Owner could not recover the locked old ciphertext';
    end if;
    begin
        perform public.miloom_stage_rotated_resource_secret(
            'card', v_card, 1, 1, v_wrap,
            jsonb_build_object('password', 'plaintext'), v_device, v_confirmation
        );
        raise exception 'Rotation accepted plaintext';
    exception when invalid_parameter_value then null;
    end;
    perform public.miloom_stage_rotated_resource_secret(
        'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 1)
       <> 'rotation_required'
       or (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 2)
       <> 'staging' then
        raise exception 'Staging retired the old key or activated the new key prematurely';
    end if;
    if (select key_version from public.miloom_get_owner_resource_secret(
        'card', v_card, v_device, v_confirmation
    )) <> 2 then
        raise exception 'Owner could not verify the replacement stage';
    end if;
    begin
        perform public.miloom_activate_rotated_resource_secret(
            'card', v_card, 1, '{}'::jsonb, v_wrap, v_device, v_confirmation
        );
        raise exception 'Unverified rotated ciphertext was activated';
    exception when insufficient_privilege then null;
    end;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 1)
       <> 'rotation_required' then
        raise exception 'Rejected rotation lost the locked old key';
    end if;
    begin
        perform public.miloom_activate_rotated_resource_secret(
            'card', v_card, 1, v_fields, v_wrap, v_device, v_confirmation
        );
        raise exception 'Rotation dropped an old credential field';
    exception when insufficient_privilege then null;
    end;
    v_fields := v_fields || jsonb_build_object(
        'login', 'miloom-resource:v1:2:' || v_wrap
    );
    perform public.miloom_stage_rotated_resource_secret(
        'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    perform public.miloom_activate_rotated_resource_secret(
        'card', v_card, 1, v_fields, v_wrap, v_device, v_confirmation
    );
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 1) <> 'retired'
       or (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 2) <> 'active'
       or exists (select 1 from public.resource_secret_device_wraps w
           where w.resource_type = 'card' and w.resource_id = v_card
             and w.key_version = 2) then
        raise exception 'Rotation reused old grants or left states inconsistent';
    end if;
    begin
        perform public.miloom_activate_rotated_resource_secret(
            'card', v_card, 1, v_fields, v_wrap, v_device, v_confirmation
        );
        raise exception 'Rotation replay succeeded';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    begin
        perform public.miloom_list_owner_locked_resource_secrets(
            v_device, v_confirmation
        );
        raise exception 'Editor listed owner locked resources';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_get_owner_resource_secret_version(
            'card', v_card, 1, v_device, v_confirmation
        );
        raise exception 'Editor read owner locked key';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_stage_rotated_resource_secret(
            'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
        );
        raise exception 'Editor staged owner rotation';
    exception when insufficient_privilege then null;
    end;
end;
$$;
