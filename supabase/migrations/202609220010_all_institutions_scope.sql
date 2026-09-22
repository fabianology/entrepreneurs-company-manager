-- A bank/institution collection is not the same as all financial records.
-- This scope never grants cards, loans, subscriptions, or documents.
-- Apply after the canonical collaboration, editor, redaction, and Admin-scope
-- migrations. This is not a production hotfix.

begin;

create or replace function public.miloom_resource_owner(p_type text, p_id uuid)
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
begin
    return case lower(p_type)
        when 'company' then (select user_id from public.companies where id = p_id)
        when 'all_subscriptions' then (select user_id from public.companies where id = p_id)
        when 'all_documents' then (select user_id from public.companies where id = p_id)
        when 'all_financials' then (select user_id from public.companies where id = p_id)
        when 'all_institutions' then (select user_id from public.companies where id = p_id)
        when 'subscription' then (select user_id from public.subscriptions where id = p_id)
        when 'institution' then (select user_id from public.institutions where id = p_id)
        when 'card' then (select user_id from public.financial_cards where id = p_id)
        when 'loan' then (select user_id from public.loans where id = p_id)
        when 'document' then (select user_id from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.miloom_resource_company(p_type text, p_id uuid)
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
begin
    return case lower(p_type)
        when 'company' then p_id
        when 'all_subscriptions' then p_id
        when 'all_documents' then p_id
        when 'all_financials' then p_id
        when 'all_institutions' then p_id
        when 'subscription' then (select company_id from public.subscriptions where id = p_id)
        when 'institution' then (select company_id from public.institutions where id = p_id)
        when 'card' then (select company_id from public.financial_cards where id = p_id)
        when 'loan' then (select company_id from public.loans where id = p_id)
        when 'document' then (select company_id from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.miloom_resource_title(p_type text, p_id uuid)
returns text
language plpgsql stable security definer set search_path = ''
as $$
begin
    return case lower(p_type)
        when 'company' then (select name from public.companies where id = p_id)
        when 'all_subscriptions' then 'All Subscriptions'
        when 'all_documents' then 'All Documents'
        when 'all_financials' then 'All Financials'
        when 'all_institutions' then 'All Institutions'
        when 'subscription' then (select name from public.subscriptions where id = p_id)
        when 'institution' then (select name from public.institutions where id = p_id)
        when 'card' then (select name from public.financial_cards where id = p_id)
        when 'loan' then (select name from public.loans where id = p_id)
        when 'document' then (select name from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

-- A child or collection grant must expose the containing company shell so the
-- recipient can navigate to the granted item. The shell is read-only unless
-- there is a separate company Editor/Admin share. Pending invitations never
-- confer access merely because their email matches the signed-in user.
create or replace function public.miloom_can_read_company(
    p_company_id uuid, p_owner_user_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select p_owner_user_id = (select auth.uid())
        or exists (
            select 1 from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.suspended_at is null
               and public.miloom_resource_company(rs.resource_type, rs.resource_id) = p_company_id
        );
$$;
revoke all on function public.miloom_can_read_company(uuid, uuid) from public, anon;
grant execute on function public.miloom_can_read_company(uuid, uuid) to authenticated;

create or replace function public.miloom_can_read_resource(
    p_resource_type text, p_resource_id uuid, p_company_id uuid, p_owner_user_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select p_owner_user_id = (select auth.uid())
        or exists (
            select 1 from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.suspended_at is null
               and (
                    (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                    or (rs.resource_type = 'company' and rs.resource_id = p_company_id)
                    or (rs.resource_id = p_company_id and (
                        (rs.resource_type = 'all_subscriptions' and lower(p_resource_type) = 'subscription')
                        or (rs.resource_type = 'all_institutions' and lower(p_resource_type) = 'institution')
                        or (rs.resource_type = 'all_financials' and lower(p_resource_type) in ('institution', 'card', 'loan'))
                        or (rs.resource_type = 'all_documents' and lower(p_resource_type) = 'document')
                    ))
               )
        );
$$;

create or replace function public.miloom_can_edit_resource(
    p_resource_type text, p_resource_id uuid, p_company_id uuid, p_owner_user_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select p_owner_user_id = (select auth.uid())
        or exists (
            select 1 from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.suspended_at is null
               and rs.role in ('Editor', 'Admin')
               and (
                    (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                    or (rs.resource_type = 'company' and rs.resource_id = p_company_id)
                    or (rs.resource_id = p_company_id and (
                        (rs.resource_type = 'all_subscriptions' and lower(p_resource_type) = 'subscription')
                        or (rs.resource_type = 'all_institutions' and lower(p_resource_type) = 'institution')
                        or (rs.resource_type = 'all_financials' and lower(p_resource_type) in ('institution', 'card', 'loan'))
                        or (rs.resource_type = 'all_documents' and lower(p_resource_type) = 'document')
                    ))
               )
        );
$$;

-- Keep the existing owner-only grant path until the separately tested Admin
-- Viewer-management RPCs are ready. No collaborator gains delegation here.
create or replace function public.miloom_share_resource(
    p_email text, p_role text, p_resource_id uuid, p_resource_type text
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
            sender_email, sender_display_name, suspended_at
        ) values (
            p_resource_id, v_type, v_target, p_role, v_actor_email, null, null
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null;

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
            sender_email, sender_display_name, status
        ) values (
            p_resource_id, v_type, v_email, p_role, v_actor,
            v_actor_email, null, 'Pending'
        ) returning id into v_invitation_id;
    else
        update public.resource_invitations
           set role = p_role, invited_by = v_actor,
               sender_email = v_actor_email, sender_display_name = null,
               status = 'Pending'
         where id = v_invitation_id;
    end if;
    return jsonb_build_object('status', 'invitation_created', 'invitation_id', v_invitation_id);
end;
$$;

notify pgrst, 'reload schema';
commit;
