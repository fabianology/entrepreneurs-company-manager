-- The password-derived wrapping key is calculated only on the device. Store
-- its version, work factor and random salt with the authenticated ciphertext.
begin;

alter table public.vault_recovery_key_wraps
    drop constraint vault_recovery_key_wraps_wrap_algorithm_check;
alter table public.vault_recovery_key_wraps
    add constraint vault_recovery_key_wraps_wrap_algorithm_check
    check (wrap_algorithm in ('HKDF-SHA256-A256GCM', 'PBKDF2-SHA256-A256GCM'));

create function public.miloom_recovery_wrap_algorithm(p_wrap text)
returns text
language sql immutable set search_path = ''
as $$
    select case
        when public.miloom_is_base64_octets(p_wrap, 60) then 'HKDF-SHA256-A256GCM'
        when p_wrap ~ '^pbkdf2-sha256:v1:600000:[A-Za-z0-9+/]{22}==:[A-Za-z0-9+/]{80}$'
          and public.miloom_is_base64_octets(split_part(p_wrap, ':', 4), 16)
          and public.miloom_is_base64_octets(split_part(p_wrap, ':', 5), 60)
        then 'PBKDF2-SHA256-A256GCM'
    end
$$;
revoke all on function public.miloom_recovery_wrap_algorithm(text) from public, anon, authenticated;

create or replace function public.miloom_bootstrap_account_vault_v2(
    p_device_id uuid,
    p_device_label text,
    p_platform text,
    p_agreement_public_key text,
    p_signing_public_key text,
    p_ephemeral_public_key text,
    p_wrapped_vault_key text,
    p_wrapped_recovery_key text,
    p_key_confirmation text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_label text := btrim(p_device_label);
    v_platform text := lower(btrim(p_platform));
begin
    perform public.miloom_require_recent_access_token();
    if p_device_id is null then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_ID';
    end if;
    if char_length(v_label) not between 1 and 80 then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_LABEL';
    end if;
    if v_platform not in ('ios', 'macos', 'web', 'other') then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_PLATFORM';
    end if;
    if not public.miloom_is_p256_public_key(p_agreement_public_key)
       or not public.miloom_is_p256_public_key(p_signing_public_key)
       or not public.miloom_is_p256_public_key(p_ephemeral_public_key) then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_PUBLIC_KEY';
    end if;
    if not public.miloom_is_base64_octets(p_wrapped_vault_key, 60)
       or public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key) is null
       or not public.miloom_is_base64_octets(p_key_confirmation, 32) then
        raise exception using errcode = '22023', message = 'INVALID_VAULT_KEY_MATERIAL';
    end if;
    if exists (select 1 from public.account_vaults where user_id = v_actor) then
        raise exception using errcode = '23505', message = 'VAULT_ALREADY_INITIALIZED';
    end if;

    insert into public.account_vaults (user_id, key_confirmation)
    values (v_actor, p_key_confirmation);

    insert into public.vault_devices (
        id, user_id, label, platform, agreement_public_key, signing_public_key,
        status, approved_at, last_seen_at
    ) values (
        p_device_id, v_actor, v_label, v_platform,
        p_agreement_public_key, p_signing_public_key,
        'approved', now(), now()
    );

    insert into public.vault_device_key_wraps (
        user_id, device_id, key_version, ephemeral_public_key, wrapped_key
    ) values (v_actor, p_device_id, 1, p_ephemeral_public_key, p_wrapped_vault_key);

    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key, wrap_algorithm)
    values (v_actor, 1, p_wrapped_recovery_key, public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key));

    insert into public.vault_audit_events (
        user_id, actor_device_id, target_device_id, event_type
    ) values (v_actor, p_device_id, p_device_id, 'vault_bootstrapped');

    return jsonb_build_object(
        'device_id', p_device_id,
        'key_version', 1,
        'status', 'approved'
    );
end;
$$;

