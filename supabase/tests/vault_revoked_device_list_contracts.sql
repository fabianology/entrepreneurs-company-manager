-- Run against an isolated Auth database after applying the vault migrations.
begin;

insert into auth.users (id) values
    ('97000000-0000-0000-0000-000000000001'),
    ('97000000-0000-0000-0000-000000000002');
insert into public.account_vaults (user_id, key_confirmation) values
    ('97000000-0000-0000-0000-000000000001', encode(decode(repeat('15', 32), 'hex'), 'base64'));

insert into public.vault_devices (
    id, user_id, label, platform, agreement_public_key, signing_public_key, status, auth_session_id
)
select id::uuid, user_id::uuid, label, 'ios',
       encode(decode('04' || repeat(key_octet, 64), 'hex'), 'base64'),
       encode(decode('04' || repeat(key_octet, 63) || 'f0', 'hex'), 'base64'),
       status, session_id::uuid
  from (values
    ('97000000-0000-0000-0000-000000000101', '97000000-0000-0000-0000-000000000001', 'First iPhone', '01', 'approved', '97000000-0000-0000-0000-000000000201'),
    ('97000000-0000-0000-0000-000000000102', '97000000-0000-0000-0000-000000000001', 'Second iPhone', '02', 'approved', '97000000-0000-0000-0000-000000000202'),
    ('97000000-0000-0000-0000-000000000103', '97000000-0000-0000-0000-000000000001', 'Old phone', '03', 'revoked', null),
    ('97000000-0000-0000-0000-000000000104', '97000000-0000-0000-0000-000000000001', 'New request', '04', 'pending', null),
    ('97000000-0000-0000-0000-000000000105', '97000000-0000-0000-0000-000000000002', 'Other account phone', '05', 'revoked', null)
  ) devices(id, user_id, label, key_octet, status, session_id);

insert into public.vault_audit_events (user_id, actor_device_id, target_device_id, event_type) values
    ('97000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000101',
     '97000000-0000-0000-0000-000000000103', 'device_revoked');
insert into public.vault_device_key_wraps (user_id, device_id, key_version, ephemeral_public_key, wrapped_key, revoked_at)
values ('97000000-0000-0000-0000-000000000001', '97000000-0000-0000-0000-000000000103', 1, 'synthetic', 'synthetic', now());

set local role authenticated;
select set_config('request.jwt.claim.sub', '97000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', jsonb_build_object(
    'sub', '97000000-0000-0000-0000-000000000001',
    'session_id', '97000000-0000-0000-0000-000000000201',
    'iat', extract(epoch from now())::bigint
)::text, true);

do $$
declare
    first_device constant uuid := '97000000-0000-0000-0000-000000000101';
    second_device constant uuid := '97000000-0000-0000-0000-000000000102';
    revoked_device constant uuid := '97000000-0000-0000-0000-000000000103';
    pending_device constant uuid := '97000000-0000-0000-0000-000000000104';
    other_device constant uuid := '97000000-0000-0000-0000-000000000105';
    target uuid;
    reenrollment jsonb;
begin
    if has_function_privilege('anon', 'public.miloom_remove_revoked_vault_device_from_list(uuid,uuid)', 'execute')
       or has_column_privilege('authenticated', 'public.vault_devices', 'removed_from_list_at', 'update') then
        raise exception 'The list visibility write can bypass its authenticated RPC';
    end if;
    foreach target in array array[first_device, second_device, pending_device, other_device] loop
        begin
            perform public.miloom_remove_revoked_vault_device_from_list(first_device, target);
            raise exception 'A removal accepted a target outside the owned revoked list';
        exception when no_data_found then
            if sqlerrm <> 'REVOKED_DEVICE_NOT_FOUND' then raise; end if;
        end;
    end loop;
    begin
        perform public.miloom_remove_revoked_vault_device_from_list(second_device, revoked_device);
        raise exception 'A session used a different trusted device as its actor';
    exception when insufficient_privilege then
        if sqlerrm <> 'TRUSTED_DEVICE_REQUIRED' then raise; end if;
    end;

    if not exists (select from public.miloom_list_vault_devices() where device_id = revoked_device and status = 'revoked') then
        raise exception 'A revoked device was hidden before removal';
    end if;
    perform public.miloom_remove_revoked_vault_device_from_list(first_device, revoked_device);
    perform public.miloom_remove_revoked_vault_device_from_list(first_device, revoked_device);

    perform set_config('request.jwt.claims', jsonb_set(
        auth.jwt(), '{session_id}', to_jsonb('97000000-0000-0000-0000-000000000202'::text)
    )::text, true);
    if exists (select from public.miloom_list_vault_devices() where device_id = revoked_device)
       or (select count(*) from public.miloom_list_vault_devices()) <> 3 then
        raise exception 'The second trusted session saw the removed entry or lost another entry';
    end if;
    if not exists (select from public.vault_audit_events where target_device_id = revoked_device and event_type = 'device_revoked')
       or not exists (select from public.vault_devices where id = revoked_device and status = 'revoked')
       or not exists (select from public.vault_device_key_wraps where device_id = revoked_device and revoked_at is not null) then
        raise exception 'Removing the entry changed the revocation record, key wrap, or audit history';
    end if;

    reenrollment := public.miloom_register_vault_device('Old phone', 'ios',
        encode(decode('04' || repeat('03', 64), 'hex'), 'base64'),
        encode(decode('04' || repeat('03', 63) || 'f0', 'hex'), 'base64'));
    if (reenrollment ->> 'device_id')::uuid is distinct from revoked_device
        or not exists (select from public.miloom_list_vault_devices() where device_id = revoked_device and status = 'pending')
        or exists (select from public.vault_device_key_wraps where device_id = revoked_device and revoked_at is null) then
        raise exception 'Re-enrollment failed to restore a visible, unapproved request';
    end if;
    perform public.miloom_revoke_pending_vault_device(second_device, revoked_device, encode(decode(repeat('15', 32), 'hex'), 'base64'));
    if not exists (select from public.miloom_list_vault_devices() where device_id = revoked_device and status = 'revoked') then
        raise exception 'A newly revoked request inherited its prior list removal';
    end if;
end;
$$;

rollback;
