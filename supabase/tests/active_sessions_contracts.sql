-- Run against a disposable database with the active-sessions migration applied.
begin;

insert into auth.users(id) values
    ('15000000-0000-0000-0000-000000000001'),
    ('15000000-0000-0000-0000-000000000002');

insert into auth.sessions(id, user_id, user_agent, ip) values
    ('25000000-0000-0000-0000-000000000001', '15000000-0000-0000-0000-000000000001', 'Miloom iOS App (iPhone; iOS 26.0)', '203.0.113.10'),
    ('25000000-0000-0000-0000-000000000002', '15000000-0000-0000-0000-000000000001', 'Miloom App (Mac)', '203.0.113.11'),
    ('25000000-0000-0000-0000-000000000003', '15000000-0000-0000-0000-000000000002', 'Other user', '203.0.113.12');

select set_config(
    'request.jwt.claims',
    '{"sub":"15000000-0000-0000-0000-000000000001","role":"authenticated","session_id":"25000000-0000-0000-0000-000000000001"}',
    true
);
set local role authenticated;

do $$
begin
    if (select count(*) from public.get_active_sessions()) <> 2 then
        raise exception 'Session inventory crossed its owner boundary';
    end if;

    if (select count(*) from public.get_active_sessions() where is_current) <> 1 then
        raise exception 'Current session was not identified exactly once';
    end if;

    if not exists (
        select 1 from public.get_active_sessions()
        where id = '25000000-0000-0000-0000-000000000001' and is_current
    ) then
        raise exception 'JWT session_id did not identify the current session';
    end if;

    begin
        perform public.revoke_session('25000000-0000-0000-0000-000000000001');
        raise exception 'Current session revocation was allowed';
    exception when raise_exception then
        if sqlerrm <> 'CURRENT_SESSION_CANNOT_BE_REVOKED' then raise; end if;
    end;

    begin
        perform public.revoke_session('25000000-0000-0000-0000-000000000003');
        raise exception 'Cross-owner session revocation was allowed';
    exception when raise_exception then
        if sqlerrm <> 'SESSION_NOT_FOUND' then raise; end if;
    end;

    perform public.revoke_session('25000000-0000-0000-0000-000000000002');
    if exists (
        select 1 from public.get_active_sessions()
        where id = '25000000-0000-0000-0000-000000000002'
    ) then
        raise exception 'Owned remote session was not revoked';
    end if;
end $$;

reset role;

set local role anon;
do $$
begin
    begin
        perform * from public.get_active_sessions();
        raise exception 'Anonymous caller listed sessions';
    exception when insufficient_privilege then null; end;
end $$;

reset role;
rollback;
