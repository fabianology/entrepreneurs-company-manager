-- Swift's UUID.uuidString is uppercase, while auth.uid()::text and Storage's
-- owner_id use lowercase. Treat the UUID prefix case-insensitively without
-- relaxing the requirement that it identify the signed-in owner. Also keep
-- the orphan scanner able to clean up uppercase-path uploads after 24 hours.
begin;

drop policy if exists miloom_document_object_insert_boundary on storage.objects;
create policy miloom_document_object_insert_boundary
on storage.objects as restrictive for insert to anon, authenticated
with check (
    bucket_id <> 'CompanyDocuments'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists miloom_document_object_update_boundary on storage.objects;
create policy miloom_document_object_update_boundary
on storage.objects as restrictive for update to anon, authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
)
with check (
    bucket_id <> 'CompanyDocuments'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists miloom_document_object_delete_boundary on storage.objects;
create policy miloom_document_object_delete_boundary
on storage.objects as restrictive for delete to anon, authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
);

drop policy if exists business_receipt_object_privacy on storage.objects;
create policy business_receipt_object_privacy
on storage.objects as restrictive for all to authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or name not like '%/expense-%'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
)
with check (
    bucket_id <> 'CompanyDocuments'
    or name not like '%/expense-%'
    or lower(split_part(name, '/', 1)) = auth.uid()::text
);

create or replace function public.miloom_queue_orphan_document_uploads()
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
    v_count integer;
begin
    with candidates as (
        select o.name, split_part(o.name, '/', 1)::uuid owner_user_id
          from storage.objects o
         where o.bucket_id = 'CompanyDocuments'
           and o.name ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}[.][a-z0-9]{1,12}$'
           and lower(coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1)))
               = lower(split_part(o.name, '/', 1))
           and o.created_at < now() - interval '24 hours'
           and not exists (
               select 1 from public.company_documents d
                where public.miloom_document_storage_path(d.url) = o.name
           )
         order by o.created_at, o.name
         limit 100
    )
    insert into public.miloom_document_file_cleanup (owner_user_id, path)
    select owner_user_id, name from candidates
    on conflict (path) do nothing;
    get diagnostics v_count = row_count;
    return v_count;
end;
$$;
revoke all on function public.miloom_queue_orphan_document_uploads()
    from public, anon, authenticated;
grant execute on function public.miloom_queue_orphan_document_uploads()
    to service_role;

commit;
