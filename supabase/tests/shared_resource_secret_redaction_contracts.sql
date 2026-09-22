-- Run with psql -v ON_ERROR_STOP=1 -f this_file against a disposable database.
-- Never run against a linked staging or production project.
create extension if not exists pgcrypto;
do $$
begin
    if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
    if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end;
$$;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to authenticated;
grant usage on schema public to authenticated;

create table public.resource_shares (
    resource_id uuid not null, resource_type text not null,
    user_id uuid not null, role text not null, suspended_at timestamptz
);
create table public.subscriptions (
    id uuid primary key, user_id uuid not null, company_id uuid not null,
    name text not null, login_id text, password text,
    two_factor_auth text, recovery_method text
);
create table public.financial_cards (
    id uuid primary key, user_id uuid not null, company_id uuid not null,
    name text not null, login text, password text, card_number text, expiry text
);
create table public.institutions (
    id uuid primary key, user_id uuid not null, company_id uuid not null,
    name text not null, login_url text, username text, email text,
    password text, two_factor text, accounts_data jsonb
);
grant select, insert, update, delete on public.subscriptions, public.financial_cards, public.institutions to authenticated;
alter table public.subscriptions enable row level security;
alter table public.financial_cards enable row level security;
alter table public.institutions enable row level security;
create policy subscription_access on public.subscriptions to authenticated
    using (user_id = auth.uid() or exists (
        select 1 from public.resource_shares s where s.user_id = auth.uid()
        and s.resource_type = 'subscription' and s.resource_id = id
    ));
create policy card_access on public.financial_cards to authenticated
    using (user_id = auth.uid() or exists (
        select 1 from public.resource_shares s where s.user_id = auth.uid()
        and s.resource_type = 'card' and s.resource_id = id
    ));
create policy institution_access on public.institutions to authenticated
    using (user_id = auth.uid() or exists (
        select 1 from public.resource_shares s where s.user_id = auth.uid()
        and s.resource_type = 'institution' and s.resource_id = id
    ));
create policy card_insert on public.financial_cards for insert to authenticated
    with check (user_id = auth.uid() or exists (
        select 1 from public.resource_shares s where s.user_id = auth.uid()
        and s.resource_type = 'card' and s.resource_id = id
    ));
grant select on public.resource_shares to authenticated;

