-- Recover a locked resource with a fresh, independently generated data key.
-- The old key remains owner-readable until the replacement ciphertext has
-- been staged, read back and confirmed. Collaborator wraps are never copied
-- to the new version; every recipient must request fresh owner approval.
begin;

create or replace function public.miloom_validate_rotated_resource_fields(
    p_resource_type text, p_key_version integer, p_fields jsonb
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_field text;
    v_value text;
    v_allowed text[];
    v_encoded text;
begin
    if p_key_version is null or p_key_version < 2
       or p_fields is null or jsonb_typeof(p_fields) <> 'object'
       or p_fields = '{}'::jsonb or octet_length(p_fields::text) > 262144 then
        raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELDS';
    end if;
    v_allowed := case p_resource_type
        when 'institution' then array['login_url','username','email','password','two_factor','accounts_data']
        when 'card' then array['login','password','card_number','expiry']
        when 'subscription' then array['login_id','password','two_factor_auth','recovery_method']
        else null end;
    if v_allowed is null then
        raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELDS';
    end if;
    for v_field, v_value in select key, value from jsonb_each_text(p_fields) loop
        if not v_field = any(v_allowed)
           or jsonb_typeof(p_fields -> v_field) <> 'string'
           or split_part(v_value, ':', 1) <> 'miloom-resource'
           or split_part(v_value, ':', 2) <> 'v1'
           or split_part(v_value, ':', 3) <> p_key_version::text
           or split_part(v_value, ':', 5) <> '' then
            raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELD';
        end if;
        v_encoded := split_part(v_value, ':', 4);
        if v_encoded !~ '^[A-Za-z0-9+/]+={0,2}$' then
            raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELD';
        end if;
        begin
            if octet_length(decode(v_encoded, 'base64')) < 28 then
                raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELD';
            end if;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'INVALID_ROTATED_FIELD';
        end;
    end loop;
end;
$$;
revoke all on function public.miloom_validate_rotated_resource_fields(text, integer, jsonb)
    from public, anon, authenticated;

create or replace function public.miloom_get_owner_resource_secret_version(
    p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    owner_account_key_version integer, owner_wrapped_resource_key text,
    encrypted_fields jsonb, state text
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
           sv.encrypted_fields, sv.state
      from public.resource_secret_versions sv
     where sv.resource_type = lower(p_resource_type) and sv.resource_id = p_resource_id
       and sv.key_version = p_key_version and sv.owner_user_id = auth.uid()
       and sv.state in ('staging', 'active', 'rotation_required');
end;
$$;
revoke all on function public.miloom_get_owner_resource_secret_version(
    text, uuid, integer, uuid, text
) from public, anon;
grant execute on function public.miloom_get_owner_resource_secret_version(
    text, uuid, integer, uuid, text
) to authenticated;

create or replace function public.miloom_list_owner_locked_resource_secrets(
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    resource_title text, company_name text
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    return query
    select sv.resource_type, sv.resource_id, sv.key_version,
           public.miloom_resource_title(sv.resource_type, sv.resource_id), c.name
      from public.resource_secret_versions sv
      join public.companies c on c.id = sv.company_id
     where sv.owner_user_id = auth.uid() and sv.state = 'rotation_required'
     order by c.name, sv.resource_type, sv.resource_id;
end;
$$;
revoke all on function public.miloom_list_owner_locked_resource_secrets(uuid, text)
    from public, anon;
grant execute on function public.miloom_list_owner_locked_resource_secrets(uuid, text)
    to authenticated;

create or replace function public.miloom_stage_rotated_resource_secret(
    p_resource_type text, p_resource_id uuid, p_old_key_version integer,
    p_new_owner_account_key_version integer, p_new_owner_wrapped_resource_key text,
    p_new_encrypted_fields jsonb, p_actor_device_id uuid, p_key_confirmation text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_old public.resource_secret_versions%rowtype;
    v_company uuid;
    v_new_version integer := p_old_key_version + 1;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    select * into v_old from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_old_key_version and sv.owner_user_id = auth.uid()
     for update;
    if v_old.resource_id is null or v_old.state <> 'rotation_required'
       or exists (select 1 from public.resource_secret_versions sv
           where sv.resource_type = v_type and sv.resource_id = p_resource_id
             and sv.key_version > v_new_version)
       or not public.miloom_is_base64_octets(p_new_owner_wrapped_resource_key, 60)
       or not exists (select 1 from public.account_vaults av
           where av.user_id = auth.uid() and av.rotation_status = 'stable'
             and av.current_key_version = p_new_owner_account_key_version) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ROTATION_NOT_READY';
    end if;
    perform public.miloom_validate_rotated_resource_fields(
        v_type, v_new_version, p_new_encrypted_fields
    );
    v_company := public.miloom_resource_company(v_type, p_resource_id);
    if v_company is distinct from v_old.company_id then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_COMPANY_CHANGED';
    end if;
    insert into public.resource_secret_versions (
        owner_user_id, resource_type, resource_id, company_id, key_version,
        owner_account_key_version, owner_wrapped_resource_key, encrypted_fields, state
    ) values (
        auth.uid(), v_type, p_resource_id, v_company, v_new_version,
        p_new_owner_account_key_version, p_new_owner_wrapped_resource_key,
        p_new_encrypted_fields, 'staging'
    ) on conflict (resource_type, resource_id, key_version) do update set
        owner_account_key_version = excluded.owner_account_key_version,
        owner_wrapped_resource_key = excluded.owner_wrapped_resource_key,
        encrypted_fields = excluded.encrypted_fields
      where public.resource_secret_versions.owner_user_id = auth.uid()
        and public.resource_secret_versions.state = 'staging';
    if not found then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ROTATION_STAGE_LOCKED';
    end if;
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (auth.uid(), auth.uid(), v_type, p_resource_id, v_new_version, 'key_staged');
    return jsonb_build_object('status', 'staged', 'key_version', v_new_version);
end;
$$;
revoke all on function public.miloom_stage_rotated_resource_secret(
    text, uuid, integer, integer, text, jsonb, uuid, text
) from public, anon;
grant execute on function public.miloom_stage_rotated_resource_secret(
    text, uuid, integer, integer, text, jsonb, uuid, text
) to authenticated;

create or replace function public.miloom_activate_rotated_resource_secret(
    p_resource_type text, p_resource_id uuid, p_old_key_version integer,
    p_expected_new_encrypted_fields jsonb,
    p_expected_new_owner_wrapped_resource_key text,
    p_actor_device_id uuid, p_key_confirmation text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_old public.resource_secret_versions%rowtype;
    v_new public.resource_secret_versions%rowtype;
    v_old_keys text[];
    v_new_keys text[];
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    select * into v_old from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_old_key_version and sv.owner_user_id = auth.uid()
     for update;
    select * into v_new from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_old_key_version + 1 and sv.owner_user_id = auth.uid()
     for update;
    select array_agg(field order by field) into v_old_keys
      from jsonb_object_keys(v_old.encrypted_fields) as fields(field);
    select array_agg(field order by field) into v_new_keys
      from jsonb_object_keys(v_new.encrypted_fields) as fields(field);
    if v_old.resource_id is null or v_old.state <> 'rotation_required'
       or v_new.resource_id is null or v_new.state <> 'staging'
       or v_old_keys is distinct from v_new_keys
       or v_new.owner_account_key_version is distinct from (
           select av.current_key_version from public.account_vaults av
            where av.user_id = auth.uid() and av.rotation_status = 'stable'
       ) or v_new.encrypted_fields is distinct from p_expected_new_encrypted_fields
       or v_new.owner_wrapped_resource_key is distinct from
           p_expected_new_owner_wrapped_resource_key then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ROTATION_CHANGED';
    end if;
    update public.resource_secret_versions
       set state = 'retired', retired_at = now()
     where resource_type = v_type and resource_id = p_resource_id
       and key_version = p_old_key_version and state = 'rotation_required';
    update public.resource_secret_versions
       set state = 'active', activated_at = now()
     where resource_type = v_type and resource_id = p_resource_id
       and key_version = p_old_key_version + 1 and state = 'staging';
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values
        (auth.uid(), auth.uid(), v_type, p_resource_id, p_old_key_version, 'key_retired'),
        (auth.uid(), auth.uid(), v_type, p_resource_id, p_old_key_version + 1, 'key_rotated');
    return jsonb_build_object('status', 'active', 'key_version', p_old_key_version + 1);
end;
$$;
revoke all on function public.miloom_activate_rotated_resource_secret(
    text, uuid, integer, jsonb, text, uuid, text
) from public, anon;
grant execute on function public.miloom_activate_rotated_resource_secret(
    text, uuid, integer, jsonb, text, uuid, text
) to authenticated;

notify pgrst, 'reload schema';
commit;
