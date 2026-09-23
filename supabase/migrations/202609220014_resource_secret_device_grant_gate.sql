-- An active Editor/Admin share alone never delivers a password key. A trusted
-- recipient device must request one exact resource, then a trusted owner device
-- must explicitly approve and wrap that resource key for that device. Revokes
-- lock affected ciphertext until the owner rotates its resource key.

begin;

create table public.resource_secret_access_requests (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    resource_type text not null,
    resource_id uuid not null,
    key_version integer not null,
    recipient_user_id uuid not null references auth.users(id) on delete cascade,
    recipient_device_id uuid not null references public.vault_devices(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'approved', 'revoked')),
    requested_at timestamptz not null default now(),
    approved_at timestamptz,
    revoked_at timestamptz,
    foreign key (resource_type, resource_id, key_version)
        references public.resource_secret_versions(resource_type, resource_id, key_version) on delete cascade
);
create unique index resource_secret_access_requests_pending_idx
    on public.resource_secret_access_requests
    (resource_type, resource_id, key_version, recipient_device_id)
    where status = 'pending';
create index resource_secret_access_requests_owner_idx
    on public.resource_secret_access_requests (owner_user_id, status, requested_at desc);
alter table public.resource_secret_access_requests enable row level security;
revoke all on table public.resource_secret_access_requests from public, anon, authenticated;

