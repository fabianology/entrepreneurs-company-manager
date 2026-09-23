-- Run after document_orphan_cleanup_fixture.sql and migration 024.
do $$
begin
    if has_function_privilege('authenticated',
        'public.miloom_queue_orphan_document_uploads()', 'EXECUTE')
       or not has_function_privilege('service_role',
        'public.miloom_queue_orphan_document_uploads()', 'EXECUTE') then
        raise exception 'Orphan scan has incorrect grants';
    end if;
    if public.miloom_queue_orphan_document_uploads() <> 1 then
        raise exception 'Orphan scan did not find exactly the one old abandoned upload';
    end if;
    if (select count(*) from public.miloom_document_file_cleanup) <> 1
       or not exists (
           select 1 from public.miloom_document_file_cleanup
            where path = '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000001.pdf'
       ) then
        raise exception 'Orphan scan queued an unsafe or ineligible file';
    end if;
    if public.miloom_queue_orphan_document_uploads() <> 0 then
        raise exception 'Orphan scan is not idempotent';
    end if;
end;
$$;
