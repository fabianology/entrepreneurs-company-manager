-- Disposable PostgreSQL fixture for 009/010 delegated scope contracts.
do $$ begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon; end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated; end if;
end $$;
create schema auth;
create table auth.users (
    id uuid primary key,
    email text,
    created_at timestamptz default now()
);
create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create table public.companies (
    id uuid primary key, user_id uuid not null, name text
);
create table public.subscriptions (
    id uuid primary key, user_id uuid not null, company_id uuid not null, name text
);
create table public.institutions (
    id uuid primary key, user_id uuid not null, company_id uuid not null, name text
);
create table public.financial_cards (
    id uuid primary key, user_id uuid not null, company_id uuid not null, name text
);
create table public.loans (
    id uuid primary key, user_id uuid not null, company_id uuid not null, name text
);
create table public.company_documents (
    id uuid primary key, user_id uuid not null, company_id uuid not null, name text
);
create table public.resource_shares (
    id uuid primary key default gen_random_uuid(),
    resource_id uuid not null,
    resource_type text not null,
    user_id uuid not null,
    role text not null,
    sender_email text,
    sender_display_name text,
    suspended_at timestamptz,
    created_at timestamptz not null default now(),
    unique (resource_id, resource_type, user_id)
);
create table public.resource_invitations (
    id uuid primary key default gen_random_uuid(),
    resource_id uuid not null,
    resource_type text not null,
    email text not null,
    role text not null,
    invited_by uuid not null,
    sender_email text,
    sender_display_name text,
    status text not null,
    created_at timestamptz not null default now(),
    unique (resource_id, resource_type, email)
);
create table public.resource_access_blocks (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null,
    blocked_email text not null,
    blocked_user_id uuid,
    created_at timestamptz not null default now()
);
create unique index resource_access_blocks_owner_email_idx
    on public.resource_access_blocks (owner_user_id, lower(blocked_email));

insert into auth.users (id,email) values
    ('00000000-0000-0000-0000-000000000001','owner@example.com'),
    ('00000000-0000-0000-0000-000000000002','editor@example.com'),
    ('00000000-0000-0000-0000-000000000003','viewer@example.com');
insert into public.companies values
    ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Company A'),
    ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Company B');
insert into public.subscriptions values
    ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Service A');
insert into public.institutions values
    ('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Bank A'),
    ('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','Bank B');
insert into public.financial_cards values
    ('40000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Card A');
insert into public.loans values
    ('50000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Loan A');
insert into public.company_documents values
    ('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Document A');
