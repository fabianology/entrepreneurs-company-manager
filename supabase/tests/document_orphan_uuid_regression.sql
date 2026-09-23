-- psql -v ON_ERROR_STOP=1 -d miloom_orphan_regression -f this-file
-- ISOLATED disposable database only: minimal table shapes, real migration 029
-- followed by the corrective migration. Never run against a hosted project.
do $$ begin
    if current_database() <> 'miloom_orphan_regression' then
        raise exception 'Disposable regression database required';
    end if;
end $$;
create schema storage;
create table storage.objects (
    bucket_id text, name text, owner_id text, created_at timestamptz
);
create table public.company_documents (url text);
create table public.miloom_document_file_cleanup (
    id uuid default gen_random_uuid(), owner_user_id uuid,
    path text unique, created_at timestamptz default now()
);
\ir ../migrations/202609220029_preserve_legacy_document_file_references.sql
\ir ../migrations/202609230001_fix_orphan_document_uuid_filter.sql

-- Positive aged orphan, fresh orphan, relative attachment, absolute legacy
-- attachment, wrong owner, unrelated bucket and non-app filename.
insert into storage.objects
select 'CompanyDocuments',
       '00000000-0000-0000-0000-000000000001/' ||
       '90000000-0000-0000-0000-' || lpad(n::text,12,'0') || '.pdf',
       case when n=5 then '00000000-0000-0000-0000-000000000002'
            else '00000000-0000-0000-0000-000000000001' end,
       now() - case when n=2 then interval '1 hour' else interval '25 hours' end
from generate_series(1,5) n;
insert into storage.objects values
 ('Avatars','00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000006.pdf',null,now()-interval '25 hours'),
 ('CompanyDocuments','00000000-0000-0000-0000-000000000001/expense-old.pdf',null,now()-interval '25 hours');
insert into public.company_documents values
 ('00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000003.pdf'),
 ('https://legacy.example.test/storage/v1/object/sign/CompanyDocuments/00000000-0000-0000-0000-000000000001%2F90000000-0000-0000-0000-000000000004.pdf?token=old#preview');
do $$ begin
    if public.miloom_queue_orphan_document_uploads() <> 1 then
        raise exception 'Expected exactly one aged unreferenced app upload';
    end if;
    if (select count(*) from public.miloom_document_file_cleanup) <> 1
       or not exists (select 1 from public.miloom_document_file_cleanup
          where path='00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000001.pdf') then
        raise exception 'Wrong file queued';
    end if;
    if public.miloom_queue_orphan_document_uploads() <> 0 then
        raise exception 'Discovery is not idempotent';
    end if;
    if has_function_privilege('anon','public.miloom_queue_orphan_document_uploads()','EXECUTE')
       or has_function_privilege('authenticated','public.miloom_queue_orphan_document_uploads()','EXECUTE')
       or not has_function_privilege('service_role','public.miloom_queue_orphan_document_uploads()','EXECUTE') then
        raise exception 'Cleanup privilege boundary changed';
    end if;
end $$;
select 'PASS: positive orphan, grace, both reference forms, owner, bucket, filename, idempotency, privileges' as result;
