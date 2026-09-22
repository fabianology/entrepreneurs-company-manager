-- Entity Admins may list an entity's collaborators and grant/revoke Viewer
-- access within it. Owner-only Editor/Admin grants, block, and broad revoke
-- remain unchanged. No vault key or password access is delegated here.

begin;

create or replace function public.miloom_admin_entity_id(p_company_id uuid)
returns uuid
language sql stable security definer set search_path = ''
as $$
    select c.id from public.companies c
     where c.id = p_company_id
       and exists (
           select 1 from public.resource_shares rs
            where rs.user_id = (select auth.uid())
              and rs.resource_type = 'company'
              and rs.resource_id = c.id
              and rs.role = 'Admin'
              and rs.suspended_at is null
       );
$$;
revoke all on function public.miloom_admin_entity_id(uuid) from public, anon, authenticated;

create or replace function public.miloom_admin_list_entity_access(p_company_id uuid)
returns table (
    access_id uuid, access_kind text, resource_id uuid, resource_type text,
    company_id uuid, email text, subject_user_id uuid, role text,
    status text, created_at timestamptz
)
language plpgsql stable security definer set search_path = ''
as $$
begin
    if auth.uid() is null or public.miloom_admin_entity_id(p_company_id) is null then
        raise exception using errcode = '42501', message = 'ENTITY_ADMIN_REQUIRED';
    end if;
    return query
    select rs.id, 'direct'::text, rs.resource_id, rs.resource_type,
           p_company_id, lower(au.email), rs.user_id, rs.role,
           case when rs.suspended_at is null then 'Active' else 'Suspended' end,
           rs.created_at
      from public.resource_shares rs
      join auth.users au on au.id = rs.user_id
     where public.miloom_resource_company(rs.resource_type, rs.resource_id) = p_company_id
    union all
    select ri.id, 'invitation'::text, ri.resource_id, ri.resource_type,
           p_company_id, lower(ri.email), au.id, ri.role, ri.status, ri.created_at
      from public.resource_invitations ri
      left join auth.users au on lower(au.email) = lower(ri.email)
     where public.miloom_resource_company(ri.resource_type, ri.resource_id) = p_company_id
       and ri.status in ('Pending', 'Accepted');
end;
$$;
revoke all on function public.miloom_admin_list_entity_access(uuid) from public, anon;
grant execute on function public.miloom_admin_list_entity_access(uuid) to authenticated;

create or replace function public.miloom_admin_share_viewer(
    p_email text, p_resource_id uuid, p_resource_type text
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
            sender_email, sender_display_name, suspended_at
        ) values (
            p_resource_id, v_type, v_target, 'Viewer',
            v_actor_email, null, null
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null;
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
            sender_email, sender_display_name, status
        ) values (
            p_resource_id, v_type, v_email, 'Viewer', v_actor,
            v_actor_email, null, 'Pending'
        ) returning id into v_invitation_id;
    else
        update public.resource_invitations
           set invited_by = v_actor, sender_email = v_actor_email,
               sender_display_name = null, status = 'Pending'
         where id = v_invitation_id and role = 'Viewer';
        if not found then
            raise exception using errcode = '42501', message = 'HIGHER_ROLE_MANAGED_BY_OWNER';
        end if;
    end if;
    return jsonb_build_object('status', 'invitation_created', 'invitation_id', v_invitation_id);
end;
$$;
revoke all on function public.miloom_admin_share_viewer(text, uuid, text) from public, anon;
grant execute on function public.miloom_admin_share_viewer(text, uuid, text) to authenticated;

