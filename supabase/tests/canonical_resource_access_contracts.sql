-- Run against a disposable database after 202609210002_canonical_resource_access.sql.
begin;

insert into auth.users (id, email) values
    ('81000000-0000-0000-0000-000000000001', 'owner@example.com'),
    ('81000000-0000-0000-0000-000000000002', 'collaborator@example.com'),
    ('81000000-0000-0000-0000-000000000003', 'other-owner@example.com');

insert into public.companies (id, user_id, name, structure) values
    ('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', 'First Entity', 'LLC'),
    ('82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'Second Entity', 'LLC'),
    ('82000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000003', 'Other Entity', 'LLC');

insert into public.subscriptions (id, user_id, company_id, name) values
    ('83000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000001', 'First Subscription'),
    ('83000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', '82000000-0000-0000-0000-000000000002', 'Second Subscription');

select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"81000000-0000-0000-0000-000000000001","email":"owner@example.com"}', true);
set local role authenticated;

do $$
declare
    v_result jsonb;
begin
    v_result := public.miloom_share_resource(
        'Collaborator@Example.com', 'Editor',
        '82000000-0000-0000-0000-000000000001', 'company'
    );
    if v_result->>'status' <> 'shared_directly' then
        raise exception 'Registered collaborator did not receive a direct share';
    end if;
    if not exists (
        select 1 from public.miloom_list_managed_access()
         where access_kind = 'direct'
           and email = 'collaborator@example.com'
           and company_id = '82000000-0000-0000-0000-000000000001'
           and role = 'Editor'
           and status = 'Active'
    ) then
        raise exception 'Direct share missing from unified management list';
    end if;

    v_result := public.miloom_share_resource(
        'pending@example.com', 'Viewer',
        '83000000-0000-0000-0000-000000000001', 'subscription'
    );
    if v_result->>'status' <> 'invitation_created' or v_result->>'invitation_id' is null then
        raise exception 'Unknown collaborator did not receive an invitation ID';
    end if;
    if not exists (
        select 1 from public.miloom_list_managed_access()
         where access_kind = 'invitation'
           and email = 'pending@example.com'
           and company_id = '82000000-0000-0000-0000-000000000001'
           and status = 'Pending'
    ) then
        raise exception 'Invitation missing from unified management list';
    end if;

    begin
        perform public.miloom_share_resource(
            'collaborator@example.com', 'Viewer',
            '82000000-0000-0000-0000-000000000003', 'company'
        );
        raise exception 'Cross-owner share was accepted';
    exception when insufficient_privilege then
        if sqlerrm <> 'RESOURCE_NOT_OWNED' then raise; end if;
    end;

    begin
        perform public.miloom_share_resource(
            'collaborator@example.com', 'Owner',
            '82000000-0000-0000-0000-000000000001', 'company'
        );
        raise exception 'Invalid role was accepted';
    exception when invalid_parameter_value then
        if sqlerrm <> 'INVALID_COLLABORATOR_ROLE' then raise; end if;
    end;
end;
$$;

-- Older app builds retain their original RPC signatures, but their requests
-- are now authorized and normalized by the canonical implementation.
do $$
declare
    v_text_result text;
    v_json_result json;
begin
    v_text_result := public.share_resource(
        'collaborator@example.com', 'Viewer',
        '82000000-0000-0000-0000-000000000002', 'company',
        'forged-sender@example.com', 'Forged Sender'
    );
    if v_text_result <> 'share_created' then
        raise exception 'Legacy text sharing RPC did not preserve its response contract';
    end if;

    v_json_result := public.share_resource(
        'legacy-pending@example.com', 'Viewer',
        '83000000-0000-0000-0000-000000000002', 'subscription',
        '81000000-0000-0000-0000-000000000003',
        'forged-sender@example.com', 'Forged Sender'
    );
    if v_json_result->>'status' <> 'invited' then
        raise exception 'Legacy JSON sharing RPC did not preserve its response contract';
    end if;
    if not exists (
        select 1 from public.resource_invitations
         where email = 'legacy-pending@example.com'
           and invited_by = '81000000-0000-0000-0000-000000000001'
           and sender_email = 'owner@example.com'
    ) then
        raise exception 'Legacy sharing RPC trusted forged inviter or sender data';
    end if;
end;
$$;

-- Resource scope removes only the selected resource and any matching form of access.
do $$
declare v_access_id uuid;
begin
    select access_id into v_access_id
      from public.miloom_list_managed_access()
     where resource_id = '82000000-0000-0000-0000-000000000001'
       and subject_user_id = '81000000-0000-0000-0000-000000000002';
    perform public.miloom_revoke_access(v_access_id, 'direct', 'resource');
    if exists (select 1 from public.miloom_list_managed_access() where access_id = v_access_id) then
        raise exception 'Resource revoke retained the direct share';
    end if;
    if not exists (select 1 from public.miloom_list_managed_access() where email = 'pending@example.com') then
        raise exception 'Resource revoke removed unrelated invitation';
    end if;
