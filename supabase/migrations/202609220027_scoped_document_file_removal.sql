-- A scoped Editor/Admin may detach or delete only an eligible document through
-- a server-checked, exact-old-URL operation. Storage bytes are queued by 023.
begin;

create or replace function public.miloom_validate_document_storage_link()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_storage_owner text;
    v_marker text := current_setting('miloom.document_upload_reservation', true);
    v_clear_marker text := current_setting('miloom.document_file_clear', true);
    v_authorized boolean := false;
begin
    if tg_op = 'UPDATE' and old.url is distinct from new.url
       and auth.uid() is distinct from old.user_id then
        if v_marker ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
            select exists (
                select 1 from public.miloom_document_upload_reservations r
                 where r.id = v_marker::uuid and r.actor_user_id = auth.uid()
                   and r.document_id = old.id and r.owner_user_id = old.user_id
                   and r.expected_url is not distinct from old.url
                   and r.path = new.url and r.finalized_at is null
                   and r.expires_at > now()
            ) into v_authorized;
        end if;
        if new.url is null and v_clear_marker = old.id::text
           and public.miloom_document_file_editor_allowed(
               auth.uid(), old.user_id, old.id, old.company_id,
               to_jsonb(old) ->> 'visibility'
           ) then
            v_authorized := true;
        end if;
    end if;
    if tg_op = 'INSERT' then
        if public.miloom_document_url_is_storage(new.url)
           and auth.uid() is distinct from new.user_id then
            raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
        end if;
    elsif old.url is distinct from new.url
       and auth.uid() is distinct from old.user_id
       and (public.miloom_document_url_is_storage(old.url)
            or public.miloom_document_url_is_storage(new.url))
       and not v_authorized then
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

create or replace function public.miloom_protect_document_file_delete()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if public.miloom_document_url_is_storage(old.url)
       and auth.uid() is distinct from old.user_id
       and not (
           coalesce(current_setting('miloom.document_delete_id', true) = old.id::text, false)
           and public.miloom_document_file_editor_allowed(
               auth.uid(), old.user_id, old.id, old.company_id,
               to_jsonb(old) ->> 'visibility'
           )
       ) then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_OWNER_REQUIRED';
    end if;
    return old;
end;
$$;
revoke all on function public.miloom_protect_document_file_delete()
    from public, anon, authenticated;

create or replace function public.miloom_clear_document_file(
    p_document_id uuid, p_expected_url text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_doc public.company_documents%rowtype;
begin
    if v_actor is null or nullif(p_expected_url, '') is null then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_ACCESS_DENIED';
    end if;
    select * into v_doc from public.company_documents d
     where d.id = p_document_id for update;
    if v_doc.id is null or v_doc.url is distinct from p_expected_url
       or not public.miloom_document_file_editor_allowed(
           v_actor, v_doc.user_id, v_doc.id, v_doc.company_id,
           to_jsonb(v_doc) ->> 'visibility'
       ) then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_ACCESS_DENIED';
    end if;
    perform set_config('miloom.document_file_clear', v_doc.id::text, true);
    update public.company_documents set url = null where id = v_doc.id;
    return jsonb_build_object('status', 'cleared', 'document_id', v_doc.id);
end;
$$;
revoke all on function public.miloom_clear_document_file(uuid,text)
    from public, anon;
grant execute on function public.miloom_clear_document_file(uuid,text)
    to authenticated;

create or replace function public.miloom_delete_document_with_file(
    p_document_id uuid, p_expected_url text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_doc public.company_documents%rowtype;
begin
    if v_actor is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    select * into v_doc from public.company_documents d
     where d.id = p_document_id for update;
    if v_doc.id is null or v_doc.url is distinct from p_expected_url
       or not public.miloom_document_file_editor_allowed(
           v_actor, v_doc.user_id, v_doc.id, v_doc.company_id,
           to_jsonb(v_doc) ->> 'visibility'
       ) then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_ACCESS_DENIED';
    end if;
    perform set_config('miloom.document_delete_id', v_doc.id::text, true);
    delete from public.company_documents where id = v_doc.id;
    return jsonb_build_object('status', 'deleted', 'document_id', v_doc.id);
end;
$$;
revoke all on function public.miloom_delete_document_with_file(uuid,text)
    from public, anon;
grant execute on function public.miloom_delete_document_with_file(uuid,text)
    to authenticated;

notify pgrst, 'reload schema';
commit;
