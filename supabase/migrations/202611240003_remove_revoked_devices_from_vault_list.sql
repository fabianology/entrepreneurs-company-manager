begin;

alter table public.vault_devices
    add column removed_from_list_at timestamptz check (
        removed_from_list_at is null or status = 'revoked'
    );

-- A device that requests access again should appear as pending and stay visible
-- if the new request or approval is later revoked.
create function public.miloom_restore_vault_device_list_visibility()
returns trigger
language plpgsql set search_path = ''
as $$
begin
    new.removed_from_list_at := null;
    return new;
end;
$$;

create trigger vault_devices_restore_list_visibility
before update of status on public.vault_devices
for each row when (old.status = 'revoked' and new.status <> 'revoked')
execute function public.miloom_restore_vault_device_list_visibility();

revoke all on function public.miloom_restore_vault_device_list_visibility()
    from public, anon, authenticated;

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
     where d.user_id = auth.uid() and d.removed_from_list_at is null
     order by d.created_at desc, d.id;
$$;

create function public.miloom_remove_revoked_vault_device_from_list(
    p_actor_device_id uuid,
    p_target_device_id uuid
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
begin
    perform 1 from public.vault_devices d
     where d.user_id = v_user_id and d.id in (p_actor_device_id, p_target_device_id)
     order by d.id for update;
    perform public.miloom_require_current_resource_device(p_actor_device_id);

    -- Keep the device record so revocation, re-enrollment, and audit links are preserved.
    update public.vault_devices d
       set removed_from_list_at = coalesce(d.removed_from_list_at, now())
     where d.id = p_target_device_id and d.user_id = v_user_id and d.status = 'revoked';
    if not found then
        raise exception using errcode = 'P0002', message = 'REVOKED_DEVICE_NOT_FOUND';
    end if;
end;
$$;

revoke all on function public.miloom_remove_revoked_vault_device_from_list(uuid, uuid)
    from public, anon;
grant execute on function public.miloom_remove_revoked_vault_device_from_list(uuid, uuid)
    to authenticated;

notify pgrst, 'reload schema';
commit;
