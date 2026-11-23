begin;

alter table public.resource_shares add column include_credentials boolean not null default true;
alter table public.resource_invitations add column include_credentials boolean not null default true;

-- Credential scope is evaluated against the resource's current company.
-- An explicit exclusion for the exact item overrides inherited sharing.
create function public.miloom_resource_secret_role_allowed(
    p_user_id uuid, p_type text, p_id uuid, p_write boolean
) returns boolean
language sql stable security definer set search_path = ''
as $$
    with scope as (
        select public.miloom_resource_owner(p_type, p_id) as owner_id,
               public.miloom_resource_company(p_type, p_id) as company_id
    )
    select exists (
        select 1 from scope
         where p_user_id is not null and scope.owner_id is not null
           and scope.company_id is not null and p_user_id <> scope.owner_id
           and exists (
               select 1 from auth.users u where u.id = p_user_id
                 and u.email_confirmed_at is not null and not coalesce(u.is_anonymous, false)
           )
           and not exists (
               select 1 from public.resource_access_blocks b
               join auth.users u on u.id = p_user_id
               where b.owner_user_id = scope.owner_id
                 and (b.blocked_user_id = p_user_id or lower(b.blocked_email) = lower(u.email))
           )
           and not exists (
               select 1 from public.resource_shares direct
               where direct.user_id = p_user_id and direct.resource_type = p_type
                 and direct.resource_id = p_id and direct.suspended_at is null
                 and not direct.include_credentials
           )
           and exists (
               select 1 from public.resource_shares s
               where s.user_id = p_user_id and s.suspended_at is null and s.include_credentials
                 and (s.role in ('Admin','Editor') or (not p_write and s.role = 'Viewer'))
                 and ((s.resource_type = p_type and s.resource_id = p_id)
                   or (s.resource_id = scope.company_id and (
                       s.resource_type = 'company'
                       or (s.resource_type = 'all_institutions' and p_type = 'institution')
                       or (s.resource_type = 'all_financials' and p_type in ('institution','card'))
                       or (s.resource_type = 'all_subscriptions' and p_type = 'subscription')
                   )))
           )
    );
$$;
revoke all on function public.miloom_resource_secret_role_allowed(uuid,text,uuid,boolean)
    from public, anon, authenticated;

create or replace function public.miloom_resource_secret_user_eligible(
    p_user_id uuid, p_resource_type text, p_resource_id uuid
) returns boolean
language sql stable security definer set search_path = ''
as $$
    select public.miloom_resource_secret_role_allowed(p_user_id, lower(p_resource_type), p_resource_id, false);
$$;

-- Owners can wrap only keys from their own vault, and only for an approved
-- device that is currently eligible. Provisioning works even if the recipient
-- has yet to open the item, and is repeatable as devices and resources change.
create function public.miloom_queue_resource_key_deliveries(
    p_actor_device_id uuid, p_key_confirmation text
) returns void
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    insert into public.resource_secret_access_requests (
        owner_user_id, resource_type, resource_id, key_version, recipient_user_id, recipient_device_id
    )
    select sv.owner_user_id, sv.resource_type, sv.resource_id, sv.key_version, d.user_id, d.id
      from public.resource_secret_versions sv
      join lateral (
          select distinct s.user_id from public.resource_shares s
          where s.include_credentials and s.suspended_at is null
            and ((s.resource_id = sv.resource_id and s.resource_type = sv.resource_type)
              or (s.resource_id = sv.company_id
                  and s.resource_type in ('company','all_institutions','all_financials','all_subscriptions')))
      ) recipient on true
      join public.vault_devices d on d.user_id = recipient.user_id and d.status = 'approved'
     where sv.owner_user_id = auth.uid() and sv.state = 'active'
       and public.miloom_resource_secret_user_eligible(d.user_id, sv.resource_type, sv.resource_id)
       and not exists (
           select 1 from public.resource_secret_device_wraps w
           where w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
             and w.key_version = sv.key_version and w.recipient_device_id = d.id
             and w.grant_status = 'active'
       )
     order by sv.resource_type, sv.resource_id, d.id
     limit 50
    on conflict (resource_type, resource_id, key_version, recipient_device_id)
       where status = 'pending' do nothing;
end;
$$;
revoke all on function public.miloom_queue_resource_key_deliveries(uuid,text) from public, anon, authenticated;
grant execute on function public.miloom_queue_resource_key_deliveries(uuid,text) to authenticated;


