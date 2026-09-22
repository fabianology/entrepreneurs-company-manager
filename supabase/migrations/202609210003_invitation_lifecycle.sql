-- Recipient-bound, expiring, single-use invitation lifecycle.
-- Depends on 202609210002_canonical_resource_access.sql.

begin;

create extension if not exists pgcrypto with schema extensions;

alter table public.resource_invitations
    add column if not exists token_hash bytea,
    add column if not exists token_issued_at timestamptz,
    add column if not exists expires_at timestamptz,
    add column if not exists last_sent_at timestamptz,
    add column if not exists accepted_at timestamptz,
    add column if not exists declined_at timestamptz;

update public.resource_invitations
   set expires_at = coalesce(created_at, now()) + interval '7 days'
 where status = 'Pending' and expires_at is null;

create unique index if not exists resource_invitations_token_hash_idx
    on public.resource_invitations (token_hash)
    where token_hash is not null;

create index if not exists resource_invitations_recipient_pending_idx
    on public.resource_invitations (lower(email), expires_at desc)
    where status = 'Pending';

create or replace function public.miloom_prepare_invitation_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.status = 'Pending' and tg_op = 'INSERT' then
        new.expires_at := coalesce(new.expires_at, now() + interval '7 days');
        new.accepted_at := null;
        new.declined_at := null;
    elsif new.status = 'Pending' and (
        old.status is distinct from 'Pending' or new.expires_at is null
    ) then
        new.expires_at := now() + interval '7 days';
        new.accepted_at := null;
        new.declined_at := null;
    end if;
    return new;
end;
$$;

drop trigger if exists prepare_miloom_invitation_lifecycle on public.resource_invitations;
create trigger prepare_miloom_invitation_lifecycle
before insert or update on public.resource_invitations
for each row execute function public.miloom_prepare_invitation_lifecycle();

