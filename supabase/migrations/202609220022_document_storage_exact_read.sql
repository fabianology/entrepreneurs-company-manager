-- Private CompanyDocuments downloads and signed-URL creation follow the exact
-- document share, not mere knowledge of an object path. File mutation remains
-- owner-only until a separate server-mediated collaborator upload flow exists.
begin;

do $$
begin
    if exists (select 1 from storage.buckets b
        where b.id = 'CompanyDocuments' and b.public) then
        raise exception using errcode = '42501',
            message = 'COMPANY_DOCUMENTS_BUCKET_MUST_BE_PRIVATE';
    end if;
end;
$$;

create or replace function public.miloom_can_read_document_storage_object(
    p_path text, p_object_owner_id text
)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_object_owner uuid;
    v_owner_text text := coalesce(
        nullif(p_object_owner_id, ''), split_part(p_path, '/', 1)
    );
begin
    if v_actor is null or p_path is null or p_path = ''
       or v_owner_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        return false;
    end if;
    v_object_owner := v_owner_text::uuid;
    if v_actor = v_object_owner then return true; end if;

    return exists (
        select 1 from public.company_documents d
         where d.url = p_path and d.user_id = v_object_owner
           and coalesce(to_jsonb(d) ->> 'visibility', 'entity') <> 'owner_private'
           and not exists (
               select 1 from public.resource_access_blocks b
               join auth.users au on au.id = v_actor
                where b.owner_user_id = d.user_id
                  and (b.blocked_user_id = v_actor
                       or lower(b.blocked_email) = lower(au.email))
           )
           and public.miloom_can_read_resource(
               'document', d.id, d.company_id, d.user_id
           )
    );
end;
$$;
revoke all on function public.miloom_can_read_document_storage_object(text, text)
    from public, anon;
grant execute on function public.miloom_can_read_document_storage_object(text, text)
    to authenticated;

-- A permissive path is needed because old policies allow only the uploader.
-- The restrictive boundary also wins over any other broad SELECT policy.
drop policy if exists miloom_document_object_exact_read on storage.objects;
create policy miloom_document_object_exact_read
on storage.objects as permissive for select to authenticated
using (
    bucket_id = 'CompanyDocuments'
    and public.miloom_can_read_document_storage_object(name, owner_id)
);

drop policy if exists miloom_document_object_boundary on storage.objects;
create policy miloom_document_object_boundary
on storage.objects as restrictive for select to authenticated
using (
    bucket_id <> 'CompanyDocuments'
    or public.miloom_can_read_document_storage_object(name, owner_id)
);

-- A linked file can be shared only when the document owner also owns the
-- object. This prevents a document row from laundering somebody else's path.
-- Existing mismatches remain unreadable to collaborators for manual repair.
create or replace function public.miloom_document_url_is_storage(p_url text)
returns boolean
language sql immutable set search_path = ''
as $$
    select coalesce(
        p_url ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
        or p_url like '%/CompanyDocuments/%', false
    );
$$;
revoke all on function public.miloom_document_url_is_storage(text)
    from public, anon, authenticated;

create or replace function public.miloom_validate_document_storage_link()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_storage_owner text;
begin
    if tg_op = 'UPDATE' then
        if old.url is distinct from new.url
           and public.miloom_document_url_is_storage(old.url)
           and auth.uid() is distinct from old.user_id then
            raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
        end if;
    end if;
    if new.url is null or new.url = '' or new.url ~* '^(https?://|file://|/)' then
        return new;
    end if;
    select coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1))
      into v_storage_owner
      from storage.objects o
     where o.bucket_id = 'CompanyDocuments' and o.name = new.url;
    if v_storage_owner is null or v_storage_owner !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or v_storage_owner::uuid is distinct from new.user_id then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_MISMATCH';
    end if;
    return new;
end;
$$;
drop trigger if exists miloom_validate_document_storage_link on public.company_documents;
create trigger miloom_validate_document_storage_link
before insert or update of url, user_id on public.company_documents
for each row execute function public.miloom_validate_document_storage_link();
revoke all on function public.miloom_validate_document_storage_link()
    from public, anon, authenticated;

create or replace function public.miloom_protect_document_file_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if public.miloom_document_url_is_storage(old.url)
       and auth.uid() is distinct from old.user_id then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
    end if;
    return old;
end;
$$;
drop trigger if exists miloom_protect_document_file_delete on public.company_documents;
create trigger miloom_protect_document_file_delete
before delete on public.company_documents
for each row execute function public.miloom_protect_document_file_delete();
revoke all on function public.miloom_protect_document_file_delete()
    from public, anon, authenticated;

commit;
