-- Zero-knowledge vault key foundation.
-- This migration stores public keys and encrypted key wraps only. It never
-- accepts or stores a plaintext account vault key or recovery code.

begin;

create table if not exists public.account_vaults (
    user_id uuid primary key references auth.users(id) on delete cascade,
    current_key_version integer not null default 1 check (current_key_version > 0),
    field_algorithm text not null default 'A256GCM' check (field_algorithm = 'A256GCM'),
    created_at timestamptz not null default now(),
    rotated_at timestamptz,
    updated_at timestamptz not null default now()
);

create table if not exists public.vault_devices (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    label text not null check (char_length(label) between 1 and 80),
    platform text not null check (platform in ('ios', 'macos', 'web', 'other')),
    agreement_public_key text not null,
    signing_public_key text not null,
    public_key_format text not null default 'p256-x963-base64'
        check (public_key_format = 'p256-x963-base64'),
    status text not null default 'pending'
        check (status in ('pending', 'approved', 'revoked')),
    created_at timestamptz not null default now(),
    approved_at timestamptz,
    revoked_at timestamptz,
    last_seen_at timestamptz,
    unique (user_id, agreement_public_key),
    unique (user_id, signing_public_key)
);

create table if not exists public.vault_device_key_wraps (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    device_id uuid not null references public.vault_devices(id) on delete cascade,
    key_version integer not null check (key_version > 0),
    wrap_algorithm text not null default 'P256-HKDF-SHA256-A256GCM'
        check (wrap_algorithm = 'P256-HKDF-SHA256-A256GCM'),
    ephemeral_public_key text not null,
    wrapped_key text not null,
    created_at timestamptz not null default now(),
    revoked_at timestamptz
);

create unique index if not exists vault_device_key_wraps_active_idx
    on public.vault_device_key_wraps (user_id, device_id, key_version)
    where revoked_at is null;

create table if not exists public.vault_recovery_key_wraps (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    key_version integer not null check (key_version > 0),
    wrap_algorithm text not null default 'HKDF-SHA256-A256GCM'
        check (wrap_algorithm = 'HKDF-SHA256-A256GCM'),
    wrapped_key text not null,
    created_at timestamptz not null default now(),
    revoked_at timestamptz
);

create unique index if not exists vault_recovery_key_wraps_active_idx
    on public.vault_recovery_key_wraps (user_id, key_version)
    where revoked_at is null;

create table if not exists public.vault_audit_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    actor_device_id uuid references public.vault_devices(id) on delete set null,
    target_device_id uuid references public.vault_devices(id) on delete set null,
    event_type text not null check (event_type in (
        'vault_bootstrapped',
        'device_registration_requested',
        'device_approved',
        'device_revoked',
        'recovery_rotated',
        'vault_key_rotated'
    )),
    details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
    created_at timestamptz not null default now()
);

create index if not exists vault_devices_owner_created_idx
    on public.vault_devices (user_id, created_at desc);
create index if not exists vault_audit_events_owner_created_idx
    on public.vault_audit_events (user_id, created_at desc);

create or replace function public.miloom_is_base64_octets(p_value text, p_octets integer)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
    v_decoded bytea;
begin
    v_decoded := decode(p_value, 'base64');
    return octet_length(v_decoded) = p_octets;
exception when others then
    return false;
end;
$$;

create or replace function public.miloom_is_p256_public_key(p_value text)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
    v_decoded bytea;
begin
    v_decoded := decode(p_value, 'base64');
    return octet_length(v_decoded) = 65 and get_byte(v_decoded, 0) = 4;
exception when others then
    return false;
end;
$$;

create or replace function public.miloom_require_recent_access_token()
returns void
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
    v_iat_text text := auth.jwt() ->> 'iat';
    v_issued_at timestamptz;
begin
    if auth.uid() is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if v_iat_text is null or v_iat_text !~ '^[0-9]{10,}$' then
        raise exception using errcode = '42501', message = 'RECENT_ACCESS_TOKEN_REQUIRED';
    end if;
    v_issued_at := to_timestamp(v_iat_text::double precision);
    if v_issued_at < now() - interval '10 minutes' or v_issued_at > now() + interval '2 minutes' then
        raise exception using errcode = '42501', message = 'RECENT_ACCESS_TOKEN_REQUIRED';
    end if;
