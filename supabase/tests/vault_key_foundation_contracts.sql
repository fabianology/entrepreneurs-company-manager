-- Run against a disposable database after 202609210004_vault_key_foundation.sql.
begin;

create temporary table vault_phase3_fixture (
    name text primary key,
    device_id uuid not null
);
grant select, insert, update on vault_phase3_fixture to authenticated, service_role;

insert into auth.users (id) values
    ('93000000-0000-0000-0000-000000000001'),
    ('93000000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '93000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

insert into vault_phase3_fixture(name, device_id)
select 'owner_one', (public.miloom_bootstrap_account_vault(
    'Owner iPhone',
    'ios',
    encode(set_byte(decode(repeat('00', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('22', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('33', 60), 'hex'), 'base64'),
    encode(decode(repeat('44', 60), 'hex'), 'base64')
)->>'device_id')::uuid;

do $$
begin
    if (select count(*) from public.miloom_list_vault_devices()) <> 1 then
        raise exception 'Bootstrap device missing from owner list';
    end if;
    if not exists (
        select 1 from public.account_vaults
         where user_id = '93000000-0000-0000-0000-000000000001'
           and current_key_version = 1
    ) then
        raise exception 'Account vault metadata was not created';
    end if;
    if not exists (
        select 1 from public.vault_recovery_key_wraps
         where user_id = '93000000-0000-0000-0000-000000000001'
           and octet_length(decode(wrapped_key, 'base64')) = 60
    ) then
        raise exception 'Recovery wrap was not stored';
    end if;

    begin
        perform public.miloom_bootstrap_account_vault(
            'Duplicate', 'ios',
            encode(set_byte(decode(repeat('55', 65), 'hex'), 0, 4), 'base64'),
            encode(set_byte(decode(repeat('66', 65), 'hex'), 0, 4), 'base64'),
            encode(set_byte(decode(repeat('77', 65), 'hex'), 0, 4), 'base64'),
            encode(decode(repeat('88', 60), 'hex'), 'base64'),
            encode(decode(repeat('99', 60), 'hex'), 'base64')
        );
        raise exception 'Second bootstrap succeeded';
    exception when unique_violation then
        if sqlerrm <> 'VAULT_ALREADY_INITIALIZED' then raise; end if;
    end;

    begin
        insert into public.vault_devices (
            user_id, label, platform, agreement_public_key, signing_public_key
        ) values (
            '93000000-0000-0000-0000-000000000001', 'Bypass', 'ios', 'x', 'y'
        );
        raise exception 'Authenticated client directly inserted a vault device';
    exception when insufficient_privilege then null;
    end;
end;
$$;

-- A stale access token cannot request sensitive vault enrollment work.
select set_config(
    'request.jwt.claims',
    '{"sub":"93000000-0000-0000-0000-000000000001","iat":1}',
    true
);
do $$
begin
    begin
        perform public.miloom_register_vault_device(
            'Stale Device', 'ios',
            encode(set_byte(decode(repeat('aa', 65), 'hex'), 0, 4), 'base64'),
            encode(set_byte(decode(repeat('bb', 65), 'hex'), 0, 4), 'base64')
        );
        raise exception 'Stale access token registered a device';
    exception when insufficient_privilege then
        if sqlerrm <> 'RECENT_ACCESS_TOKEN_REQUIRED' then raise; end if;
    end;
end;
$$;

select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '93000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);

insert into vault_phase3_fixture(name, device_id)
select 'pending', (public.miloom_register_vault_device(
    'New iPad',
    'ios',
    encode(set_byte(decode(repeat('aa', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('bb', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

do $$
begin
    if not exists (
        select 1 from public.miloom_list_vault_devices()
         where device_id = (select device_id from vault_phase3_fixture where name = 'pending')
           and status = 'pending'
    ) then
        raise exception 'New device was not registered pending';
    end if;
    if has_function_privilege(
        'authenticated',
        'public.miloom_finalize_vault_device_approval(uuid,uuid,uuid,integer,text,text)',
        'EXECUTE'
    ) then
        raise exception 'Authenticated client can bypass signed device approval';
    end if;
end;
$$;

-- A different account cannot enumerate or retrieve the first account's vault.
reset role;
select set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000002', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '93000000-0000-0000-0000-000000000002',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

do $$
begin
    if exists (select 1 from public.miloom_list_vault_devices()) then
        raise exception 'Cross-owner vault device listing leaked';
    end if;
    if exists (
        select 1 from public.miloom_get_vault_device_wrap(
            (select device_id from vault_phase3_fixture where name = 'owner_one')
        )
    ) then
        raise exception 'Cross-owner vault key wrap leaked';
    end if;
    if exists (
        select 1 from public.vault_recovery_key_wraps
         where user_id = '93000000-0000-0000-0000-000000000001'
    ) then
        raise exception 'Cross-owner recovery wrap leaked';
    end if;
end;
$$;

-- Only the service boundary can finalize an approval after Phase 4 verifies
-- the signed challenge from the already-approved device.
reset role;
set local role service_role;
select public.miloom_finalize_vault_device_approval(
    '93000000-0000-0000-0000-000000000001',
    (select device_id from vault_phase3_fixture where name = 'owner_one'),
    (select device_id from vault_phase3_fixture where name = 'pending'),
    1,
    encode(set_byte(decode(repeat('cc', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('dd', 60), 'hex'), 'base64')
);

reset role;
select set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '93000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

do $$
begin
    if not exists (
        select 1 from public.miloom_get_vault_device_wrap(
            (select device_id from vault_phase3_fixture where name = 'pending')
        ) where key_version = 1
    ) then
        raise exception 'Approved device cannot retrieve its encrypted key wrap';
    end if;
    if not exists (
        select 1 from public.vault_audit_events
         where event_type = 'device_approved'
           and target_device_id = (select device_id from vault_phase3_fixture where name = 'pending')
    ) then
        raise exception 'Device approval audit event missing';
    end if;
end;
$$;

reset role;
do $$
begin
    if exists (
        select 1
          from information_schema.columns
         where table_schema = 'public'
           and table_name in (
               'account_vaults', 'vault_devices', 'vault_device_key_wraps',
               'vault_recovery_key_wraps', 'vault_audit_events'
           )
           and column_name in ('vault_key', 'recovery_code', 'plaintext_key', 'private_key')
    ) then
        raise exception 'Vault schema contains plaintext key material';
    end if;
end;
$$;

set local role anon;
do $$
begin
    if has_function_privilege('anon', 'public.miloom_list_vault_devices()', 'EXECUTE') then
        raise exception 'Anonymous role can list vault devices';
    end if;
    if has_function_privilege(
        'anon',
        'public.miloom_bootstrap_account_vault(text,text,text,text,text,text,text)',
        'EXECUTE'
    ) then
        raise exception 'Anonymous role can bootstrap a vault';
    end if;
end;
$$;

rollback;
