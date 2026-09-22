-- Run against a disposable database after Phase 1 and Phase 2 collaboration migrations.
begin;

create temporary table phase2_tokens (
    name text primary key,
    invitation_id uuid not null,
    token text
);
grant select, insert, update on phase2_tokens to service_role, authenticated;

insert into auth.users (id, email) values
    ('91000000-0000-0000-0000-000000000001', 'owner@example.com'),
    ('91000000-0000-0000-0000-000000000002', 'wrong-recipient@example.com');

insert into public.companies (id, user_id, name, structure) values
    ('92000000-0000-0000-0000-000000000001', '91000000-0000-0000-0000-000000000001', 'Invitation Entity', 'LLC');

select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000001","email":"owner@example.com"}', true);
set local role authenticated;

do $$
declare v_result jsonb;
begin
    v_result := public.miloom_share_resource(
        'recipient@example.com', 'Editor',
        '92000000-0000-0000-0000-000000000001', 'company'
    );
    if v_result->>'status' <> 'invitation_created' then
        raise exception 'Pending recipient did not receive invitation';
    end if;
end;
$$;

insert into phase2_tokens(name, invitation_id)
select 'accept', id
  from public.resource_invitations
 where email = 'recipient@example.com';

reset role;
set local role service_role;

update phase2_tokens
   set token = public.miloom_issue_invitation_token(
    invitation_id,
    '91000000-0000-0000-0000-000000000001'
)->>'token'
 where name = 'accept';

do $$
begin
    begin
        perform public.miloom_issue_invitation_token(
            (select invitation_id from phase2_tokens where name = 'accept'),
            '91000000-0000-0000-0000-000000000001'
        );
        raise exception 'Immediate resend bypassed rate limit';
    exception when raise_exception then
        if sqlerrm <> 'INVITATION_SEND_RATE_LIMITED' then raise; end if;
    end;
end;
$$;

reset role;
insert into auth.users (id, email) values
    ('91000000-0000-0000-0000-000000000003', 'recipient@example.com');

-- A different authenticated email cannot preview or act on an intercepted token.
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000002","email":"wrong-recipient@example.com"}', true);
set local role authenticated;

do $$
begin
    if exists (
        select 1 from public.miloom_preview_invitation_token(
            (select token from phase2_tokens where name = 'accept')
        )
    ) then
        raise exception 'Wrong recipient previewed intercepted invitation';
    end if;
    begin
        perform public.miloom_accept_invitation_token(
            (select token from phase2_tokens where name = 'accept')
        );
        raise exception 'Wrong recipient accepted intercepted invitation';
    exception when no_data_found then
        if sqlerrm <> 'INVITATION_NOT_AVAILABLE' then raise; end if;
    end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000003","email":"recipient@example.com"}', true);
set local role authenticated;

do $$
declare v_token text := (select token from phase2_tokens where name = 'accept');
begin
    if not exists (select 1 from public.miloom_list_my_invitations()) then
        raise exception 'Recipient inbox omitted pending invitation';
    end if;
    if not exists (
        select 1 from public.miloom_preview_invitation_token(v_token)
         where role = 'Editor' and company_title = 'Invitation Entity'
    ) then
        raise exception 'Recipient could not preview valid token';
    end if;

    perform public.miloom_accept_invitation_token(v_token);
    if not exists (
        select 1 from public.resource_shares
         where resource_id = '92000000-0000-0000-0000-000000000001'
           and user_id = '91000000-0000-0000-0000-000000000003'
           and role = 'Editor'
    ) then
        raise exception 'Accept did not create direct share';
    end if;
    if exists (select 1 from public.miloom_list_my_invitations()) then
        raise exception 'Accepted invitation remained in recipient inbox';
    end if;

    begin
        perform public.miloom_accept_invitation_token(v_token);
        raise exception 'Single-use token was replayed';
    exception when no_data_found then
        if sqlerrm <> 'INVITATION_NOT_AVAILABLE' then raise; end if;
    end;
end;
$$;

-- Owner management shows only the direct edge after acceptance.
reset role;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000001","email":"owner@example.com"}', true);
set local role authenticated;

do $$
begin
    if (select count(*) from public.miloom_list_managed_access() where email = 'recipient@example.com') <> 1 then
        raise exception 'Accepted invitation duplicated direct access in owner management';
    end if;
end;
$$;

-- A signed-in recipient can decline from the inbox without an email token.
select public.miloom_share_resource(
    'decline@example.com', 'Viewer',
    '92000000-0000-0000-0000-000000000001', 'company'
);
reset role;
insert into auth.users (id, email) values
    ('91000000-0000-0000-0000-000000000004', 'decline@example.com');
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000004","email":"decline@example.com"}', true);
set local role authenticated;

do $$
declare v_id uuid;
begin
    select invitation_id into v_id from public.miloom_list_my_invitations();
    perform public.miloom_decline_invitation(v_id);
    if exists (select 1 from public.miloom_list_my_invitations()) then
        raise exception 'Declined invitation remained in inbox';
    end if;
    if exists (
        select 1 from public.resource_shares
         where user_id = '91000000-0000-0000-0000-000000000004'
    ) then
        raise exception 'Decline created direct access';
    end if;
end;
$$;

-- Expired invitations are hidden and cannot be accepted.
reset role;
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000001","email":"owner@example.com"}', true);
set local role authenticated;
select public.miloom_share_resource(
    'expired@example.com', 'Viewer',
    '92000000-0000-0000-0000-000000000001', 'company'
);
reset role;
insert into auth.users (id, email) values
    ('91000000-0000-0000-0000-000000000005', 'expired@example.com');
update public.resource_invitations set expires_at = now() - interval '1 minute' where email = 'expired@example.com';
select set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000005', true);
select set_config('request.jwt.claims', '{"sub":"91000000-0000-0000-0000-000000000005","email":"expired@example.com"}', true);
set local role authenticated;

do $$
declare v_id uuid;
begin
    select id into v_id from public.resource_invitations where email = 'expired@example.com';
    if exists (select 1 from public.miloom_list_my_invitations()) then
        raise exception 'Expired invitation appeared in inbox';
    end if;
    begin
        perform public.miloom_accept_invitation(v_id);
        raise exception 'Expired invitation was accepted';
    exception when no_data_found then
        if sqlerrm <> 'INVITATION_NOT_AVAILABLE' then raise; end if;
    end;
end;
$$;

reset role;
set local role anon;
do $$
begin
    if has_function_privilege('anon', 'public.miloom_list_my_invitations()', 'EXECUTE') then
        raise exception 'Anonymous role can list invitations';
    end if;
    if has_function_privilege('anon', 'public.miloom_accept_invitation_token(text)', 'EXECUTE') then
        raise exception 'Anonymous role can accept invitation tokens';
    end if;
    if has_function_privilege('authenticated', 'public.miloom_issue_invitation_token(uuid,uuid)', 'EXECUTE') then
        raise exception 'Authenticated clients can issue invitation tokens';
    end if;
end;
$$;

rollback;
