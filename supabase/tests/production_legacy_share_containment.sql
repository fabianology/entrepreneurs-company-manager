-- Isolated, production-shaped rehearsal of the one-off sharing containment.
-- Run in a disposable PostgreSQL database, then apply the ops SQL, then run
-- the assertions below with psql's -v ON_ERROR_STOP=1.
create role anon;
create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create table auth.users (
    id uuid primary key,
    email text,
    created_at timestamptz default now()
);
create table public.companies (id uuid primary key, user_id uuid not null);
create table public.subscriptions (id uuid primary key, user_id uuid not null);
create table public.institutions (id uuid primary key, user_id uuid not null);
create table public.financial_cards (id uuid primary key, user_id uuid not null);
create table public.loans (id uuid primary key, user_id uuid not null);
create table public.company_documents (id uuid primary key, user_id uuid not null);
create table public.resource_invitations (
    id uuid primary key default gen_random_uuid(),
    resource_id uuid not null,
    resource_type text not null,
    email text not null,
    role text not null default 'Viewer',
    invited_by uuid not null,
    sender_email text,
    sender_display_name text,
    status text not null default 'Pending',
    unique (resource_id, resource_type, email)
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
    unique (resource_id, resource_type, user_id)
);
insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-000000000001', 'owner@example.com'),
    ('00000000-0000-0000-0000-000000000002', 'other@example.com'),
    ('00000000-0000-0000-0000-000000000003', 'target@example.com');
insert into public.companies values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');
insert into public.subscriptions values
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001');
