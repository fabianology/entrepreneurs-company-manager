-- Run only after the disposable vault fixture, migrations 009-021, the local
-- Auth fixture, and the activation migration. No hosted credentials required.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_viewer uuid := '00000000-0000-0000-0000-000000000003';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_other uuid := '30000000-0000-0000-0000-000000000002';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
begin
    if not has_function_privilege('authenticated',
        'public.miloom_activate_staged_resource_secret(text,uuid,integer,bigint,jsonb,text,uuid,text)',
        'EXECUTE') or has_function_privilege('anon',
        'public.miloom_activate_staged_resource_secret(text,uuid,integer,bigint,jsonb,text,uuid,text)',
        'EXECUTE') then
        raise exception 'Activation RPC has wrong role grants';
    end if;
    insert into public.resource_shares(resource_id, resource_type, user_id, role)
    values (v_card, 'card', v_editor, 'Editor'),
           (v_card, 'card', v_viewer, 'Viewer');
    if public.miloom_resource_secret_user_eligible(v_editor, 'card', v_card)
       or public.miloom_resource_secret_user_eligible(v_viewer, 'card', v_card)
       or public.miloom_resource_secret_user_eligible(v_editor, 'institution', v_other) then
        raise exception 'Unverified, Viewer, or cross-scope user was eligible';
    end if;
    update auth.users set email_confirmed_at = now() where id = v_editor;
    if not public.miloom_resource_secret_user_eligible(v_editor, 'card', v_card) then
        raise exception 'Verified scoped Editor was rejected';
    end if;
    update auth.users set is_anonymous = true where id = v_editor;
    if public.miloom_resource_secret_user_eligible(v_editor, 'card', v_card) then
        raise exception 'Anonymous Editor was eligible';
    end if;
    update auth.users set is_anonymous = false where id = v_editor;
    update public.resource_shares set suspended_at = now()
     where resource_id = v_card and user_id = v_editor;
    if public.miloom_resource_secret_user_eligible(v_editor, 'card', v_card) then
        raise exception 'Suspended Editor was eligible';
    end if;
    update public.resource_shares set suspended_at = null
     where resource_id = v_card and user_id = v_editor;
    update public.financial_cards set password = 'synthetic-source' where id = v_card;
    perform set_config('request.jwt.claim.sub', v_owner::text, false);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', false);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, false);
    perform public.miloom_stage_resource_secret('card', v_card, 1, 1, v_wrap,
        jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap),
        v_device, v_confirmation);
end;
$$;

set role authenticated;
do $$
declare
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_fields jsonb := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap);
begin
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000002', false);
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, 1, v_fields, v_wrap, v_device, v_confirmation);
        raise exception 'Non-owner activation succeeded';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000001', false);
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, 0, v_fields, v_wrap, v_device, v_confirmation);
        raise exception 'Stale source revision activated';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, 1, '{}'::jsonb, v_wrap, v_device, v_confirmation);
        raise exception 'Mismatched ciphertext activated';
    exception when insufficient_privilege then null;
    end;
    if public.miloom_activate_staged_resource_secret(
        'card', v_card, 1, 1, v_fields, v_wrap, v_device, v_confirmation
    ) ->> 'status' <> 'active' then
        raise exception 'Owner cutover failed';
    end if;
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, 1, v_fields, v_wrap, v_device, v_confirmation);
        raise exception 'Second activation succeeded';
    exception when insufficient_privilege then null;
    end;
end;
$$;
reset role;

do $$
begin
    if (select password from public.financial_cards
         where id = '40000000-0000-0000-0000-000000000001') is not null
       or (select state from public.resource_secret_versions
            where resource_type = 'card'
              and resource_id = '40000000-0000-0000-0000-000000000001') <> 'active'
       or (select count(*) from public.resource_secret_device_wraps) <> 0 then
        raise exception 'Cutover did not scrub source or granted a collaborator key';
    end if;
end;
$$;
