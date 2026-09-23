-- Run after Storage fixture, 023, orphan fixture, 024 and 029.
begin;
select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000001', true);

insert into public.company_documents (id, user_id, company_id, name, url)
values (
    '60000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Legacy full URL',
    'https://legacy.example.test/storage/v1/object/public/CompanyDocuments/00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000001.pdf?download=1'
);
update public.company_documents
   set url = 'https://legacy.example.test/storage/v1/object/sign/CompanyDocuments/00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000003.pdf?token=old'
 where id = '60000000-0000-0000-0000-000000000006';

do $$
declare
    v_path text := '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000001.pdf';
    v_switched_path text := '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000003.pdf';
begin
    if not exists (select 1 from public.miloom_document_file_cleanup
        where path = v_switched_path)
       or exists (select 1 from public.miloom_pending_document_file_cleanup(25)
        where path = v_switched_path) then
        raise exception 'Replacing a relative link with a full URL offered its live file for deletion';
    end if;
    if public.miloom_queue_orphan_document_uploads() <> 0 then
        raise exception 'Orphan scan queued an object with a live full-URL reference';
    end if;
    insert into public.miloom_document_file_cleanup(owner_user_id, path)
    values ('00000000-0000-0000-0000-000000000001', v_path);
    if exists (select 1 from public.miloom_pending_document_file_cleanup(25)
        where path = v_path) then
        raise exception 'Worker was offered a live full-URL object';
    end if;
    if public.miloom_document_storage_path(
        'https://legacy.example.test/CompanyDocuments/' || v_path || '#preview'
    ) <> v_path then
        raise exception 'Legacy fragment was not normalized';
    end if;
    if public.miloom_document_storage_path(
        'https://legacy.example.test/CompanyDocuments/'
        || replace(v_path, '/', '%2F') || '?token=old'
    ) <> v_path then
        raise exception 'Legacy encoded path was not normalized';
    end if;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000001', true);
    delete from public.company_documents
     where id = '60000000-0000-0000-0000-000000000007';
    if not exists (select 1 from public.miloom_pending_document_file_cleanup(25)
        where path = v_path) then
        raise exception 'Detached full-URL object stayed blocked from cleanup';
    end if;
    begin
        insert into public.company_documents (id, user_id, company_id, name, url)
        values (
            '60000000-0000-0000-0000-000000000008',
            '00000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001',
            'Reattach full URL',
            'https://legacy.example.test/storage/v1/object/public/CompanyDocuments/' || v_path
        );
        raise exception 'Queued object was reattached through a full URL';
    exception when insufficient_privilege then null;
    end;
end;
$$;
rollback;
