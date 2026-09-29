-- Run after 202609290002 against the disposable Storage fixture.
begin;
grant select, insert, update, delete on storage.objects to authenticated;
create policy uppercase_path_test_insert on storage.objects
    for insert to authenticated with check (true);
create policy uppercase_path_test_update on storage.objects
    for update to authenticated using (true) with check (true);
create policy uppercase_path_test_delete on storage.objects
    for delete to authenticated using (true);

set local role authenticated;
select set_config('request.jwt.claim.sub',
    'abcdef12-0000-0000-0000-000000000001', true);

insert into storage.objects(bucket_id, name, owner_id)
values ('CompanyDocuments',
    'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg',
    'abcdef12-0000-0000-0000-000000000001');
do $$
begin
    update storage.objects set owner_id = 'abcdef12-0000-0000-0000-000000000001'
     where bucket_id = 'CompanyDocuments'
       and name = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg';
    if not found then raise exception 'Owner cannot update uppercase-path object'; end if;
    begin
        insert into storage.objects(bucket_id, name, owner_id)
        values ('CompanyDocuments',
            'ABCDEF12-0000-0000-0000-000000000002/90000000-0000-0000-0000-000000000011.jpg',
            'abcdef12-0000-0000-0000-000000000001');
        raise exception 'Cross-owner uppercase-path upload was accepted';
    exception when insufficient_privilege then null;
    end;
    begin
        update storage.objects
           set name = 'ABCDEF12-0000-0000-0000-000000000002/90000000-0000-0000-0000-000000000012.jpg'
         where bucket_id = 'CompanyDocuments'
           and name = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg';
        raise exception 'Owner moved an object into another account folder';
    exception when insufficient_privilege then null;
    end;
end $$;
insert into storage.objects(bucket_id, name, owner_id)
values ('CompanyDocuments',
    'ABCDEF12-0000-0000-0000-000000000001/expense-case-test.jpg',
    'abcdef12-0000-0000-0000-000000000001');
delete from storage.objects
 where bucket_id = 'CompanyDocuments'
   and name = 'ABCDEF12-0000-0000-0000-000000000001/expense-case-test.jpg';
reset role;

-- Simulate an abandoned uploaded object old enough for the cleanup grace.
update storage.objects set created_at = now() - interval '25 hours'
 where bucket_id = 'CompanyDocuments'
   and name = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg';
do $$
begin
    perform public.miloom_queue_orphan_document_uploads();
    if not exists (
        select 1 from public.miloom_document_file_cleanup
         where path = 'ABCDEF12-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000010.jpg'
           and owner_user_id = 'abcdef12-0000-0000-0000-000000000001'::uuid
    ) then
        raise exception 'Uppercase-path orphan was not safely queued';
    end if;
end $$;
rollback;
