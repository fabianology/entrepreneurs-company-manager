-- Run after migrations 022–023, 025–026 and reservation fixture.
do $$
declare
    v_prepared jsonb;
    v_path text;
    v_id uuid;
    v_next jsonb;
    v_next_path text;
    v_next_id uuid;
    v_old text := '00000000-0000-0000-0000-000000000001/shared.pdf';
begin
    if has_table_privilege('authenticated',
        'public.miloom_document_upload_reservations', 'SELECT')
       or has_function_privilege('anon',
           'public.miloom_prepare_document_upload(uuid,text,text,integer)', 'EXECUTE')
       or has_function_privilege('anon',
           'public.miloom_finalize_document_upload(uuid)', 'EXECUTE') then
        raise exception 'Upload reservation grants are too broad';
    end if;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000003', true);
    if (public.miloom_document_upload_status(
        '60000000-0000-0000-0000-000000000001'
    ) ->> 'can_upload')::boolean then
        raise exception 'Viewer sees document file upload capability';
    end if;
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000001', v_old, 'pdf', 4
        );
        raise exception 'Viewer prepared a document upload';
    exception when insufficient_privilege then null;
    end;
    perform set_config('request.jwt.claim.sub',
        '00000000-0000-0000-0000-000000000002', true);
    if not (public.miloom_document_upload_status(
        '60000000-0000-0000-0000-000000000001'
    ) ->> 'can_upload')::boolean then
        raise exception 'Exact Editor lost document file upload capability';
    end if;
    insert into public.company_documents (id, user_id, company_id, name, visibility)
    values ('60000000-0000-0000-0000-000000000009',
        '00000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001', 'Private draft', 'owner_private');
    insert into public.resource_shares(resource_id, resource_type, user_id, role)
    values ('60000000-0000-0000-0000-000000000009', 'document',
        '00000000-0000-0000-0000-000000000002', 'Editor');
    if (public.miloom_document_upload_status(
        '60000000-0000-0000-0000-000000000009'
    ) ->> 'can_upload')::boolean then
        raise exception 'Editor gained an owner-private file capability';
    end if;
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000009', null, 'pdf', 4
        );
        raise exception 'Editor prepared an owner-private upload';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000001', 'stale', 'pdf', 4
        );
        raise exception 'Stale document URL accepted';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000001', v_old, '../pdf', 4
        );
        raise exception 'Unsafe extension accepted';
    exception when invalid_parameter_value then null;
    end;
    update storage.buckets set file_size_limit = null where id = 'CompanyDocuments';
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000001', v_old, 'pdf', 4
        );
        raise exception 'Unbounded bucket issued a signed-upload reservation';
    exception when insufficient_privilege then null;
    end;
    update storage.buckets set file_size_limit = 26214400 where id = 'CompanyDocuments';
    v_prepared := public.miloom_prepare_document_upload(
        '60000000-0000-0000-0000-000000000001', v_old, 'PDF', 4
    );
    v_id := (v_prepared ->> 'reservation_id')::uuid;
    v_path := v_prepared ->> 'path';
    if v_path !~* '^00000000-0000-0000-0000-000000000001/[0-9a-f-]{36}[.]pdf$' then
        raise exception 'Reservation path is not owner-bound and normalized';
    end if;
    begin
        perform public.miloom_finalize_document_upload(v_id);
        raise exception 'Missing upload was finalized';
    exception when insufficient_privilege then null;
    end;
    insert into storage.objects(bucket_id, name, owner_id, metadata)
    values ('CompanyDocuments', v_path, null, '{"size":4}'::jsonb);
    begin
        update public.company_documents set url = v_path
         where id = '60000000-0000-0000-0000-000000000001';
        raise exception 'Direct collaborator URL write bypassed reservation';
    exception when insufficient_privilege then null;
    end;
    if public.miloom_finalize_document_upload(v_id) ->> 'path' <> v_path then
        raise exception 'Authorized document upload was not attached';
    end if;
    if (select url from public.company_documents
         where id = '60000000-0000-0000-0000-000000000001') <> v_path
       or not exists (select 1 from public.miloom_document_file_cleanup
           where path = v_old) then
        raise exception 'Replacement did not update the document and queue the old file';
    end if;
    begin
        perform public.miloom_finalize_document_upload(v_id);
        raise exception 'Reservation replay was accepted';
    exception when insufficient_privilege then null;
    end;
    v_next := public.miloom_prepare_document_upload(
        '60000000-0000-0000-0000-000000000001', v_path, 'pdf', 4
    );
    v_next_id := (v_next ->> 'reservation_id')::uuid;
    v_next_path := v_next ->> 'path';
    insert into storage.objects(bucket_id, name, owner_id, metadata)
    values ('CompanyDocuments', v_next_path, null, '{"size":5}'::jsonb);
    begin
        perform public.miloom_finalize_document_upload(v_next_id);
        raise exception 'An upload with the wrong byte count was attached';
    exception when insufficient_privilege then null;
    end;
    if (select url from public.company_documents
         where id = '60000000-0000-0000-0000-000000000001') <> v_path then
        raise exception 'Failed upload changed the document';
    end if;
    v_next := public.miloom_prepare_document_upload(
        '60000000-0000-0000-0000-000000000001', v_path, 'pdf', 4
    );
    v_next_id := (v_next ->> 'reservation_id')::uuid;
    v_next_path := v_next ->> 'path';
    insert into storage.objects(bucket_id, name, owner_id, metadata)
    values ('CompanyDocuments', v_next_path, null, '{"size":4}'::jsonb);
    insert into public.resource_access_blocks(owner_user_id, blocked_email, blocked_user_id)
    values ('00000000-0000-0000-0000-000000000001',
        'editor@example.com', '00000000-0000-0000-0000-000000000002');
    if (public.miloom_document_upload_status(
        '60000000-0000-0000-0000-000000000001'
    ) ->> 'can_upload')::boolean then
        raise exception 'Blocked Editor still sees document file upload capability';
    end if;
    begin
        perform public.miloom_prepare_document_upload(
            '60000000-0000-0000-0000-000000000001', v_path, 'pdf', 4
        );
        raise exception 'Blocked Editor prepared another upload';
    exception when insufficient_privilege then null;
    end;
    begin
        perform public.miloom_finalize_document_upload(v_next_id);
        raise exception 'Blocked Editor finalized a previously prepared upload';
    exception when insufficient_privilege then null;
    end;
end;
$$;