insert into public.subscriptions values (
    '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Service', 'owner@login.test',
    'subscription-secret', 'App', 'backup-secret'
);
insert into public.financial_cards values (
    '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Card', 'owner-login',
    'card-secret', '4111111111111111', '12/30'
);
insert into public.institutions values (
    '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'cccccccc-cccc-cccc-cccc-cccccccccccc', 'Bank', 'https://bank.test',
    'bank-user', 'owner@bank.test', 'bank-secret', 'SMS',
    '[{"id":"a1","name":"Checking","accountNumber":"123456789", "routingNumber":"987654321", "wireRoutingNumber":"123123123", "last4":"6789"}]'
);
insert into public.resource_shares values
    ('11111111-1111-1111-1111-111111111111', 'subscription', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Viewer', null),
    ('22222222-2222-2222-2222-222222222222', 'card', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Viewer', null),
    ('33333333-3333-3333-3333-333333333333', 'institution', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Editor', null);

\ir ../migrations/202609220007_redact_shared_resource_secrets.sql

set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
    if (select password from public.subscriptions limit 1) <> 'subscription-secret'
    then raise exception 'Additive migration broke the legacy owner read'; end if;
end;
$$;
reset role;
\ir ../migrations/202609220008_restrict_shared_secret_table_reads.sql
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', false);
do $$
begin
    if (select password from public.miloom_visible_subscriptions() limit 1) <> 'subscription-secret'
        or (select card_number from public.miloom_visible_financial_cards() limit 1) <> '4111111111111111'
        or (select accounts_data->0->>'accountNumber' from public.miloom_visible_institutions() limit 1) <> '123456789'
    then raise exception 'Owner lost a credential'; end if;
    if not has_column_privilege('authenticated', 'public.subscriptions', 'id', 'SELECT')
        or has_column_privilege('authenticated', 'public.subscriptions', 'password', 'SELECT')
        or has_column_privilege('authenticated', 'public.financial_cards', 'card_number', 'SELECT')
        or has_column_privilege('authenticated', 'public.institutions', 'accounts_data', 'SELECT')
    then raise exception 'Column-level grants are not fail-closed'; end if;
end;
$$;
insert into public.financial_cards (id, user_id, company_id, name, password)
values ('44444444-4444-4444-4444-444444444444',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'New owner card', 'new-owner-secret');
do $$
begin
    if (select password from public.miloom_visible_financial_cards()
        where id = '44444444-4444-4444-4444-444444444444') <> 'new-owner-secret'
    then raise exception 'Owner insert/read failed after grant lockdown'; end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false);
do $$
begin
    if (select count(*) from public.miloom_visible_subscriptions()) <> 1
        or (select count(*) from public.miloom_visible_financial_cards()) <> 1
        or (select count(*) from public.miloom_visible_institutions()) <> 1
    then raise exception 'Shared records disappeared'; end if;
    if (select login_id is not null or password is not null or recovery_method is not null
        from public.miloom_visible_subscriptions() limit 1)
        or (select login is not null or password is not null or card_number is not null or expiry is not null
        from public.miloom_visible_financial_cards() limit 1)
        or (select login_url is not null or username is not null or email is not null
            or password is not null or two_factor is not null
            from public.miloom_visible_institutions() limit 1)
    then raise exception 'Collaborator received a credential'; end if;
    if (select accounts_data->0->>'accountNumber' is not null
        or accounts_data->0->>'routingNumber' is not null
        or accounts_data->0->>'wireRoutingNumber' is not null
        or accounts_data->0->>'last4' <> '6789'
        from public.miloom_visible_institutions() limit 1)
    then raise exception 'Institution account redaction damaged safe data or leaked a number'; end if;
    begin
        execute 'select password from public.subscriptions';
        raise exception 'Direct secret SELECT unexpectedly succeeded';
    exception when insufficient_privilege then null;
    end;
    if (select count(*) from public.financial_cards) <> 1
    then raise exception 'Collaborator identifier projection failed or crossed scope'; end if;
end;
$$;

-- Native saves use explicit UPDATE/INSERT because ON CONFLICT DO UPDATE
-- requires SELECT on updated credential columns, which must remain closed.
update public.financial_cards set name = 'Renamed Card'
where id = '22222222-2222-2222-2222-222222222222'
returning id;

update public.institutions set name = 'Renamed Bank', login_url = null,
    username = null, email = null, password = null, two_factor = null,
    accounts_data = '[]'::jsonb
where id = '33333333-3333-3333-3333-333333333333';

reset role;
do $$
begin
    if (select name from public.institutions) <> 'Renamed Bank'
        or (select password from public.institutions) <> 'bank-secret'
        or (select login_url from public.institutions) <> 'https://bank.test'
        or (select accounts_data->0->>'accountNumber' from public.institutions) <> '123456789'
    then raise exception 'Editor write changed owner credentials'; end if;
    if (select name from public.financial_cards where id = '22222222-2222-2222-2222-222222222222') <> 'Renamed Card'
        or (select password from public.financial_cards where id = '22222222-2222-2222-2222-222222222222') <> 'card-secret'
        or (select card_number from public.financial_cards where id = '22222222-2222-2222-2222-222222222222') <> '4111111111111111'
    then raise exception 'Editor upsert changed owner card credentials'; end if;
end;
$$;
update public.resource_shares set suspended_at = now()
where user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
insert into public.resource_shares values
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'company', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Viewer', null),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'all_financials', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'Viewer', null);

set role authenticated;
select set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', false);
do $$
begin
    if (select count(*) from public.miloom_visible_subscriptions()) <> 0
        or (select count(*) from public.miloom_visible_financial_cards()) <> 0
        or (select count(*) from public.miloom_visible_institutions()) <> 0
    then raise exception 'Suspended collaborator still sees records'; end if;
end;
$$;
select set_config('request.jwt.claim.sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd', false);
do $$
begin
    if (select count(*) from public.miloom_visible_subscriptions()) <> 1
        or (select count(*) from public.miloom_visible_financial_cards()) <> 2
        or (select count(*) from public.miloom_visible_institutions()) <> 1
    then raise exception 'Company share is missing a resource'; end if;
end;
$$;
select set_config('request.jwt.claim.sub', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', false);
do $$
begin
    if (select count(*) from public.miloom_visible_subscriptions()) <> 0
        or (select count(*) from public.miloom_visible_financial_cards()) <> 2
        or (select count(*) from public.miloom_visible_institutions()) <> 1
    then raise exception 'Financial category share crossed its scope'; end if;
end;
$$;
reset role;

select 'shared resource secret redaction contracts passed' as result;
