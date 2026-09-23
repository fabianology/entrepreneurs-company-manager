-- Run after fresh delegated_scope_fixture.sql, migrations 009-011,
-- resource_secret_foundation_fixture.sql, and migrations 012-013.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrapped text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_fields jsonb;
begin
    v_fields := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrapped);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);

    if public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_wrapped, v_fields, v_device, v_confirmation
    ) ->> 'status' <> 'staged' then
        raise exception 'Owner could not stage an encrypted card';
    end if;
    if (select count(*) from public.miloom_get_staged_resource_secret(
        'card', v_card, v_device, v_confirmation
    )) <> 1 then
        raise exception 'Owner could not resume its staged card';
    end if;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> 'staging' then
        raise exception 'Staging accidentally activated a secret';
    end if;
    if (select count(*) from public.resource_secret_device_wraps) <> 0 then
        raise exception 'Staging created a collaborator key wrap';
    end if;

    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 1, 1, v_wrapped, v_fields,
            '70000000-0000-0000-0000-000000000001', v_confirmation
        );
        raise exception 'Another user device staged a resource key';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 1, 1, v_wrapped,
            jsonb_build_object('password', 'plaintext'), v_device, v_confirmation
        );
        raise exception 'Plaintext field passed the stage contract';
    exception when invalid_parameter_value then null;
    end;
    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 1, 1, v_wrapped,
            jsonb_build_object('account_number', 'miloom-resource:v1:1:' || v_wrapped),
            v_device, v_confirmation
        );
        raise exception 'Unsupported secret field passed the stage contract';
    exception when invalid_parameter_value then null;
    end;
    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 2, 1, v_wrapped,
            jsonb_build_object('password', 'miloom-resource:v1:2:' || v_wrapped),
            v_device, v_confirmation
        );
        raise exception 'A skipped resource-key version was staged';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 1, 1, v_wrapped, v_fields, v_device,
            encode(convert_to(repeat('z', 32), 'utf8'), 'base64')
        );
        raise exception 'Wrong owner key confirmation was accepted';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    begin
        perform public.miloom_get_staged_resource_secret(
            'card', v_card, v_device, v_confirmation
        );
        raise exception 'Collaborator read owner staged key';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_stage_resource_secret(
            'card', v_card, 1, 1, v_wrapped, v_fields, v_device, v_confirmation
        );
        raise exception 'Collaborator staged owner secret';
    exception when insufficient_privilege then null;
    end;
end;
$$;
