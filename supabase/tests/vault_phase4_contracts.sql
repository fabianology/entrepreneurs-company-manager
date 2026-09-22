-- Run after the vault foundation and Phase 4 migrations in a disposable DB.
begin;

create temporary table vault_phase4_fixture (
    name text primary key,
    id uuid not null
);
grant select, insert on vault_phase4_fixture to authenticated, service_role;

insert into auth.users (id) values ('94000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub', '94000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '94000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

select public.miloom_bootstrap_account_vault_v2(
    '94000000-0000-0000-0000-000000000010',
    'Owner iPhone',
    'ios',
    encode(set_byte(decode(repeat('10', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('11', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('12', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('13', 60), 'hex'), 'base64'),
    encode(decode(repeat('14', 60), 'hex'), 'base64'),
    encode(decode(repeat('15', 32), 'hex'), 'base64')
);

insert into vault_phase4_fixture(name, id)
select 'pending', (public.miloom_register_vault_device(
    'New iPad',
    'ios',
    encode(set_byte(decode(repeat('20', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('21', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

insert into vault_phase4_fixture(name, id)
select 'challenge', (public.miloom_create_vault_approval_challenge(
    '94000000-0000-0000-0000-000000000010',
    (select id from vault_phase4_fixture where name = 'pending')
)->>'challenge_id')::uuid;

do $$
begin
    if has_column_privilege('authenticated', 'public.account_vaults', 'key_confirmation', 'SELECT') then
        raise exception 'Authenticated clients can read the recovery proof';
    end if;
    if has_table_privilege('authenticated', 'public.vault_device_approval_challenges', 'SELECT') then
        raise exception 'Authenticated clients can read approval challenges directly';
    end if;
    if has_function_privilege(
        'authenticated',
        'public.miloom_consume_vault_approval_challenge(uuid,uuid,uuid,uuid,integer,text,text)',
        'EXECUTE'
    ) then
        raise exception 'Authenticated clients can bypass edge signature verification';
    end if;
    if has_function_privilege(
        'authenticated',
        'public.miloom_bootstrap_account_vault(text,text,text,text,text,text,text)',
        'EXECUTE'
    ) then
        raise exception 'Legacy unbound bootstrap remains callable';
    end if;
end;
$$;

reset role;
set local role service_role;
select public.miloom_consume_vault_approval_challenge(
    '94000000-0000-0000-0000-000000000001',
    (select id from vault_phase4_fixture where name = 'challenge'),
    '94000000-0000-0000-0000-000000000010',
    (select id from vault_phase4_fixture where name = 'pending'),
    1,
    encode(set_byte(decode(repeat('22', 65), 'hex'), 0, 4), 'base64'),
    encode(decode(repeat('23', 60), 'hex'), 'base64')
);

do $$
begin
    begin
        perform public.miloom_consume_vault_approval_challenge(
            '94000000-0000-0000-0000-000000000001',
            (select id from vault_phase4_fixture where name = 'challenge'),
            '94000000-0000-0000-0000-000000000010',
            (select id from vault_phase4_fixture where name = 'pending'),
            1,
            encode(set_byte(decode(repeat('22', 65), 'hex'), 0, 4), 'base64'),
            encode(decode(repeat('23', 60), 'hex'), 'base64')
        );
        raise exception 'Approval challenge was replayed';
    exception when insufficient_privilege then
        if sqlerrm <> 'APPROVAL_CHALLENGE_INVALID' then raise; end if;
    end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', '94000000-0000-0000-0000-000000000001', true);
select set_config(
    'request.jwt.claims',
    jsonb_build_object(
        'sub', '94000000-0000-0000-0000-000000000001',
        'iat', extract(epoch from now())::bigint
    )::text,
    true
);
set local role authenticated;

do $$
begin
    if not exists (
        select 1 from public.miloom_list_vault_devices()
         where device_id = (select id from vault_phase4_fixture where name = 'pending')
           and status = 'approved'
    ) then
        raise exception 'Signed approval finalizer did not approve target device';
    end if;
end;
$$;

insert into vault_phase4_fixture(name, id)
select 'recovery_pending', (public.miloom_register_vault_device(
    'Replacement iPhone',
    'ios',
    encode(set_byte(decode(repeat('30', 65), 'hex'), 0, 4), 'base64'),
    encode(set_byte(decode(repeat('31', 65), 'hex'), 0, 4), 'base64')
)->>'device_id')::uuid;

do $$
begin
    begin
        perform public.miloom_recover_vault_device(
            (select id from vault_phase4_fixture where name = 'recovery_pending'),
            1,
            encode(set_byte(decode(repeat('32', 65), 'hex'), 0, 4), 'base64'),
            encode(decode(repeat('33', 60), 'hex'), 'base64'),
            encode(decode(repeat('ff', 32), 'hex'), 'base64')
        );
        raise exception 'Incorrect recovery proof was accepted';
    exception when insufficient_privilege then
        if sqlerrm <> 'RECOVERY_PROOF_INVALID' then raise; end if;
    end;

    perform public.miloom_recover_vault_device(
        (select id from vault_phase4_fixture where name = 'recovery_pending'),
        1,
        encode(set_byte(decode(repeat('32', 65), 'hex'), 0, 4), 'base64'),
        encode(decode(repeat('33', 60), 'hex'), 'base64'),
        encode(decode(repeat('15', 32), 'hex'), 'base64')
    );

    if not exists (
        select 1 from public.miloom_list_vault_devices()
         where device_id = (select id from vault_phase4_fixture where name = 'recovery_pending')
           and status = 'approved'
    ) then
        raise exception 'Valid recovery proof did not approve target device';
    end if;
end;
$$;

rollback;
