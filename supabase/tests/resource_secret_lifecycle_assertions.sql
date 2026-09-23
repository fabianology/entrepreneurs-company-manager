-- Run after cutover/rotation assertions and migration 019 in a disposable DB.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_subscription uuid := '20000000-0000-0000-0000-000000000001';
    v_company_b uuid := '10000000-0000-0000-0000-000000000002';
    v_foreign_company uuid := '10000000-0000-0000-0000-000000000003';
    v_editor_device uuid := '70000000-0000-0000-0000-000000000001';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
begin
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_card, 'card', v_editor, 'Editor');
    insert into public.resource_secret_device_wraps (
        resource_type, resource_id, key_version, recipient_user_id,
        recipient_device_id, ephemeral_public_key, wrapped_resource_key,
        grant_status, activated_at
    ) values (
        'card', v_card, 2, v_editor, v_editor_device, v_public_key, v_wrap,
        'active', now()
    );
    insert into public.resource_access_blocks (
        owner_user_id, blocked_email, blocked_user_id
    ) values (v_owner, 'editor@example.com', v_editor);
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 2)
       <> 'rotation_required'
       or (select grant_status from public.resource_secret_device_wraps
           where resource_type = 'card' and resource_id = v_card and key_version = 2)
       <> 'revoked' then
        raise exception 'Blocking a recipient retained an active credential grant';
    end if;
    delete from public.resource_access_blocks
     where owner_user_id = v_owner and blocked_user_id = v_editor;
    if (select state from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card and key_version = 2)
       <> 'rotation_required' then
        raise exception 'Unblocking silently restored a stale credential key';
    end if;

    insert into public.companies (id, user_id, name)
    values (v_foreign_company, v_editor, 'Foreign Company');
    begin
        update public.institutions set company_id = v_foreign_company where id = v_bank;
        raise exception 'Bank credential moved into a foreign-owned entity';
    exception when insufficient_privilege then null;
    end;
    update public.institutions set company_id = v_company_b where id = v_bank;
    if (select state from public.resource_secret_versions
         where resource_type = 'institution' and resource_id = v_bank) <> 'rotation_required'
       or (select company_id from public.resource_secret_versions
           where resource_type = 'institution' and resource_id = v_bank) <> v_company_b then
        raise exception 'Moving a bank did not lock and rebind its credential key';
    end if;
    begin
        update public.institutions set user_id = v_editor where id = v_bank;
        raise exception 'Ownership changed with a live resource key';
    exception when insufficient_privilege then null;
    end;
    if (select user_id from public.institutions where id = v_bank) <> v_owner then
        raise exception 'Rejected ownership change still changed the source owner';
    end if;

    delete from public.subscriptions where id = v_subscription;
    if exists (select 1 from public.resource_secret_versions
        where resource_type = 'subscription' and resource_id = v_subscription)
       or not exists (select 1 from public.resource_secret_audit_events
           where resource_type = 'subscription' and resource_id = v_subscription
             and event_type = 'key_retired') then
        raise exception 'Deleted service left a decryptable resource key behind';
    end if;
end;
$$;
