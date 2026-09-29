-- Run after 202609290003 in the disposable Storage fixture. No synthetic
-- permissive policy is installed: this catches a missing owner write grant.
begin;
grant select, insert, update, delete on storage.objects to authenticated;
grant usage on schema storage, auth to anon;
grant select, insert, update, delete on storage.objects to anon;

do $$
begin
    if (select count(*) from pg_policies
        where schemaname = 'storage' and tablename = 'objects'
          and policyname in ('miloom_document_owner_insert',
                             'miloom_document_owner_update',
                             'miloom_document_owner_delete')
          and permissive = 'PERMISSIVE') <> 3 then
        raise exception 'Missing narrow permissive owner Storage write policies';
    end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',
    'abcdef12-0000-0000-0000-000000000001', true);

insert into storage.objects(bucket_id, name, owner_id) values
    ('CompanyDocuments',
     'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg',
     'abcdef12-0000-0000-0000-000000000001');
insert into storage.objects(bucket_id, name, owner_id) values
    ('CompanyDocuments',
     'abcdef12-0000-0000-0000-000000000001/expense-90000000-0000-0000-0000-000000000011.pdf',
     'abcdef12-0000-0000-0000-000000000001');

do $$
declare
    v_affected integer;
begin
    if not row_security_active('storage.objects'::regclass) then
        raise exception 'Owner write test did not run under RLS';
    end if;
    begin
        insert into storage.objects(bucket_id, name, owner_id) values
            ('CompanyDocuments',
             'ABCDEF12-0000-0000-0000-000000000002/90000000-0000-0000-0000-000000000012.jpg',
             'abcdef12-0000-0000-0000-000000000001');
        raise exception 'Cross-owner folder insert succeeded';
    exception when insufficient_privilege then null;
    end;
    begin
        insert into storage.objects(bucket_id, name, owner_id) values
            ('CompanyDocuments',
             'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000013.jpg',
             'abcdef12-0000-0000-0000-000000000002');
        raise exception 'Spoofed owner_id insert succeeded';
    exception when insufficient_privilege then null;
    end;
    begin
        insert into storage.objects(bucket_id, name, owner_id) values
            ('CompanyDocuments',
             'ABCDEF12-0000-0000-0000-000000000001/nested/file.jpg',
             'abcdef12-0000-0000-0000-000000000001');
        raise exception 'Nested path insert succeeded';
    exception when insufficient_privilege then null;
    end;
    update storage.objects set owner_id = 'abcdef12-0000-0000-0000-000000000001'
     where bucket_id = 'CompanyDocuments'
       and name = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg';
    get diagnostics v_affected = row_count;
    if v_affected <> 1 then raise exception 'Owner update did not pass'; end if;
    update storage.objects set owner_id = 'abcdef12-0000-0000-0000-000000000001'
     where bucket_id = 'CompanyDocuments'
       and name = '00000000-0000-0000-0000-000000000002/other.pdf';
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then raise exception 'Cross-owner update passed'; end if;
    delete from storage.objects
     where bucket_id = 'CompanyDocuments'
       and name = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg';
    get diagnostics v_affected = row_count;
    if v_affected <> 1 then raise exception 'Owner delete did not pass'; end if;
    delete from storage.objects
     where bucket_id = 'CompanyDocuments'
       and name = '00000000-0000-0000-0000-000000000002/other.pdf';
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then raise exception 'Cross-owner delete passed'; end if;
end $$;
reset role;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
    begin
        insert into storage.objects(bucket_id, name) values
            ('CompanyDocuments',
             'abcdef12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000014.jpg');
        raise exception 'Anonymous direct upload passed';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;
rollback;