-- Revoking a trusted device must not be blocked by the insert-time approval
-- check on the wrapped-key table.
create or replace function public.miloom_validate_resource_secret_device_wrap()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if new.grant_status in ('pending', 'active') and not exists (
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

create or replace function public.miloom_resource_secret_user_eligible(
    p_user_id uuid, p_resource_type text, p_resource_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select p_user_id is not null
       and p_user_id is distinct from public.miloom_resource_owner(p_resource_type, p_resource_id)
       and public.miloom_resource_company(p_resource_type, p_resource_id) is not null
       and not exists (
           select 1 from public.resource_access_blocks b
           join auth.users au on au.id = p_user_id
            where b.owner_user_id = public.miloom_resource_owner(p_resource_type, p_resource_id)
              and (b.blocked_user_id = p_user_id or lower(b.blocked_email) = lower(au.email))
       )
       and exists (
           select 1 from public.resource_shares rs
            where rs.user_id = p_user_id
              and rs.suspended_at is null
              and rs.role in ('Editor', 'Admin')
              and (
                  (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                  or (rs.resource_type = 'company'
                      and rs.resource_id = public.miloom_resource_company(p_resource_type, p_resource_id))
                  or (rs.resource_id = public.miloom_resource_company(p_resource_type, p_resource_id)
                      and (
                          (rs.resource_type = 'all_institutions' and lower(p_resource_type) = 'institution')
                          or (rs.resource_type = 'all_financials' and lower(p_resource_type) in ('institution', 'card'))
                          or (rs.resource_type = 'all_subscriptions' and lower(p_resource_type) = 'subscription')
                      ))
              )
       );
$$;
revoke all on function public.miloom_resource_secret_user_eligible(uuid, text, uuid)
    from public, anon, authenticated;

create or replace function public.miloom_require_current_resource_device(p_device_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_session_id uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
    perform public.miloom_require_recent_access_token();
    if v_actor is null or v_session_id is null or not exists (
        select 1 from public.vault_devices d
         where d.id = p_device_id and d.user_id = v_actor
           and d.status = 'approved' and d.auth_session_id = v_session_id
    ) then
        raise exception using errcode = '42501', message = 'TRUSTED_DEVICE_REQUIRED';
    end if;
end;
$$;
revoke all on function public.miloom_require_current_resource_device(uuid)
    from public, anon, authenticated;

create or replace function public.miloom_request_resource_secret_access(
    p_resource_type text, p_resource_id uuid, p_recipient_device_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_secret public.resource_secret_versions%rowtype;
    v_request_id uuid;
begin
    perform public.miloom_require_current_resource_device(p_recipient_device_id);
    select * into v_secret from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.state = 'active'
     order by sv.key_version desc limit 1;
    if v_secret.resource_id is null or not public.miloom_resource_secret_user_eligible(
        auth.uid(), v_type, p_resource_id
    ) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    insert into public.resource_secret_access_requests (
        owner_user_id, resource_type, resource_id, key_version,
        recipient_user_id, recipient_device_id
    ) values (
        v_secret.owner_user_id, v_type, p_resource_id, v_secret.key_version,
        auth.uid(), p_recipient_device_id
    ) on conflict (resource_type, resource_id, key_version, recipient_device_id)
        where status = 'pending' do update set requested_at = now()
    returning id into v_request_id;
    return jsonb_build_object('status', 'pending_owner_approval', 'request_id', v_request_id);
end;
$$;
revoke all on function public.miloom_request_resource_secret_access(text, uuid, uuid)
    from public, anon;
grant execute on function public.miloom_request_resource_secret_access(text, uuid, uuid)
    to authenticated;

create or replace function public.miloom_list_resource_secret_requests(
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    request_id uuid, resource_type text, resource_id uuid, key_version integer,
    resource_title text, company_name text,
    recipient_user_id uuid, recipient_email text, recipient_device_id uuid,
    recipient_device_label text, agreement_public_key text, requested_at timestamptz
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    return query
    select ar.id, ar.resource_type, ar.resource_id, ar.key_version,
           public.miloom_resource_title(ar.resource_type, ar.resource_id), c.name,
           ar.recipient_user_id, lower(au.email), ar.recipient_device_id,
           d.label, d.agreement_public_key, ar.requested_at
      from public.resource_secret_access_requests ar
      join public.vault_devices d on d.id = ar.recipient_device_id
      join auth.users au on au.id = ar.recipient_user_id
      join public.resource_secret_versions sv
        on sv.resource_type = ar.resource_type and sv.resource_id = ar.resource_id
       and sv.key_version = ar.key_version
      join public.companies c on c.id = sv.company_id
     where ar.owner_user_id = auth.uid()
       and ar.status = 'pending' and sv.state = 'active'
       and d.user_id = ar.recipient_user_id and d.status = 'approved'
       and public.miloom_resource_secret_user_eligible(
           ar.recipient_user_id, ar.resource_type, ar.resource_id
       )
     order by ar.requested_at desc, ar.id;
end;
$$;
revoke all on function public.miloom_list_resource_secret_requests(uuid, text)
    from public, anon;
grant execute on function public.miloom_list_resource_secret_requests(uuid, text)
    to authenticated;

create or replace function public.miloom_get_owner_resource_secret(
    p_resource_type text, p_resource_id uuid,
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    owner_account_key_version integer, owner_wrapped_resource_key text,
    encrypted_fields jsonb, state text
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if public.miloom_resource_owner(lower(p_resource_type), p_resource_id) is distinct from auth.uid() then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    return query
    select sv.resource_type, sv.resource_id, sv.key_version,
           sv.owner_account_key_version, sv.owner_wrapped_resource_key,
           sv.encrypted_fields, sv.state
      from public.resource_secret_versions sv
     where sv.resource_type = lower(p_resource_type) and sv.resource_id = p_resource_id
       and sv.owner_user_id = auth.uid()
       and sv.state in ('staging', 'active', 'rotation_required')
     order by sv.key_version desc limit 1;
end;
$$;
revoke all on function public.miloom_get_owner_resource_secret(text, uuid, uuid, text)
    from public, anon;
grant execute on function public.miloom_get_owner_resource_secret(text, uuid, uuid, text)
    to authenticated;

create or replace function public.miloom_approve_resource_secret_access(
    p_request_id uuid, p_actor_device_id uuid, p_key_confirmation text,
    p_ephemeral_public_key text, p_wrapped_resource_key text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_request public.resource_secret_access_requests%rowtype;
    v_secret public.resource_secret_versions%rowtype;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if not public.miloom_is_p256_public_key(p_ephemeral_public_key)
       or not public.miloom_is_base64_octets(p_wrapped_resource_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_KEY_WRAP';
    end if;
    select * into v_request from public.resource_secret_access_requests
     where id = p_request_id and owner_user_id = auth.uid();
    if v_request.id is null then
        raise exception using errcode = '42501', message = 'SECRET_REQUEST_NOT_OWNED';
    end if;
    select * into v_secret from public.resource_secret_versions
     where resource_type = v_request.resource_type and resource_id = v_request.resource_id
       and key_version = v_request.key_version and owner_user_id = auth.uid()
     for update;
    select * into v_request from public.resource_secret_access_requests
     where id = p_request_id and owner_user_id = auth.uid()
     for update;
    if v_secret.resource_id is null or v_secret.state <> 'active'
       or v_request.status <> 'pending'
       or not public.miloom_resource_secret_user_eligible(
           v_request.recipient_user_id, v_request.resource_type, v_request.resource_id
       ) or not exists (
           select 1 from public.vault_devices d
            where d.id = v_request.recipient_device_id
              and d.user_id = v_request.recipient_user_id
              and d.status = 'approved'
       ) then
        raise exception using errcode = '42501', message = 'SECRET_REQUEST_NO_LONGER_VALID';
    end if;
    insert into public.resource_secret_device_wraps (
        resource_type, resource_id, key_version, recipient_user_id,
        recipient_device_id, ephemeral_public_key, wrapped_resource_key,
        grant_status, activated_at
    ) values (
        v_request.resource_type, v_request.resource_id, v_request.key_version,
        v_request.recipient_user_id, v_request.recipient_device_id,
        p_ephemeral_public_key, p_wrapped_resource_key, 'active', now()
    );
    update public.resource_secret_access_requests
       set status = 'approved', approved_at = now()
     where id = p_request_id;
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (
        auth.uid(), auth.uid(), v_request.resource_type, v_request.resource_id,
        v_request.key_version, 'device_granted'
    );
    return jsonb_build_object('status', 'approved', 'key_version', v_request.key_version);
end;
$$;
revoke all on function public.miloom_approve_resource_secret_access(
    uuid, uuid, text, text, text
) from public, anon;
grant execute on function public.miloom_approve_resource_secret_access(
    uuid, uuid, text, text, text
) to authenticated;

create or replace function public.miloom_get_resource_secret_for_device(
    p_resource_type text, p_resource_id uuid, p_device_id uuid
)
returns table (
    owner_user_id uuid, resource_type text, resource_id uuid, key_version integer,
    encrypted_fields jsonb, ephemeral_public_key text, wrapped_resource_key text
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_current_resource_device(p_device_id);
    if not public.miloom_resource_secret_user_eligible(
        auth.uid(), lower(p_resource_type), p_resource_id
    ) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    return query
    select sv.owner_user_id, sv.resource_type, sv.resource_id, sv.key_version,
           sv.encrypted_fields, w.ephemeral_public_key, w.wrapped_resource_key
      from public.resource_secret_versions sv
      join public.resource_secret_device_wraps w
        on w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
       and w.key_version = sv.key_version
     where sv.resource_type = lower(p_resource_type) and sv.resource_id = p_resource_id
       and sv.state = 'active' and w.grant_status = 'active'
       and w.recipient_user_id = auth.uid() and w.recipient_device_id = p_device_id;
end;
$$;
revoke all on function public.miloom_get_resource_secret_for_device(text, uuid, uuid)
    from public, anon;
grant execute on function public.miloom_get_resource_secret_for_device(text, uuid, uuid)
    to authenticated;

create or replace function public.miloom_lock_resource_secret_on_state_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if old.state = 'active' and new.state in ('rotation_required', 'retired') then
        update public.resource_secret_device_wraps
           set grant_status = 'revoked', revoked_at = now()
         where resource_type = new.resource_type and resource_id = new.resource_id
           and key_version = new.key_version and grant_status = 'active';
        update public.resource_secret_access_requests
           set status = 'revoked', revoked_at = now()
         where resource_type = new.resource_type and resource_id = new.resource_id
           and key_version = new.key_version and status = 'pending';
        insert into public.resource_secret_audit_events (
            owner_user_id, resource_type, resource_id, key_version, event_type
        ) values (
            new.owner_user_id, new.resource_type, new.resource_id, new.key_version,
            case when new.state = 'retired' then 'key_retired' else 'rotation_required' end
        );
    end if;
    return new;
end;
$$;
create trigger lock_resource_secret_on_state_change
after update of state on public.resource_secret_versions
for each row execute function public.miloom_lock_resource_secret_on_state_change();
revoke all on function public.miloom_lock_resource_secret_on_state_change()
    from public, anon, authenticated;

create or replace function public.miloom_lock_resource_secret_on_share_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_secret public.resource_secret_versions%rowtype;
begin
    if old.role not in ('Editor', 'Admin') or old.suspended_at is not null then return null; end if;
    if tg_op = 'UPDATE' and new.role in ('Editor', 'Admin') and new.suspended_at is null
       and new.user_id = old.user_id and new.resource_id = old.resource_id
       and new.resource_type = old.resource_type then
        return null;
    end if;
    for v_secret in
        select * from public.resource_secret_versions sv
         where sv.state = 'active'
           and sv.owner_user_id = public.miloom_resource_owner(old.resource_type, old.resource_id)
           and (
               (old.resource_type = sv.resource_type and old.resource_id = sv.resource_id)
               or (old.resource_type = 'company' and old.resource_id = sv.company_id)
               or (old.resource_type = 'all_institutions' and old.resource_id = sv.company_id
                   and sv.resource_type = 'institution')
               or (old.resource_type = 'all_financials' and old.resource_id = sv.company_id
                   and sv.resource_type in ('institution', 'card'))
               or (old.resource_type = 'all_subscriptions' and old.resource_id = sv.company_id
                   and sv.resource_type = 'subscription')
           )
    loop
        if not public.miloom_resource_secret_user_eligible(
            old.user_id, v_secret.resource_type, v_secret.resource_id
        ) then
            update public.resource_secret_versions
               set state = 'rotation_required'
             where resource_type = v_secret.resource_type and resource_id = v_secret.resource_id
               and key_version = v_secret.key_version and state = 'active';
        end if;
    end loop;
    return null;
end;
$$;
create trigger lock_resource_secret_on_share_change
after update or delete on public.resource_shares
for each row execute function public.miloom_lock_resource_secret_on_share_change();
revoke all on function public.miloom_lock_resource_secret_on_share_change()
    from public, anon, authenticated;

create or replace function public.miloom_lock_resource_secret_on_device_revoke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if old.status = 'approved' and new.status <> 'approved' then
        update public.resource_secret_versions sv
           set state = 'rotation_required'
         where sv.state = 'active' and exists (
             select 1 from public.resource_secret_device_wraps w
              where w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
                and w.key_version = sv.key_version and w.recipient_device_id = new.id
                and w.grant_status = 'active'
         );
    end if;
    return new;
end;
$$;
create trigger lock_resource_secret_on_device_revoke
after update of status on public.vault_devices
for each row execute function public.miloom_lock_resource_secret_on_device_revoke();
revoke all on function public.miloom_lock_resource_secret_on_device_revoke()
    from public, anon, authenticated;

create or replace function public.miloom_lock_resource_secret_on_account_key_rotation()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if new.current_key_version <> old.current_key_version then
        update public.resource_secret_versions
           set state = 'rotation_required'
         where owner_user_id = new.user_id and state = 'active';
    end if;
    return new;
end;
$$;
create trigger lock_resource_secret_on_account_key_rotation
after update of current_key_version on public.account_vaults
for each row execute function public.miloom_lock_resource_secret_on_account_key_rotation();
revoke all on function public.miloom_lock_resource_secret_on_account_key_rotation()
    from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
