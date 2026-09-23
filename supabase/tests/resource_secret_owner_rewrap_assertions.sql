-- Run after a fresh delegated scope fixture, 009-011, vault fixture, and 012-015.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_old_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_new_wrap text := replace(encode(convert_to(repeat('y', 60), 'utf8'), 'base64'), E'\n', '');
    v_old_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_new_confirmation text := encode(convert_to(repeat('n', 32), 'utf8'), 'base64');
begin
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_old_wrap,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_old_wrap),
        v_device, v_old_confirmation
    );
    update public.account_vaults
       set current_key_version = 2, key_confirmation = v_new_confirmation,
           rotation_status = 'migrating'
     where user_id = v_owner;
    if (select count(*) from public.miloom_list_resource_secret_owner_wraps_for_rotation(
        v_device, v_new_confirmation
    )) <> 1 then
        raise exception 'Owner could not find the old wrap during migration';
    end if;
    begin
        update public.account_vaults set rotation_status = 'stable' where user_id = v_owner;
        raise exception 'Rotation completed with a stranded resource key';
    exception when check_violation then null;
    end;
    begin
        perform public.miloom_rewrap_resource_secret_owner_key(
            'card', v_card, 1, 1, v_new_wrap, v_device, v_old_confirmation
        );
        raise exception 'Old confirmation accepted for rewrap';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    begin
        perform public.miloom_list_resource_secret_owner_wraps_for_rotation(
            v_device, v_new_confirmation
        );
        raise exception 'Editor read the owner wrap';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_rewrap_resource_secret_owner_key(
        'card', v_card, 1, 1, v_new_wrap, v_device, v_new_confirmation
    );
    if (select count(*) from public.miloom_list_resource_secret_owner_wraps_for_rotation(
        v_device, v_new_confirmation
    )) <> 0 then
        raise exception 'Rewrapped resource still depends on the old account key';
    end if;
    begin
        perform public.miloom_rewrap_resource_secret_owner_key(
            'card', v_card, 1, 1, v_new_wrap, v_device, v_new_confirmation
        );
        raise exception 'Stale rewrap replay accepted';
    exception when insufficient_privilege then null;
    end;
    update public.account_vaults set rotation_status = 'stable' where user_id = v_owner;
    if (select owner_account_key_version from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> 2 then
        raise exception 'Owner wrap version mismatch after rotation';
    end if;
end;
$$;
