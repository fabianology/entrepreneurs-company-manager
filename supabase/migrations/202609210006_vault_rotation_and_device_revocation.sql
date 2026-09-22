-- Phase 5: trusted-device revocation, resumable account-key rotation, and
-- recovery-code rotation. Ordinary resource shares still grant no vault key.

begin;

alter table public.account_vaults
    add column if not exists rotation_status text not null default 'stable',
    add column if not exists previous_key_version integer;

alter table public.vault_devices
    add column if not exists auth_session_id uuid;

create or replace function public.miloom_capture_vault_device_session()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
    if new.auth_session_id is null and auth.uid() = new.user_id then
        new.auth_session_id := nullif(auth.jwt() ->> 'session_id', '')::uuid;
    end if;
    return new;
end;
$$;

drop trigger if exists vault_devices_capture_session on public.vault_devices;
create trigger vault_devices_capture_session
before insert on public.vault_devices
for each row execute function public.miloom_capture_vault_device_session();
revoke all on function public.miloom_capture_vault_device_session() from public, anon, authenticated;

alter table public.account_vaults
    drop constraint if exists account_vaults_rotation_status_check;
alter table public.account_vaults
    add constraint account_vaults_rotation_status_check
    check (rotation_status in ('stable', 'migrating'));
alter table public.account_vaults
    drop constraint if exists account_vaults_previous_version_check;
alter table public.account_vaults
    add constraint account_vaults_previous_version_check
    check (
        (rotation_status = 'stable' and previous_key_version is null)
        or
        (rotation_status = 'migrating' and previous_key_version = current_key_version - 1)
    );

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
        'vault_key_rotated',
        'vault_rotation_completed'
    ));

create table if not exists public.vault_key_transitions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    from_key_version integer not null check (from_key_version > 0),
    to_key_version integer not null check (to_key_version = from_key_version + 1),
    wrap_algorithm text not null default 'A256GCM'
        check (wrap_algorithm = 'A256GCM'),
    wrapped_previous_key text not null,
    created_at timestamptz not null default now(),
    completed_at timestamptz,
    unique (user_id, from_key_version, to_key_version)
);

create unique index if not exists vault_key_transitions_active_idx
    on public.vault_key_transitions (user_id)
    where completed_at is null;

alter table public.vault_key_transitions enable row level security;
drop policy if exists vault_key_transitions_owner_read on public.vault_key_transitions;
create policy vault_key_transitions_owner_read on public.vault_key_transitions
for select to authenticated using (user_id = auth.uid() and completed_at is null);
revoke all on table public.vault_key_transitions from public, anon, authenticated;
grant select (user_id, from_key_version, to_key_version, wrap_algorithm, wrapped_previous_key, created_at, completed_at)
    on public.vault_key_transitions to authenticated;

grant select (rotation_status, previous_key_version)
    on public.account_vaults to authenticated;
revoke all on table public.vault_devices from authenticated;
grant select (
    id, user_id, label, platform, agreement_public_key, signing_public_key,
    public_key_format, status, created_at, approved_at, revoked_at, last_seen_at
) on public.vault_devices to authenticated;

