-- Run after vault migrations 004 through 006 in a disposable database.
begin;

create temporary table vault_phase5_fixture (name text primary key, id uuid not null);
grant select, insert on vault_phase5_fixture to authenticated, service_role;

insert into auth.users (id) values ('95000000-0000-0000-0000-000000000001');
insert into auth.sessions (id, user_id) values
    ('95000000-0000-0000-0000-000000000101', '95000000-0000-0000-0000-000000000001'),
    ('95000000-0000-0000-0000-000000000102', '95000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '95000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint,
        'session_id', '95000000-0000-0000-0000-000000000101'
    )::text,
    true
);
set local role authenticated;

select public.miloom_bootstrap_account_vault_v2(
    '95000000-0000-0000-0000-000000000010', 'Owner iPhone', 'ios',
    encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('12', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('13', 60), 'hex'), 'base64'),
    encode(decode(repeat('14', 60), 'hex'), 'base64'),
    encode(decode(repeat('15', 32), 'hex'), 'base64')
);

select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '95000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint,
        'session_id', '95000000-0000-0000-0000-000000000102'
    )::text,
    true
);

insert into vault_phase5_fixture(name, id)
select 'second', (public.miloom_register_vault_device(
    'Second iPhone', 'ios',
    encode(set_byte(decode(repeat('20', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('21', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

reset role;
set local role service_role;
select public.miloom_finalize_vault_device_approval(
    '95000000-0000-0000-0000-000000000001',
    '95000000-0000-0000-0000-000000000010',
    (select id from vault_phase5_fixture where name = 'second'),
    1,
    encode(set_byte(decode(repeat('22', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('23', 60), 'hex'), 'base64')
);

reset role;
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '95000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '95000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint,
        'session_id', '95000000-0000-0000-0000-000000000101'
    )::text,
    true
);

do $$
begin
    begin
        perform public.miloom_revoke_vault_device_and_rotate(
            '95000000-0000-0000-0000-000000000010',
            (select id from vault_phase5_fixture where name = 'second'),
            2,
            jsonb_build_array(jsonb_build_object(
                'device_id', '95000000-0000-0000-0000-000000000010',
                'ephemeral_public_key', encode(set_byte(decode(repeat('30', 65), 'hex'), 0, 4), 'base64'),
                'wrapped_key', encode(decode(repeat('31', 60), 'hex'), 'base64')
            )),
            encode(decode(repeat('32', 60), 'hex'), 'base64'),
            encode(decode(repeat('33', 32), 'hex'), 'base64'),
            encode(decode(repeat('ff', 32), 'hex'), 'base64'),
            encode(decode(repeat('34', 60), 'hex'), 'base64')
        );
        raise exception 'Incorrect current-key proof rotated the vault';
    exception when insufficient_privilege then
        if sqlerrm <> 'VAULT_PROOF_INVALID' then raise; end if;
    end;
end;
$$;

select public.miloom_revoke_vault_device_and_rotate(
    '95000000-0000-0000-0000-000000000010',
    (select id from vault_phase5_fixture where name = 'second'),
    2,
    jsonb_build_array(jsonb_build_object(
        'device_id', '95000000-0000-0000-0000-000000000010',
        'ephemeral_public_key', encode(set_byte(decode(repeat('30', 65), 'hex'), 0, 4), 'base64'),
        'wrapped_key', encode(decode(repeat('31', 60), 'hex'), 'base64')
    )),
    encode(decode(repeat('32', 60), 'hex'), 'base64'),
    encode(decode(repeat('33', 32), 'hex'), 'base64'),
    encode(decode(repeat('15', 32), 'hex'), 'base64'),
    encode(decode(repeat('34', 60), 'hex'), 'base64')
);

do $$
begin
    if not exists (
        select 1 from public.account_vaults
         where user_id = '95000000-0000-0000-0000-000000000001'
           and current_key_version = 2
           and previous_key_version = 1
           and rotation_status = 'migrating'
    ) then raise exception 'Vault rotation state was not recorded'; end if;
    if not exists (
        select 1 from public.vault_devices
         where id = (select id from vault_phase5_fixture where name = 'second')
           and status = 'revoked'
    ) then raise exception 'Target device was not revoked'; end if;
    if exists (
        select 1 from public.vault_device_key_wraps
         where device_id = (select id from vault_phase5_fixture where name = 'second')
           and revoked_at is null
    ) then raise exception 'Revoked device retained an active key wrap'; end if;
    if not exists (
        select 1 from public.vault_device_key_wraps
         where device_id = '95000000-0000-0000-0000-000000000010'
           and key_version = 2 and revoked_at is null
    ) then raise exception 'Remaining device did not receive the new key wrap'; end if;
    if not exists (
        select 1 from public.vault_key_transitions
         where user_id = '95000000-0000-0000-0000-000000000001'
           and from_key_version = 1 and to_key_version = 2 and completed_at is null
    ) then raise exception 'Resumable transition wrap is missing'; end if;
end;
$$;

reset role;
do $$
begin
    if exists (
        select 1 from auth.sessions where id = '95000000-0000-0000-0000-000000000102'
    ) then raise exception 'Revoked device auth session remained active'; end if;
    if not exists (
        select 1 from auth.sessions where id = '95000000-0000-0000-0000-000000000101'
    ) then raise exception 'Current device auth session was revoked'; end if;
end;
$$;
set local role authenticated;

select public.miloom_complete_vault_rotation(
    '95000000-0000-0000-0000-000000000010',
    2,
    encode(decode(repeat('33', 32), 'hex'), 'base64')
);

do $$
begin
    if exists (select 1 from public.vault_key_transitions) then
        raise exception 'Completed transition remains readable to the client';
    end if;
end;
$$;

select public.miloom_rotate_vault_recovery(
    '95000000-0000-0000-0000-000000000010',
    2,
    encode(decode(repeat('40', 60), 'hex'), 'base64'),
    encode(decode(repeat('33', 32), 'hex'), 'base64')
);

insert into vault_phase5_fixture(name, id)
select 'pending', (public.miloom_register_vault_device(
    'Pending iPad', 'ios',
    encode(set_byte(decode(repeat('41', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('42', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

select public.miloom_revoke_pending_vault_device(
    '95000000-0000-0000-0000-000000000010',
    (select id from vault_phase5_fixture where name = 'pending'),
    encode(decode(repeat('33', 32), 'hex'), 'base64')
);

do $$
begin
    if not exists (
        select 1 from public.account_vaults
         where user_id = '95000000-0000-0000-0000-000000000001'
           and current_key_version = 2
           and previous_key_version is null
           and rotation_status = 'stable'
    ) then raise exception 'Vault rotation did not complete'; end if;
    if not exists (
        select 1 from public.vault_recovery_key_wraps
         where user_id = '95000000-0000-0000-0000-000000000001'
           and key_version = 2
           and wrapped_key = encode(decode(repeat('40', 60), 'hex'), 'base64')
           and revoked_at is null
    ) then raise exception 'Recovery rotation did not replace the active wrap'; end if;
    if not exists (
        select 1 from public.vault_devices
         where id = (select id from vault_phase5_fixture where name = 'pending')
           and status = 'revoked'
    ) then raise exception 'Pending request was not revoked'; end if;
    if (select count(*) from public.vault_audit_events
         where user_id = '95000000-0000-0000-0000-000000000001'
           and event_type in ('device_revoked', 'vault_key_rotated', 'vault_rotation_completed', 'recovery_rotated')) < 5 then
        raise exception 'Vault lifecycle audit events are incomplete';
    end if;
end;
$$;

set local role anon;
do $$
begin
    if has_function_privilege(
        'anon',
        'public.miloom_revoke_vault_device_and_rotate(uuid,uuid,integer,jsonb,text,text,text,text)',
        'EXECUTE'
    ) then raise exception 'Anonymous role can rotate a vault'; end if;
end;
$$;

rollback;
