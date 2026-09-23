-- Keep deleted/replaced document files retryable without deleting Storage
-- metadata directly (which would leave the underlying object bytes behind).
begin;

create table if not exists public.miloom_document_file_cleanup (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null,
    path text not null unique,
    created_at timestamptz not null default now()
);
alter table public.miloom_document_file_cleanup enable row level security;
revoke all on public.miloom_document_file_cleanup from public, anon, authenticated;
grant select, delete on public.miloom_document_file_cleanup to service_role;

create or replace function public.miloom_queue_detached_document_file()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_path text := old.url;
begin
    if tg_op = 'UPDATE' and old.url is not distinct from new.url then
        return new;
    end if;
    if v_path ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$'
       and split_part(v_path, '/', 1)::uuid = old.user_id
       and exists (
           select 1 from storage.objects o
            where o.bucket_id = 'CompanyDocuments' and o.name = v_path
              and coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1)) = old.user_id::text
       ) and not exists (
           select 1 from public.company_documents d where d.url = v_path
       ) then
        insert into public.miloom_document_file_cleanup (owner_user_id, path)
        values (old.user_id, v_path) on conflict (path) do nothing;
    end if;
    if tg_op = 'DELETE' then return old; end if;
    return new;
end;
$$;
drop trigger if exists miloom_queue_detached_document_file on public.company_documents;
create trigger miloom_queue_detached_document_file
after update of url or delete on public.company_documents
for each row execute function public.miloom_queue_detached_document_file();
revoke all on function public.miloom_queue_detached_document_file()
    from public, anon, authenticated;

-- A queued path cannot be attached to another document while a worker could
-- be deleting it. The Storage owner check from migration 022 still applies.
create or replace function public.miloom_reject_queued_document_file()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if tg_op = 'INSERT' or old.url is distinct from new.url then
        if new.url is not null and exists (
            select 1 from public.miloom_document_file_cleanup q where q.path = new.url
        ) then
            raise exception using errcode = '42501', message = 'DOCUMENT_FILE_PENDING_DELETION';
        end if;
    end if;
    return new;
end;
$$;
drop trigger if exists miloom_reject_queued_document_file on public.company_documents;
create trigger miloom_reject_queued_document_file
before insert or update of url on public.company_documents
for each row execute function public.miloom_reject_queued_document_file();
revoke all on function public.miloom_reject_queued_document_file()
    from public, anon, authenticated;

create or replace function public.miloom_document_path_is_queued(p_path text)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select exists (select 1 from public.miloom_document_file_cleanup q where q.path = p_path);
$$;
revoke all on function public.miloom_document_path_is_queued(text)
    from public, anon;
grant execute on function public.miloom_document_path_is_queued(text)
    to authenticated;

-- An owner must not overwrite/re-upload the same path while its old object is
-- queued for deletion. Restrictive policies also win over existing broad ones.
drop policy if exists miloom_document_cleanup_no_reupload on storage.objects;
create policy miloom_document_cleanup_no_reupload
on storage.objects as restrictive for insert to authenticated
with check (
    bucket_id <> 'CompanyDocuments'
    or not public.miloom_document_path_is_queued(name)
);
drop policy if exists miloom_document_cleanup_no_overwrite on storage.objects;
create policy miloom_document_cleanup_no_overwrite
on storage.objects as restrictive for update to authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or not public.miloom_document_path_is_queued(name)
)
with check (
    bucket_id <> 'CompanyDocuments'
    or not public.miloom_document_path_is_queued(name)
);

create or replace function public.miloom_pending_document_file_cleanup(p_limit integer default 25)
returns table(id uuid, path text)
language sql security definer set search_path = ''
as $$
    select q.id, q.path from public.miloom_document_file_cleanup q
     where not exists (select 1 from public.company_documents d where d.url = q.path)
     order by q.created_at, q.id
     limit least(greatest(coalesce(p_limit, 25), 1), 100);
$$;
revoke all on function public.miloom_pending_document_file_cleanup(integer)
    from public, anon, authenticated;
grant execute on function public.miloom_pending_document_file_cleanup(integer)
    to service_role;

commit;
