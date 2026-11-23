begin;

-- Keep the existing credential ACL and device approval flow. The new app
-- needs the old status plus the edit permission already enforced by the
-- scoped update RPC. A full sharing rollout can replace this compatibility RPC.
do $migration$
begin
    if to_regprocedure('public.miloom_resource_credential_status(text,uuid,uuid)') is null then
        execute $function$
            create function public.miloom_resource_credential_status(
                p_resource_type text, p_resource_id uuid, p_device_id uuid default null
            ) returns table (status text, can_edit boolean)
            language sql stable security definer set search_path = ''
            as $body$
                select case when s.status = 'request' then 'unavailable' else s.status end,
                       s.status = 'ready'
                  from public.miloom_resource_secret_access_status(
                      p_resource_type, p_resource_id, p_device_id
                  ) as s
            $body$
        $function$;
        revoke all on function public.miloom_resource_credential_status(text,uuid,uuid)
            from public, anon, authenticated;
        grant execute on function public.miloom_resource_credential_status(text,uuid,uuid)
            to authenticated;
    end if;
end;
$migration$;

-- Older apps still save unconverted records through a direct update. Keep
-- that path during the owner rollout. The earlier scoped cutover trigger
-- still rejects legacy credential writes on every activated record.
create or replace function public.miloom_guard_legacy_resource_fields()
returns trigger
language plpgsql set search_path = ''
as $$
declare
    v_type text := case tg_table_name when 'subscriptions' then 'subscription'
        when 'financial_cards' then 'card' else 'institution' end;
    v_original jsonb := '{}'::jsonb;
begin
    if current_user <> 'authenticated' or
       to_regprocedure('public.miloom_resource_secret_role_allowed(uuid,text,uuid,boolean)') is null then
        return new;
    end if;
    if tg_op = 'UPDATE' then
        v_original := public.miloom_legacy_resource_fields(v_type, to_jsonb(old));
    end if;
    if public.miloom_legacy_resource_fields(v_type, to_jsonb(new)) is distinct from v_original then
        raise exception using errcode = '42501', message = 'USE_RESOURCE_SECRET_UPDATE';
    end if;
    return new;
end;
$$;

-- The client supplies a digest of the unchanged legacy website and verifies
-- the encrypted replacement locally. Both the move and the new credentials
-- commit together. A stale draft or any other legacy value fails closed.
create function public.miloom_save_owned_bank_with_legacy_website(
    p_record jsonb, p_owner_account_key_version integer, p_owner_wrapped_resource_key text,
    p_encrypted_fields jsonb, p_actor_device_id uuid, p_key_confirmation text,
    p_expected_legacy_website_digest text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_id uuid := (p_record->>'id')::uuid;
    v_bank jsonb;
    v_legacy_fields jsonb;
    v_has_scoped_version boolean;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if v_id is null or (p_record->>'user_id')::uuid is distinct from v_actor then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    if p_expected_legacy_website_digest is null or
       not coalesce(p_encrypted_fields ? 'login_url', false) then
        raise exception using errcode = '22023', message = 'RESOURCE_SECRET_FIELDS_INCOMPLETE';
    end if;

    -- Use the same lock order as the normal protected save.
    perform 1 from public.account_vaults av where av.user_id = v_actor for update;
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    perform 1 from public.resource_secret_versions sv
     where sv.resource_type = 'institution' and sv.resource_id = v_id
       and sv.state in ('active','rotation_required') for update;
    v_has_scoped_version := found;

    select to_jsonb(i) into v_bank from public.institutions i
     where i.id = v_id and i.user_id = v_actor for update;
    if v_bank is null then
        raise exception using errcode = 'P0002', message = 'PROTECTED_RESOURCE_NOT_FOUND';
    end if;
    v_legacy_fields := public.miloom_legacy_resource_fields('institution', v_bank);
    if v_legacy_fields - 'login_url' <> '{}'::jsonb then
        raise exception using errcode = '42501', message = 'LEGACY_CREDENTIALS_REQUIRE_CONVERSION';
    end if;
    if v_legacy_fields = '{}'::jsonb and v_has_scoped_version then
        -- The normal RPC verifies that this is an exact retry.
        null;
    elsif p_expected_legacy_website_digest is distinct from
          encode(sha256(convert_to(v_legacy_fields->>'login_url', 'UTF8')), 'hex') then
        raise exception using errcode = '40001', message = 'RESOURCE_SECRET_SOURCE_CHANGED';
    else
        update public.institutions set login_url = null where id = v_id and user_id = v_actor;
    end if;

    perform public.miloom_save_owned_protected_resource(
        'institution', p_record, false, p_owner_account_key_version, p_owner_wrapped_resource_key,
        p_encrypted_fields, p_actor_device_id, p_key_confirmation
    );
end;
$$;
revoke all on function public.miloom_save_owned_bank_with_legacy_website(jsonb,integer,text,jsonb,uuid,text,text)
    from public, anon, authenticated;
grant execute on function public.miloom_save_owned_bank_with_legacy_website(jsonb,integer,text,jsonb,uuid,text,text)
    to authenticated;

notify pgrst, 'reload schema';
commit;
