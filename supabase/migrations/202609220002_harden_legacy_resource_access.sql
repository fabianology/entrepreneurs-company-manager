-- Preserve older client RPC signatures while routing every mutation through
-- the canonical owner-validated resource access contract.

begin;

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
set search_path = public, auth
as $$
declare
    v_result jsonb;
begin
    v_result := public.miloom_share_resource(
        p_email,
        p_role,
        p_resource_id,
        p_resource_type
    );

    if v_result->>'status' = 'shared_directly' then
        return 'share_created';
    end if;
    return 'invitation_created';
end;
$$;

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
set search_path = public, auth
as $$
declare
    v_result jsonb;
begin
    v_result := public.miloom_share_resource(
        p_email,
        p_role,
        p_resource_id,
        p_resource_type
    );

    if v_result->>'status' = 'shared_directly' then
        return json_build_object('status', 'shared_directly');
    end if;
    return json_build_object('status', 'invited');
end;
$$;

create or replace function public.leave_resource(p_resource_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
begin
    if v_actor is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;

    select lower(email) into v_actor_email
      from auth.users
     where id = v_actor;

    delete from public.resource_shares
     where resource_id = p_resource_id
       and user_id = v_actor;

    if v_actor_email is not null then
        delete from public.resource_invitations
         where resource_id = p_resource_id
           and lower(email) = v_actor_email;
    end if;
end;
$$;

revoke all on function public.share_resource(text, text, uuid, text, text, text)
from public, anon;
revoke all on function public.share_resource(text, text, uuid, text, uuid, text, text)
from public, anon;
revoke all on function public.leave_resource(uuid)
from public, anon;

grant execute on function public.share_resource(text, text, uuid, text, text, text)
to authenticated, service_role;
grant execute on function public.share_resource(text, text, uuid, text, uuid, text, text)
to authenticated, service_role;
grant execute on function public.leave_resource(uuid)
to authenticated, service_role;

commit;
