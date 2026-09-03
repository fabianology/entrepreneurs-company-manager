-- Minimal production-shaped baseline for rehearsing the Phase 6 foundation
-- migrations without production credentials or user data.

create extension if not exists pgcrypto;

do $$
begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
    if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end;
$$;

create schema if not exists auth;
create table auth.users (id uuid primary key default gen_random_uuid());
create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$ select '{}'::jsonb $$;

create table public.companies (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    last_modified timestamptz
);
create table public.subscriptions (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, name text not null default '', status text,
    billing_cycle text, next_renewal text, payment_method text,
    payment_method_id uuid, plaid_account_id text, plaid_stream_id text,
    sub_services_data jsonb default '[]'::jsonb
);
create table public.institutions (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, email text, accounts_data jsonb default '[]'::jsonb,
    is_disconnected boolean default false, last_synced_at timestamptz
);
create table public.financial_cards (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, name text not null default '', plaid_account_id text,
    promo_ends timestamptz
);
create table public.loans (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, name text not null default '', status text,
    maturity_date timestamptz
);
create table public.company_documents (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, name text not null default '', url text
);
create table public.user_preferences (user_id uuid primary key);
create table public.resource_shares (
    id uuid primary key default gen_random_uuid(), resource_id uuid not null,
    resource_type text not null, user_id uuid not null
);
create table public.resource_invitations (
    id uuid primary key default gen_random_uuid(), resource_id uuid not null,
    resource_type text not null, email text not null
);
create table public.plaid_items (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    institution_id uuid, status text default 'active', access_token text,
    created_at timestamptz default now(), updated_at timestamptz default now()
);
create table public.plaid_transactions (
    id uuid primary key default gen_random_uuid(), user_id uuid not null,
    company_id uuid, institution_id uuid, plaid_item_id uuid not null,
    account_id text, amount double precision, category text[],
    merchant_name text, name text, date date, pending boolean default false
);

grant select on table public.companies to authenticated;
