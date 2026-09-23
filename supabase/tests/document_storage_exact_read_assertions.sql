-- Run after document_storage_exact_read_fixture.sql and migration 022.
do $$
begin
    if has_function_privilege('anon',
        'public.miloom_can_read_document_storage_object(text,text)', 'EXECUTE')
       or not has_function_privilege('authenticated',
        'public.miloom_can_read_document_storage_object(text,text)', 'EXECUTE') then
        raise exception 'Storage helper has wrong app grants';
    end if;
    begin
        insert into public.company_documents (id, user_id, company_id, name, url)
        values ('60000000-0000-0000-0000-000000000004',
            '00000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001', 'Hijack',
            '00000000-0000-0000-0000-000000000002/other.pdf');
        raise exception 'Another owner file was attached to a document';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000003', true);
    begin
        update public.company_documents set url = null
         where id = '60000000-0000-0000-0000-000000000001';
        raise exception 'Viewer detached owner file';
    exception when insufficient_privilege then null;
    end;
    begin
        delete from public.company_documents
         where id = '60000000-0000-0000-0000-000000000001';
        raise exception 'Viewer deleted owner file link';
    exception when insufficient_privilege then null;
    end;
end;
$$;

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000003', false);
set role authenticated;
do $$
begin
    if (select count(*) from storage.objects
         where bucket_id = 'CompanyDocuments') <> 1
       or not exists (select 1 from storage.objects
           where name = '00000000-0000-0000-0000-000000000001/shared.pdf')
       or (select count(*) from storage.objects
           where bucket_id = 'Avatars') <> 1 then
        raise exception 'Exact Viewer share or unrelated bucket boundary failed';
    end if;
end;
$$;
reset role;

insert into public.resource_shares (resource_id, resource_type, user_id, role)
values ('10000000-0000-0000-0000-000000000001', 'company',
        '00000000-0000-0000-0000-000000000003', 'Viewer');
set role authenticated;
do $$
begin
    if (select count(*) from storage.objects
         where bucket_id = 'CompanyDocuments') <> 2 then
        raise exception 'Entity Viewer did not get exactly the nonprivate files';
    end if;
end;
$$;
reset role;

insert into public.resource_access_blocks (owner_user_id, blocked_email, blocked_user_id)
values ('00000000-0000-0000-0000-000000000001', 'viewer@example.com',
        '00000000-0000-0000-0000-000000000003');
set role authenticated;
do $$
begin
    if exists (select 1 from storage.objects
         where bucket_id = 'CompanyDocuments') then
        raise exception 'Blocked Viewer retained file reads';
    end if;
end;
$$;
reset role;

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000001', false);
set role authenticated;
do $$
begin
    if (select count(*) from storage.objects
         where bucket_id = 'CompanyDocuments') <> 3 then
        raise exception 'Owner lost access to own documents';
    end if;
end;
$$;
reset role;

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000002', false);
set role authenticated;
do $$
begin
    if (select count(*) from storage.objects
         where bucket_id = 'CompanyDocuments') <> 1
       or not exists (select 1 from storage.objects
           where name = '00000000-0000-0000-0000-000000000002/other.pdf') then
        raise exception 'Unrelated object owner boundary failed';
    end if;
end;
$$;
reset role;