end;
$$;

create or replace function public.miloom_bootstrap_account_vault(
    p_device_label text,
    p_platform text,
    p_agreement_public_key text,
    p_signing_public_key text,
    p_ephemeral_public_key text,
    p_wrapped_vault_key text,
    p_wrapped_recovery_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_device_id uuid;
    v_label text := btrim(p_device_label);
    v_platform text := lower(btrim(p_platform));
begin
    perform public.miloom_require_recent_access_token();

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
       or not public.miloom_is_base64_octets(p_wrapped_recovery_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_VAULT_KEY_WRAP';
    end if;
    if exists (select 1 from public.account_vaults where user_id = v_actor) then
        raise exception using errcode = '23505', message = 'VAULT_ALREADY_INITIALIZED';
    end if;

    insert into public.account_vaults (user_id) values (v_actor);

    insert into public.vault_devices (
        user_id, label, platform, agreement_public_key, signing_public_key,
        status, approved_at, last_seen_at
    ) values (
        v_actor, v_label, v_platform, p_agreement_public_key, p_signing_public_key,
        'approved', now(), now()
    ) returning id into v_device_id;

    insert into public.vault_device_key_wraps (
        user_id, device_id, key_version, ephemeral_public_key, wrapped_key
    ) values (
        v_actor, v_device_id, 1, p_ephemeral_public_key, p_wrapped_vault_key
    );

    insert into public.vault_recovery_key_wraps (user_id, key_version, wrapped_key)
    values (v_actor, 1, p_wrapped_recovery_key);

    insert into public.vault_audit_events (
        user_id, actor_device_id, target_device_id, event_type
    ) values (
        v_actor, v_device_id, v_device_id, 'vault_bootstrapped'
    );

    return jsonb_build_object(
        'device_id', v_device_id,
        'key_version', 1,
        'status', 'approved'
    );
end;
$$;

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
    v_device_id uuid;
    v_label text := btrim(p_device_label);
    v_platform text := lower(btrim(p_platform));
begin
    perform public.miloom_require_recent_access_token();
    if not exists (select 1 from public.account_vaults where user_id = v_actor) then
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

    return jsonb_build_object('device_id', v_device_id, 'status', 'pending');
end;
$$;

create or replace function public.miloom_list_vault_devices()
returns table (
    device_id uuid,
    label text,
    platform text,
    agreement_public_key text,
    signing_public_key text,
    status text,
    created_at timestamptz,
    approved_at timestamptz,
    revoked_at timestamptz,
    last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select d.id, d.label, d.platform, d.agreement_public_key, d.signing_public_key,
           d.status, d.created_at, d.approved_at, d.revoked_at, d.last_seen_at
      from public.vault_devices d
     where d.user_id = auth.uid()
     order by d.created_at desc, d.id;
$$;

create or replace function public.miloom_get_vault_device_wrap(p_device_id uuid)
returns table (
    device_id uuid,
    key_version integer,
    wrap_algorithm text,
    ephemeral_public_key text,
    wrapped_key text
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select w.device_id, w.key_version, w.wrap_algorithm,
           w.ephemeral_public_key, w.wrapped_key
      from public.vault_device_key_wraps w
      join public.vault_devices d on d.id = w.device_id
     where w.user_id = auth.uid()
       and w.device_id = p_device_id
       and w.revoked_at is null
       and d.status = 'approved';
$$;

-- Phase 4 must verify an approval challenge signed by an already approved
-- device before its edge function invokes this service-only finalizer.
create or replace function public.miloom_finalize_vault_device_approval(
    p_user_id uuid,
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
begin
    if not public.miloom_is_p256_public_key(p_ephemeral_public_key)
       or not public.miloom_is_base64_octets(p_wrapped_vault_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_VAULT_KEY_WRAP';
    end if;
    if not exists (
        select 1 from public.account_vaults v
         where v.user_id = p_user_id and v.current_key_version = p_key_version
    ) then
        raise exception using errcode = 'P0002', message = 'VAULT_KEY_VERSION_NOT_FOUND';
    end if;
    if not exists (
        select 1 from public.vault_devices d
         where d.id = p_actor_device_id
           and d.user_id = p_user_id
           and d.status = 'approved'
    ) then
        raise exception using errcode = '42501', message = 'APPROVING_DEVICE_NOT_AUTHORIZED';
    end if;
    if not exists (
        select 1 from public.vault_devices d
         where d.id = p_target_device_id
           and d.user_id = p_user_id
           and d.status = 'pending'
    ) then
        raise exception using errcode = 'P0002', message = 'PENDING_DEVICE_NOT_FOUND';
    end if;

    insert into public.vault_device_key_wraps (
        user_id, device_id, key_version, ephemeral_public_key, wrapped_key
    ) values (
        p_user_id, p_target_device_id, p_key_version,
        p_ephemeral_public_key, p_wrapped_vault_key
    )
    on conflict (user_id, device_id, key_version) where revoked_at is null
    do update set
        ephemeral_public_key = excluded.ephemeral_public_key,
        wrapped_key = excluded.wrapped_key,
        wrap_algorithm = excluded.wrap_algorithm,
        created_at = now();

    update public.vault_devices
       set status = 'approved', approved_at = now(), revoked_at = null
     where id = p_target_device_id and user_id = p_user_id;

    insert into public.vault_audit_events (
        user_id, actor_device_id, target_device_id, event_type
    ) values (
        p_user_id, p_actor_device_id, p_target_device_id, 'device_approved'
    );
end;
$$;

alter table public.account_vaults enable row level security;
alter table public.vault_devices enable row level security;
alter table public.vault_device_key_wraps enable row level security;
alter table public.vault_recovery_key_wraps enable row level security;
alter table public.vault_audit_events enable row level security;

create policy account_vaults_owner_read on public.account_vaults
for select to authenticated using (user_id = auth.uid());
create policy vault_devices_owner_read on public.vault_devices
for select to authenticated using (user_id = auth.uid());
create policy vault_device_key_wraps_owner_read on public.vault_device_key_wraps
for select to authenticated using (user_id = auth.uid());
create policy vault_recovery_key_wraps_owner_read on public.vault_recovery_key_wraps
for select to authenticated using (user_id = auth.uid());
create policy vault_audit_events_owner_read on public.vault_audit_events
for select to authenticated using (user_id = auth.uid());

revoke all on table public.account_vaults from public, anon, authenticated;
revoke all on table public.vault_devices from public, anon, authenticated;
revoke all on table public.vault_device_key_wraps from public, anon, authenticated;
revoke all on table public.vault_recovery_key_wraps from public, anon, authenticated;
revoke all on table public.vault_audit_events from public, anon, authenticated;

grant select on table public.account_vaults to authenticated;
grant select on table public.vault_devices to authenticated;
grant select on table public.vault_device_key_wraps to authenticated;
grant select on table public.vault_recovery_key_wraps to authenticated;
grant select on table public.vault_audit_events to authenticated;

revoke all on function public.miloom_is_base64_octets(text, integer) from public, anon, authenticated;
revoke all on function public.miloom_is_p256_public_key(text) from public, anon, authenticated;
revoke all on function public.miloom_require_recent_access_token() from public, anon, authenticated;
revoke all on function public.miloom_bootstrap_account_vault(text, text, text, text, text, text, text) from public, anon;
revoke all on function public.miloom_register_vault_device(text, text, text, text) from public, anon;
revoke all on function public.miloom_list_vault_devices() from public, anon;
revoke all on function public.miloom_get_vault_device_wrap(uuid) from public, anon;
revoke all on function public.miloom_finalize_vault_device_approval(uuid, uuid, uuid, integer, text, text) from public, anon, authenticated;

grant execute on function public.miloom_bootstrap_account_vault(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.miloom_register_vault_device(text, text, text, text) to authenticated;
grant execute on function public.miloom_list_vault_devices() to authenticated;
grant execute on function public.miloom_get_vault_device_wrap(uuid) to authenticated;
grant execute on function public.miloom_finalize_vault_device_approval(uuid, uuid, uuid, integer, text, text) to service_role;

notify pgrst, 'reload schema';

commit;
