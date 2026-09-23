-- Authenticated owner or explicitly granted Editor/Admin device can replace
-- an active resource's ciphertext with an optimistic, exact-version compare.
-- This never accepts plaintext or writes a legacy credential column.
begin;

-- The existing strict envelope validator also applies to active version 1.
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
    if p_key_version is null or p_key_version < 1
       or p_fields is null or jsonb_typeof(p_fields) <> 'object'
       or p_fields = '{}'::jsonb or octet_length(p_fields::text) > 262144 then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELDS';
    end if;
    v_allowed := case p_resource_type
        when 'institution' then array['login_url','username','email','password','two_factor','accounts_data']
        when 'card' then array['login','password','card_number','expiry']
        when 'subscription' then array['login_id','password','two_factor_auth','recovery_method']
        else null end;
    if v_allowed is null then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELDS';
    end if;
    for v_field, v_value in select key, value from jsonb_each_text(p_fields) loop
        if not v_field = any(v_allowed)
           or jsonb_typeof(p_fields -> v_field) <> 'string'
           or split_part(v_value, ':', 1) <> 'miloom-resource'
           or split_part(v_value, ':', 2) <> 'v1'
           or split_part(v_value, ':', 3) <> p_key_version::text
           or split_part(v_value, ':', 5) <> '' then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end if;
        v_encoded := split_part(v_value, ':', 4);
        if v_encoded !~ '^[A-Za-z0-9+/]+={0,2}$' then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end if;
        begin
            if octet_length(decode(v_encoded, 'base64')) < 28 then
                raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
            end if;
        exception when invalid_text_representation then
            raise exception using errcode = '22023', message = 'INVALID_RESOURCE_FIELD';
        end;
    end loop;
end;
$$;
revoke all on function public.miloom_validate_rotated_resource_fields(text, integer, jsonb)
    from public, anon, authenticated;

alter table public.resource_secret_audit_events
    drop constraint resource_secret_audit_events_event_type_check;
alter table public.resource_secret_audit_events
    add constraint resource_secret_audit_events_event_type_check
    check (event_type in (
        'key_staged', 'key_activated', 'device_granted', 'device_revoked',
        'rotation_required', 'key_rotated', 'key_retired', 'secret_updated'
    ));

create or replace function public.miloom_update_resource_secret(
    p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_expected_encrypted_fields jsonb, p_new_encrypted_fields jsonb,
    p_actor_device_id uuid
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_actor uuid := auth.uid();
    v_secret public.resource_secret_versions%rowtype;
begin
    perform public.miloom_require_current_resource_device(p_actor_device_id);
    if v_type not in ('institution', 'card', 'subscription') then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end if;
    select * into v_secret from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_key_version
     for update;
    if v_secret.resource_id is null or v_secret.state <> 'active'
       or public.miloom_resource_owner(v_type, p_resource_id) is distinct from v_secret.owner_user_id
       or v_secret.encrypted_fields is distinct from p_expected_encrypted_fields then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_CHANGED';
    end if;
    if v_actor <> v_secret.owner_user_id and (
        not public.miloom_resource_secret_user_eligible(v_actor, v_type, p_resource_id)
        or not exists (
            select 1 from public.resource_secret_device_wraps w
             where w.resource_type = v_type and w.resource_id = p_resource_id
               and w.key_version = p_key_version and w.recipient_user_id = v_actor
               and w.recipient_device_id = p_actor_device_id
               and w.grant_status = 'active'
        )
    ) then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_ACCESS_NOT_GRANTED';
    end if;
    perform public.miloom_validate_rotated_resource_fields(
        v_type, p_key_version, p_new_encrypted_fields
    );
    if p_new_encrypted_fields = v_secret.encrypted_fields then
        return jsonb_build_object('status', 'unchanged', 'key_version', p_key_version);
    end if;
    update public.resource_secret_versions
       set encrypted_fields = p_new_encrypted_fields
     where resource_type = v_type and resource_id = p_resource_id
       and key_version = p_key_version and state = 'active';
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (
        v_secret.owner_user_id, v_actor, v_type, p_resource_id, p_key_version, 'secret_updated'
    );
    return jsonb_build_object('status', 'updated', 'key_version', p_key_version);
end;
$$;
revoke all on function public.miloom_update_resource_secret(
    text, uuid, integer, jsonb, jsonb, uuid
) from public, anon;
grant execute on function public.miloom_update_resource_secret(
    text, uuid, integer, jsonb, jsonb, uuid
) to authenticated;

commit;
