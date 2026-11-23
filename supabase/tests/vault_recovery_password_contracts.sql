-- Run with the vault and device grants in an isolated Auth database.
begin;
insert into auth.users(id) values ('95000000-0000-0000-0000-000000000901');
select set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-000000000901', true);
select set_config('request.jwt.claims', jsonb_build_object(
    'sub','95000000-0000-0000-0000-000000000901',
    'session_id','95000000-0000-0000-0000-000000000902',
    'iat',extract(epoch from now())::bigint
)::text, true);
set local role authenticated;
do $$
declare
    v_user uuid := auth.uid();
    v_device uuid := '95000000-0000-0000-0000-000000000903';
    v_pub text := encode(decode('04' || repeat('10', 64), 'hex'), 'base64');
    v_envelope text := replace(encode(decode(repeat('14', 60), 'hex'), 'base64'), chr(10), '');
    v_confirmation text := encode(decode(repeat('15', 32), 'hex'), 'base64');
    v_method text := 'pbkdf2-sha256:v1:600000:' || encode(decode(repeat('16',16),'hex'),'base64') || ':' || v_envelope;
begin
    begin
        perform public.miloom_bootstrap_account_vault_for_user(v_device,'iPhone','ios',
            v_pub,v_pub,v_pub,v_envelope,v_method,v_confirmation,gen_random_uuid());
        raise exception 'Vault setup succeeded for the wrong signed-in account';
    exception when insufficient_privilege then null;
    end;
    perform public.miloom_bootstrap_account_vault_for_user(v_device,'iPhone','ios',
        v_pub,v_pub,v_pub,v_envelope,v_method,v_confirmation,v_user);
    if not exists (select from public.vault_recovery_key_wraps
        where user_id = v_user and wrapped_key = v_method and wrap_algorithm = 'PBKDF2-SHA256-A256GCM') then
        raise exception 'Password recovery metadata was lost';
    end if;
    begin
        perform public.miloom_rotate_vault_recovery(v_device,1,replace(v_method,'600000','1'),v_confirmation);
        raise exception 'Invalid recovery cost was accepted';
    exception when invalid_parameter_value then null;
    end;

    perform public.miloom_rotate_vault_recovery(v_device,1,v_envelope,v_confirmation);
    if not exists (select from public.vault_recovery_key_wraps
        where user_id = v_user and wrapped_key = v_envelope and revoked_at is null
          and wrap_algorithm = 'HKDF-SHA256-A256GCM')
       or exists (select from public.vault_recovery_key_wraps
        where user_id = v_user and wrapped_key = v_method and revoked_at is null) then
        raise exception 'Replacement left the old method active';
    end if;
end
$$;

reset role;
insert into public.vault_devices (
    id,user_id,label,platform,agreement_public_key,signing_public_key,status,approved_at
)
select '95000000-0000-0000-0000-000000000904',auth.uid(),'Second phone','ios',
       encode(decode('04'||repeat('30',64),'hex'),'base64'),
       encode(decode('04'||repeat('31',64),'hex'),'base64'),'approved',now();
set local role authenticated;
do $$
declare
    v_device uuid := '95000000-0000-0000-0000-000000000903';
    v_revoked uuid := '95000000-0000-0000-0000-000000000904';
    v_pub text := encode(decode('04'||repeat('10',64),'hex'),'base64');
    v_envelope text := replace(encode(decode(repeat('14',60),'hex'),'base64'), chr(10), '');
    v_old_confirmation text := encode(decode(repeat('15',32),'hex'),'base64');
    v_new_confirmation text := encode(decode(repeat('35',32),'hex'),'base64');
    v_password_wrap text := 'pbkdf2-sha256:v1:600000:' || encode(decode(repeat('16',16),'hex'),'base64') || ':' || v_envelope;
    v_id uuid;
    v_devices jsonb := jsonb_build_array(jsonb_build_object(
        'device_id',v_device,'ephemeral_public_key',v_pub,'wrapped_key',v_envelope));
begin
    perform public.miloom_rotate_vault_recovery(v_device,1,v_password_wrap,v_old_confirmation);
    select id into strict v_id from public.vault_recovery_key_wraps
        where user_id = auth.uid() and key_version = 1 and revoked_at is null;
    begin
        perform public.miloom_revoke_vault_device_and_rotate_with_recovery(v_device,v_revoked,
            2,v_devices,v_envelope,v_new_confirmation,v_old_confirmation,v_envelope,v_id);
        raise exception 'Device revocation replaced the recovery password with a generated key';
    exception when invalid_parameter_value then
        if sqlerrm <> 'RECOVERY_METHOD_CHANGED' then raise; end if;
    end;
    begin
        perform public.miloom_revoke_vault_device_and_rotate_with_recovery(v_device,v_revoked,
            2,v_devices,v_password_wrap,v_new_confirmation,v_old_confirmation,v_envelope,gen_random_uuid());
        raise exception 'Device revocation accepted a stale recovery wrap';
    exception when invalid_parameter_value then
        if sqlerrm <> 'RECOVERY_METHOD_CHANGED' then raise; end if;
    end;
    perform public.miloom_revoke_vault_device_and_rotate_with_recovery(v_device,v_revoked,
        2,v_devices,v_password_wrap,v_new_confirmation,v_old_confirmation,v_envelope,v_id);
    if not exists (select from public.vault_recovery_key_wraps where user_id=auth.uid() and key_version=2
        and wrap_algorithm='PBKDF2-SHA256-A256GCM' and revoked_at is null)
       or not exists (select from public.vault_devices where id=v_revoked and status='revoked') then
        raise exception 'The password wrap was not retained after device revocation';
    end if;
end
$$;
rollback;
