-- Run after 202609220004_disable_automatic_invitation_acceptance.sql.
begin;

do $$
begin
    if not exists (
        select 1
        from pg_trigger trigger_record
        join pg_class table_record on table_record.oid = trigger_record.tgrelid
        join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
        where not trigger_record.tgisinternal
          and schema_record.nspname = 'auth'
          and table_record.relname = 'users'
          and trigger_record.tgname = 'on_auth_user_created'
    ) then
        raise exception 'Profile creation trigger is missing';
    end if;

    if not exists (
        select 1
        from pg_trigger trigger_record
        join pg_class table_record on table_record.oid = trigger_record.tgrelid
        join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
        where not trigger_record.tgisinternal
          and schema_record.nspname = 'auth'
          and table_record.relname = 'users'
          and trigger_record.tgname = 'business_expense_user_cleanup'
    ) then
        raise exception 'Account cleanup trigger is missing';
    end if;

    if exists (
        select 1
        from pg_trigger trigger_record
        join pg_class table_record on table_record.oid = trigger_record.tgrelid
        join pg_namespace schema_record on schema_record.oid = table_record.relnamespace
        where not trigger_record.tgisinternal
          and schema_record.nspname = 'auth'
          and table_record.relname = 'users'
          and trigger_record.tgname = 'on_auth_user_created_invitations'
    ) then
        raise exception 'Legacy signup-time invitation auto-acceptance is enabled';
    end if;
end;
$$;

insert into auth.users (id, email) values
    ('97000000-0000-0000-0000-000000000001', 'trigger-owner@example.com');

insert into public.companies (id, user_id, name, structure) values
    ('97000000-0000-0000-0000-000000000011', '97000000-0000-0000-0000-000000000001', 'Trigger Contract Entity', 'LLC');

insert into public.resource_invitations (
    resource_id,
    resource_type,
    email,
    role,
    invited_by,
    sender_email,
    status,
    expires_at
) values (
    '97000000-0000-0000-0000-000000000011',
    'company',
    'trigger-recipient@example.com',
    'Viewer',
    '97000000-0000-0000-0000-000000000001',
    'trigger-owner@example.com',
    'Pending',
    now() + interval '7 days'
);

insert into auth.users (id, email) values
    ('97000000-0000-0000-0000-000000000002', 'trigger-recipient@example.com');

do $$
begin
    if not exists (
        select 1 from public.profiles
        where id = '97000000-0000-0000-0000-000000000001'
          and email = 'trigger-owner@example.com'
    ) or not exists (
        select 1 from public.profiles
        where id = '97000000-0000-0000-0000-000000000002'
          and email = 'trigger-recipient@example.com'
    ) then
        raise exception 'Signup did not create the expected profile rows';
    end if;

    if not exists (
        select 1 from public.resource_invitations
        where email = 'trigger-recipient@example.com'
          and status = 'Pending'
    ) then
        raise exception 'Signup did not preserve the pending invitation';
    end if;

    if exists (
        select 1 from public.resource_shares
        where user_id = '97000000-0000-0000-0000-000000000002'
          and resource_id = '97000000-0000-0000-0000-000000000011'
    ) then
        raise exception 'Signup bypassed recipient acceptance and created direct access';
    end if;
end;
$$;

rollback;
