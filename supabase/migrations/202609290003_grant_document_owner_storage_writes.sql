-- Restrictive owner boundaries do not grant access by themselves. Restore the
-- narrow permissive policy needed for an authenticated owner to upload and
-- manage files in their own CompanyDocuments folder. Signed collaborator
-- uploads continue through the reservation/finalization flow.
begin;

drop policy if exists miloom_document_owner_insert on storage.objects;
create policy miloom_document_owner_insert
on storage.objects as permissive for insert to authenticated
with check (
    bucket_id = 'CompanyDocuments'
    and name ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[^/]+$'
    and lower(split_part(name, '/', 1)) = auth.uid()::text
    and lower(coalesce(nullif(owner_id, ''), split_part(name, '/', 1))) = auth.uid()::text
);

drop policy if exists miloom_document_owner_update on storage.objects;
create policy miloom_document_owner_update
on storage.objects as permissive for update to authenticated
using (
    bucket_id = 'CompanyDocuments'
    and lower(split_part(name, '/', 1)) = auth.uid()::text
    and lower(coalesce(nullif(owner_id, ''), split_part(name, '/', 1))) = auth.uid()::text
)
with check (
    bucket_id = 'CompanyDocuments'
    and lower(split_part(name, '/', 1)) = auth.uid()::text
    and lower(coalesce(nullif(owner_id, ''), split_part(name, '/', 1))) = auth.uid()::text
);

drop policy if exists miloom_document_owner_delete on storage.objects;
create policy miloom_document_owner_delete
on storage.objects as permissive for delete to authenticated
using (
    bucket_id = 'CompanyDocuments'
    and lower(split_part(name, '/', 1)) = auth.uid()::text
    and lower(coalesce(nullif(owner_id, ''), split_part(name, '/', 1))) = auth.uid()::text
);

commit;
