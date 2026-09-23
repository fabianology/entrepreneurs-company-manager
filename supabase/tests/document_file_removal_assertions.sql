-- Run after Storage fixture, reservation fixture and migrations 022–023, 025–027.
insert into public.resource_shares(resource_id, resource_type, user_id, role)
values ('60000000-0000-0000-0000-000000000002', 'document',
    '00000000-0000-0000-0000-000000000002', 'Editor'),
    ('60000000-0000-0000-0000-000000000003', 'document',
    '00000000-0000-0000-0000-000000000002', 'Editor');

do $$
declare
    v_shared text := '00000000-0000-0000-0000-000000000001/shared.pdf';
    v_sibling text := '00000000-0000-0000-0000-000000000001/sibling.pdf';
begin
    if has_function_privilege('anon',
        'public.miloom_clear_document_file(uuid,text)', 'EXECUTE')
       or has_function_privilege('anon',
        'public.miloom_delete_document_with_file(uuid,text)', 'EXECUTE') then
        raise exception 'Document file removal is anonymously executable';
    end if;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000002', true);
    begin
        update public.company_documents set url = null
         where id = '60000000-0000-0000-0000-000000000001';
        raise exception 'Editor directly cleared owner file';
    exception when insufficient_privilege then null;
    end;
    begin
        delete from public.company_documents
         where id = '60000000-0000-0000-0000-000000000001';
        raise exception 'Editor directly deleted linked document';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_clear_document_file(
            '60000000-0000-0000-0000-000000000001', 'stale'
        );
        raise exception 'Stale file clear was accepted';
    exception when insufficient_privilege then null;
    end;
    if public.miloom_clear_document_file(
        '60000000-0000-0000-0000-000000000001', v_shared
    ) ->> 'status' <> 'cleared' then
        raise exception 'Scoped Editor could not clear file';
    end if;
    if (select url from public.company_documents
         where id = '60000000-0000-0000-0000-000000000001') is not null
       or not exists (select 1 from public.miloom_document_file_cleanup
           where path = v_shared) then
        raise exception 'Clearing did not detach and queue the exact file';
    end if;
    begin
        perform public.miloom_clear_document_file(
            '60000000-0000-0000-0000-000000000001', v_shared
        );
        raise exception 'Cleared file was replayed';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000001', true);
    update public.company_documents set url = 'file:///owner/legacy.pdf'
     where id = '60000000-0000-0000-0000-000000000001';
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000002', true);
    if public.miloom_clear_document_file(
        '60000000-0000-0000-0000-000000000001', 'file:///owner/legacy.pdf'
    ) ->> 'status' <> 'cleared' then
        raise exception 'Scoped Editor could not detach a legacy local reference';
    end if;
    insert into public.resource_access_blocks (
        owner_user_id, blocked_email, blocked_user_id
    ) values (
        '00000000-0000-0000-0000-000000000001',
        'blocked-editor@example.test',
        '00000000-0000-0000-0000-000000000002'
    );
    begin
        perform public.miloom_delete_document_with_file(
            '60000000-0000-0000-0000-000000000001', null
        );
        raise exception 'Blocked Editor deleted shared document';
    exception when insufficient_privilege then null;
    end;
    delete from public.resource_access_blocks
     where owner_user_id = '00000000-0000-0000-0000-000000000001'
       and blocked_user_id = '00000000-0000-0000-0000-000000000002';
    if public.miloom_delete_document_with_file(
        '60000000-0000-0000-0000-000000000002', v_sibling
    ) ->> 'status' <> 'deleted' then
        raise exception 'Scoped Editor could not delete linked document';
    end if;
    if exists (select 1 from public.company_documents
        where id = '60000000-0000-0000-0000-000000000002')
       or not exists (select 1 from public.miloom_document_file_cleanup
           where path = v_sibling) then
        raise exception 'Deleting did not queue the exact file';
    end if;
    begin
        perform public.miloom_delete_document_with_file(
            '60000000-0000-0000-0000-000000000003',
            '00000000-0000-0000-0000-000000000001/private.pdf'
        );
        raise exception 'Editor deleted owner-private document';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000003', true);
    begin
        perform public.miloom_delete_document_with_file(
            '60000000-0000-0000-0000-000000000001', null
        );
        raise exception 'Viewer deleted shared document';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000001', true);
    if public.miloom_delete_document_with_file(
        '60000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001/private.pdf'
    ) ->> 'status' <> 'deleted' then
        raise exception 'Owner lost private document deletion';
    end if;
end;
$$;
