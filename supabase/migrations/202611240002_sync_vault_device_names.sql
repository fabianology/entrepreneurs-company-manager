begin;

alter table public.vault_devices
    add column display_name text check (
        char_length(display_name) between 1 and 80 and display_name !~ '[[:cntrl:]]'
    );

create or replace function public.miloom_list_vault_devices()
returns table (
    device_id uuid,
    label text,
    platform text,
    agreement_public_key text,
    signing_public_key text,
    status text,
    created_at timestamptz,
    approved_at timestamptz,
    revoked_at timestamptz,
    last_seen_at timestamptz
)
language sql stable security definer set search_path = ''
as $$
    select d.id, case when d.status = 'pending' then d.label else coalesce(d.display_name, d.label) end,
           d.platform, d.agreement_public_key, d.signing_public_key,
           d.status, d.created_at, d.approved_at, d.revoked_at, d.last_seen_at
      from public.vault_devices d
     where d.user_id = auth.uid()
     order by d.created_at desc, d.id;
$$;

create function public.miloom_rename_vault_device(
    p_actor_device_id uuid,
    p_target_device_id uuid,
    p_name text,
    p_import_if_missing boolean default false
)
returns text
language plpgsql security definer set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
    v_name text := regexp_replace(p_name, '^[[:space:]]+|[[:space:]]+$', '', 'g');
    v_existing_name text;
begin
    if v_name is null or char_length(v_name) not between 1 and 80 or v_name ~ '[[:cntrl:]]' then
        raise exception using errcode = '22023', message = 'INVALID_DEVICE_NAME';
    end if;

    -- Lock in a consistent order so simultaneous renames and revocations see one current state.
    perform 1 from public.vault_devices d
     where d.user_id = v_user_id and d.id in (p_actor_device_id, p_target_device_id)
     order by d.id for update;
    perform public.miloom_require_current_resource_device(p_actor_device_id);

    select d.display_name into v_existing_name from public.vault_devices d
     where d.id = p_target_device_id and d.user_id = v_user_id and d.status = 'approved';
    if not found then
        raise exception using errcode = 'P0002', message = 'APPROVED_DEVICE_NOT_FOUND';
    end if;
    if (p_import_if_missing and v_existing_name is not null) or v_existing_name = v_name then
        return v_existing_name;
    end if;

    update public.vault_devices set display_name = v_name
     where id = p_target_device_id and user_id = v_user_id;
    return v_name;
end;
$$;

revoke all on function public.miloom_rename_vault_device(uuid, uuid, text, boolean) from public, anon;
grant execute on function public.miloom_rename_vault_device(uuid, uuid, text, boolean) to authenticated;

notify pgrst, 'reload schema';
commit;
