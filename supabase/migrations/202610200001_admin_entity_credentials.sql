-- Explicit owner consent for entity Admin credentials. The UI defaults ON,
-- but storage defaults OFF: existing shares/invites and older clients gain nothing.
-- Keys remain resource-specific and must be delivered by a trusted owner device.
begin;

alter table public.resource_shares add column include_entity_credentials boolean not null default false;
alter table public.resource_invitations add column include_entity_credentials boolean not null default false;
alter table public.resource_shares add constraint admin_credentials_company_only
    check (not include_entity_credentials or (role = 'Admin' and resource_type = 'company'));
alter table public.resource_invitations add constraint admin_credentials_company_only
    check (not include_entity_credentials or (role = 'Admin' and resource_type = 'company'));

create table public.admin_credential_devices (
    id uuid primary key default gen_random_uuid(),
    share_id uuid not null references public.resource_shares(id) on delete cascade,
    device_id uuid not null references public.vault_devices(id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'approved')),
    requested_at timestamptz not null default now(),
    approved_at timestamptz,
    unique (share_id, device_id)
);
alter table public.admin_credential_devices enable row level security;
revoke all on table public.admin_credential_devices from public, anon, authenticated;

-- Clearing/downgrading/suspending consent also removes device approvals and
-- locks affected keys, even when another overlapping business share survives.
create function public.miloom_admin_credentials_share_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if tg_op = 'UPDATE' then
        if new.role <> 'Admin' or new.resource_type <> 'company' or new.suspended_at is not null
           or new.user_id <> old.user_id or new.resource_id <> old.resource_id then
            new.include_entity_credentials := false;
        end if;
        if not old.include_entity_credentials or (new.include_entity_credentials
            and new.user_id = old.user_id and new.resource_id = old.resource_id) then return new; end if;
    elsif not old.include_entity_credentials then return old;
    end if;
    update public.resource_secret_versions sv set state = 'rotation_required'
     where sv.company_id = old.resource_id and sv.state = 'active'
       and exists (select 1 from public.resource_secret_device_wraps w
           where w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
             and w.key_version = sv.key_version and w.recipient_user_id = old.user_id
             and w.grant_status = 'active');
    delete from public.admin_credential_devices where share_id = old.id;
    if tg_op = 'DELETE' then return old; end if;
    return new;
end;
$$;
create trigger admin_credentials_share_guard before update or delete on public.resource_shares
for each row execute function public.miloom_admin_credentials_share_guard();
revoke all on function public.miloom_admin_credentials_share_guard() from public, anon, authenticated;

create function public.miloom_admin_credentials_invitation_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if new.role <> 'Admin' or new.resource_type <> 'company'
       or new.resource_id is distinct from old.resource_id
       or new.email is distinct from old.email or new.invited_by is distinct from old.invited_by
       or (new.status = 'Pending' and old.status <> 'Pending') then
        new.include_entity_credentials := false;
    end if;
    if new.status not in ('Pending', 'Accepted') then
        new.include_entity_credentials := false;
    end if;
    return new;
end;
$$;
create trigger admin_credentials_invitation_guard before update on public.resource_invitations
for each row execute function public.miloom_admin_credentials_invitation_guard();
revoke all on function public.miloom_admin_credentials_invitation_guard() from public, anon, authenticated;

-- Existing verified-email acceptance remains authoritative. Transfer the exact
-- invitation's consent only within its successful acceptance transaction.
create function public.miloom_accept_admin_credentials()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if old.status = 'Pending' and new.status = 'Accepted' and new.role = 'Admin'
       and new.resource_type = 'company' then
        update public.resource_shares rs set include_entity_credentials = new.include_entity_credentials
         where rs.resource_type = 'company' and rs.resource_id = new.resource_id
           and rs.role = 'Admin' and rs.user_id = auth.uid()
           and exists (select 1 from auth.users u where u.id = rs.user_id
               and lower(u.email) = lower(new.email) and u.email_confirmed_at is not null)
           and public.miloom_resource_owner('company', new.resource_id) = new.invited_by;
    end if;
    return new;
