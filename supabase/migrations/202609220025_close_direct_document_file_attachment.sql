-- Close the empty-document attach gap before adding a server-mediated
-- collaborator file flow. Metadata/link edits remain available in scope.
begin;

create or replace function public.miloom_validate_document_storage_link()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_storage_owner text;
begin
    if tg_op = 'INSERT' then
        if public.miloom_document_url_is_storage(new.url)
           and auth.uid() is distinct from new.user_id then
            raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
        end if;
    elsif old.url is distinct from new.url
       and auth.uid() is distinct from old.user_id
       and (public.miloom_document_url_is_storage(old.url)
            or public.miloom_document_url_is_storage(new.url)) then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
    end if;
    if new.url is null or new.url = '' or new.url ~* '^(https?://|file://|/)' then
        return new;
    end if;
    select coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1))
      into v_storage_owner
      from storage.objects o
     where o.bucket_id = 'CompanyDocuments' and o.name = new.url;
    if v_storage_owner is null
       or v_storage_owner !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or v_storage_owner::uuid is distinct from new.user_id then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_MISMATCH';
    end if;
    return new;
end;
$$;
revoke all on function public.miloom_validate_document_storage_link()
    from public, anon, authenticated;

commit;
