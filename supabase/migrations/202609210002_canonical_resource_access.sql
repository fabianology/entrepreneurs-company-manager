-- Canonical collaboration access contract.
-- This migration intentionally introduces versioned Miloom RPCs rather than
-- replacing the untracked legacy share_resource / leave_resource functions.

begin;

alter table public.resource_shares
    add column if not exists role text not null default 'Viewer',
    add column if not exists sender_email text,
    add column if not exists sender_display_name text,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists suspended_at timestamptz;

alter table public.resource_invitations
    add column if not exists role text not null default 'Viewer',
    add column if not exists invited_by uuid references auth.users(id) on delete cascade,
    add column if not exists sender_email text,
    add column if not exists sender_display_name text,
    add column if not exists created_at timestamptz not null default now(),
    add column if not exists status text not null default 'Pending';

update public.resource_shares
   set role = 'Viewer'
 where role not in ('Viewer', 'Editor', 'Admin');

update public.resource_invitations
   set email = lower(btrim(email)),
       role = case when role in ('Viewer', 'Editor', 'Admin') then role else 'Viewer' end,
       status = case when status in ('Pending', 'Accepted', 'Declined', 'Revoked') then status else 'Pending' end;

do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'resource_shares_role_check') then
        alter table public.resource_shares
            add constraint resource_shares_role_check check (role in ('Viewer', 'Editor', 'Admin'));
    end if;
    if not exists (select 1 from pg_constraint where conname = 'resource_invitations_role_check') then
        alter table public.resource_invitations
            add constraint resource_invitations_role_check check (role in ('Viewer', 'Editor', 'Admin'));
    end if;
    if not exists (select 1 from pg_constraint where conname = 'resource_invitations_status_check') then
        alter table public.resource_invitations
            add constraint resource_invitations_status_check check (status in ('Pending', 'Accepted', 'Declined', 'Revoked'));
    end if;
end;
$$;

create table if not exists public.resource_access_blocks (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid not null references auth.users(id) on delete cascade,
    blocked_email text not null,
    blocked_user_id uuid references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    constraint resource_access_blocks_email_check check (
        blocked_email = lower(btrim(blocked_email)) and blocked_email like '%@%'
    )
);

create unique index if not exists resource_access_blocks_owner_email_idx
    on public.resource_access_blocks (owner_user_id, lower(blocked_email));

create index if not exists resource_access_blocks_owner_user_idx
    on public.resource_access_blocks (owner_user_id, blocked_user_id)
    where blocked_user_id is not null;

-- Remove duplicate rows before establishing one canonical edge per subject/resource.
with ranked as (
    select id, row_number() over (
        partition by resource_id, resource_type, user_id
        order by created_at desc, id desc
    ) as position
    from public.resource_shares
)
delete from public.resource_shares rs
using ranked
where rs.id = ranked.id and ranked.position > 1;

with ranked as (
    select id, row_number() over (
        partition by resource_id, resource_type, lower(email)
        order by created_at desc, id desc
    ) as position
    from public.resource_invitations
    where status in ('Pending', 'Accepted')
)
delete from public.resource_invitations ri
using ranked
where ri.id = ranked.id and ranked.position > 1;

create unique index if not exists resource_shares_subject_resource_idx
    on public.resource_shares (resource_id, resource_type, user_id);

create unique index if not exists resource_invitations_active_subject_resource_idx
    on public.resource_invitations (resource_id, resource_type, lower(email))
    where status in ('Pending', 'Accepted');

create index if not exists resource_invitations_owner_created_idx
    on public.resource_invitations (invited_by, created_at desc);