end;
$$;
create trigger accept_admin_credentials after update of status on public.resource_invitations
for each row execute function public.miloom_accept_admin_credentials();
revoke all on function public.miloom_accept_admin_credentials() from public, anon, authenticated;

-- Discover eligible devices without approving them. Covers direct shares,
-- accepted invitations, and devices enrolled after the Admin was invited.
create function public.miloom_seed_admin_credential_devices()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    insert into public.admin_credential_devices(share_id, device_id)
    select rs.id, d.id from public.resource_shares rs join public.vault_devices d on d.user_id = rs.user_id
     where rs.resource_type = 'company' and rs.role = 'Admin' and rs.include_entity_credentials
       and rs.suspended_at is null and d.status = 'approved'
       and ((tg_table_name = 'resource_shares' and rs.id = new.id)
         or (tg_table_name = 'vault_devices' and d.id = new.id))
       and not exists (select 1 from public.resource_access_blocks b join auth.users u on u.id = rs.user_id
          where b.owner_user_id = public.miloom_resource_owner('company', rs.resource_id)
            and (b.blocked_user_id = u.id or lower(b.blocked_email) = lower(u.email)))
    on conflict (share_id, device_id) do nothing;
    return new;
end;
$$;
create trigger seed_admin_credential_devices after insert or update on public.resource_shares
for each row execute function public.miloom_seed_admin_credential_devices();
-- Alphabetically after reset_admin_credential_device: changing a key requires
-- fresh pending consent, never reuse of the previous approved device grant.
create trigger zz_seed_admin_credential_devices after insert or update on public.vault_devices
for each row execute function public.miloom_seed_admin_credential_devices();
revoke all on function public.miloom_seed_admin_credential_devices() from public, anon, authenticated;

