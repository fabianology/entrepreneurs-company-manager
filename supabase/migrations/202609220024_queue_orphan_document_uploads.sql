-- A cancelled/failed document edit may leave an app-generated Storage object
-- that was never linked to a row. Queue only that narrow filename shape after
-- a 24-hour grace period; the worker removes the bytes through Storage API.
begin;

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
           and o.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.][a-z0-9]{1,12}$'
           and coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1))
               = split_part(o.name, '/', 1)
           and o.created_at < now() - interval '24 hours'
           and not exists (
               select 1 from public.company_documents d where d.url = o.name
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