create or replace function public.miloom_resource_owner(p_type text, p_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    return case lower(p_type)
        when 'company' then (select user_id from public.companies where id = p_id)
        when 'all_subscriptions' then (select user_id from public.companies where id = p_id)
        when 'all_documents' then (select user_id from public.companies where id = p_id)
        when 'all_financials' then (select user_id from public.companies where id = p_id)
        when 'subscription' then (select user_id from public.subscriptions where id = p_id)
        when 'institution' then (select user_id from public.institutions where id = p_id)
        when 'card' then (select user_id from public.financial_cards where id = p_id)
        when 'loan' then (select user_id from public.loans where id = p_id)
        when 'document' then (select user_id from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.miloom_resource_company(p_type text, p_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    return case lower(p_type)
        when 'company' then p_id
        when 'all_subscriptions' then p_id
        when 'all_documents' then p_id
        when 'all_financials' then p_id
        when 'subscription' then (select company_id from public.subscriptions where id = p_id)
        when 'institution' then (select company_id from public.institutions where id = p_id)
        when 'card' then (select company_id from public.financial_cards where id = p_id)
        when 'loan' then (select company_id from public.loans where id = p_id)
        when 'document' then (select company_id from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.miloom_share_resource(
    p_email text,
    p_role text,
    p_resource_id uuid,
    p_resource_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_email text := lower(btrim(p_email));
    v_resource_type text := lower(btrim(p_resource_type));
    v_target_user uuid;
    v_invitation_id uuid;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if v_email is null or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_EMAIL';
    end if;
    if p_role not in ('Viewer', 'Editor', 'Admin') then
        raise exception using errcode = '22023', message = 'INVALID_COLLABORATOR_ROLE';
    end if;
    if v_resource_type not in (
        'company', 'all_subscriptions', 'subscription', 'all_documents', 'document',
        'all_financials', 'institution', 'card', 'loan'
    ) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;
    if public.miloom_resource_owner(v_resource_type, p_resource_id) is distinct from v_actor then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;

    select lower(email) into v_actor_email from auth.users where id = v_actor;
    if v_actor_email is null then raise exception using errcode = '42501', message = 'ACTOR_EMAIL_REQUIRED'; end if;
    if v_email = v_actor_email then
        raise exception using errcode = '22023', message = 'CANNOT_SHARE_WITH_SELF';
    end if;

    select id into v_target_user
      from auth.users
     where lower(email) = v_email
     order by created_at nulls last, id
     limit 1;

    if exists (
        select 1 from public.resource_access_blocks b
         where b.owner_user_id = v_actor
           and (lower(b.blocked_email) = v_email or (v_target_user is not null and b.blocked_user_id = v_target_user))
    ) then
        raise exception using errcode = 'P0001', message = 'COLLABORATOR_BLOCKED';
    end if;

    if v_target_user is not null then
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role, sender_email, sender_display_name, suspended_at
        ) values (
            p_resource_id, v_resource_type, v_target_user, p_role, v_actor_email, null, null
        )
        on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null;

        delete from public.resource_invitations
         where resource_id = p_resource_id
           and resource_type = v_resource_type
           and lower(email) = v_email
           and invited_by = v_actor
           and status in ('Pending', 'Accepted');

        return jsonb_build_object('status', 'shared_directly');
    end if;

    select id into v_invitation_id
      from public.resource_invitations
     where resource_id = p_resource_id
       and resource_type = v_resource_type
       and lower(email) = v_email
       and status in ('Pending', 'Accepted')
     limit 1;

    if v_invitation_id is null then
        insert into public.resource_invitations (
            resource_id, resource_type, email, role, invited_by,
            sender_email, sender_display_name, status
        ) values (
            p_resource_id, v_resource_type, v_email, p_role, v_actor,
            v_actor_email, null, 'Pending'
        ) returning id into v_invitation_id;
    else
        update public.resource_invitations
           set role = p_role,
               invited_by = v_actor,
               sender_email = v_actor_email,
               sender_display_name = null,
               status = 'Pending'
         where id = v_invitation_id;
    end if;

    return jsonb_build_object(
        'status', 'invitation_created',
        'invitation_id', v_invitation_id
    );
end;
$$;

create or replace function public.miloom_list_managed_access()
returns table (
    access_id uuid,
    access_kind text,
    resource_id uuid,
    resource_type text,
    company_id uuid,
    email text,
    subject_user_id uuid,
    role text,
    status text,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select rs.id,
           'direct'::text,
           rs.resource_id,
           rs.resource_type,
           public.miloom_resource_company(rs.resource_type, rs.resource_id),
           lower(au.email),
           rs.user_id,
           rs.role,
           case when rs.suspended_at is null then 'Active' else 'Suspended' end,
           rs.created_at
      from public.resource_shares rs
      join auth.users au on au.id = rs.user_id
     where public.miloom_resource_owner(rs.resource_type, rs.resource_id) = auth.uid()

    union all

    select ri.id,
           'invitation'::text,
           ri.resource_id,
           ri.resource_type,
           public.miloom_resource_company(ri.resource_type, ri.resource_id),
           lower(ri.email),
           au.id,
           ri.role,
           ri.status,
           ri.created_at
      from public.resource_invitations ri
      left join auth.users au on lower(au.email) = lower(ri.email)
     where ri.invited_by = auth.uid()
       and ri.status in ('Pending', 'Accepted')

    order by 10 desc, 1;
$$;

create or replace function public.miloom_list_access_blocks()
returns table (
    id uuid,
    email text,
    blocked_user_id uuid,
    created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    select b.id, b.blocked_email, b.blocked_user_id, b.created_at
      from public.resource_access_blocks b
     where b.owner_user_id = auth.uid()
     order by b.created_at desc, b.id;
$$;

create or replace function public.miloom_revoke_access(
    p_access_id uuid,
    p_access_kind text,
    p_scope text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_email text;
    v_subject_user uuid;
    v_resource_id uuid;
    v_resource_type text;
    v_company_id uuid;
    v_deleted_invitations integer := 0;
    v_deleted_shares integer := 0;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if p_access_kind not in ('direct', 'invitation') then
        raise exception using errcode = '22023', message = 'INVALID_ACCESS_KIND';
    end if;
    if p_scope not in ('resource', 'entity', 'person') then
        raise exception using errcode = '22023', message = 'INVALID_REVOKE_SCOPE';
    end if;

    if p_access_kind = 'direct' then
        select lower(au.email), rs.user_id, rs.resource_id, rs.resource_type
          into v_email, v_subject_user, v_resource_id, v_resource_type
          from public.resource_shares rs
          join auth.users au on au.id = rs.user_id
         where rs.id = p_access_id
           and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
    else
        select lower(ri.email), au.id, ri.resource_id, ri.resource_type
          into v_email, v_subject_user, v_resource_id, v_resource_type
          from public.resource_invitations ri
          left join auth.users au on lower(au.email) = lower(ri.email)
         where ri.id = p_access_id
           and ri.invited_by = v_actor;
    end if;

    if v_email is null or v_resource_id is null then
        raise exception using errcode = 'P0002', message = 'ACCESS_RECORD_NOT_FOUND';
    end if;

    v_company_id := public.miloom_resource_company(v_resource_type, v_resource_id);

    if p_scope = 'resource' then
        delete from public.resource_invitations ri
         where ri.invited_by = v_actor
           and lower(ri.email) = v_email
           and ri.resource_id = v_resource_id
           and ri.resource_type = v_resource_type;
        get diagnostics v_deleted_invitations = row_count;

        if v_subject_user is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject_user
               and rs.resource_id = v_resource_id
               and rs.resource_type = v_resource_type
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
            get diagnostics v_deleted_shares = row_count;
        end if;
    elsif p_scope = 'entity' then
        if v_company_id is null then
            raise exception using errcode = 'P0001', message = 'ENTITY_SCOPE_UNAVAILABLE';
        end if;

        delete from public.resource_invitations ri
         where ri.invited_by = v_actor
           and lower(ri.email) = v_email
           and public.miloom_resource_company(ri.resource_type, ri.resource_id) = v_company_id;
        get diagnostics v_deleted_invitations = row_count;

        if v_subject_user is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject_user
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor
               and public.miloom_resource_company(rs.resource_type, rs.resource_id) = v_company_id;
            get diagnostics v_deleted_shares = row_count;
        end if;
    else
        delete from public.resource_invitations ri
         where ri.invited_by = v_actor
           and lower(ri.email) = v_email;
        get diagnostics v_deleted_invitations = row_count;

        if v_subject_user is not null then
            delete from public.resource_shares rs
             where rs.user_id = v_subject_user
               and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_actor;
            get diagnostics v_deleted_shares = row_count;
        end if;

        insert into public.resource_access_blocks (owner_user_id, blocked_email, blocked_user_id)
        values (v_actor, v_email, v_subject_user)
        on conflict (owner_user_id, lower(blocked_email)) do update set
            blocked_user_id = excluded.blocked_user_id,
            created_at = now();
    end if;

    return jsonb_build_object(
        'scope', p_scope,
        'deleted_invitations', v_deleted_invitations,
        'deleted_shares', v_deleted_shares,
        'blocked', p_scope = 'person'
    );
end;
$$;

create or replace function public.miloom_unblock_collaborator(p_block_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    delete from public.resource_access_blocks
     where id = p_block_id and owner_user_id = auth.uid();
    if not found then raise exception using errcode = 'P0002', message = 'BLOCK_NOT_FOUND'; end if;
end;
$$;

create or replace function public.miloom_leave_resource(
    p_resource_id uuid,
    p_resource_type text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_email text;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    select lower(email) into v_email from auth.users where id = v_actor;

    delete from public.resource_shares
     where resource_id = p_resource_id
       and resource_type = lower(btrim(p_resource_type))
       and user_id = v_actor;

    if v_email is not null then
        delete from public.resource_invitations
         where resource_id = p_resource_id
           and resource_type = lower(btrim(p_resource_type))
           and lower(email) = v_email;
    end if;
end;
$$;

alter table public.resource_shares enable row level security;
alter table public.resource_invitations enable row level security;
alter table public.resource_access_blocks enable row level security;

do $$
declare v_policy record;
begin
    for v_policy in
        select schemaname, tablename, policyname
          from pg_policies
         where schemaname = 'public'
           and tablename in ('resource_shares', 'resource_invitations', 'resource_access_blocks')
    loop
        execute format('drop policy if exists %I on %I.%I', v_policy.policyname, v_policy.schemaname, v_policy.tablename);
    end loop;
end;
$$;

create policy resource_shares_subject_read
on public.resource_shares for select to authenticated
using (user_id = auth.uid());

create policy resource_invitations_participant_read
on public.resource_invitations for select to authenticated
using (
    invited_by = auth.uid()
    or (
        lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        and status in ('Pending', 'Accepted')
    )
);

create policy resource_access_blocks_owner_read
on public.resource_access_blocks for select to authenticated
using (owner_user_id = auth.uid());

revoke all on table public.resource_shares from anon;
revoke all on table public.resource_invitations from anon;
revoke all on table public.resource_access_blocks from anon;
revoke insert, update, delete on table public.resource_shares from authenticated;
revoke insert, update, delete on table public.resource_invitations from authenticated;
revoke insert, update, delete on table public.resource_access_blocks from authenticated;
grant select on table public.resource_shares to authenticated;
grant select on table public.resource_invitations to authenticated;
grant select on table public.resource_access_blocks to authenticated;

revoke all on function public.miloom_resource_owner(text, uuid) from public, anon, authenticated;
revoke all on function public.miloom_resource_company(text, uuid) from public, anon, authenticated;
revoke all on function public.miloom_share_resource(text, text, uuid, text) from public, anon;
revoke all on function public.miloom_list_managed_access() from public, anon;
revoke all on function public.miloom_list_access_blocks() from public, anon;
revoke all on function public.miloom_revoke_access(uuid, text, text) from public, anon;
revoke all on function public.miloom_unblock_collaborator(uuid) from public, anon;
revoke all on function public.miloom_leave_resource(uuid, text) from public, anon;

grant execute on function public.miloom_share_resource(text, text, uuid, text) to authenticated;
grant execute on function public.miloom_list_managed_access() to authenticated;
grant execute on function public.miloom_list_access_blocks() to authenticated;
grant execute on function public.miloom_revoke_access(uuid, text, text) to authenticated;
grant execute on function public.miloom_unblock_collaborator(uuid) to authenticated;
grant execute on function public.miloom_leave_resource(uuid, text) to authenticated;

notify pgrst, 'reload schema';

commit;
