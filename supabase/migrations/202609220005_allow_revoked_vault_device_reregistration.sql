-- Allow a revoked vault device to request access again without restoring its
-- former key material or bypassing the normal approval/recovery boundary.

begin;

create or replace function public.miloom_register_vault_device(
    p_device_label text,
    p_platform text,
    p_agreement_public_key text,
    p_signing_public_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_device public.vault_devices%rowtype;
    v_device_id uuid;
    v_label text := btrim(p_device_label);
    v_platform text := lower(btrim(p_platform));
begin
    perform public.miloom_require_recent_access_token();

    -- Serialize registrations for one vault so retries cannot create competing
    -- rows for the same public-key identity.
    perform 1
      from public.account_vaults
     where user_id = v_actor
     for update;
    if not found then
        raise exception using errcode = 'P0002', message = 'VAULT_NOT_INITIALIZED';
    end if;
    if char_length(v_label) not between 1 and 80 then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_LABEL';
    end if;
    if v_platform not in ('ios', 'macos', 'web', 'other') then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_PLATFORM';
    end if;
    if not public.miloom_is_p256_public_key(p_agreement_public_key)
       or not public.miloom_is_p256_public_key(p_signing_public_key) then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_PUBLIC_KEY';
    end if;

    -- A key may only be reused with its original paired device identity.
    if exists (
        select 1
          from public.vault_devices
         where user_id = v_actor
           and (
               (agreement_public_key = p_agreement_public_key
                and signing_public_key <> p_signing_public_key)
               or
               (signing_public_key = p_signing_public_key
                and agreement_public_key <> p_agreement_public_key)
           )
    ) then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_IDENTITY';
    end if;

    select *
      into v_device
      from public.vault_devices
     where user_id = v_actor
       and agreement_public_key = p_agreement_public_key
       and signing_public_key = p_signing_public_key
     for update;

    if found then
        if v_device.status = 'revoked' then
            -- Defense in depth: re-enrollment never revives an earlier wrap.
            update public.vault_device_key_wraps
               set revoked_at = coalesce(revoked_at, now())
             where user_id = v_actor
               and device_id = v_device.id
               and revoked_at is null;

            delete from public.vault_device_approval_challenges
             where user_id = v_actor
               and target_device_id = v_device.id
               and consumed_at is null;

            update public.vault_devices
               set label = v_label,
                   platform = v_platform,
                   status = 'pending',
                   approved_at = null,
                   revoked_at = null,
                   last_seen_at = null,
                   auth_session_id = null
             where id = v_device.id;

            insert into public.vault_audit_events (
                user_id, target_device_id, event_type, details
            ) values (
                v_actor,
                v_device.id,
                'device_registration_requested',
                jsonb_build_object('re_enrollment', true)
            );

            return jsonb_build_object(
                'device_id', v_device.id,
                'status', 'pending',
                're_enrolled', true
            );
        end if;

        -- Registration requests are safe to retry and never downgrade an
        -- already approved device.
        return jsonb_build_object(
            'device_id', v_device.id,
            'status', v_device.status,
            're_enrolled', false
        );
    end if;

    insert into public.vault_devices (
        user_id, label, platform, agreement_public_key, signing_public_key, status
    ) values (
        v_actor, v_label, v_platform, p_agreement_public_key, p_signing_public_key, 'pending'
    ) returning id into v_device_id;

    insert into public.vault_audit_events (
        user_id, target_device_id, event_type
    ) values (
        v_actor, v_device_id, 'device_registration_requested'
    );

    return jsonb_build_object(
        'device_id', v_device_id,
        'status', 'pending',
        're_enrolled', false
    );
end;
$$;

revoke all on function public.miloom_register_vault_device(text, text, text, text)
    from public, anon;
grant execute on function public.miloom_register_vault_device(text, text, text, text)
    to authenticated;

notify pgrst, 'reload schema';

commit;