end;
$$;

-- Entity scope spans company-level and child-resource access, but not another entity.
select public.miloom_share_resource('collaborator@example.com', 'Viewer', '82000000-0000-0000-0000-000000000001', 'company');
select public.miloom_share_resource('collaborator@example.com', 'Editor', '83000000-0000-0000-0000-000000000001', 'subscription');
select public.miloom_share_resource('collaborator@example.com', 'Viewer', '82000000-0000-0000-0000-000000000002', 'company');

do $$
declare v_access_id uuid;
begin
    select access_id into v_access_id
      from public.miloom_list_managed_access()
     where resource_id = '83000000-0000-0000-0000-000000000001'
       and subject_user_id = '81000000-0000-0000-0000-000000000002';
    perform public.miloom_revoke_access(v_access_id, 'direct', 'entity');
    if exists (
        select 1 from public.miloom_list_managed_access()
         where subject_user_id = '81000000-0000-0000-0000-000000000002'
           and company_id = '82000000-0000-0000-0000-000000000001'
    ) then
        raise exception 'Entity revoke retained access inside the entity';
    end if;
    if not exists (
        select 1 from public.miloom_list_managed_access()
         where subject_user_id = '81000000-0000-0000-0000-000000000002'
           and resource_id = '82000000-0000-0000-0000-000000000002'
    ) then
        raise exception 'Entity revoke removed access to another entity';
    end if;
end;
$$;

-- Person scope removes portfolio-wide access and blocks future grants until unblocked.
do $$
declare v_access_id uuid; v_block_id uuid;
begin
    select access_id into v_access_id
      from public.miloom_list_managed_access()
     where subject_user_id = '81000000-0000-0000-0000-000000000002'
       and resource_id = '82000000-0000-0000-0000-000000000002';
    perform public.miloom_revoke_access(v_access_id, 'direct', 'person');

    if exists (
        select 1 from public.miloom_list_managed_access()
         where email = 'collaborator@example.com'
    ) then
        raise exception 'Person block retained managed access';
    end if;

    select id into v_block_id
      from public.miloom_list_access_blocks()
     where email = 'collaborator@example.com';
    if v_block_id is null then raise exception 'Person block was not recorded'; end if;

    begin
        perform public.miloom_share_resource(
            'collaborator@example.com', 'Viewer',
            '82000000-0000-0000-0000-000000000001', 'company'
        );
        raise exception 'Blocked collaborator was shared again';
    exception when raise_exception then
        if sqlerrm <> 'COLLABORATOR_BLOCKED' then raise; end if;
    end;

    perform public.miloom_unblock_collaborator(v_block_id);
    perform public.miloom_share_resource(
        'collaborator@example.com', 'Viewer',
        '82000000-0000-0000-0000-000000000001', 'company'
    );
end;
$$;

-- Another owner cannot enumerate or mutate this owner's access records.
reset role;
select set_config('request.jwt.claim.sub', '81000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"81000000-0000-0000-0000-000000000003","email":"other-owner@example.com"}', true);
set local role authenticated;

do $$
begin
    if exists (select 1 from public.miloom_list_managed_access()) then
        raise exception 'Cross-owner management list leaked access';
    end if;
    begin
        perform public.miloom_revoke_access(
            (select id from public.resource_shares limit 1), 'direct', 'resource'
        );
        raise exception 'Cross-owner revoke was accepted';
    exception when no_data_found then
        if sqlerrm <> 'ACCESS_RECORD_NOT_FOUND' then raise; end if;
    end;
end;
$$;

reset role;
set local role anon;
do $$
begin
    if has_function_privilege('anon', 'public.miloom_share_resource(text,text,uuid,text)', 'EXECUTE') then
        raise exception 'Anonymous role can execute sharing RPC';
    end if;
    if has_function_privilege('anon', 'public.miloom_revoke_access(uuid,text,text)', 'EXECUTE') then
        raise exception 'Anonymous role can execute revoke RPC';
    end if;
    if has_function_privilege('anon', 'public.share_resource(text,text,uuid,text,text,text)', 'EXECUTE') then
        raise exception 'Anonymous role can execute legacy text sharing RPC';
    end if;
    if has_function_privilege('anon', 'public.share_resource(text,text,uuid,text,uuid,text,text)', 'EXECUTE') then
        raise exception 'Anonymous role can execute legacy JSON sharing RPC';
    end if;
    if has_function_privilege('anon', 'public.leave_resource(uuid)', 'EXECUTE') then
        raise exception 'Anonymous role can execute legacy leave RPC';
    end if;
end;
$$;

rollback;
