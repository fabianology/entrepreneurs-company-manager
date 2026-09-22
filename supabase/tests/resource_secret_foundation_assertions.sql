-- Run after the disposable fixture, 009-011, resource_secret_foundation_fixture.sql,
-- then migration 012. Never run against staging or production data.

do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_company uuid := '10000000-0000-0000-0000-000000000001';
    v_key text := encode(convert_to(repeat('x', 60), 'utf8'), 'base64');
    v_public_key text := encode(decode('04' || repeat('11', 64), 'hex'), 'base64');
begin
    if has_table_privilege('authenticated', 'public.resource_secret_versions', 'select')
       or has_table_privilege('authenticated', 'public.resource_secret_device_wraps', 'select')
       or has_table_privilege('authenticated', 'public.resource_secret_audit_events', 'select') then
        raise exception 'ordinary authenticated table reads are enabled';
    end if;
    if not (select relrowsecurity from pg_class where oid = 'public.resource_secret_versions'::regclass)
       or not (select relrowsecurity from pg_class where oid = 'public.resource_secret_device_wraps'::regclass) then
        raise exception 'resource secret RLS was not enabled';
    end if;

    insert into public.resource_secret_versions (
        owner_user_id, resource_type, resource_id, company_id,
        key_version, owner_account_key_version, owner_wrapped_resource_key
    ) values (v_owner, 'institution', v_bank, v_company, 1, 1, v_key);

    begin
        insert into public.resource_secret_versions (
            owner_user_id, resource_type, resource_id, company_id,
            key_version, owner_account_key_version, owner_wrapped_resource_key
        ) values (v_editor, 'institution', v_bank, v_company, 2, 1, v_key);
        raise exception 'wrong owner key inserted';
    exception when check_violation then null;
    end;
    begin
        insert into public.resource_secret_versions (
            owner_user_id, resource_type, resource_id, company_id,
            key_version, owner_account_key_version, owner_wrapped_resource_key
        ) values (v_owner, 'institution', v_bank, v_company, 2, 9, v_key);
        raise exception 'future account key version inserted';
    exception when check_violation then null;
    end;
    begin
        insert into public.resource_secret_device_wraps (
            resource_type, resource_id, key_version, recipient_user_id,
            recipient_device_id, ephemeral_public_key, wrapped_resource_key
        ) values ('institution', v_bank, 1, v_editor,
            '70000000-0000-0000-0000-000000000002', v_public_key, v_key);
        raise exception 'pending or wrong-user device accepted';
    exception when check_violation then null;
    end;
    insert into public.resource_secret_device_wraps (
        resource_type, resource_id, key_version, recipient_user_id,
        recipient_device_id, ephemeral_public_key, wrapped_resource_key
    ) values ('institution', v_bank, 1, v_editor,
        '70000000-0000-0000-0000-000000000001', v_public_key, v_key);

    begin
        insert into public.resource_secret_device_wraps (
            resource_type, resource_id, key_version, recipient_user_id,
            recipient_device_id, ephemeral_public_key, wrapped_resource_key
        ) values ('institution', '30000000-0000-0000-0000-000000000002', 1, v_editor,
            '70000000-0000-0000-0000-000000000001', v_public_key, v_key);
        raise exception 'wrap without exact resource key accepted';
    exception when foreign_key_violation then null;
    end;
end;
$$;
