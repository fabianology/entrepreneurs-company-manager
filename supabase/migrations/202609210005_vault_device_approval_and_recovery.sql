-- Phase 4: one-time signed device approvals, recovery proof, and a bootstrap
-- contract whose client-generated device id can be authenticated by the wrap.

begin;

alter table public.account_vaults
    add column if not exists key_confirmation text;

alter table public.account_vaults
    drop constraint if exists account_vaults_key_confirmation_check;
alter table public.account_vaults
    add constraint account_vaults_key_confirmation_check
    check (key_confirmation is null or public.miloom_is_base64_octets(key_confirmation, 32));

alter table public.vault_audit_events
    drop constraint if exists vault_audit_events_event_type_check;
alter table public.vault_audit_events
    add constraint vault_audit_events_event_type_check check (event_type in (
        'vault_bootstrapped',
        'device_registration_requested',
        'device_approved',
        'device_revoked',
        'recovery_device_approved',
        'recovery_rotated',
        'vault_key_rotated'
    ));

create table if not exists public.vault_device_approval_challenges (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    actor_device_id uuid not null references public.vault_devices(id) on delete cascade,
    target_device_id uuid not null references public.vault_devices(id) on delete cascade,
    key_version integer not null check (key_version > 0),
    nonce text not null check (char_length(nonce) between 40 and 64),
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '5 minutes'),
    consumed_at timestamptz,
    check (expires_at > created_at),
    check (actor_device_id <> target_device_id)
);

create index if not exists vault_approval_challenges_lookup_idx
    on public.vault_device_approval_challenges (user_id, id)
    where consumed_at is null;

alter table public.vault_device_approval_challenges enable row level security;
revoke all on table public.vault_device_approval_challenges from public, anon, authenticated;

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
       or not public.miloom_is_base64_octets(p_wrapped_recovery_key, 60)
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

    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key)
    values (v_actor, 1, p_wrapped_recovery_key);

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

create or replace function public.miloom_create_vault_approval_challenge(
    p_actor_device_id uuid,
    p_target_device_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
    v_actor uuid := auth.uid();
    v_key_version integer;
    v_challenge_id uuid;
    v_nonce text;
begin
    perform public.miloom_require_recent_access_token();
    select current_key_version into v_key_version
      from public.account_vaults
     where user_id = v_actor;
    if v_key_version is null then
        raise exception using errcode = 'P0002', message = 'VAULT_NOT_INITIALIZED';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = p_actor_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'APPROVING_DEVICE_NOT_AUTHORIZED';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = p_target_device_id and user_id = v_actor and status = 'pending'
    ) then
        raise exception using errcode = 'P0002', message = 'PENDING_DEVICE_NOT_FOUND';
    end if;

    delete from public.vault_device_approval_challenges
     where user_id = v_actor
       and actor_device_id = p_actor_device_id
       and target_device_id = p_target_device_id
       and consumed_at is null;

    v_challenge_id := gen_random_uuid();
    v_nonce := translate(encode(gen_random_bytes(32), 'base64'), E'+/=\n', '-_');
    insert into public.vault_device_approval_challenges (
        id, user_id, actor_device_id, target_device_id, key_version, nonce
    ) values (
        v_challenge_id, v_actor, p_actor_device_id, p_target_device_id,
        v_key_version, v_nonce
    );

    return jsonb_build_object(
        'challenge_id', v_challenge_id,
        'nonce', v_nonce,
        'key_version', v_key_version,
        'expires_at', now() + interval '5 minutes'
    );
end;
$$;

