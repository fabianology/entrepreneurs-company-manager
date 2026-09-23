-- Account-key rotation must not strand an owner-wrapped resource key. The
-- device explicitly rewraps each nonretired resource key before the existing
-- vault rotation can become stable. Active collaborator grants stay locked
-- by 014 and are never restored by this migration.
begin;

create or replace function public.miloom_require_rotating_owner_resource_device(
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
         where av.user_id = v_actor and av.rotation_status = 'migrating'
           and av.key_confirmation = p_key_confirmation
    ) or not exists (
        select 1 from public.vault_devices d
         where d.id = p_device_id and d.user_id = v_actor
           and d.status = 'approved' and d.auth_session_id = v_session_id
    ) then
        raise exception using errcode = '42501', message = 'ROTATING_OWNER_DEVICE_REQUIRED';
    end if;
end;
$$;
revoke all on function public.miloom_require_rotating_owner_resource_device(uuid, text)
    from public, anon, authenticated;

create or replace function public.miloom_list_resource_secret_owner_wraps_for_rotation(
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    owner_account_key_version integer, owner_wrapped_resource_key text
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_rotating_owner_resource_device(
        p_actor_device_id, p_key_confirmation
    );
    return query
    select sv.resource_type, sv.resource_id, sv.key_version,
           sv.owner_account_key_version, sv.owner_wrapped_resource_key
      from public.resource_secret_versions sv
      join public.account_vaults av on av.user_id = sv.owner_user_id
     where sv.owner_user_id = auth.uid() and sv.state <> 'retired'
       and sv.owner_account_key_version <> av.current_key_version
     order by sv.resource_type, sv.resource_id, sv.key_version;
end;
$$;
revoke all on function public.miloom_list_resource_secret_owner_wraps_for_rotation(uuid, text)
    from public, anon;
grant execute on function public.miloom_list_resource_secret_owner_wraps_for_rotation(uuid, text)
    to authenticated;

create or replace function public.miloom_rewrap_resource_secret_owner_key(
    p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_expected_owner_account_key_version integer, p_new_owner_wrapped_resource_key text,
    p_actor_device_id uuid, p_key_confirmation text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_current_version integer;
begin
    perform public.miloom_require_rotating_owner_resource_device(
        p_actor_device_id, p_key_confirmation
    );
    if not public.miloom_is_base64_octets(p_new_owner_wrapped_resource_key, 60) then
        raise exception using errcode = '22023', message = 'INVALID_OWNER_RESOURCE_KEY_WRAP';
    end if;
    select av.current_key_version into v_current_version
      from public.account_vaults av where av.user_id = auth.uid();
    update public.resource_secret_versions sv
       set owner_account_key_version = v_current_version,
           owner_wrapped_resource_key = p_new_owner_wrapped_resource_key
     where sv.resource_type = lower(btrim(p_resource_type))
       and sv.resource_id = p_resource_id and sv.key_version = p_key_version
       and sv.owner_user_id = auth.uid() and sv.state <> 'retired'
       and sv.owner_account_key_version = p_expected_owner_account_key_version
       and sv.owner_account_key_version <> v_current_version;
    if not found then
        raise exception using errcode = '42501', message = 'OWNER_RESOURCE_KEY_REWRAP_CONFLICT';
    end if;
end;
$$;
revoke all on function public.miloom_rewrap_resource_secret_owner_key(
    text, uuid, integer, integer, text, uuid, text
) from public, anon;
grant execute on function public.miloom_rewrap_resource_secret_owner_key(
    text, uuid, integer, integer, text, uuid, text
) to authenticated;

-- This guard also covers older clients calling miloom_complete_vault_rotation
-- without the new rewrap step; no server path may discard the prior key while
-- a staged or locked secret still depends on it.
create or replace function public.miloom_guard_resource_secret_owner_rotation_completion()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if old.rotation_status = 'migrating' and new.rotation_status = 'stable'
       and exists (
           select 1 from public.resource_secret_versions sv
            where sv.owner_user_id = new.user_id and sv.state <> 'retired'
              and sv.owner_account_key_version <> new.current_key_version
       ) then
        raise exception using errcode = '23514', message = 'RESOURCE_SECRET_OWNER_REWRAP_REQUIRED';
    end if;
    return new;
end;
$$;
create trigger guard_resource_secret_owner_rotation_completion
before update of rotation_status on public.account_vaults
for each row execute function public.miloom_guard_resource_secret_owner_rotation_completion();
revoke all on function public.miloom_guard_resource_secret_owner_rotation_completion()
    from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
