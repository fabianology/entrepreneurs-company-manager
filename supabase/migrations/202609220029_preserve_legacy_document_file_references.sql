-- A legacy document may store an absolute Storage URL instead of the relative
-- object key. Treat either spelling as a live reference before queueing or
-- processing cleanup. A false positive only retains bytes; a false negative
-- could delete a file still displayed by the app.
begin;

create or replace function public.miloom_document_storage_path(p_url text)
returns text
language sql immutable set search_path = ''
as $$
    select case
        when u.url is null then null
        when u.url like '%/CompanyDocuments/%' then
            split_part(
                split_part(split_part(u.url, '/CompanyDocuments/', 2), '?', 1),
                '#', 1
            )
        else u.url
    end
    from (select replace(replace(p_url, '%2F', '/'), '%2f', '/') as url) u;
$$;
revoke all on function public.miloom_document_storage_path(text)
    from public, anon, authenticated;
create index if not exists miloom_company_document_storage_path_idx
    on public.company_documents (public.miloom_document_storage_path(url))
    where url is not null;

create or replace function public.miloom_reject_queued_document_file()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if tg_op = 'INSERT' or old.url is distinct from new.url then
        if new.url is not null and exists (
            select 1 from public.miloom_document_file_cleanup q
             where q.path = public.miloom_document_storage_path(new.url)
        ) then
            raise exception using errcode = '42501', message = 'DOCUMENT_FILE_PENDING_DELETION';
        end if;
    end if;
    return new;
end;
$$;
revoke all on function public.miloom_reject_queued_document_file()
    from public, anon, authenticated;

create or replace function public.miloom_pending_document_file_cleanup(p_limit integer default 25)
returns table(id uuid, path text)
language sql security definer set search_path = ''
as $$
    select q.id, q.path from public.miloom_document_file_cleanup q
     where not exists (
         select 1 from public.company_documents d
          where public.miloom_document_storage_path(d.url) = q.path
     )
     order by q.created_at, q.id
     limit least(greatest(coalesce(p_limit, 25), 1), 100);
$$;
revoke all on function public.miloom_pending_document_file_cleanup(integer)
    from public, anon, authenticated;
grant execute on function public.miloom_pending_document_file_cleanup(integer)
    to service_role;

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
           and o.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.][a-z0-9]{1,12}$'
           and coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1))
               = split_part(o.name, '/', 1)
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
