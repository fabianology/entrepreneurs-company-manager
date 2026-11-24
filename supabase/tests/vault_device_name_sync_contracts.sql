-- Run against an isolated Auth database after applying the vault migrations.
begin;

insert into auth.users (id) values
    ('96000000-0000-0000-0000-000000000001'),
    ('96000000-0000-0000-0000-000000000002');

insert into public.vault_devices (
    id, user_id, label, platform, agreement_public_key, signing_public_key, status, auth_session_id
) values
    ('96000000-0000-0000-0000-000000000101', '96000000-0000-0000-0000-000000000001',
     'First iPhone', 'ios', 'agreement-101', 'signing-101', 'approved', '96000000-0000-0000-0000-000000000201'),
    ('96000000-0000-0000-0000-000000000102', '96000000-0000-0000-0000-000000000001',
     'Second iPhone', 'ios', 'agreement-102', 'signing-102', 'approved', '96000000-0000-0000-0000-000000000202'),
    ('96000000-0000-0000-0000-000000000103', '96000000-0000-0000-0000-000000000001',
     'Requested iPhone', 'ios', 'agreement-103', 'signing-103', 'pending', '96000000-0000-0000-0000-000000000203'),
    ('96000000-0000-0000-0000-000000000104', '96000000-0000-0000-0000-000000000001',
     'Revoked iPhone', 'ios', 'agreement-104', 'signing-104', 'revoked', '96000000-0000-0000-0000-000000000204'),
    ('96000000-0000-0000-0000-000000000105', '96000000-0000-0000-0000-000000000002',
     'Other account iPhone', 'ios', 'agreement-105', 'signing-105', 'approved', '96000000-0000-0000-0000-000000000205');

set local role authenticated;
select set_config('request.jwt.claim.sub', '96000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', jsonb_build_object(
    'sub', '96000000-0000-0000-0000-000000000001',
    'session_id', '96000000-0000-0000-0000-000000000201',
    'iat', extract(epoch from now())::bigint
)::text, true);

do $$
declare
    first_device constant uuid := '96000000-0000-0000-0000-000000000101';
    second_device constant uuid := '96000000-0000-0000-0000-000000000102';
    pending_device constant uuid := '96000000-0000-0000-0000-000000000103';
    revoked_device constant uuid := '96000000-0000-0000-0000-000000000104';
    other_device constant uuid := '96000000-0000-0000-0000-000000000105';
    target uuid;
    invalid_name text;
begin
    if has_function_privilege('anon', 'public.miloom_rename_vault_device(uuid,uuid,text,boolean)', 'execute')
       or has_column_privilege('authenticated', 'public.vault_devices', 'display_name', 'update') then
        raise exception 'Device rename can bypass its authenticated RPC';
    end if;

    if (select label from public.miloom_list_vault_devices() where device_id = second_device)
        is distinct from 'Second iPhone' then
        raise exception 'An unnamed device lost its registration label';
    end if;
    if public.miloom_rename_vault_device(first_device, second_device, '  Alex’s iPhone  ', true)
        is distinct from 'Alex’s iPhone' then
        raise exception 'The local name was not imported and trimmed';
    end if;

    foreach target in array array[pending_device, revoked_device, other_device] loop
        begin
            perform public.miloom_rename_vault_device(first_device, target, 'Unrelated name');
            raise exception 'A rename targeted a device outside the approved list';
        exception when no_data_found then
            if sqlerrm <> 'APPROVED_DEVICE_NOT_FOUND' then raise; end if;
        end;
    end loop;
    begin
        perform public.miloom_rename_vault_device(second_device, first_device, 'Wrong session');
        raise exception 'A session used a different device as its actor';
    exception when insufficient_privilege then
        if sqlerrm <> 'TRUSTED_DEVICE_REQUIRED' then raise; end if;
    end;
    foreach invalid_name in array array[null::text, '  ', repeat('é', 81), E'Double\nline'] loop
        begin
            perform public.miloom_rename_vault_device(first_device, second_device, invalid_name);
            raise exception 'An invalid device name was accepted';
        exception when invalid_parameter_value then
            if sqlerrm <> 'INVALID_DEVICE_NAME' then raise; end if;
        end;
    end loop;

    perform set_config('request.jwt.claims', jsonb_set(
        auth.jwt(), '{session_id}', to_jsonb('96000000-0000-0000-0000-000000000202'::text)
    )::text, true);
    if (select label from public.miloom_list_vault_devices() where device_id = second_device)
        is distinct from 'Alex’s iPhone' then
        raise exception 'The second approved session did not see the imported name';
    end if;
    if public.miloom_rename_vault_device(second_device, second_device, 'Alex’s work phone')
        is distinct from 'Alex’s work phone' then
        raise exception 'The second approved session could not rename its device';
    end if;

    perform set_config('request.jwt.claims', jsonb_set(
        auth.jwt(), '{session_id}', to_jsonb('96000000-0000-0000-0000-000000000201'::text)
    )::text, true);
    if public.miloom_rename_vault_device(first_device, second_device, 'Older local name', true)
        is distinct from 'Alex’s work phone' then
        raise exception 'A local import replaced a shared name';
    end if;
    if exists (select from public.miloom_list_vault_devices() where device_id = other_device) then
        raise exception 'The list exposed another account’s device';
    end if;
    if not exists (
        select from public.vault_devices where id = second_device and label = 'Second iPhone'
           and agreement_public_key = 'agreement-102' and signing_public_key = 'signing-102' and status = 'approved'
    ) then
        raise exception 'Renaming changed registration or trust metadata';
    end if;

    perform set_config('request.jwt.claims', jsonb_set(
        auth.jwt(), '{session_id}', to_jsonb('96000000-0000-0000-0000-000000000204'::text)
    )::text, true);
    begin
        perform public.miloom_rename_vault_device(revoked_device, second_device, 'Revoked actor');
        raise exception 'A revoked device could rename an approved device';
    exception when insufficient_privilege then
        if sqlerrm <> 'TRUSTED_DEVICE_REQUIRED' then raise; end if;
    end;
end;
$$;

rollback;