create or replace function public.miloom_consume_vault_approval_challenge(
    p_user_id uuid,
    p_challenge_id uuid,
    p_actor_device_id uuid,
    p_target_device_id uuid,
    p_key_version integer,
    p_ephemeral_public_key text,
    p_wrapped_vault_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_consumed uuid;
begin
    update public.vault_device_approval_challenges
       set consumed_at = now()
     where id = p_challenge_id
       and user_id = p_user_id
       and actor_device_id = p_actor_device_id
       and target_device_id = p_target_device_id
       and key_version = p_key_version
       and consumed_at is null
       and expires_at > now()
    returning id into v_consumed;
    if v_consumed is null then
        raise exception using errcode = '42501', message = 'APPROVAL_CHALLENGE_INVALID';
    end if;

    perform public.miloom_finalize_vault_device_approval(
        p_user_id,
        p_actor_device_id,
        p_target_device_id,
        p_key_version,
        p_ephemeral_public_key,
        p_wrapped_vault_key
    );
end;
$$;

create or replace function public.miloom_recover_vault_device(
    p_device_id uuid,
    p_key_version integer,
    p_ephemeral_public_key text,
    p_wrapped_vault_key text,
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
    if not public.miloom_is_p256_public_key(p_ephemeral_public_key)
       or not public.miloom_is_base64_octets(p_wrapped_vault_key, 60)
       or not public.miloom_is_base64_octets(p_key_confirmation, 32) then
        raise exception using errcode = '22023', message = 'INVALID_VAULT_KEY_MATERIAL';
    end if;
    if not exists (
        select 1 from public.account_vaults
         where user_id = v_actor
           and current_key_version = p_key_version
           and key_confirmation = p_key_confirmation
    ) then
        raise exception using errcode = '42501', message = 'RECOVERY_PROOF_INVALID';
    end if;
    if not exists (
        select 1 from public.vault_devices
         where id = p_device_id and user_id = v_actor and status = 'pending'
    ) then
        raise exception using errcode = 'P0002', message = 'PENDING_DEVICE_NOT_FOUND';
    end if;

    insert into public.vault_device_key_wraps (
        user_id, device_id, key_version, ephemeral_public_key, wrapped_key
    ) values (
        v_actor, p_device_id, p_key_version, p_ephemeral_public_key, p_wrapped_vault_key
    )
    on conflict (user_id, device_id, key_version) where revoked_at is null
    do update set
        ephemeral_public_key = excluded.ephemeral_public_key,
        wrapped_key = excluded.wrapped_key,
        created_at = now();

    update public.vault_devices
       set status = 'approved', approved_at = now(), revoked_at = null, last_seen_at = now()
     where id = p_device_id and user_id = v_actor;

    insert into public.vault_audit_events (
        user_id, target_device_id, event_type
    ) values (v_actor, p_device_id, 'recovery_device_approved');
end;
$$;

-- The legacy bootstrap cannot produce a record-bound self wrap because its
-- server-generated device id is unknown to the client before encryption.
revoke all on function public.miloom_bootstrap_account_vault(text, text, text, text, text, text, text)
    from public, anon, authenticated;

revoke all on table public.account_vaults from authenticated;
grant select (user_id, current_key_version, field_algorithm, created_at, rotated_at, updated_at)
    on public.account_vaults to authenticated;

revoke all on function public.miloom_bootstrap_account_vault_v2(uuid, text, text, text, text, text, text, text, text)
    from public, anon;
revoke all on function public.miloom_create_vault_approval_challenge(uuid, uuid)
    from public, anon;
revoke all on function public.miloom_consume_vault_approval_challenge(uuid, uuid, uuid, uuid, integer, text, text)
    from public, anon, authenticated;
revoke all on function public.miloom_recover_vault_device(uuid, integer, text, text, text)
    from public, anon;

grant execute on function public.miloom_bootstrap_account_vault_v2(uuid, text, text, text, text, text, text, text, text)
    to authenticated;
grant execute on function public.miloom_create_vault_approval_challenge(uuid, uuid)
    to authenticated;
grant execute on function public.miloom_consume_vault_approval_challenge(uuid, uuid, uuid, uuid, integer, text, text)
    to service_role;
grant execute on function public.miloom_recover_vault_device(uuid, integer, text, text, text)
    to authenticated;

notify pgrst, 'reload schema';

commit;