create function public.miloom_share_admin_entity(
    p_email text, p_company_id uuid, p_include_credentials boolean,
    p_actor_device_id uuid default null, p_key_confirmation text default null
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
    if auth.uid() is null or public.miloom_resource_owner('company', p_company_id) is distinct from auth.uid() then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    if p_include_credentials is null then raise exception 'EXPLICIT_CREDENTIAL_CHOICE_REQUIRED'; end if;
    if p_include_credentials then
        perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    end if;
    v_result := public.miloom_share_resource(p_email, 'Admin', p_company_id, 'company');
    if v_result ->> 'status' = 'shared_directly' then
        update public.resource_shares rs set include_entity_credentials = p_include_credentials
         where rs.resource_type = 'company' and rs.resource_id = p_company_id and rs.role = 'Admin'
           and rs.user_id in (select id from auth.users where lower(email) = lower(btrim(p_email)));
    elsif v_result ->> 'status' = 'invitation_created' then
        update public.resource_invitations set include_entity_credentials = p_include_credentials
         where id = (v_result ->> 'invitation_id')::uuid and invited_by = auth.uid();
    else raise exception 'UNEXPECTED_SHARE_RESULT'; end if;
    return v_result;
end;
$$;
revoke all on function public.miloom_share_admin_entity(text,uuid,boolean,uuid,text) from public, anon;
grant execute on function public.miloom_share_admin_entity(text,uuid,boolean,uuid,text) to authenticated;

-- Returns false for ordinary resource grants; never broadens Editor/Viewer scope.
create function public.miloom_request_admin_credentials(
    p_resource_type text, p_resource_id uuid, p_recipient_device_id uuid
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_share public.resource_shares%rowtype;
begin
    perform public.miloom_require_current_resource_device(p_recipient_device_id);
    if not public.miloom_resource_secret_user_eligible(auth.uid(), lower(p_resource_type), p_resource_id) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    select * into v_share from public.resource_shares rs
     where rs.resource_type = 'company'
       and rs.resource_id = public.miloom_resource_company(lower(p_resource_type), p_resource_id)
       and rs.user_id = auth.uid() and rs.role = 'Admin' and rs.suspended_at is null
       and rs.include_entity_credentials for update;
    if v_share.id is null then return false; end if;
    insert into public.admin_credential_devices (share_id, device_id)
        values (v_share.id, p_recipient_device_id) on conflict (share_id, device_id) do nothing;
    return true;
end;
$$;
revoke all on function public.miloom_request_admin_credentials(text,uuid,uuid) from public, anon;
grant execute on function public.miloom_request_admin_credentials(text,uuid,uuid) to authenticated;

create function public.miloom_list_admin_credential_devices(p_actor_device_id uuid, p_key_confirmation text)
returns table (id uuid, company_id uuid, company_name text, recipient_email text,
    recipient_device_label text, status text)
language plpgsql security definer set search_path = '' as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    return query select ad.id, c.id, c.name, lower(u.email), d.label, ad.status
      from public.admin_credential_devices ad
      join public.resource_shares rs on rs.id = ad.share_id
      join public.companies c on c.id = rs.resource_id
      join public.vault_devices d on d.id = ad.device_id and d.user_id = rs.user_id
      join auth.users u on u.id = rs.user_id
     where c.user_id = auth.uid() and rs.resource_type = 'company' and rs.role = 'Admin'
       and rs.include_entity_credentials and rs.suspended_at is null and d.status = 'approved'
       and not exists (select 1 from public.resource_access_blocks b where b.owner_user_id = c.user_id
           and (b.blocked_user_id = u.id or lower(b.blocked_email) = lower(u.email)))
     order by ad.requested_at, ad.id;
end;
$$;
revoke all on function public.miloom_list_admin_credential_devices(uuid,text) from public, anon;
grant execute on function public.miloom_list_admin_credential_devices(uuid,text) to authenticated;

-- Lock the share before the device approval. All delivery calls recheck consent,
-- ownership, block status, membership, device state, resource scope and key version.
create function public.miloom_require_admin_credential_device(p_grant_id uuid)
returns public.admin_credential_devices language plpgsql security definer set search_path = '' as $$
declare v_share public.resource_shares%rowtype; v_grant public.admin_credential_devices%rowtype;
begin
    select rs.* into v_share from public.resource_shares rs
      join public.admin_credential_devices ad on ad.share_id = rs.id
     where ad.id = p_grant_id for update of rs;
    select * into v_grant from public.admin_credential_devices where id = p_grant_id for update;
    if auth.uid() is null or v_grant.id is null or v_share.role <> 'Admin'
       or v_share.resource_type <> 'company' or not v_share.include_entity_credentials
       or v_share.suspended_at is not null
       or public.miloom_resource_owner('company', v_share.resource_id) is distinct from auth.uid()
       or not exists (select 1 from public.vault_devices d where d.id = v_grant.device_id
           and d.user_id = v_share.user_id and d.status = 'approved')
       or exists (select 1 from public.resource_access_blocks b join auth.users u on u.id = v_share.user_id
           where b.owner_user_id = auth.uid() and (b.blocked_user_id = u.id or lower(b.blocked_email) = lower(u.email))) then
        raise exception using errcode = '42501', message = 'ADMIN_CREDENTIAL_CONSENT_REQUIRED';
    end if;
    return v_grant;
end;
$$;
revoke all on function public.miloom_require_admin_credential_device(uuid) from public, anon, authenticated;

create function public.miloom_approve_admin_credential_device(
    p_grant_id uuid, p_actor_device_id uuid, p_key_confirmation text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    perform public.miloom_require_admin_credential_device(p_grant_id);
    update public.admin_credential_devices set status = 'approved', approved_at = now() where id = p_grant_id;
end;
$$;
revoke all on function public.miloom_approve_admin_credential_device(uuid,uuid,text) from public, anon;
grant execute on function public.miloom_approve_admin_credential_device(uuid,uuid,text) to authenticated;

create function public.miloom_list_admin_credential_resources(
    p_grant_id uuid, p_actor_device_id uuid, p_key_confirmation text
)
returns table (resource_type text, resource_id uuid)
language plpgsql security definer set search_path = '' as $$
declare v_grant public.admin_credential_devices%rowtype; v_company uuid;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    v_grant := public.miloom_require_admin_credential_device(p_grant_id);
    select resource_id into v_company from public.resource_shares where id = v_grant.share_id;
    return query select 'subscription'::text, s.id from public.subscriptions s where s.company_id = v_company and s.user_id = auth.uid()
        union all select 'card', c.id from public.financial_cards c where c.company_id = v_company and c.user_id = auth.uid()
        union all select 'institution', i.id from public.institutions i where i.company_id = v_company and i.user_id = auth.uid();
end;
$$;
revoke all on function public.miloom_list_admin_credential_resources(uuid,uuid,text) from public, anon;
grant execute on function public.miloom_list_admin_credential_resources(uuid,uuid,text) to authenticated;

create function public.miloom_list_admin_credential_deliveries(
    p_grant_id uuid, p_actor_device_id uuid, p_key_confirmation text
)
returns table (request_id uuid, resource_type text, resource_id uuid, key_version integer,
    resource_title text, company_name text, recipient_user_id uuid, recipient_email text,
    recipient_device_id uuid, recipient_device_label text, agreement_public_key text, requested_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_grant public.admin_credential_devices%rowtype;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    v_grant := public.miloom_require_admin_credential_device(p_grant_id);
    if v_grant.status <> 'approved' then raise exception using errcode = '42501', message = 'ADMIN_DEVICE_APPROVAL_REQUIRED'; end if;
    return query select ad.id, sv.resource_type, sv.resource_id, sv.key_version,
        public.miloom_resource_title(sv.resource_type, sv.resource_id), c.name,
        rs.user_id, lower(u.email), d.id, d.label, d.agreement_public_key, ad.requested_at
      from public.admin_credential_devices ad join public.resource_shares rs on rs.id = ad.share_id
      join public.companies c on c.id = rs.resource_id
      join public.vault_devices d on d.id = ad.device_id
      join auth.users u on u.id = rs.user_id
      join public.resource_secret_versions sv on sv.company_id = c.id and sv.owner_user_id = auth.uid()
     where ad.id = p_grant_id and sv.state = 'active'
       and public.miloom_resource_company(sv.resource_type, sv.resource_id) = c.id
       and not exists (select 1 from public.resource_secret_device_wraps w where w.resource_type = sv.resource_type
           and w.resource_id = sv.resource_id and w.key_version = sv.key_version
           and w.recipient_device_id = d.id and w.grant_status = 'active');
end;
$$;
revoke all on function public.miloom_list_admin_credential_deliveries(uuid,uuid,text) from public, anon;
grant execute on function public.miloom_list_admin_credential_deliveries(uuid,uuid,text) to authenticated;

create function public.miloom_deliver_admin_credential(
    p_grant_id uuid, p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_actor_device_id uuid, p_key_confirmation text, p_ephemeral_public_key text, p_wrapped_resource_key text
)
returns void language plpgsql security definer set search_path = '' as $$
declare v_grant public.admin_credential_devices%rowtype; v_share public.resource_shares%rowtype;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    v_grant := public.miloom_require_admin_credential_device(p_grant_id);
    select * into v_share from public.resource_shares where id = v_grant.share_id;
    perform 1 from public.vault_devices where id = v_grant.device_id and status = 'approved' for update;
    if not found or v_grant.status <> 'approved' then raise exception using errcode = '42501', message = 'ADMIN_DEVICE_APPROVAL_REQUIRED'; end if;
    perform 1 from public.resource_secret_versions sv
     where sv.resource_type = p_resource_type and sv.resource_id = p_resource_id and sv.key_version = p_key_version
       and sv.company_id = v_share.resource_id and sv.owner_user_id = auth.uid() and sv.state = 'active'
       and public.miloom_resource_company(sv.resource_type, sv.resource_id) = v_share.resource_id for update;
    if not found or not public.miloom_resource_secret_user_eligible(v_share.user_id, p_resource_type, p_resource_id) then
        raise exception using errcode = '42501', message = 'ADMIN_RESOURCE_OUT_OF_SCOPE';
    end if;
    if p_ephemeral_public_key is null or p_wrapped_resource_key is null
       or not public.miloom_is_p256_public_key(p_ephemeral_public_key)
       or not public.miloom_is_base64_octets(p_wrapped_resource_key, 60) then raise exception 'INVALID_RESOURCE_KEY_WRAP'; end if;
    -- Idempotent retries do not reactivate revoked grants at the same key version.
    if exists (select 1 from public.resource_secret_device_wraps w where w.resource_type = p_resource_type
        and w.resource_id = p_resource_id and w.key_version = p_key_version
        and w.recipient_device_id = v_grant.device_id and w.grant_status <> 'active') then
        raise exception using errcode = '42501', message = 'RESOURCE_KEY_REPLACEMENT_REQUIRED';
    end if;
    if exists (select 1 from public.resource_secret_device_wraps w where w.resource_type = p_resource_type
        and w.resource_id = p_resource_id and w.key_version = p_key_version and w.recipient_device_id = v_grant.device_id) then return; end if;
    insert into public.resource_secret_device_wraps (resource_type, resource_id, key_version, recipient_user_id,
        recipient_device_id, ephemeral_public_key, wrapped_resource_key, grant_status, activated_at)
    values (p_resource_type, p_resource_id, p_key_version, v_share.user_id, v_grant.device_id,
        p_ephemeral_public_key, p_wrapped_resource_key, 'active', now());
    insert into public.resource_secret_audit_events(owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type)
    values (auth.uid(), auth.uid(), p_resource_type, p_resource_id, p_key_version, 'device_granted');
    update public.resource_secret_access_requests set status = 'approved', approved_at = now()
     where resource_type = p_resource_type and resource_id = p_resource_id and key_version = p_key_version
       and recipient_device_id = v_grant.device_id and status = 'pending';
end;
$$;
revoke all on function public.miloom_deliver_admin_credential(uuid,text,uuid,integer,uuid,text,text,text) from public, anon;
grant execute on function public.miloom_deliver_admin_credential(uuid,text,uuid,integer,uuid,text,text,text) to authenticated;

-- Device trust changes require a new entity-device approval, never silent reuse.
create function public.miloom_reset_admin_credential_device()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if new.status <> 'approved' or new.agreement_public_key is distinct from old.agreement_public_key
       or new.user_id is distinct from old.user_id then
        update public.resource_secret_versions sv set state = 'rotation_required'
         where sv.state = 'active' and exists (
            select 1 from public.resource_secret_device_wraps w
             where w.recipient_device_id = old.id and w.grant_status = 'active'
               and w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
               and w.key_version = sv.key_version);
        delete from public.admin_credential_devices where device_id = old.id;
    end if;
    return new;
end;
$$;
create trigger reset_admin_credential_device after update on public.vault_devices
for each row execute function public.miloom_reset_admin_credential_device();
revoke all on function public.miloom_reset_admin_credential_device() from public, anon, authenticated;

create function public.miloom_reset_admin_credentials_on_block()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    delete from public.admin_credential_devices ad using public.resource_shares rs, auth.users u
     where ad.share_id = rs.id and u.id = rs.user_id and rs.resource_type = 'company'
       and public.miloom_resource_owner('company', rs.resource_id) = new.owner_user_id
       and (u.id = new.blocked_user_id or lower(u.email) = lower(new.blocked_email));
    return new;
end;
$$;
create trigger reset_admin_credentials_on_block after insert or update on public.resource_access_blocks
for each row execute function public.miloom_reset_admin_credentials_on_block();
revoke all on function public.miloom_reset_admin_credentials_on_block() from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
