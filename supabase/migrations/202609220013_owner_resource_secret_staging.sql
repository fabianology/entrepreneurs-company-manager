-- Owner-only, non-activating migration path for per-resource ciphertext.
-- Staged values are not served to collaborators and do not replace the
-- legacy owner fields. Activation requires a separate client/read rollout.

begin;

create or replace function public.miloom_require_owner_resource_device(
    p_device_id uuid, p_key_confirmation text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_session_id uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
    perform public.miloom_require_recent_access_token();
    if v_actor is null or v_session_id is null or not exists (
        select 1 from public.account_vaults av
         where av.user_id = v_actor
           and av.key_confirmation = p_key_confirmation
           and av.rotation_status = 'stable'
    ) or not exists (
        select 1 from public.vault_devices d
         where d.id = p_device_id
           and d.user_id = v_actor
           and d.status = 'approved'
           and d.auth_session_id = v_session_id
    ) then
        raise exception using errcode = '42501', message = 'TRUSTED_OWNER_DEVICE_REQUIRED';
    end if;
end;
$$;
revoke all on function public.miloom_require_owner_resource_device(uuid, text)
    from public, anon, authenticated;

create or replace function public.miloom_stage_resource_secret(
    p_resource_type text,
    p_resource_id uuid,
    p_key_version integer,
    p_owner_account_key_version integer,
    p_owner_wrapped_resource_key text,
    p_encrypted_fields jsonb,
    p_actor_device_id uuid,
    p_key_confirmation text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_type text := lower(btrim(p_resource_type));
    v_company uuid;
    v_field text;
    v_value text;
    v_encoded text;
    v_allowed text[];
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if v_type not in ('institution', 'card', 'subscription') or p_key_version is null
       or p_key_version < 1 or p_owner_account_key_version is null
       or not public.miloom_is_base64_octets(p_owner_wrapped_resource_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_SECRET_STAGE';
    end if;
    if public.miloom_resource_owner(v_type, p_resource_id) is distinct from v_actor then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    v_company := public.miloom_resource_company(v_type, p_resource_id);
    if v_company is null or not exists (
        select 1 from public.account_vaults av
         where av.user_id = v_actor
           and av.current_key_version = p_owner_account_key_version
           and av.rotation_status = 'stable'
    ) then
        raise exception using errcode = '42501', message = 'OWNER_VAULT_VERSION_MISMATCH';
    end if;
    if p_encrypted_fields is null or jsonb_typeof(p_encrypted_fields) <> 'object'
       or p_encrypted_fields = '{}'::jsonb
       or octet_length(p_encrypted_fields::text) > 262144 then
        raise exception using errcode = '22023', message = 'INVALID_ENCRYPTED_FIELDS';
    end if;
    v_allowed := case v_type
        when 'institution' then array['login_url','username','email','password','two_factor','accounts_data']
        when 'card' then array['login','password','card_number','expiry']
        when 'subscription' then array['login_id','password','two_factor_auth','recovery_method']
    end;
    for v_field, v_value in select key, value from jsonb_each_text(p_encrypted_fields) loop
        if not v_field = any(v_allowed)
           or jsonb_typeof(p_encrypted_fields -> v_field) <> 'string'
           or split_part(v_value, ':', 1) <> 'miloom-resource'
           or split_part(v_value, ':', 2) <> 'v1'
           or split_part(v_value, ':', 3) <> p_key_version::text
           or split_part(v_value, ':', 5) <> '' then
            raise exception using errcode = '22023', message = 'INVALID_ENCRYPTED_FIELD';
        end if;
        v_encoded := split_part(v_value, ':', 4);
        if v_encoded !~ '^[A-Za-z0-9+/]+={0,2}$' then
            raise exception using errcode = '22023', message = 'INVALID_ENCRYPTED_FIELD';
        end if;
        begin
            if octet_length(decode(v_encoded, 'base64')) < 28 then
                raise exception using errcode = '22023', message = 'INVALID_ENCRYPTED_FIELD';
            end if;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'INVALID_ENCRYPTED_FIELD';
        end;
    end loop;

    -- A new key may only stage the first version or the successor of a fully
    -- retired version. Repeating the same unfinished stage is retryable.
    if exists (
        select 1 from public.resource_secret_versions sv
         where sv.resource_type = v_type and sv.resource_id = p_resource_id
           and sv.state in ('active', 'rotation_required')
    ) or p_key_version <> coalesce((
        select max(sv.key_version) + 1 from public.resource_secret_versions sv
         where sv.resource_type = v_type and sv.resource_id = p_resource_id
           and sv.state <> 'staging'
    ), 1) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ROTATION_REQUIRED';
    end if;
    insert into public.resource_secret_versions (
        owner_user_id, resource_type, resource_id, company_id, key_version,
        owner_account_key_version, owner_wrapped_resource_key, encrypted_fields, state
    ) values (
        v_actor, v_type, p_resource_id, v_company, p_key_version,
        p_owner_account_key_version, p_owner_wrapped_resource_key, p_encrypted_fields, 'staging'
    ) on conflict (resource_type, resource_id, key_version) do update set
        owner_account_key_version = excluded.owner_account_key_version,
        owner_wrapped_resource_key = excluded.owner_wrapped_resource_key,
        encrypted_fields = excluded.encrypted_fields
      where public.resource_secret_versions.owner_user_id = v_actor
        and public.resource_secret_versions.state = 'staging';
    if not found then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_STAGE_LOCKED';
    end if;
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (v_actor, v_actor, v_type, p_resource_id, p_key_version, 'key_staged');
    return jsonb_build_object('status', 'staged', 'key_version', p_key_version);
end;
$$;
revoke all on function public.miloom_stage_resource_secret(
    text, uuid, integer, integer, text, jsonb, uuid, text
) from public, anon;
grant execute on function public.miloom_stage_resource_secret(
    text, uuid, integer, integer, text, jsonb, uuid, text
) to authenticated;

create or replace function public.miloom_get_staged_resource_secret(
    p_resource_type text, p_resource_id uuid,
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    owner_account_key_version integer, owner_wrapped_resource_key text,
    encrypted_fields jsonb
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if public.miloom_resource_owner(lower(p_resource_type), p_resource_id) is distinct from auth.uid() then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    return query
    select sv.resource_type, sv.resource_id, sv.key_version,
           sv.owner_account_key_version, sv.owner_wrapped_resource_key,
           sv.encrypted_fields
      from public.resource_secret_versions sv
     where sv.resource_type = lower(p_resource_type)
       and sv.resource_id = p_resource_id
       and sv.owner_user_id = auth.uid()
       and sv.state = 'staging';
end;
$$;
revoke all on function public.miloom_get_staged_resource_secret(text, uuid, uuid, text)
    from public, anon;
grant execute on function public.miloom_get_staged_resource_secret(text, uuid, uuid, text)
    to authenticated;

notify pgrst, 'reload schema';
commit;
