-- Additive, closed-by-default storage for independently encrypted resource
-- secrets. This migration does NOT expose credentials or key wraps to shares.
-- Grant/fetch/rotation RPCs require a separate reviewed migration and client.

begin;

create table public.resource_secret_versions (
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    resource_type text not null check (resource_type in ('institution', 'card', 'subscription')),
    resource_id uuid not null,
    company_id uuid not null references public.companies(id) on delete cascade,
    key_version integer not null check (key_version > 0),
    owner_account_key_version integer not null check (owner_account_key_version > 0),
    owner_wrapped_resource_key text not null,
    encrypted_fields jsonb not null default '{}'::jsonb check (jsonb_typeof(encrypted_fields) = 'object'),
    state text not null default 'staging' check (state in ('staging', 'active', 'rotation_required', 'retired')),
    created_at timestamptz not null default now(),
    activated_at timestamptz,
    retired_at timestamptz,
    primary key (resource_type, resource_id, key_version),
    check ((state = 'active' and activated_at is not null and retired_at is null)
        or (state <> 'active')),
    check (public.miloom_is_base64_octets(owner_wrapped_resource_key, 60))
);

create unique index resource_secret_versions_one_current_idx
    on public.resource_secret_versions (resource_type, resource_id)
    where state in ('active', 'rotation_required');
create index resource_secret_versions_owner_idx
    on public.resource_secret_versions (owner_user_id, company_id, resource_type, resource_id);

create table public.resource_secret_device_wraps (
    id uuid primary key default gen_random_uuid(),
    resource_type text not null,
    resource_id uuid not null,
    key_version integer not null,
    recipient_user_id uuid not null references auth.users(id) on delete cascade,
    recipient_device_id uuid not null references public.vault_devices(id) on delete cascade,
    ephemeral_public_key text not null check (public.miloom_is_p256_public_key(ephemeral_public_key)),
    wrapped_resource_key text not null check (public.miloom_is_base64_octets(wrapped_resource_key, 60)),
    grant_status text not null default 'pending' check (grant_status in ('pending', 'active', 'revoked')),
    created_at timestamptz not null default now(),
    activated_at timestamptz,
    revoked_at timestamptz,
    foreign key (resource_type, resource_id, key_version)
        references public.resource_secret_versions(resource_type, resource_id, key_version) on delete cascade,
    unique (resource_type, resource_id, key_version, recipient_device_id),
    check ((grant_status = 'active' and activated_at is not null and revoked_at is null)
        or (grant_status <> 'active'))
);

create index resource_secret_device_wraps_recipient_idx
    on public.resource_secret_device_wraps (recipient_user_id, recipient_device_id, grant_status);

create or replace function public.miloom_validate_resource_secret_record()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if public.miloom_resource_owner(new.resource_type, new.resource_id) is distinct from new.owner_user_id
       or public.miloom_resource_company(new.resource_type, new.resource_id) is distinct from new.company_id then
        raise exception using errcode = '23514', message = 'RESOURCE_SECRET_OWNER_MISMATCH';
    end if;
    if not exists (
        select 1 from public.account_vaults av
         where av.user_id = new.owner_user_id
           and new.owner_account_key_version <= av.current_key_version
    ) then
        raise exception using errcode = '23514', message = 'OWNER_VAULT_KEY_VERSION_INVALID';
    end if;
    return new;
end;
$$;
create trigger validate_resource_secret_record
before insert or update on public.resource_secret_versions
for each row execute function public.miloom_validate_resource_secret_record();

create or replace function public.miloom_validate_resource_secret_device_wrap()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.vault_devices d
         where d.id = new.recipient_device_id
           and d.user_id = new.recipient_user_id
           and d.status = 'approved'
    ) then
        raise exception using errcode = '23514', message = 'RESOURCE_SECRET_DEVICE_NOT_APPROVED';
    end if;
    return new;
end;
$$;
create trigger validate_resource_secret_device_wrap
before insert or update on public.resource_secret_device_wraps
for each row execute function public.miloom_validate_resource_secret_device_wrap();

create table public.resource_secret_audit_events (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    actor_user_id uuid references auth.users(id) on delete set null,
    resource_type text not null,
    resource_id uuid not null,
    key_version integer not null check (key_version > 0),
    event_type text not null check (event_type in (
        'key_staged', 'key_activated', 'device_granted', 'device_revoked',
        'rotation_required', 'key_rotated', 'key_retired'
    )),
    created_at timestamptz not null default now()
);
create index resource_secret_audit_owner_idx
    on public.resource_secret_audit_events (owner_user_id, created_at desc);

alter table public.resource_secret_versions enable row level security;
alter table public.resource_secret_device_wraps enable row level security;
alter table public.resource_secret_audit_events enable row level security;
revoke all on table public.resource_secret_versions from public, anon, authenticated;
revoke all on table public.resource_secret_device_wraps from public, anon, authenticated;
revoke all on table public.resource_secret_audit_events from public, anon, authenticated;
revoke all on function public.miloom_validate_resource_secret_record() from public, anon, authenticated;
revoke all on function public.miloom_validate_resource_secret_device_wrap() from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