create function public.miloom_bootstrap_account_vault_for_user(
    p_device_id uuid, p_device_label text, p_platform text, p_agreement_public_key text,
    p_signing_public_key text, p_ephemeral_public_key text, p_wrapped_vault_key text,
    p_wrapped_recovery_key text, p_key_confirmation text, p_expected_user_id uuid
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
    if p_expected_user_id is null or auth.uid() is distinct from p_expected_user_id then
        raise exception using errcode = '42501', message = 'VAULT_ACCOUNT_CHANGED';
    end if;
    return public.miloom_bootstrap_account_vault_v2(
        p_device_id, p_device_label, p_platform, p_agreement_public_key, p_signing_public_key,
        p_ephemeral_public_key, p_wrapped_vault_key, p_wrapped_recovery_key, p_key_confirmation);
end
$$;
revoke all on function public.miloom_bootstrap_account_vault_for_user(uuid,text,text,text,text,text,text,text,text,uuid)
    from public, anon, authenticated;
grant execute on function public.miloom_bootstrap_account_vault_for_user(uuid,text,text,text,text,text,text,text,text,uuid)
    to authenticated;

create function public.miloom_revoke_vault_device_and_rotate_with_recovery(
    p_actor_device_id uuid,
    p_revoked_device_id uuid,
    p_new_key_version integer,
    p_device_wraps jsonb,
    p_wrapped_recovery_key text,
    p_new_key_confirmation text,
    p_current_key_confirmation text,
    p_wrapped_previous_key text,
    p_expected_recovery_wrap_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_current_version integer;
    v_expected_devices integer;
    v_supplied_devices integer;
    v_valid_devices integer;
    v_wrap record;
begin
    perform public.miloom_require_recent_access_token();
    if p_actor_device_id = p_revoked_device_id then
        raise exception using errcode = '22023', message = 'CURRENT_DEVICE_CANNOT_BE_REVOKED';
    end if;
    if jsonb_typeof(p_device_wraps) <> 'array' then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_WRAPS';
    end if;
    if public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key) is null
       or not public.miloom_is_base64_octets(p_new_key_confirmation, 32)
       or not public.miloom_is_base64_octets(p_current_key_confirmation, 32)
       or not public.miloom_is_base64_octets(p_wrapped_previous_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_VAULT_KEY_MATERIAL';
    end if;

    select current_key_version into v_current_version
      from public.account_vaults
     where user_id = v_actor
       and key_confirmation = p_current_key_confirmation
       and rotation_status = 'stable'
     for update;
    if v_current_version is null then
        raise exception using errcode = '42501', message = 'VAULT_PROOF_INVALID';
    end if;
    if p_new_key_version <> v_current_version + 1 then
        raise exception using errcode = '22023', message = 'INVALID_KEY_VERSION';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = p_actor_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'ACTOR_DEVICE_NOT_APPROVED';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = p_revoked_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = 'P0002', message = 'APPROVED_DEVICE_NOT_FOUND';
    end if;

    select count(*) into v_expected_devices
      from public.vault_devices
     where user_id = v_actor and status = 'approved' and id <> p_revoked_device_id;

    select count(*) into v_supplied_devices
      from jsonb_to_recordset(p_device_wraps)
        as supplied(device_id uuid, ephemeral_public_key text, wrapped_key text);

    -- Recompute separately so duplicate ids cannot satisfy the exact-set check.
    select count(*) into v_valid_devices
      from jsonb_to_recordset(p_device_wraps)
        as supplied(device_id uuid, ephemeral_public_key text, wrapped_key text)
     where public.miloom_is_p256_public_key(ephemeral_public_key)
       and public.miloom_is_base64_octets(wrapped_key, 60)
       and exists (
           select 1 from public.vault_devices d
            where d.id = supplied.device_id
              and d.user_id = v_actor
              and d.status = 'approved'
              and d.id <> p_revoked_device_id
       );

    if v_supplied_devices <> v_expected_devices
       or v_valid_devices <> v_expected_devices
       or (select count(distinct device_id) from jsonb_to_recordset(p_device_wraps)
             as supplied(device_id uuid, ephemeral_public_key text, wrapped_key text)) <> v_expected_devices then
        raise exception using errcode = '22023', message = 'DEVICE_WRAP_SET_MISMATCH';
    end if;

    update public.vault_devices
       set status = 'revoked', revoked_at = now()
     where id = p_revoked_device_id and user_id = v_actor;
    delete from auth.sessions session
     using public.vault_devices device
     where device.id = p_revoked_device_id
       and device.user_id = v_actor
       and device.auth_session_id = session.id
       and session.user_id = v_actor;
    update public.vault_device_key_wraps
       set revoked_at = now()
     where user_id = v_actor and revoked_at is null;
    if not exists (
        select 1 from public.vault_recovery_key_wraps
         where user_id = v_actor and key_version = v_current_version
           and revoked_at is null
           and wrap_algorithm = public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key)
           and (id = p_expected_recovery_wrap_id
                or (p_expected_recovery_wrap_id is null and wrap_algorithm = 'HKDF-SHA256-A256GCM'))
    ) then
        raise exception using errcode = '22023', message = 'RECOVERY_METHOD_CHANGED';
    end if;

    update public.vault_recovery_key_wraps
       set revoked_at = now()
     where user_id = v_actor and revoked_at is null;

    for v_wrap in
        select * from jsonb_to_recordset(p_device_wraps)
          as supplied(device_id uuid, ephemeral_public_key text, wrapped_key text)
    loop
        insert into public.vault_device_key_wraps (
            user_id, device_id, key_version, ephemeral_public_key, wrapped_key
        ) values (
            v_actor, v_wrap.device_id, p_new_key_version,
            v_wrap.ephemeral_public_key, v_wrap.wrapped_key
        );
    end loop;

    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key, wrap_algorithm)
    values (v_actor, p_new_key_version, p_wrapped_recovery_key, public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key));
    insert into public.vault_key_transitions (
        user_id, from_key_version, to_key_version, wrapped_previous_key
    ) values (
        v_actor, v_current_version, p_new_key_version, p_wrapped_previous_key
    );
    update public.account_vaults
       set current_key_version = p_new_key_version,
           previous_key_version = v_current_version,
           rotation_status = 'migrating',
           key_confirmation = p_new_key_confirmation,
           rotated_at = now(),
           updated_at = now()
     where user_id = v_actor;

    insert into public.vault_audit_events (
        user_id, actor_device_id, target_device_id, event_type, details
    ) values
        (v_actor, p_actor_device_id, p_revoked_device_id, 'device_revoked', '{}'::jsonb),
        (v_actor, p_actor_device_id, null, 'vault_key_rotated',
         jsonb_build_object('from_version', v_current_version, 'to_version', p_new_key_version));
