-- One-off production containment for the pre-canonical collaboration schema.
-- Apply only to production ref xxqdytdbpiqjilhutvhz after rehearsing against
-- the production-shaped schema. Canonical migration 202609220002 supersedes
-- these wrappers when the full collaboration rollout is approved.
begin;

create or replace function public.share_resource(
    p_email text,
    p_role text,
    p_resource_id uuid,
    p_resource_type text,
    p_invited_by uuid,
    p_sender_email text default null,
    p_sender_display_name text default null
)
returns json
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_owner uuid;
    v_actor_email text;
    v_email text := lower(btrim(p_email));
    v_type text := lower(btrim(p_resource_type));
    v_target uuid;
begin
    if v_actor is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if v_email is null or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_EMAIL';
    end if;
    if p_role is null or p_role not in ('Viewer', 'Editor', 'Admin') then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_ROLE';
    end if;
    if v_type is null or v_type not in (
        'company', 'all_subscriptions', 'subscription', 'all_documents',
        'document', 'all_financials', 'institution', 'card', 'loan'
    ) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;

    v_owner := case v_type
        when 'company' then (select user_id from public.companies where id = p_resource_id)
        when 'all_subscriptions' then (select user_id from public.companies where id = p_resource_id)
        when 'all_documents' then (select user_id from public.companies where id = p_resource_id)
        when 'all_financials' then (select user_id from public.companies where id = p_resource_id)
        when 'subscription' then (select user_id from public.subscriptions where id = p_resource_id)
        when 'institution' then (select user_id from public.institutions where id = p_resource_id)
        when 'card' then (select user_id from public.financial_cards where id = p_resource_id)
        when 'loan' then (select user_id from public.loans where id = p_resource_id)
        when 'document' then (select user_id from public.company_documents where id = p_resource_id)
    end;
    if v_owner is distinct from v_actor then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;

    select lower(email) into v_actor_email
      from auth.users where id = v_actor;
    if v_actor_email is null then
        raise exception using errcode = '42501', message = 'ACTOR_EMAIL_REQUIRED';
    end if;
    if v_email = v_actor_email then
        raise exception using errcode = '22023', message = 'CANNOT_SHARE_WITH_SELF';
    end if;

    -- The caller-supplied inviter and sender email are deliberately ignored.
    select id into v_target
      from auth.users
     where lower(email) = v_email
     order by created_at nulls last, id
     limit 1;

    insert into public.resource_invitations (
        resource_id, resource_type, email, role, invited_by,
        sender_email, sender_display_name, status
    ) values (
        p_resource_id, v_type, v_email, p_role, v_actor,
        v_actor_email, p_sender_display_name,
        case when v_target is null then 'Pending' else 'Accepted' end
    )
    on conflict (resource_id, resource_type, email) do update set
        role = excluded.role,
        invited_by = excluded.invited_by,
        sender_email = excluded.sender_email,
        sender_display_name = excluded.sender_display_name,
        status = excluded.status;

    if v_target is not null then
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role,
            sender_email, sender_display_name, suspended_at
        ) values (
            p_resource_id, v_type, v_target, p_role,
            v_actor_email, p_sender_display_name, null
        )
        on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = excluded.sender_display_name,
            suspended_at = null;
        return '{"status":"shared_directly"}'::json;
    end if;
    return '{"status":"invited"}'::json;
end;
$$;

create or replace function public.share_resource(
    p_email text,
    p_role text,
    p_resource_id uuid,
    p_resource_type text,
    p_sender_email text,
    p_sender_display_name text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_result json;
begin
    v_result := public.share_resource(
        p_email, p_role, p_resource_id, p_resource_type,
        auth.uid(), p_sender_email, p_sender_display_name
    );
    if v_result ->> 'status' = 'shared_directly' then
        return 'share_created';
    end if;
    return 'invitation_created';
end;
$$;

revoke all on function public.share_resource(text, text, uuid, text, uuid, text, text)
    from public, anon;
revoke all on function public.share_resource(text, text, uuid, text, text, text)
    from public, anon;
grant execute on function public.share_resource(text, text, uuid, text, uuid, text, text)
    to authenticated;
grant execute on function public.share_resource(text, text, uuid, text, text, text)
    to authenticated;

commit;
