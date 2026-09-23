-- Run on a fresh disposable foundation fixture after migrations 009-020.
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
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_request uuid;
begin
    if has_function_privilege('anon',
        'public.miloom_resource_secret_access_status(text,uuid,uuid)', 'EXECUTE')
       or not has_function_privilege('authenticated',
        'public.miloom_resource_secret_access_status(text,uuid,uuid)', 'EXECUTE') then
        raise exception 'Status RPC has wrong app grants';
    end if;
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_card, 'card', v_editor, 'Editor'),
           (v_card, 'card', v_viewer, 'Viewer');
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_owner_device)) <> 'not_ready' then
        raise exception 'Unstaged resource appeared available';
    end if;
    perform public.miloom_stage_resource_secret('card', v_card, 1, 1, v_wrap,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap),
        v_owner_device, v_confirmation);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_owner_device)) <> 'not_ready' then
        raise exception 'Staged resource appeared available';
    end if;
    -- The initial activation RPC is intentionally closed. Only this isolated
    -- superuser fixture simulates a future, separately reviewed cutover.
    update public.resource_secret_versions set state = 'active', activated_at = now()
     where resource_type = 'card' and resource_id = v_card;
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_owner_device)) <> 'ready' then
        raise exception 'Owner active status incorrect';
    end if;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_owner_device)) <> 'device_needed'
       or (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_editor_device)) <> 'request' then
        raise exception 'Editor device/request status incorrect';
    end if;
    v_request := (public.miloom_request_resource_secret_access(
        'card', v_card, v_editor_device) ->> 'request_id')::uuid;
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_editor_device)) <> 'pending' then
        raise exception 'Pending status incorrect';
    end if;

    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform public.miloom_approve_resource_secret_access(
        v_request, v_owner_device, v_confirmation, v_public_key, v_wrap);
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_editor_device)) <> 'ready'
       or public.miloom_request_resource_secret_access(
        'card', v_card, v_editor_device) ->> 'status' <> 'already_approved'
       or exists (select 1 from public.resource_secret_access_requests
           where resource_id = v_card and recipient_device_id = v_editor_device
             and status = 'pending') then
        raise exception 'Approved device created another pending request';
    end if;

    perform set_config('request.jwt.claim.sub', v_viewer::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000003', true);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_viewer_device)) <> 'unavailable' then
        raise exception 'Viewer learned secret status';
    end if;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    delete from public.resource_shares
     where resource_id = v_card and user_id = v_editor;
    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000002', true);
    if (select status from public.miloom_resource_secret_access_status(
        'card', v_card, v_editor_device)) <> 'unavailable' then
        raise exception 'Revoked editor learned secret status';
    end if;
end;
$$;
