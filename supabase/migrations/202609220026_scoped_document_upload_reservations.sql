-- Server-authorized, exact-document upload reservations. No collaborator gets
-- direct permission to set a document Storage URL or the owner's bucket key.
-- The signed-upload issuer and client are separate rollout steps.
begin;

create table public.miloom_document_upload_reservations (
    id uuid primary key default gen_random_uuid(),
    document_id uuid not null references public.company_documents(id) on delete cascade,
    actor_user_id uuid not null,
    owner_user_id uuid not null,
    expected_url text,
    path text not null unique,
    byte_count integer not null check (byte_count between 1 and 26214400),
    created_at timestamptz not null default now(),
    expires_at timestamptz not null default (now() + interval '10 minutes'),
    finalized_at timestamptz
);
create index miloom_document_upload_actor_created_idx
    on public.miloom_document_upload_reservations(actor_user_id, created_at desc);
alter table public.miloom_document_upload_reservations enable row level security;
revoke all on public.miloom_document_upload_reservations from public, anon, authenticated;

create or replace function public.miloom_document_file_editor_allowed(
    p_actor uuid, p_owner uuid, p_document_id uuid, p_company_id uuid, p_visibility text
)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
begin
    if p_actor is null or p_owner is null or p_document_id is null then return false; end if;
    if p_actor = p_owner then return true; end if;
    if p_visibility = 'owner_private' then return false; end if;
    if exists (
        select 1 from public.resource_access_blocks b
        left join auth.users u on u.id = p_actor
         where b.owner_user_id = p_owner
           and (b.blocked_user_id = p_actor
                or lower(b.blocked_email) = lower(u.email))
    ) then return false; end if;
    return public.miloom_can_edit_resource(
        'document', p_document_id, p_company_id, p_owner
    );
end;
$$;
revoke all on function public.miloom_document_file_editor_allowed(uuid,uuid,uuid,uuid,text)
    from public, anon, authenticated;