end;
$$;


revoke all on function public.miloom_revoke_vault_device_and_rotate_with_recovery(uuid,uuid,integer,jsonb,text,text,text,text,uuid)
    from public, anon, authenticated;
grant execute on function public.miloom_revoke_vault_device_and_rotate_with_recovery(uuid,uuid,integer,jsonb,text,text,text,text,uuid)
    to authenticated;

create or replace function public.miloom_revoke_vault_device_and_rotate(
    p_actor_device_id uuid, p_revoked_device_id uuid, p_new_key_version integer, p_device_wraps jsonb,
    p_wrapped_recovery_key text, p_new_key_confirmation text, p_current_key_confirmation text,
    p_wrapped_previous_key text
)
returns void language sql security definer set search_path = ''
as $$
    select public.miloom_revoke_vault_device_and_rotate_with_recovery(
        p_actor_device_id, p_revoked_device_id, p_new_key_version, p_device_wraps,
        p_wrapped_recovery_key, p_new_key_confirmation, p_current_key_confirmation, p_wrapped_previous_key, null);
$$;

create or replace function public.miloom_rotate_vault_recovery(
    p_actor_device_id uuid,
    p_key_version integer,
    p_wrapped_recovery_key text,
    p_key_confirmation text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
begin
    perform public.miloom_require_recent_access_token();
    if public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key) is null then
        raise exception using errcode = '22023', message = 'INVALID_RECOVERY_WRAP';
    end if;
    perform public.miloom_require_current_resource_device(p_actor_device_id);
    perform 1 from public.account_vaults where user_id = v_actor for update;
    if not exists (
        select 1 from public.account_vaults
         where user_id = v_actor
           and current_key_version = p_key_version
           and key_confirmation = p_key_confirmation
    ) or not exists (
        select 1 from public.vault_devices
         where id = p_actor_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'VAULT_PROOF_INVALID';
    end if;

    update public.vault_recovery_key_wraps
       set revoked_at = now()
     where user_id = v_actor and key_version = p_key_version and revoked_at is null;
    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key, wrap_algorithm)
    values (v_actor, p_key_version, p_wrapped_recovery_key, public.miloom_recovery_wrap_algorithm(p_wrapped_recovery_key));
    insert into public.vault_audit_events (
        user_id, actor_device_id, event_type
    ) values (v_actor, p_actor_device_id, 'recovery_rotated');
end;
$$;

notify pgrst, 'reload schema';
commit;
