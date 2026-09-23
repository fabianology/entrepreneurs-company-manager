-- Disposable-only Storage shape and prior broad policy for migration 022.
alter table public.company_documents
    add column url text, add column visibility text not null default 'entity';
create schema storage;
create table storage.buckets (id text primary key, public boolean not null);
create table storage.objects (
    bucket_id text not null, name text not null, owner_id text,
    primary key (bucket_id, name)
);
insert into storage.buckets values ('CompanyDocuments', false), ('Avatars', true);
insert into storage.objects values
    ('CompanyDocuments', '00000000-0000-0000-0000-000000000001/shared.pdf',
        '00000000-0000-0000-0000-000000000001'),
    ('CompanyDocuments', '00000000-0000-0000-0000-000000000001/sibling.pdf',
        '00000000-0000-0000-0000-000000000001'),
    ('CompanyDocuments', '00000000-0000-0000-0000-000000000001/private.pdf',
        '00000000-0000-0000-0000-000000000001'),
    ('CompanyDocuments', '00000000-0000-0000-0000-000000000002/other.pdf',
        '00000000-0000-0000-0000-000000000002'),
    ('Avatars', 'public/avatar.png', null);
update public.company_documents
   set url = '00000000-0000-0000-0000-000000000001/shared.pdf'
 where id = '60000000-0000-0000-0000-000000000001';
insert into public.company_documents (id, user_id, company_id, name, url, visibility)
values
    ('60000000-0000-0000-0000-000000000002',
     '00000000-0000-0000-0000-000000000001',
     '10000000-0000-0000-0000-000000000001', 'Sibling',
     '00000000-0000-0000-0000-000000000001/sibling.pdf', 'entity'),
    ('60000000-0000-0000-0000-000000000003',
     '00000000-0000-0000-0000-000000000001',
     '10000000-0000-0000-0000-000000000001', 'Private',
     '00000000-0000-0000-0000-000000000001/private.pdf', 'owner_private');
insert into public.resource_shares (resource_id, resource_type, user_id, role)
values ('60000000-0000-0000-0000-000000000001', 'document',
        '00000000-0000-0000-0000-000000000003', 'Viewer');

alter table storage.objects enable row level security;
grant usage on schema storage, auth to authenticated;
grant select on storage.objects to authenticated;
-- Simulate an unrelated preexisting permissive SELECT policy: the restrictive
-- boundary introduced by 022 must still deny unshared files.
create policy broad_select on storage.objects for select to authenticated using (true);
