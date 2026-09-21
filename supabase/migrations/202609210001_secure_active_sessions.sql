-- User-owned session inventory and targeted revocation.
-- The server derives the current session from the verified JWT instead of
-- trusting a session identifier supplied by the client.

drop function if exists public.get_active_sessions();

create function public.get_active_sessions()
returns table (
    id uuid,
    created_at timestamptz,
    updated_at timestamptz,
    user_agent text,
    ip_address text,
    is_current boolean
)
language sql
stable
security definer
set search_path = ''
as $$
    select
        session.id,
        session.created_at,
        session.updated_at,
        session.user_agent,
        session.ip::text,
        coalesce(session.id::text = auth.jwt() ->> 'session_id', false)
    from auth.sessions as session
    where session.user_id = auth.uid()
    order by session.updated_at desc;
$$;

revoke all on function public.get_active_sessions() from public, anon;
grant execute on function public.get_active_sessions() to authenticated;

drop function if exists public.revoke_session(uuid);

create function public.revoke_session(session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'AUTHENTICATION_REQUIRED' using errcode = 'P0001';
    end if;

    if $1::text = auth.jwt() ->> 'session_id' then
        raise exception 'CURRENT_SESSION_CANNOT_BE_REVOKED' using errcode = 'P0001';
    end if;

    delete from auth.sessions as session
    where session.id = $1
      and session.user_id = auth.uid();

    if not found then
        raise exception 'SESSION_NOT_FOUND' using errcode = 'P0001';
    end if;
end;
$$;

revoke all on function public.revoke_session(uuid) from public, anon;
grant execute on function public.revoke_session(uuid) to authenticated;

notify pgrst, 'reload schema';