create or replace function public.miloom_bind_vault_device_session(
    p_device_id uuid,
    p_key_confirmation text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_session_id uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
    if v_session_id is null then
        raise exception using errcode = '42501', message = 'SESSION_ID_REQUIRED';
    end if;
    if not exists (
        select 1 from public.account_vaults
         where user_id = v_actor and key_confirmation = p_key_confirmation
    ) then
        raise exception using errcode = '42501', message = 'VAULT_PROOF_INVALID';
    end if;
    update public.vault_devices
       set auth_session_id = v_session_id, last_seen_at = now()
     where id = p_device_id and user_id = v_actor and status = 'approved';
    if not found then
        raise exception using errcode = 'P0002', message = 'APPROVED_DEVICE_NOT_FOUND';
    end if;
end;
$$;

create or replace function public.miloom_revoke_pending_vault_device(
    p_actor_device_id uuid,
    p_target_device_id uuid,
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
    if p_actor_device_id = p_target_device_id then
        raise exception using errcode = '22023', message = 'CURRENT_DEVICE_CANNOT_BE_REVOKED';
    end if;
    if not exists (
        select 1 from public.account_vaults
         where user_id = v_actor and key_confirmation = p_key_confirmation
    ) or not exists (
        select 1 from public.vault_devices
         where id = p_actor_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'VAULT_PROOF_INVALID';
    end if;

    update public.vault_devices
       set status = 'revoked', revoked_at = now()
     where id = p_target_device_id and user_id = v_actor and status = 'pending';
    if not found then
        raise exception using errcode = 'P0002', message = 'PENDING_DEVICE_NOT_FOUND';
    end if;

    delete from public.vault_device_approval_challenges
     where user_id = v_actor and target_device_id = p_target_device_id and consumed_at is null;
    insert into public.vault_audit_events (
        user_id, actor_device_id, target_device_id, event_type
    ) values (v_actor, p_actor_device_id, p_target_device_id, 'device_revoked');
end;
$$;

create or replace function public.miloom_revoke_vault_device_and_rotate(
    p_actor_device_id uuid,
    p_revoked_device_id uuid,
    p_new_key_version integer,
    p_device_wraps jsonb,
    p_wrapped_recovery_key text,
    p_new_key_confirmation text,
    p_current_key_confirmation text,
    p_wrapped_previous_key text
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
    if not public.miloom_is_base64_octets(p_wrapped_recovery_key, 60)
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

    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key)
    values (v_actor, p_new_key_version, p_wrapped_recovery_key);
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

create or replace function public.miloom_complete_vault_rotation(
    p_actor_device_id uuid,
    p_key_version integer,
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
    if not exists (
        select 1 from public.account_vaults
         where user_id = v_actor
           and current_key_version = p_key_version
           and key_confirmation = p_key_confirmation
           and rotation_status = 'migrating'
    ) or not exists (
        select 1 from public.vault_devices
         where id = p_actor_device_id and user_id = v_actor and status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'VAULT_PROOF_INVALID';
    end if;

    update public.vault_key_transitions
       set completed_at = now()
     where user_id = v_actor and to_key_version = p_key_version and completed_at is null;
    if not found then
        raise exception using errcode = 'P0002', message = 'ACTIVE_ROTATION_NOT_FOUND';
    end if;
    update public.account_vaults
       set rotation_status = 'stable', previous_key_version = null, updated_at = now()
     where user_id = v_actor;
    insert into public.vault_audit_events (
        user_id, actor_device_id, event_type, details
    ) values (
        v_actor, p_actor_device_id, 'vault_rotation_completed',
        jsonb_build_object('key_version', p_key_version)
    );
end;
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
    if not public.miloom_is_base64_octets(p_wrapped_recovery_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_RECOVERY_WRAP';
    end if;
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
    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key)
    values (v_actor, p_key_version, p_wrapped_recovery_key);
    insert into public.vault_audit_events (
        user_id, actor_device_id, event_type
    ) values (v_actor, p_actor_device_id, 'recovery_rotated');
end;
$$;

revoke all on function public.miloom_revoke_pending_vault_device(uuid, uuid, text) from public, anon;
revoke all on function public.miloom_bind_vault_device_session(uuid, text) from public, anon;
revoke all on function public.miloom_revoke_vault_device_and_rotate(uuid, uuid, integer, jsonb, text, text, text, text) from public, anon;
revoke all on function public.miloom_complete_vault_rotation(uuid, integer, text) from public, anon;
revoke all on function public.miloom_rotate_vault_recovery(uuid, integer, text, text) from public, anon;
grant execute on function public.miloom_revoke_pending_vault_device(uuid, uuid, text) to authenticated;
grant execute on function public.miloom_bind_vault_device_session(uuid, text) to authenticated;
grant execute on function public.miloom_revoke_vault_device_and_rotate(uuid, uuid, integer, jsonb, text, text, text, text) to authenticated;
grant execute on function public.miloom_complete_vault_rotation(uuid, integer, text) to authenticated;
grant execute on function public.miloom_rotate_vault_recovery(uuid, integer, text, text) to authenticated;

notify pgrst, 'reload schema';

commit;