-- Allow an active resource to keep its encrypted key after the last saved field is cleared.
create or replace function public.miloom_validate_rotated_resource_fields(
    p_resource_type text, p_key_version integer, p_fields jsonb
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_field text;
    v_value text;
    v_allowed text[];
    v_encoded text;
begin
    if p_key_version is null or p_key_version < 1
       or p_fields is null or jsonb_typeof(p_fields) <> 'object'
       or octet_length(p_fields::text) > 262144 then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELDS';
    end if;
    v_allowed := case p_resource_type
        when 'institution' then array['login_url','username','email','password','two_factor','accounts_data']
        when 'card' then array['login','password','card_number','expiry']
        when 'subscription' then array['login_id','password','two_factor_auth','recovery_method']
        else null end;
    if v_allowed is null then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELDS';
    end if;
    for v_field, v_value in select key, value from jsonb_each_text(p_fields) loop
        if not v_field = any(v_allowed)
           or jsonb_typeof(p_fields -> v_field) <> 'string'
           or split_part(v_value, ':', 1) <> 'miloom-resource'
           or split_part(v_value, ':', 2) <> 'v1'
           or split_part(v_value, ':', 3) <> p_key_version::text
           or split_part(v_value, ':', 5) <> '' then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end if;
        v_encoded := split_part(v_value, ':', 4);
        if v_encoded !~ '^[A-Za-z0-9+/]+={0,2}$' then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end if;
        begin
            if octet_length(decode(v_encoded, 'base64')) < 28 then
                raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
            end if;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end;
    end loop;
end;
$$;

create or replace function public.miloom_update_resource_secret(
    p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_expected_encrypted_fields jsonb, p_new_encrypted_fields jsonb,
    p_actor_device_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_actor uuid := auth.uid();
    v_secret public.resource_secret_versions%rowtype;
begin
    perform public.miloom_require_current_resource_device(p_actor_device_id);
    if v_type not in ('institution', 'card', 'subscription') then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;
    select * into v_secret from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_key_version
     for update;
    if v_secret.resource_id is null or v_secret.state <> 'active'
       or public.miloom_resource_owner(v_type, p_resource_id) is distinct from v_secret.owner_user_id
       or v_secret.encrypted_fields is distinct from p_expected_encrypted_fields then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_CHANGED';
    end if;
    if v_actor <> v_secret.owner_user_id and (
        not public.miloom_resource_secret_role_allowed(v_actor, v_type, p_resource_id, true)
        or not exists (
            select 1 from public.resource_secret_device_wraps w
             where w.resource_type = v_type and w.resource_id = p_resource_id
               and w.key_version = p_key_version and w.recipient_user_id = v_actor
               and w.recipient_device_id = p_actor_device_id
               and w.grant_status = 'active'
        )
    ) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    perform public.miloom_validate_rotated_resource_fields(v_type, p_key_version, p_new_encrypted_fields);
    if p_new_encrypted_fields = v_secret.encrypted_fields then
        return jsonb_build_object('status', 'unchanged', 'key_version', p_key_version);
    end if;
    update public.resource_secret_versions
       set encrypted_fields = p_new_encrypted_fields
     where resource_type = v_type and resource_id = p_resource_id
       and key_version = p_key_version and state = 'active';
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (
        v_secret.owner_user_id, v_actor, v_type, p_resource_id, p_key_version, 'secret_updated'
    );
    return jsonb_build_object('status', 'updated', 'key_version', p_key_version);
end;
$$;

create or replace function public.miloom_lock_resource_secret_on_share_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_share public.resource_shares%rowtype;
    v_secret public.resource_secret_versions%rowtype;
begin
    if tg_op = 'INSERT' and (new.include_credentials or new.suspended_at is not null) then
        return null;
    elsif tg_op = 'UPDATE' and old.suspended_at is not null and new.include_credentials then
        return null;
    end if;
    if tg_op = 'UPDATE' and new.role = old.role and new.include_credentials = old.include_credentials
       and new.suspended_at is null
       and new.user_id = old.user_id and new.resource_id = old.resource_id
       and new.resource_type = old.resource_type then
        return null;
    end if;
    v_share := case when tg_op = 'INSERT' then new else old end;
    for v_secret in
        select * from public.resource_secret_versions sv
         where sv.state = 'active'
           and sv.owner_user_id = public.miloom_resource_owner(v_share.resource_type, v_share.resource_id)
           and (
               (v_share.resource_type = sv.resource_type and v_share.resource_id = sv.resource_id)
               or (v_share.resource_type = 'company' and v_share.resource_id = sv.company_id)
               or (v_share.resource_type = 'all_institutions' and v_share.resource_id = sv.company_id
                   and sv.resource_type = 'institution')
               or (v_share.resource_type = 'all_financials' and v_share.resource_id = sv.company_id
                   and sv.resource_type in ('institution', 'card'))
               or (v_share.resource_type = 'all_subscriptions' and v_share.resource_id = sv.company_id
                   and sv.resource_type = 'subscription')
           )
         order by sv.resource_type, sv.resource_id, sv.key_version
         for update
    loop
        if not public.miloom_resource_secret_user_eligible(
            v_share.user_id, v_secret.resource_type, v_secret.resource_id
        ) and exists (
            select 1 from public.resource_secret_device_wraps w
            where w.resource_type = v_secret.resource_type and w.resource_id = v_secret.resource_id
              and w.key_version = v_secret.key_version and w.recipient_user_id = v_share.user_id
              and w.grant_status = 'active'
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
drop trigger lock_resource_secret_on_share_change on public.resource_shares;
create trigger lock_resource_secret_on_share_change
after insert or update or delete on public.resource_shares
for each row execute function public.miloom_lock_resource_secret_on_share_change();


create or replace function public.miloom_share_resource_with_credentials(
    p_email text, p_role text, p_resource_id uuid, p_resource_type text, p_include_credentials boolean
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_email text := lower(btrim(p_email));
    v_type text := lower(btrim(p_resource_type));
    v_target uuid;
    v_invitation_id uuid;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if v_email is null or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_EMAIL';
    end if;
    if p_role is null or p_role not in ('Viewer', 'Editor', 'Admin') then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_ROLE';
    end if;
    if v_type is null or v_type not in (
        'company', 'all_subscriptions', 'subscription', 'all_documents', 'document',
        'all_financials', 'all_institutions', 'institution', 'card', 'loan'
    ) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;
    if p_role = 'Admin' and v_type <> 'company' then
        raise exception using errcode = '22023', message = 'ADMIN_ENTITY_ONLY';
    end if;
    if public.miloom_resource_owner(v_type, p_resource_id) is distinct from v_actor then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;

    select lower(email) into v_actor_email from auth.users where id = v_actor;
    if v_actor_email is null then raise exception using errcode = '42501', message = 'ACTOR_EMAIL_REQUIRED'; end if;
    if v_email = v_actor_email then
        raise exception using errcode = '22023', message = 'CANNOT_SHARE_WITH_SELF';
    end if;

    select id into v_target from auth.users
     where lower(email) = v_email
     order by created_at nulls last, id limit 1;
    if exists (
        select 1 from public.resource_access_blocks b
         where b.owner_user_id = v_actor
           and (lower(b.blocked_email) = v_email
                or (v_target is not null and b.blocked_user_id = v_target))
    ) then
        raise exception using errcode = 'P0001', message = 'COLLABORATOR_BLOCKED';
    end if;

    if v_target is not null then
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role,
            sender_email, sender_display_name, suspended_at, include_credentials
        ) values (
            p_resource_id, v_type, v_target, p_role, v_actor_email, null, null, p_include_credentials
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null, include_credentials = excluded.include_credentials;

        delete from public.resource_invitations
         where resource_id = p_resource_id
           and resource_type = v_type
           and lower(email) = v_email
           and invited_by = v_actor
           and status in ('Pending', 'Accepted');
        return jsonb_build_object('status', 'shared_directly');
    end if;

    select id into v_invitation_id from public.resource_invitations
     where resource_id = p_resource_id
       and resource_type = v_type
       and lower(email) = v_email
       and status in ('Pending', 'Accepted')
     limit 1;

    if v_invitation_id is null then
        insert into public.resource_invitations (
            resource_id, resource_type, email, role, invited_by,
            sender_email, sender_display_name, status, include_credentials
        ) values (
            p_resource_id, v_type, v_email, p_role, v_actor,
            v_actor_email, null, 'Pending', p_include_credentials
        ) returning id into v_invitation_id;
    else
        update public.resource_invitations
           set role = p_role, invited_by = v_actor,
               sender_email = v_actor_email, sender_display_name = null,
               status = 'Pending', include_credentials = p_include_credentials
         where id = v_invitation_id;
    end if;
    return jsonb_build_object('status', 'invitation_created', 'invitation_id', v_invitation_id);
end;
$$;
revoke all on function public.miloom_share_resource_with_credentials(text,text,uuid,text,boolean) from public, anon, authenticated;
grant execute on function public.miloom_share_resource_with_credentials(text,text,uuid,text,boolean) to authenticated;

create or replace function public.miloom_share_resource(p_email text, p_role text, p_resource_id uuid, p_resource_type text)
returns jsonb language sql security definer set search_path = ''
as $$
    select public.miloom_share_resource_with_credentials(p_email,p_role,p_resource_id,p_resource_type, true);
$$;


create or replace function public.miloom_admin_share_viewer_with_credentials(
    p_email text, p_resource_id uuid, p_resource_type text, p_include_credentials boolean
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_email text := lower(btrim(p_email));
    v_type text := lower(btrim(p_resource_type));
    v_owner uuid;
    v_company uuid;
    v_target uuid;
    v_invitation_id uuid;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if v_email is null or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_EMAIL';
    end if;
    if v_type is null or v_type not in (
        'company', 'all_subscriptions', 'subscription', 'all_documents', 'document',
        'all_financials', 'all_institutions', 'institution', 'card', 'loan'
    ) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;

    v_owner := public.miloom_resource_owner(v_type, p_resource_id);
    v_company := public.miloom_resource_company(v_type, p_resource_id);
    if v_owner is null or v_company is null
       or public.miloom_admin_entity_id(v_company) is null then
        raise exception using errcode = '42501', message = 'ENTITY_ADMIN_REQUIRED';
    end if;
    if p_include_credentials and v_type in (
        'company','all_subscriptions','all_financials','all_institutions','subscription','card','institution'
    ) and (
        not exists (
            select 1 from public.resource_shares s
             where s.resource_type = 'company' and s.resource_id = v_company
               and s.user_id = v_actor and s.role = 'Admin'
               and s.suspended_at is null and s.include_credentials
        )
        or (v_type in ('subscription','card','institution') and not
            public.miloom_resource_secret_user_eligible(v_actor, v_type, p_resource_id))
    ) then
        raise exception using errcode = '42501', message = 'CREDENTIAL_SHARING_NOT_AUTHORIZED';
    end if;
    select lower(email) into v_actor_email from auth.users where id = v_actor;
    if v_actor_email is null then raise exception using errcode = '42501', message = 'ACTOR_EMAIL_REQUIRED'; end if;
    if v_email = v_actor_email then
        raise exception using errcode = '22023', message = 'CANNOT_SHARE_WITH_SELF';
    end if;
    select id into v_target from auth.users where lower(email) = v_email
     order by created_at nulls last, id limit 1;
    if v_target = v_owner then
        raise exception using errcode = '22023', message = 'CANNOT_SHARE_WITH_OWNER';
    end if;
    if exists (
        select 1 from public.resource_access_blocks b
         where b.owner_user_id = v_owner
           and (lower(b.blocked_email) = v_email
                or (v_target is not null and b.blocked_user_id = v_target))
    ) then
        raise exception using errcode = '42501', message = 'COLLABORATOR_BLOCKED';
    end if;
    -- Never overwrite or disguise any higher-role grant in this entity.
    if exists (
        select 1 from public.resource_shares rs
         where rs.user_id = v_target
           and rs.role in ('Editor', 'Admin')
           and public.miloom_resource_company(rs.resource_type, rs.resource_id) = v_company
    ) or exists (
        select 1 from public.resource_invitations ri
         where lower(ri.email) = v_email
           and ri.role in ('Editor', 'Admin')
           and ri.status in ('Pending', 'Accepted')
           and public.miloom_resource_company(ri.resource_type, ri.resource_id) = v_company
    ) then
        raise exception using errcode = '42501', message = 'HIGHER_ROLE_MANAGED_BY_OWNER';
    end if;

    if v_target is not null then
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role,
            sender_email, sender_display_name, suspended_at, include_credentials
        ) values (
            p_resource_id, v_type, v_target, 'Viewer',
            v_actor_email, null, null, p_include_credentials
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null, include_credentials = excluded.include_credentials;
        delete from public.resource_invitations ri
         where ri.resource_id = p_resource_id
           and ri.resource_type = v_type
           and lower(ri.email) = v_email
           and ri.role = 'Viewer'
           and ri.status in ('Pending', 'Accepted');
        return jsonb_build_object('status', 'shared_directly');
    end if;

    select id into v_invitation_id from public.resource_invitations
     where resource_id = p_resource_id
       and resource_type = v_type
       and lower(email) = v_email
       and status in ('Pending', 'Accepted')
     limit 1;
    if v_invitation_id is null then
        insert into public.resource_invitations (
            resource_id, resource_type, email, role, invited_by,
            sender_email, sender_display_name, status, include_credentials
        ) values (
            p_resource_id, v_type, v_email, 'Viewer', v_actor,
            v_actor_email, null, 'Pending', p_include_credentials
        ) returning id into v_invitation_id;
    else
        update public.resource_invitations
           set invited_by = v_actor, sender_email = v_actor_email,
               sender_display_name = null, status = 'Pending', include_credentials = p_include_credentials
         where id = v_invitation_id and role = 'Viewer';
        if not found then
            raise exception using errcode = '42501', message = 'HIGHER_ROLE_MANAGED_BY_OWNER';
        end if;
    end if;
    return jsonb_build_object('status', 'invitation_created', 'invitation_id', v_invitation_id);
end;
$$;
revoke all on function public.miloom_admin_share_viewer_with_credentials(text,uuid,text,boolean) from public, anon, authenticated;
grant execute on function public.miloom_admin_share_viewer_with_credentials(text,uuid,text,boolean) to authenticated;

create or replace function public.miloom_admin_share_viewer(p_email text, p_resource_id uuid, p_resource_type text)
returns jsonb language sql security definer set search_path = ''
as $$
    select public.miloom_admin_share_viewer_with_credentials(p_email,p_resource_id,p_resource_type, false);
$$;


create or replace function public.miloom_act_on_invitation(
    p_invitation_id uuid, p_token text, p_accept boolean
)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_email_verified boolean;
    v_invitation public.resource_invitations%rowtype;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if (p_invitation_id is null) = (p_token is null) then
        raise exception using errcode = '22023', message = 'INVITATION_REFERENCE_REQUIRED';
    end if;

    -- Hold the identity row stable through grant creation, including concurrent
    -- changes to the current email/confirmation state.
    select lower(u.email), u.email_confirmed_at is not null
        and not coalesce(u.is_anonymous, false)
      into v_actor_email, v_email_verified
      from auth.users u where u.id = v_actor for share;

    select * into v_invitation from public.resource_invitations ri
     where ((p_invitation_id is not null and ri.id = p_invitation_id)
        or (p_token is not null and p_token ~ '^[0-9a-f]{64}$'
            and ri.token_hash = extensions.digest(p_token, 'sha256')))
       and lower(ri.email) = v_actor_email
       and ri.status = 'Pending' and ri.expires_at > now()
     for update;
    if not found then raise exception using errcode = 'P0002', message = 'INVITATION_NOT_AVAILABLE'; end if;
    if exists (select 1 from public.resource_access_blocks b
        where b.owner_user_id = public.miloom_resource_owner(v_invitation.resource_type, v_invitation.resource_id)
          and (lower(b.blocked_email) = v_actor_email or b.blocked_user_id = v_actor)) then
        raise exception using errcode = '42501', message = 'INVITATION_BLOCKED';
    end if;

    if p_accept then
        if v_email_verified is distinct from true then
            raise exception using errcode = '42501', message = 'INVITATION_EMAIL_VERIFICATION_REQUIRED';
        end if;
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role, sender_email, sender_display_name, suspended_at, include_credentials
        ) values (
            v_invitation.resource_id, v_invitation.resource_type, v_actor,
            v_invitation.role, v_invitation.sender_email, null, null, v_invitation.include_credentials
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role, sender_email = excluded.sender_email,
            sender_display_name = null, suspended_at = null, include_credentials = excluded.include_credentials;
        update public.resource_invitations set status = 'Accepted', accepted_at = now(),
            declined_at = null, token_hash = null, token_issued_at = null
         where id = v_invitation.id;
        return jsonb_build_object('status', 'accepted', 'resource_id', v_invitation.resource_id,
            'resource_type', v_invitation.resource_type);
    end if;
    update public.resource_invitations set status = 'Declined', declined_at = now(),
        accepted_at = null, token_hash = null, token_issued_at = null
     where id = v_invitation.id;
    return jsonb_build_object('status', 'declined');
end;
$$;

create or replace function public.miloom_resource_credential_status(
    p_resource_type text, p_resource_id uuid, p_device_id uuid default null
)
returns table (status text, can_edit boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_actor uuid := auth.uid();
    v_owner uuid;
    v_version integer;
    v_state text;
    v_trusted boolean;
begin
    if v_actor is null or v_type not in ('institution', 'card', 'subscription') then
        return query select 'unavailable'::text, false;
        return;
    end if;
    v_owner := public.miloom_resource_owner(v_type, p_resource_id);
    if v_owner is null or (v_owner <> v_actor and not
        public.miloom_resource_secret_user_eligible(v_actor, v_type, p_resource_id)) then
        return query select 'unavailable'::text, false;
        return;
    end if;

    select sv.key_version, sv.state into v_version, v_state
      from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.state in ('active', 'rotation_required')
     order by sv.key_version desc limit 1;
    if v_version is null then
        return query select 'not_ready'::text, false;
        return;
    end if;
    if v_state <> 'active' then
        return query select 'locked'::text, false;
        return;
    end if;

    select exists (
        select 1 from public.vault_devices d
         where d.id = p_device_id and d.user_id = v_actor
           and d.status = 'approved'
           and d.auth_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid
    ) into v_trusted;
    if not v_trusted then
        return query select 'device_needed'::text, false;
        return;
    end if;
    if v_owner = v_actor or exists (
        select 1 from public.resource_secret_device_wraps w
         where w.resource_type = v_type and w.resource_id = p_resource_id
           and w.key_version = v_version and w.recipient_user_id = v_actor
           and w.recipient_device_id = p_device_id and w.grant_status = 'active'
    ) then
        return query select 'ready'::text, v_owner = v_actor or
            public.miloom_resource_secret_role_allowed(v_actor, v_type, p_resource_id, true);
        return;
    end if;
    return query select 'pending'::text, false;
end;
$$;
revoke all on function public.miloom_resource_credential_status(text,uuid,uuid) from public, anon, authenticated;
grant execute on function public.miloom_resource_credential_status(text,uuid,uuid) to authenticated;

-- Search and resource lists receive presence only. The exact device must
-- still be approved and the share eligible when credentials are opened.
create function public.miloom_has_visible_resource_credentials(p_type text, p_id uuid, p_owner uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.resource_secret_versions v
        where v.resource_type = p_type and v.resource_id = p_id and v.owner_user_id = p_owner
          and v.state in ('active','rotation_required') and v.encrypted_fields <> '{}'::jsonb
          and (p_owner = auth.uid() or public.miloom_resource_secret_user_eligible(auth.uid(),p_type,p_id))
    )
$$;
revoke all on function public.miloom_has_visible_resource_credentials(text,uuid,uuid)
    from public, anon, authenticated;

create function public.miloom_visible_subscriptions_with_credentials()
returns setof jsonb language sql stable security definer set search_path = ''
as $$
    select to_jsonb(r) || case
        when public.miloom_has_visible_resource_credentials('subscription',r.id,r.user_id)
        then '{"has_scoped_credentials":true}'::jsonb else '{}'::jsonb end
    from public.miloom_visible_subscriptions() r
$$;
revoke all on function public.miloom_visible_subscriptions_with_credentials() from public, anon, authenticated;
grant execute on function public.miloom_visible_subscriptions_with_credentials() to authenticated;

create function public.miloom_visible_financial_cards_with_credentials()
returns setof jsonb language sql stable security definer set search_path = ''
as $$
    select to_jsonb(r) || case
        when public.miloom_has_visible_resource_credentials('card',r.id,r.user_id)
        then '{"has_scoped_credentials":true}'::jsonb else '{}'::jsonb end
    from public.miloom_visible_financial_cards() r
$$;
revoke all on function public.miloom_visible_financial_cards_with_credentials() from public, anon, authenticated;
grant execute on function public.miloom_visible_financial_cards_with_credentials() to authenticated;

create function public.miloom_visible_institutions_with_credentials()
returns setof jsonb language sql stable security definer set search_path = ''
as $$
    select to_jsonb(r) || case
        when public.miloom_has_visible_resource_credentials('institution',r.id,r.user_id)
        then '{"has_scoped_credentials":true}'::jsonb else '{}'::jsonb end
    from public.miloom_visible_institutions() r
$$;
revoke all on function public.miloom_visible_institutions_with_credentials() from public, anon, authenticated;
grant execute on function public.miloom_visible_institutions_with_credentials() to authenticated;

notify pgrst, 'reload schema';
commit;
