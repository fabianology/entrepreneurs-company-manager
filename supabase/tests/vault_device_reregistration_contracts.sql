-- Run against a disposable database after
-- 202609220005_allow_revoked_vault_device_reregistration.sql.
begin;

create temporary table vault_reregistration_fixture (
    name text primary key,
    device_id uuid not null
);
grant select, insert on vault_reregistration_fixture to authenticated;

insert into auth.users (id)
values ('97000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub', '97000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '97000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

insert into vault_reregistration_fixture(name, device_id)
select 'device', (public.miloom_bootstrap_account_vault_v2(
    '97000000-0000-0000-0000-000000000010',
    'Original iPhone', 'ios',
    encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('12', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('13', 60), 'hex'), 'base64'),
    encode(decode(repeat('14', 60), 'hex'), 'base64'),
    encode(decode(repeat('15', 32), 'hex'), 'base64')
)->>'device_id')::uuid;

do $$
declare
    v_result jsonb;
begin
    v_result := public.miloom_register_vault_device(
        'Retry While Approved', 'ios',
        encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
        encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64')
    );
    if v_result->>'status' <> 'approved' then
        raise exception 'An approved registration retry changed device status';
    end if;
end;
$$;

reset role;
update public.vault_devices
   set status = 'revoked', revoked_at = now(), approved_at = null
 where id = (select device_id from vault_reregistration_fixture where name = 'device');
set local role authenticated;

do $$
declare
    v_result jsonb;
    v_device_id uuid := (select device_id from vault_reregistration_fixture where name = 'device');
begin
    v_result := public.miloom_register_vault_device(
        'Re-enrolled iPhone', 'ios',
        encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
        encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64')
    );

    if (v_result->>'device_id')::uuid <> v_device_id
       or v_result->>'status' <> 'pending'
       or (v_result->>'re_enrolled')::boolean is not true then
        raise exception 'Revoked device was not re-enrolled as the same pending identity';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = v_device_id
           and status = 'pending'
           and approved_at is null
           and revoked_at is null
    ) then
        raise exception 'Re-enrolled device state is invalid';
    end if;
    if exists (
        select 1 from public.vault_device_key_wraps
         where device_id = v_device_id and revoked_at is null
    ) then
        raise exception 'Re-enrollment restored an old device key wrap';
    end if;
    if (select count(*) from public.vault_audit_events
         where target_device_id = v_device_id
           and event_type = 'device_registration_requested') <> 1 then
        raise exception 'Re-enrollment audit event is missing or duplicated';
    end if;

    v_result := public.miloom_register_vault_device(
        'Pending Retry', 'ios',
        encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
        encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64')
    );
    if v_result->>'status' <> 'pending'
       or (select count(*) from public.vault_audit_events
            where target_device_id = v_device_id
              and event_type = 'device_registration_requested') <> 1 then
        raise exception 'Pending registration retry was not idempotent';
    end if;
end;
$$;

reset role;
do $$
begin
    if exists (
        select 1 from public.vault_devices
         where id = (select device_id from vault_reregistration_fixture where name = 'device')
           and auth_session_id is not null
    ) then
        raise exception 'Re-enrollment retained a revoked authentication session';
    end if;
end;
$$;
set local role authenticated;

insert into vault_reregistration_fixture(name, device_id)
select 'other', (public.miloom_register_vault_device(
    'Other iPhone', 'ios',
    encode(set_byte(decode(repeat('20', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('21', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

do $$
begin
    begin
        perform public.miloom_register_vault_device(
            'Cross-paired Identity', 'ios',
            encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
            encode(set_byte(decode(repeat('21', 65), 'hex'), 0, 4), 'base64')
        );
        raise exception 'Mismatched device keys were accepted';
    exception when invalid_parameter_value then
        if sqlerrm <> 'INVALID_DEVICE_IDENTITY' then raise; end if;
    end;
end;
$$;

reset role;
set local role anon;
do $$
begin
    if has_function_privilege(
        'anon',
        'public.miloom_register_vault_device(text,text,text,text)',
        'EXECUTE'
    ) then
        raise exception 'Anonymous role can register a vault device';
    end if;
end;
$$;

rollback;
