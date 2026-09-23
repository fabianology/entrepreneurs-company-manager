-- Apply to disposable Storage fixture before migration 026.
alter table storage.buckets add column file_size_limit bigint;
update storage.buckets set file_size_limit = 26214400 where id = 'CompanyDocuments';
alter table storage.objects add column metadata jsonb;
insert into public.resource_shares (resource_id, resource_type, user_id, role)
values ('60000000-0000-0000-0000-000000000001', 'document',
    '00000000-0000-0000-0000-000000000002', 'Editor');