create or replace function public.miloom_prepare_document_upload(
    p_document_id uuid, p_expected_url text, p_extension text, p_byte_count integer
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_doc public.company_documents%rowtype;
    v_limit bigint;
    v_reservation public.miloom_document_upload_reservations%rowtype;
    v_extension text := lower(btrim(p_extension));
begin
    if v_actor is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if v_extension is null or v_extension !~ '^[a-z0-9]{1,12}$'
       or p_byte_count is null or p_byte_count < 1 or p_byte_count > 26214400 then
        raise exception using errcode = '22023', message = 'INVALID_DOCUMENT_UPLOAD';
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
    select nullif(to_jsonb(b) ->> 'file_size_limit', '')::bigint
      into v_limit from storage.buckets b where b.id = 'CompanyDocuments' and not b.public;
    if v_limit is null or v_limit > 26214400 or p_byte_count > v_limit then
        raise exception using errcode = '42501', message = 'DOCUMENT_BUCKET_LIMIT_REQUIRED';
    end if;
    if (select count(*) from public.miloom_document_upload_reservations r
         where r.actor_user_id = v_actor
           and r.created_at > now() - interval '1 hour') >= 10 then
        raise exception using errcode = '42501', message = 'DOCUMENT_UPLOAD_RATE_LIMIT';
    end if;
    insert into public.miloom_document_upload_reservations (
        document_id, actor_user_id, owner_user_id, expected_url, path, byte_count
    ) values (
        v_doc.id, v_actor, v_doc.user_id, v_doc.url,
        v_doc.user_id::text || '/' || gen_random_uuid()::text || '.' || v_extension,
        p_byte_count
    ) returning * into v_reservation;
    return jsonb_build_object(
        'reservation_id', v_reservation.id,
        'path', v_reservation.path,
        'expires_at', v_reservation.expires_at
    );
end;
$$;
revoke all on function public.miloom_prepare_document_upload(uuid,text,text,integer)
    from public, anon;
grant execute on function public.miloom_prepare_document_upload(uuid,text,text,integer)
    to authenticated;

-- The trigger checks this transaction-local reservation marker as well as
-- actor, document, old URL and new path. A direct table UPDATE has no marker.
create or replace function public.miloom_validate_document_storage_link()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_storage_owner text;
    v_marker text := current_setting('miloom.document_upload_reservation', true);
    v_authorized boolean := false;
begin
    if tg_op = 'UPDATE' and old.url is distinct from new.url
       and auth.uid() is distinct from old.user_id
       and v_marker ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select exists (
            select 1 from public.miloom_document_upload_reservations r
             where r.id = v_marker::uuid and r.actor_user_id = auth.uid()
               and r.document_id = old.id and r.owner_user_id = old.user_id
               and r.expected_url is not distinct from old.url
               and r.path = new.url and r.finalized_at is null
               and r.expires_at > now()
        ) into v_authorized;
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

create or replace function public.miloom_finalize_document_upload(p_reservation_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_reservation public.miloom_document_upload_reservations%rowtype;
    v_doc public.company_documents%rowtype;
    v_object_owner text;
    v_size text;
begin
    if v_actor is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    select * into v_reservation from public.miloom_document_upload_reservations r
     where r.id = p_reservation_id and r.actor_user_id = v_actor for update;
    if v_reservation.id is null or v_reservation.finalized_at is not null
       or v_reservation.expires_at <= now() then
        raise exception using errcode = '42501', message = 'DOCUMENT_UPLOAD_EXPIRED';
    end if;
    select * into v_doc from public.company_documents d
     where d.id = v_reservation.document_id for update;
    if v_doc.id is null or v_doc.user_id <> v_reservation.owner_user_id
       or v_doc.url is distinct from v_reservation.expected_url
       or not public.miloom_document_file_editor_allowed(
           v_actor, v_doc.user_id, v_doc.id, v_doc.company_id,
           to_jsonb(v_doc) ->> 'visibility'
       ) then
        raise exception using errcode = '42501', message = 'DOCUMENT_FILE_ACCESS_DENIED';
    end if;
    select coalesce(nullif(o.owner_id, ''), split_part(o.name, '/', 1)),
           to_jsonb(o) -> 'metadata' ->> 'size'
      into v_object_owner, v_size
      from storage.objects o
     where o.bucket_id = 'CompanyDocuments' and o.name = v_reservation.path;
    if v_object_owner is distinct from v_doc.user_id::text
       or v_size is null or v_size !~ '^[0-9]+$'
       or v_size::bigint <> v_reservation.byte_count then
        raise exception using errcode = '42501', message = 'DOCUMENT_UPLOAD_NOT_VERIFIED';
    end if;
    perform set_config('miloom.document_upload_reservation', v_reservation.id::text, true);
    update public.company_documents set url = v_reservation.path
     where id = v_doc.id;
    update public.miloom_document_upload_reservations
       set finalized_at = now() where id = v_reservation.id;
    return jsonb_build_object('status', 'attached', 'path', v_reservation.path);
end;
$$;
revoke all on function public.miloom_finalize_document_upload(uuid)
    from public, anon;
grant execute on function public.miloom_finalize_document_upload(uuid)
    to authenticated;

create or replace function public.miloom_document_upload_status(p_document_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_doc public.company_documents%rowtype;
begin
    if v_actor is null then return jsonb_build_object('can_upload', false); end if;
    select * into v_doc from public.company_documents d where d.id = p_document_id;
    if v_doc.id is null then return jsonb_build_object('can_upload', false); end if;
    return jsonb_build_object('can_upload',
        public.miloom_document_file_editor_allowed(
            v_actor, v_doc.user_id, v_doc.id, v_doc.company_id,
            to_jsonb(v_doc) ->> 'visibility'
        )
    );
end;
$$;
revoke all on function public.miloom_document_upload_status(uuid)
    from public, anon;
grant execute on function public.miloom_document_upload_status(uuid)
    to authenticated;

notify pgrst, 'reload schema';
commit;