create or replace function public.miloom_admin_revoke_viewer(
    p_access_id uuid, p_access_kind text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_resource_id uuid;
    v_type text;
    v_company uuid;
    v_email text;
    v_subject uuid;
    v_role text;
    v_count integer := 0;
begin
    if auth.uid() is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if p_access_kind not in ('direct', 'invitation') then
        raise exception using errcode = '22023', message = 'INVALID_ACCESS_KIND';
    end if;
    if p_access_kind = 'direct' then
        select rs.resource_id, rs.resource_type, rs.user_id, lower(au.email), rs.role
          into v_resource_id, v_type, v_subject, v_email, v_role
          from public.resource_shares rs join auth.users au on au.id = rs.user_id
         where rs.id = p_access_id;
    else
        select ri.resource_id, ri.resource_type, au.id, lower(ri.email), ri.role
          into v_resource_id, v_type, v_subject, v_email, v_role
          from public.resource_invitations ri
          left join auth.users au on lower(au.email) = lower(ri.email)
         where ri.id = p_access_id and ri.status in ('Pending', 'Accepted');
    end if;
    if v_resource_id is null or v_role <> 'Viewer' then
        raise exception using errcode = '42501', message = 'VIEWER_ACCESS_REQUIRED';
    end if;
    v_company := public.miloom_resource_company(v_type, v_resource_id);
    if v_company is null or public.miloom_admin_entity_id(v_company) is null then
        raise exception using errcode = '42501', message = 'ENTITY_ADMIN_REQUIRED';
    end if;

    delete from public.resource_invitations ri
     where ri.resource_id = v_resource_id and ri.resource_type = v_type
       and lower(ri.email) = v_email and ri.role = 'Viewer'
       and ri.status in ('Pending', 'Accepted');
    get diagnostics v_count = row_count;
    if v_subject is not null then
        delete from public.resource_shares rs
         where rs.resource_id = v_resource_id and rs.resource_type = v_type
           and rs.user_id = v_subject and rs.role = 'Viewer';
        v_count := v_count + found::integer;
    end if;
    return jsonb_build_object('scope', 'resource', 'removed', v_count);
end;
$$;
revoke all on function public.miloom_admin_revoke_viewer(uuid, text) from public, anon;
grant execute on function public.miloom_admin_revoke_viewer(uuid, text) to authenticated;

-- An Owner must see invitations sent by an Admin for an owned resource.
create or replace function public.miloom_list_managed_access()
returns table (
    access_id uuid, access_kind text, resource_id uuid, resource_type text,
    company_id uuid, email text, subject_user_id uuid, role text,
    status text, created_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
    select rs.id, 'direct'::text, rs.resource_id, rs.resource_type,
           public.miloom_resource_company(rs.resource_type, rs.resource_id),
           lower(au.email), rs.user_id, rs.role,
           case when rs.suspended_at is null then 'Active' else 'Suspended' end,
           rs.created_at
      from public.resource_shares rs join auth.users au on au.id = rs.user_id
     where public.miloom_resource_owner(rs.resource_type, rs.resource_id) = auth.uid()
    union all
    select ri.id, 'invitation'::text, ri.resource_id, ri.resource_type,
           public.miloom_resource_company(ri.resource_type, ri.resource_id),
           lower(ri.email), au.id, ri.role, ri.status, ri.created_at
      from public.resource_invitations ri
      left join auth.users au on lower(au.email) = lower(ri.email)
     where public.miloom_resource_owner(ri.resource_type, ri.resource_id) = auth.uid()
       and ri.status in ('Pending', 'Accepted')
    order by 10 desc, 1;
$$;

-- Existing owner RPC must also be able to revoke Admin-created invitations.
create or replace function public.miloom_revoke_access(
    p_access_id uuid, p_access_kind text, p_scope text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_email text;
    v_subject uuid;
    v_resource_id uuid;
    v_type text;
    v_company uuid;
    v_deleted_invitations integer := 0;
    v_deleted_shares integer := 0;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if p_access_kind not in ('direct', 'invitation') then
        raise exception using errcode = '22023', message = 'INVALID_ACCESS_KIND';
    end if;
    if p_scope not in ('resource', 'entity', 'person') then
        raise exception using errcode = '22023', message = 'INVALID_REVOKE_SCOPE';
    end if;
    if p_access_kind = 'direct' then
        select lower(au.email), rs.user_id, rs.resource_id, rs.resource_type
          into v_email, v_subject, v_resource_id, v_type
          from public.resource_shares rs join auth.users au on au.id = rs.user_id
         where rs.id = p_access_id
           and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
    else
        select lower(ri.email), au.id, ri.resource_id, ri.resource_type
          into v_email, v_subject, v_resource_id, v_type
          from public.resource_invitations ri
          left join auth.users au on lower(au.email) = lower(ri.email)
         where ri.id = p_access_id
           and public.miloom_resource_owner(ri.resource_type, ri.resource_id) = v_actor;
    end if;
    if v_email is null or v_resource_id is null then
        raise exception using errcode = 'P0002', message = 'ACCESS_RECORD_NOT_FOUND';
    end if;
    v_company := public.miloom_resource_company(v_type, v_resource_id);

    if p_scope = 'resource' then
        delete from public.resource_invitations ri
         where lower(ri.email) = v_email
           and ri.resource_id = v_resource_id and ri.resource_type = v_type
           and public.miloom_resource_owner(ri.resource_type, ri.resource_id) = v_actor;
        get diagnostics v_deleted_invitations = row_count;
        if v_subject is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject
               and rs.resource_id = v_resource_id and rs.resource_type = v_type
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
            get diagnostics v_deleted_shares = row_count;
        end if;
    elsif p_scope = 'entity' then
        if v_company is null then
            raise exception using errcode = 'P0001', message = 'ENTITY_SCOPE_UNAVAILABLE';
        end if;
        delete from public.resource_invitations ri
         where lower(ri.email) = v_email
           and public.miloom_resource_owner(ri.resource_type, ri.resource_id) = v_actor
           and public.miloom_resource_company(ri.resource_type, ri.resource_id) = v_company;
        get diagnostics v_deleted_invitations = row_count;
        if v_subject is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor
               and public.miloom_resource_company(rs.resource_type, rs.resource_id) = v_company;
            get diagnostics v_deleted_shares = row_count;
        end if;
    else
        delete from public.resource_invitations ri
         where lower(ri.email) = v_email
           and public.miloom_resource_owner(ri.resource_type, ri.resource_id) = v_actor;
        get diagnostics v_deleted_invitations = row_count;
        if v_subject is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
            get diagnostics v_deleted_shares = row_count;
        end if;
        insert into public.resource_access_blocks (owner_user_id, blocked_email, blocked_user_id)
        values (v_actor, v_email, v_subject)
        on conflict (owner_user_id, lower(blocked_email)) do update set
            blocked_user_id = excluded.blocked_user_id, created_at = now();
    end if;
    return jsonb_build_object(
        'scope', p_scope, 'deleted_invitations', v_deleted_invitations,
        'deleted_shares', v_deleted_shares, 'blocked', p_scope = 'person'
    );
end;
$$;

notify pgrst, 'reload schema';
commit;
