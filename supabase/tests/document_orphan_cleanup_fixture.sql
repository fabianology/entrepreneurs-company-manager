-- Extend the disposable Storage fixture before migration 024.
alter table storage.objects add column created_at timestamptz not null default now();
insert into storage.objects (bucket_id, name, owner_id, created_at) values
    ('CompanyDocuments',
     '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000001.pdf',
     '00000000-0000-0000-0000-000000000001', now() - interval '25 hours'),
    ('CompanyDocuments',
     '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000002.pdf',
     '00000000-0000-0000-0000-000000000001', now() - interval '1 hour'),
    ('CompanyDocuments',
     '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000003.pdf',
     '00000000-0000-0000-0000-000000000001', now() - interval '25 hours'),
    ('CompanyDocuments',
     '00000000-0000-0000-0000-000000000001/expense-old.pdf',
     '00000000-0000-0000-0000-000000000001', now() - interval '25 hours'),
    ('CompanyDocuments',
     '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000004.pdf',
     '00000000-0000-0000-0000-000000000002', now() - interval '25 hours');
insert into public.company_documents (id, user_id, company_id, name, url)
values ('60000000-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001', 'Still linked',
    '00000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000003.pdf');
