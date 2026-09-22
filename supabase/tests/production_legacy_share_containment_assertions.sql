-- Run after the fixture and ops SQL in a disposable PostgreSQL database.
do $$
declare
    v_result json;
    v_text text;
begin
    if has_function_privilege('anon',
        'public.share_resource(text,text,uuid,text,uuid,text,text)', 'EXECUTE')
       or has_function_privilege('anon',
        'public.share_resource(text,text,uuid,text,text,text)', 'EXECUTE') then
        raise exception 'anonymous execution remains available';
    end if;
    if not has_function_privilege('authenticated',
        'public.share_resource(text,text,uuid,text,uuid,text,text)', 'EXECUTE') then
        raise exception 'authenticated execution missing';
    end if;

    perform set_config('request.jwt.claim.sub', '', true);
    begin
        perform public.share_resource('target@example.com', 'Viewer',
            '10000000-0000-0000-0000-000000000001', 'company',
            null::uuid, null::text, null::text);
        raise exception 'unauthenticated sharing succeeded';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000002', true);
    begin
        perform public.share_resource('target@example.com', 'Viewer',
            '10000000-0000-0000-0000-000000000001', 'company',
            null::uuid, null::text, null::text);
        raise exception 'non-owner sharing succeeded';
    exception when insufficient_privilege then null;
    end;
    if exists (select 1 from public.resource_invitations) then
        raise exception 'rejected call wrote an invitation';
    end if;

    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000001', true);
    v_result := public.share_resource(' TARGET@example.com ', 'Viewer',
        '10000000-0000-0000-0000-000000000001', 'company',
        '00000000-0000-0000-0000-000000000002',
        'forged@example.com', 'Owner');
    if v_result ->> 'status' <> 'shared_directly' then
        raise exception 'registered recipient did not receive direct share';
    end if;
    if not exists (
        select 1 from public.resource_invitations
         where email = 'target@example.com'
           and invited_by = '00000000-0000-0000-0000-000000000001'
           and sender_email = 'owner@example.com'
           and status = 'Accepted'
    ) then
        raise exception 'inviter identity was not server-derived';
    end if;
    if not exists (
        select 1 from public.resource_shares
         where user_id = '00000000-0000-0000-0000-000000000003'
           and sender_email = 'owner@example.com'
    ) then
        raise exception 'direct share missing';
    end if;

    v_text := public.share_resource('new@example.com', 'Editor',
        '20000000-0000-0000-0000-000000000001', 'subscription',
        'forged@example.com', 'Owner');
    if v_text <> 'invitation_created' then
        raise exception 'legacy six-argument return value changed';
    end if;
    if not exists (
        select 1 from public.resource_invitations
         where email = 'new@example.com'
           and resource_type = 'subscription'
           and status = 'Pending'
    ) then
        raise exception 'unregistered recipient invite missing';
    end if;

    begin
        perform public.share_resource('other@example.com', 'Viewer',
            '10000000-0000-0000-0000-000000000099', 'company',
            null::uuid, null::text, null::text);
        raise exception 'nonexistent resource sharing succeeded';
    exception when insufficient_privilege then null;
    end;
end;
$$;
