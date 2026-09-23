-- Minimal, exact-resource UI status. Never exposes ciphertext or grant details
-- to an ineligible user; device readiness is tied to this auth session.
begin;

create or replace function public.miloom_resource_secret_access_status(
    p_resource_type text, p_resource_id uuid, p_device_id uuid default null
)
returns table (status text)
language plpgsql stable security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_actor uuid := auth.uid();
    v_owner uuid;
    v_version integer;
    v_state text;
    v_trusted boolean;
begin
    if v_actor is null or v_type not in ('institution', 'card', 'subscription') then
        return query select 'unavailable'::text;
        return;
    end if;
    v_owner := public.miloom_resource_owner(v_type, p_resource_id);
    if v_owner is null or (v_owner <> v_actor and not
        public.miloom_resource_secret_user_eligible(v_actor, v_type, p_resource_id)) then
        return query select 'unavailable'::text;
        return;
    end if;

    select sv.key_version, sv.state into v_version, v_state
      from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.state in ('active', 'rotation_required')
     order by sv.key_version desc limit 1;
    if v_version is null then
        return query select 'not_ready'::text;
        return;
    end if;
    if v_state <> 'active' then
        return query select 'locked'::text;
        return;
    end if;

    select exists (
        select 1 from public.vault_devices d
         where d.id = p_device_id and d.user_id = v_actor
           and d.status = 'approved'
           and d.auth_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid
    ) into v_trusted;
    if not v_trusted then
        return query select 'device_needed'::text;
        return;
    end if;
    if v_owner = v_actor or exists (
        select 1 from public.resource_secret_device_wraps w
         where w.resource_type = v_type and w.resource_id = p_resource_id
           and w.key_version = v_version and w.recipient_user_id = v_actor
           and w.recipient_device_id = p_device_id and w.grant_status = 'active'
    ) then
        return query select 'ready'::text;
        return;
    end if;
    if exists (
        select 1 from public.resource_secret_access_requests ar
         where ar.resource_type = v_type and ar.resource_id = p_resource_id
           and ar.key_version = v_version and ar.recipient_user_id = v_actor
           and ar.recipient_device_id = p_device_id and ar.status = 'pending'
    ) then
        return query select 'pending'::text;
    else
        return query select 'request'::text;
    end if;
end;
$$;
revoke all on function public.miloom_resource_secret_access_status(text, uuid, uuid)
    from public, anon;
grant execute on function public.miloom_resource_secret_access_status(text, uuid, uuid)
    to authenticated;

-- Repeated taps must not create a fresh pending request after a grant. The
-- status endpoint is advisory; the mutation enforces the same boundary.
create or replace function public.miloom_request_resource_secret_access(
    p_resource_type text, p_resource_id uuid, p_recipient_device_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_secret public.resource_secret_versions%rowtype;
    v_request_id uuid;
begin
    perform public.miloom_require_current_resource_device(p_recipient_device_id);
    select * into v_secret from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.state = 'active'
     order by sv.key_version desc limit 1 for share;
    if v_secret.resource_id is null or not public.miloom_resource_secret_user_eligible(
        auth.uid(), v_type, p_resource_id
    ) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    if exists (
        select 1 from public.resource_secret_device_wraps w
         where w.resource_type = v_type and w.resource_id = p_resource_id
           and w.key_version = v_secret.key_version
           and w.recipient_user_id = auth.uid()
           and w.recipient_device_id = p_recipient_device_id
           and w.grant_status = 'active'
    ) then
        return jsonb_build_object('status', 'already_approved',
            'key_version', v_secret.key_version);
    end if;
    insert into public.resource_secret_access_requests (
        owner_user_id, resource_type, resource_id, key_version,
        recipient_user_id, recipient_device_id
    ) values (
        v_secret.owner_user_id, v_type, p_resource_id, v_secret.key_version,
        auth.uid(), p_recipient_device_id
    ) on conflict (resource_type, resource_id, key_version, recipient_device_id)
        where status = 'pending' do update set requested_at = now()
    returning id into v_request_id;
    return jsonb_build_object('status', 'pending_owner_approval', 'request_id', v_request_id);
end;
$$;
revoke all on function public.miloom_request_resource_secret_access(text, uuid, uuid)
    from public, anon;
grant execute on function public.miloom_request_resource_secret_access(text, uuid, uuid)
    to authenticated;

commit;
