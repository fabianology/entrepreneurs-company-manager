-- Disposable local schema support for the actual verified-email accept worker.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
alter table auth.users add column email_confirmed_at timestamptz default now(),
    add column is_anonymous boolean not null default false;
alter table public.resource_invitations add column token_hash bytea,
    add column token_issued_at timestamptz, add column expires_at timestamptz default now() + interval '7 days',
    add column accepted_at timestamptz, add column declined_at timestamptz;
-- Preexisting Admin must remain opted out after migration.
insert into public.resource_shares(resource_id,resource_type,user_id,role)
values ('10000000-0000-0000-0000-000000000001','company','00000000-0000-0000-0000-000000000002','Admin');
