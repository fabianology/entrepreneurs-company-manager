-- Extend only the local lightweight fixture; never apply to hosted Auth.
create role service_role nologin bypassrls;
create schema extensions;
alter table auth.users add column email_confirmed_at timestamptz,
 add column is_anonymous boolean default false, add column raw_user_meta_data jsonb;
alter table public.companies add column structure text;
create function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
