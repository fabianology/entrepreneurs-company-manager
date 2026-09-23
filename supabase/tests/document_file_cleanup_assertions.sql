-- Run after the delegated-scope fixture, Storage fixture, migrations 022–023.
do $$
begin
    if has_table_privilege('authenticated',
        'public.miloom_document_file_cleanup', 'SELECT')
       or has_function_privilege('authenticated',
        'public.miloom_pending_document_file_cleanup(integer)', 'EXECUTE') then
        raise exception 'A signed-in client can inspect the cleanup queue';
    end if;
end;
$$;

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000001', false);
delete from public.company_documents
 where id = '60000000-0000-0000-0000-000000000002';
do $$
begin
    if not exists (select 1 from public.miloom_document_file_cleanup
        where path = '00000000-0000-0000-0000-000000000001/sibling.pdf') then
        raise exception 'Deleting the document did not queue its file';
    end if;
    if (select count(*) from public.miloom_pending_document_file_cleanup(25)) <> 1 then
        raise exception 'Worker did not see exactly one detached file';
    end if;
    begin
        insert into public.company_documents (id, user_id, company_id, name, url)
        values ('60000000-0000-0000-0000-000000000005',
            '00000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001', 'Unsafe reuse',
            '00000000-0000-0000-0000-000000000001/sibling.pdf');
        raise exception 'A queued path was attached to a new document';
    exception when insufficient_privilege then null;
    end;
end;
$$;

-- Even if an unrelated Storage policy allows uploads, a queued path cannot
-- be reused while the cleanup worker might delete it.
delete from storage.objects where bucket_id = 'CompanyDocuments'
    and name = '00000000-0000-0000-0000-000000000001/sibling.pdf';
grant insert on storage.objects to authenticated;
create policy broad_insert_for_cleanup_test on storage.objects
    for insert to authenticated with check (true);
set role authenticated;
do $$
begin
    begin
        insert into storage.objects (bucket_id, name, owner_id)
        values ('CompanyDocuments',
            '00000000-0000-0000-0000-000000000001/sibling.pdf',
            '00000000-0000-0000-0000-000000000001');
        raise exception 'A queued file path was re-uploaded';
    exception when insufficient_privilege then null;
    end;
end;
$$;
reset role;

insert into storage.objects values (
    'CompanyDocuments', '00000000-0000-0000-0000-000000000001/replaced.pdf',
    '00000000-0000-0000-0000-000000000001');
update public.company_documents
   set url = '00000000-0000-0000-0000-000000000001/replaced.pdf'
 where id = '60000000-0000-0000-0000-000000000001';
do $$
begin
    if not exists (select 1 from public.miloom_document_file_cleanup
        where path = '00000000-0000-0000-0000-000000000001/shared.pdf') then
        raise exception 'Replacing the document did not queue the old file';
    end if;
end;
$$;
