-- Restrictive path ownership for direct authenticated Storage writes. A
-- scoped collaborator upload uses the service-issued signed token, then the
-- exact-document finalization from 026; collaborators never need direct
-- INSERT/UPDATE/DELETE rights to the owner's folder.
begin;

drop policy if exists miloom_document_object_anon_read_boundary on storage.objects;
create policy miloom_document_object_anon_read_boundary
on storage.objects as restrictive for select to anon
using (bucket_id <> 'CompanyDocuments');

drop policy if exists miloom_document_object_insert_boundary on storage.objects;
create policy miloom_document_object_insert_boundary
on storage.objects as restrictive for insert to anon, authenticated
with check (
    bucket_id <> 'CompanyDocuments'
    or split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists miloom_document_object_update_boundary on storage.objects;
create policy miloom_document_object_update_boundary
on storage.objects as restrictive for update to anon, authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or split_part(name, '/', 1) = auth.uid()::text
)
with check (
    bucket_id <> 'CompanyDocuments'
    or split_part(name, '/', 1) = auth.uid()::text
);

drop policy if exists miloom_document_object_delete_boundary on storage.objects;
create policy miloom_document_object_delete_boundary
on storage.objects as restrictive for delete to anon, authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or split_part(name, '/', 1) = auth.uid()::text
);

commit;