create or replace function public.miloom_resource_title(p_type text, p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    return case lower(p_type)
        when 'company' then (select name from public.companies where id = p_id)
        when 'all_subscriptions' then 'All Subscriptions'
        when 'all_documents' then 'All Documents'
        when 'all_financials' then 'All Financials'
        when 'subscription' then (select name from public.subscriptions where id = p_id)
        when 'institution' then (select name from public.institutions where id = p_id)
        when 'card' then (select name from public.financial_cards where id = p_id)
        when 'loan' then (select name from public.loans where id = p_id)
        when 'document' then (select name from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.miloom_issue_invitation_token(
    p_invitation_id uuid,
    p_invited_by uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_token text := encode(extensions.gen_random_bytes(32), 'hex');
    v_expires_at timestamptz := now() + interval '7 days';
begin
    update public.resource_invitations
       set token_hash = extensions.digest(v_token, 'sha256'),
           token_issued_at = now(),
           expires_at = v_expires_at,
           last_sent_at = now(),
           status = 'Pending',
           accepted_at = null,
           declined_at = null
     where id = p_invitation_id
       and invited_by = p_invited_by
       and status = 'Pending'
       and (last_sent_at is null or last_sent_at <= now() - interval '1 minute');

    if not found then
        if exists (
            select 1 from public.resource_invitations
             where id = p_invitation_id
               and invited_by = p_invited_by
               and status = 'Pending'
               and last_sent_at > now() - interval '1 minute'
        ) then
            raise exception using errcode = 'P0001', message = 'INVITATION_SEND_RATE_LIMITED';
        end if;
        raise exception using errcode = 'P0002', message = 'PENDING_INVITATION_NOT_FOUND';
    end if;

    return jsonb_build_object('token', v_token, 'expires_at', v_expires_at);
end;
$$;

create or replace function public.miloom_list_my_invitations()
returns table (
    invitation_id uuid,
    resource_id uuid,
    resource_type text,
    resource_title text,
    company_id uuid,
    company_title text,
    inviter_email text,
    role text,
    created_at timestamptz,
    expires_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select ri.id,
           ri.resource_id,
           ri.resource_type,
           public.miloom_resource_title(ri.resource_type, ri.resource_id),
           public.miloom_resource_company(ri.resource_type, ri.resource_id),
           c.name,
           lower(coalesce(au.email, ri.sender_email)),
           ri.role,
           ri.created_at,
           ri.expires_at
      from public.resource_invitations ri
      join public.companies c
        on c.id = public.miloom_resource_company(ri.resource_type, ri.resource_id)
      left join auth.users au on au.id = ri.invited_by
     where auth.uid() is not null
       and lower(ri.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
       and ri.status = 'Pending'
       and ri.expires_at > now()
       and not exists (
           select 1 from public.resource_access_blocks b
            where b.owner_user_id = public.miloom_resource_owner(ri.resource_type, ri.resource_id)
              and (lower(b.blocked_email) = lower(ri.email) or b.blocked_user_id = auth.uid())
       )
     order by ri.created_at desc, ri.id;
$$;

create or replace function public.miloom_preview_invitation_token(p_token text)
returns table (
    invitation_id uuid,
    resource_id uuid,
    resource_type text,
    resource_title text,
    company_id uuid,
    company_title text,
    inviter_email text,
    role text,
    created_at timestamptz,
    expires_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select ri.id,
           ri.resource_id,
           ri.resource_type,
           public.miloom_resource_title(ri.resource_type, ri.resource_id),
           public.miloom_resource_company(ri.resource_type, ri.resource_id),
           c.name,
           lower(coalesce(au.email, ri.sender_email)),
           ri.role,
           ri.created_at,
           ri.expires_at
      from public.resource_invitations ri
      join public.companies c
        on c.id = public.miloom_resource_company(ri.resource_type, ri.resource_id)
      left join auth.users au on au.id = ri.invited_by
     where auth.uid() is not null
       and p_token ~ '^[0-9a-f]{64}$'
       and ri.token_hash = extensions.digest(p_token, 'sha256')
       and lower(ri.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
       and ri.status = 'Pending'
       and ri.expires_at > now()
       and not exists (
           select 1 from public.resource_access_blocks b
            where b.owner_user_id = public.miloom_resource_owner(ri.resource_type, ri.resource_id)
              and (lower(b.blocked_email) = lower(ri.email) or b.blocked_user_id = auth.uid())
       );
$$;

create or replace function public.miloom_act_on_invitation(
    p_invitation_id uuid,
    p_token text,
    p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_invitation public.resource_invitations%rowtype;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if (p_invitation_id is null) = (p_token is null) then
        raise exception using errcode = '22023', message = 'INVITATION_REFERENCE_REQUIRED';
    end if;

    select lower(email) into v_actor_email from auth.users where id = v_actor;

    select * into v_invitation
      from public.resource_invitations ri
     where (
            (p_invitation_id is not null and ri.id = p_invitation_id)
            or (
                p_token is not null
                and p_token ~ '^[0-9a-f]{64}$'
                and ri.token_hash = extensions.digest(p_token, 'sha256')
            )
        )
       and lower(ri.email) = v_actor_email
       and ri.status = 'Pending'
       and ri.expires_at > now()
     for update;

    if not found then raise exception using errcode = 'P0002', message = 'INVITATION_NOT_AVAILABLE'; end if;

    if exists (
        select 1 from public.resource_access_blocks b
         where b.owner_user_id = public.miloom_resource_owner(v_invitation.resource_type, v_invitation.resource_id)
           and (lower(b.blocked_email) = v_actor_email or b.blocked_user_id = v_actor)
    ) then
        raise exception using errcode = '42501', message = 'INVITATION_BLOCKED';
    end if;

    if p_accept then
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role, sender_email, sender_display_name, suspended_at
        ) values (
            v_invitation.resource_id,
            v_invitation.resource_type,
            v_actor,
            v_invitation.role,
            v_invitation.sender_email,
            null,
            null
        )
        on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role,
            sender_email = excluded.sender_email,
            sender_display_name = null,
            suspended_at = null;

        update public.resource_invitations
           set status = 'Accepted',
               accepted_at = now(),
               declined_at = null,
               token_hash = null,
               token_issued_at = null
         where id = v_invitation.id;

        return jsonb_build_object(
            'status', 'accepted',
            'resource_id', v_invitation.resource_id,
            'resource_type', v_invitation.resource_type
        );
    end if;

    update public.resource_invitations
       set status = 'Declined',
           declined_at = now(),
           accepted_at = null,
           token_hash = null,
           token_issued_at = null
     where id = v_invitation.id;

    return jsonb_build_object('status', 'declined');
end;
$$;

create or replace function public.miloom_accept_invitation(p_invitation_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$ select public.miloom_act_on_invitation(p_invitation_id, null, true); $$;

create or replace function public.miloom_accept_invitation_token(p_token text)
returns jsonb
language sql
security definer
set search_path = public
as $$ select public.miloom_act_on_invitation(null, p_token, true); $$;

create or replace function public.miloom_decline_invitation(p_invitation_id uuid)
returns jsonb
language sql
security definer
set search_path = public
as $$ select public.miloom_act_on_invitation(p_invitation_id, null, false); $$;

create or replace function public.miloom_decline_invitation_token(p_token text)
returns jsonb
language sql
security definer
set search_path = public
as $$ select public.miloom_act_on_invitation(null, p_token, false); $$;

-- Do not duplicate an accepted invitation beside its direct share in owner management.
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
           case when ri.expires_at <= now() then 'Expired' else 'Pending' end,
           ri.created_at
      from public.resource_invitations ri
      left join auth.users au on lower(au.email) = lower(ri.email)
     where ri.invited_by = auth.uid()
       and ri.status = 'Pending'

    order by 10 desc, 1;
$$;

revoke all on function public.miloom_prepare_invitation_lifecycle() from public, anon, authenticated;
revoke all on function public.miloom_resource_title(text, uuid) from public, anon, authenticated;
revoke all on function public.miloom_issue_invitation_token(uuid, uuid) from public, anon, authenticated;
revoke all on function public.miloom_act_on_invitation(uuid, text, boolean) from public, anon, authenticated;
revoke all on function public.miloom_list_my_invitations() from public, anon;
revoke all on function public.miloom_preview_invitation_token(text) from public, anon;
revoke all on function public.miloom_accept_invitation(uuid) from public, anon;
revoke all on function public.miloom_accept_invitation_token(text) from public, anon;
revoke all on function public.miloom_decline_invitation(uuid) from public, anon;
revoke all on function public.miloom_decline_invitation_token(text) from public, anon;

grant execute on function public.miloom_issue_invitation_token(uuid, uuid) to service_role;
grant execute on function public.miloom_list_my_invitations() to authenticated;
grant execute on function public.miloom_preview_invitation_token(text) to authenticated;
grant execute on function public.miloom_accept_invitation(uuid) to authenticated;
grant execute on function public.miloom_accept_invitation_token(text) to authenticated;
grant execute on function public.miloom_decline_invitation(uuid) to authenticated;
grant execute on function public.miloom_decline_invitation_token(text) to authenticated;

notify pgrst, 'reload schema';

commit;
