begin;

-- Compare only protected fields. Ordinary changes to older records preserve
-- their credential columns until a separately verified conversion.
create function public.miloom_legacy_resource_fields(p_type text, p_row jsonb)
returns jsonb
language sql immutable set search_path = ''
as $$
    select case p_type
        when 'subscription' then jsonb_strip_nulls(jsonb_build_object(
            'login_id', nullif(p_row->>'login_id',''), 'password', nullif(p_row->>'password',''),
            'two_factor_auth', nullif(nullif(p_row->>'two_factor_auth','None'),''),
            'recovery_method', nullif(p_row->>'recovery_method','')))
        when 'card' then jsonb_strip_nulls(jsonb_build_object(
            'login', nullif(p_row->>'login',''), 'password', nullif(p_row->>'password',''),
            'card_number', nullif(p_row->>'card_number',''), 'expiry', nullif(p_row->>'expiry','')))
        when 'institution' then jsonb_strip_nulls(jsonb_build_object(
            'login_url', nullif(p_row->>'login_url',''), 'username', nullif(p_row->>'username',''),
            'email', nullif(p_row->>'email',''), 'password', nullif(p_row->>'password',''),
            'two_factor', nullif(p_row->>'two_factor',''),
            'accounts_data', (
                select jsonb_agg(fields order by fields)
                from (
                    select jsonb_strip_nulls(jsonb_build_object(
                        'id', account->>'id',
                        'account_number', nullif(coalesce(account->>'accountNumber',account->>'account_number'),''),
                        'routing_number', nullif(coalesce(account->>'routingNumber',account->>'routing_number'),''),
                        'wire_routing_number', nullif(coalesce(account->>'wireRoutingNumber',account->>'wire_routing_number'),'')
                    )) as fields
                    from jsonb_array_elements(coalesce(nullif(p_row->'accounts_data','null'::jsonb), '[]'::jsonb)) a(account)
                    where public.miloom_source_accounts_have_credentials(jsonb_build_array(account))
                ) accounts
            )))
    end
$$;
revoke all on function public.miloom_legacy_resource_fields(text,jsonb) from public, anon, authenticated;
grant execute on function public.miloom_legacy_resource_fields(text,jsonb) to authenticated;
grant execute on function public.miloom_source_accounts_have_credentials(jsonb) to authenticated;

create function public.miloom_guard_legacy_resource_fields()
returns trigger
language plpgsql set search_path = ''
as $$
declare
    v_type text := case tg_table_name when 'subscriptions' then 'subscription'
        when 'financial_cards' then 'card' else 'institution' end;
    v_original jsonb := '{}'::jsonb;
begin
    if current_user <> 'authenticated' then return new; end if;
    if tg_op = 'UPDATE' then
        v_original := public.miloom_legacy_resource_fields(v_type, to_jsonb(old));
    end if;
    if public.miloom_legacy_resource_fields(v_type, to_jsonb(new)) is distinct from v_original then
        raise exception using errcode = '42501', message = 'USE_RESOURCE_SECRET_UPDATE';
    end if;
    return new;
end
$$;
revoke all on function public.miloom_guard_legacy_resource_fields() from public, anon, authenticated;

create trigger zzz_miloom_guard_legacy_resource_fields before insert or update on public.subscriptions
for each row execute function public.miloom_guard_legacy_resource_fields();
create trigger zzz_miloom_guard_legacy_resource_fields before insert or update on public.financial_cards
for each row execute function public.miloom_guard_legacy_resource_fields();
create trigger zzz_miloom_guard_legacy_resource_fields before insert or update on public.institutions
for each row execute function public.miloom_guard_legacy_resource_fields();

-- A new credential set and its metadata commit together. Restrict this
-- operation to the owner so only their approved vault can wrap the key.
create function public.miloom_save_owned_protected_resource(
    p_resource_type text, p_record jsonb, p_insert boolean,
    p_owner_account_key_version integer, p_owner_wrapped_resource_key text,
    p_encrypted_fields jsonb, p_actor_device_id uuid, p_key_confirmation text
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
    v_actor uuid := auth.uid();
    v_id uuid := (p_record->>'id')::uuid;
    v_company uuid := (p_record->>'company_id')::uuid;
    v_table text;
    v_allowed text[];
    v_previous jsonb;
    v_columns text;
    v_values text;
    v_revision bigint;
    v_existing public.resource_secret_versions%rowtype;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if v_id is null or p_insert is null or (p_record->>'user_id')::uuid is distinct from v_actor
       or public.miloom_resource_owner('company', v_company) is distinct from v_actor
       or pg_catalog.jsonb_typeof(p_record) <> 'object' then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    case p_resource_type
      when 'subscription' then
        v_table := 'subscriptions';
        v_allowed := '{company_id,name,cost,currency,billing_cycle,payment_method,payment_method_id,next_renewal,next_renewal_at,renew,status,sub_services_data,linked_emails_data,website,two_factor_auth,notes,pricing_model,service_type,last_updated,show_sub_services_tab,show_linked_emails_tab,plaid_stream_id,plaid_account_id}';
      when 'card' then
        v_table := 'financial_cards';
        v_allowed := '{company_id,name,institution_name,card_holder,last4,expires_at,network,type,status,limit,paid_from,paid_on,autopay,balance,mo_payment,apr,promo_apr,promo_ends,card_holder_type,notes,plaid_account_id}';
      when 'institution' then
        v_table := 'institutions';
        v_allowed := '{company_id,name,accounts_data,last_synced_at,is_disconnected}';
      else
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_TYPE';
    end case;
    if public.miloom_legacy_resource_fields(p_resource_type, p_record) <> '{}'::jsonb
       or exists (select 1 from jsonb_object_keys(p_record) as k(key)
                   where not k.key = any(v_allowed || array['id','user_id'])) then
        raise exception using errcode = '22023', message = 'INVALID_RESOURCE_METADATA';
    end if;
    if p_resource_type = 'subscription' then
        p_record := p_record || jsonb_build_object('two_factor_auth','None');
    end if;

    -- Serialize first credential writes with device revocation, key rotation
    -- and retirement. Concurrent submissions cannot replace active fields.
    perform 1 from public.account_vaults av where av.user_id = v_actor for update;
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    select * into v_existing from public.resource_secret_versions sv
     where sv.resource_type = p_resource_type and sv.resource_id = v_id
       and sv.state in ('active','rotation_required') for update;
    if found then
        if v_existing.owner_user_id = v_actor and v_existing.state = 'active'
           and v_existing.owner_wrapped_resource_key = p_owner_wrapped_resource_key
           and v_existing.encrypted_fields = p_encrypted_fields then return; end if;
        raise exception using errcode = '40001', message = 'RESOURCE_SECRET_CHANGED';
    end if;

    if p_insert then
        select string_agg(format('%I', k.key), ','), string_agg(format('r.%I', k.key), ',')
          into v_columns, v_values from jsonb_object_keys(p_record) k(key);
        execute format('insert into public.%1$I (%2$s) select %3$s from jsonb_populate_record(null::public.%1$I, $1) r',
                       v_table, v_columns, v_values) using p_record;
    else
        execute format('select to_jsonb(r) from public.%I r where id = $1 and user_id = $2 for update', v_table)
           into v_previous using v_id, v_actor;
        if v_previous is null then
            raise exception using errcode = 'P0002', message = 'PROTECTED_RESOURCE_NOT_FOUND';
        end if;
        if public.miloom_legacy_resource_fields(p_resource_type, v_previous) <> '{}'::jsonb then
            raise exception using errcode = '42501', message = 'LEGACY_CREDENTIALS_REQUIRE_CONVERSION';
        end if;
        select string_agg(format('%1$I = r.%1$I', k.key), ',')
          into v_columns from jsonb_object_keys(p_record - 'id' - 'user_id') k(key);
        execute format('update public.%1$I t set %2$s from jsonb_populate_record(null::public.%1$I, $1) r where t.id = $2 and t.user_id = $3',
                       v_table, v_columns) using p_record, v_id, v_actor;
    end if;
    perform public.miloom_stage_resource_secret(
        p_resource_type, v_id, 1, p_owner_account_key_version, p_owner_wrapped_resource_key,
        p_encrypted_fields, p_actor_device_id, p_key_confirmation);
    select source_secret_revision into strict v_revision from public.resource_secret_versions
     where resource_type = p_resource_type and resource_id = v_id and key_version = 1;
    perform public.miloom_activate_staged_resource_secret(
        p_resource_type, v_id, 1, v_revision, p_encrypted_fields, p_owner_wrapped_resource_key,
        p_actor_device_id, p_key_confirmation);
end
$$;
revoke all on function public.miloom_save_owned_protected_resource(text,jsonb,boolean,integer,text,jsonb,uuid,text)
    from public, anon, authenticated;
grant execute on function public.miloom_save_owned_protected_resource(text,jsonb,boolean,integer,text,jsonb,uuid,text)
    to authenticated;

-- Older development rows can still contain account-key ciphertext. Device
-- revocation rewraps just those values, under an exact compare, while legacy
-- plaintext and device-only rows remain untouched for separate conversion.
create function public.miloom_rewrap_legacy_vault_fields(
    p_resource_type text, p_resource_id uuid, p_replacements jsonb,
    p_actor_device_id uuid, p_key_confirmation text
)
returns void language plpgsql security definer set search_path = ''
as $$
declare
    v_table text;
    v_row jsonb;
    v_replacement record;
    v_index bigint;
    v_path text[];
    v_previous_version integer;
    v_current_version integer;
begin
    select previous_key_version, current_key_version into v_previous_version, v_current_version
      from public.account_vaults where user_id = auth.uid() for update;
    perform public.miloom_require_rotating_owner_resource_device(p_actor_device_id,p_key_confirmation);
    v_table := case p_resource_type when 'subscription' then 'subscriptions'
        when 'card' then 'financial_cards' when 'institution' then 'institutions' end;
    if v_table is null or v_previous_version is null or jsonb_typeof(p_replacements) <> 'array'
       or jsonb_array_length(p_replacements) not between 1 and 500 then
        raise exception using errcode = '22023', message = 'INVALID_LEGACY_REWRAP';
    end if;
    execute format('select to_jsonb(r) from public.%I r where id = $1 and user_id = $2 for update',v_table)
       into v_row using p_resource_id,auth.uid();
    if v_row is null then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;

    for v_replacement in select * from jsonb_to_recordset(p_replacements)
        as r(field text, account_id text, old_value text, new_value text)
    loop
        if v_replacement.account_id is null and v_replacement.field = 'password' then
            v_path := array['password'];
        elsif p_resource_type = 'institution' and v_replacement.account_id is not null
           and v_replacement.field in ('accountNumber','routingNumber','wireRoutingNumber') then
            select ordinal - 1 into strict v_index
              from jsonb_array_elements(v_row->'accounts_data') with ordinality as a(account,ordinal)
             where account->>'id' = v_replacement.account_id;
            v_path := array['accounts_data',v_index::text,v_replacement.field];
        else
            raise exception using errcode = '22023', message = 'INVALID_LEGACY_REWRAP';
        end if;
        if v_replacement.old_value is null or (v_row #>> v_path) is distinct from v_replacement.old_value
           or v_replacement.old_value !~ ('^miloom:v1:' || v_previous_version || ':[A-Za-z0-9+/]+={0,2}$') then
            raise exception using errcode = '40001', message = 'RESOURCE_SECRET_SOURCE_CHANGED';
        end if;
        if v_replacement.new_value is null
           or v_replacement.new_value !~ ('^miloom:v1:' || v_current_version || ':[A-Za-z0-9+/]+={0,2}$')
           or octet_length(decode(split_part(v_replacement.new_value, ':', 4), 'base64')) < 28 then
            raise exception using errcode = '22023', message = 'INVALID_LEGACY_REWRAP';
        end if;
        v_row := jsonb_set(v_row, v_path, to_jsonb(v_replacement.new_value), false);
    end loop;

    if p_resource_type = 'institution' then
        update public.institutions set password = v_row->>'password', accounts_data = v_row->'accounts_data'
         where id = p_resource_id and user_id = auth.uid();
    else
        execute format('update public.%I set password = $1 where id = $2 and user_id = $3',v_table)
          using v_row->>'password',p_resource_id,auth.uid();
    end if;
end
$$;
revoke all on function public.miloom_rewrap_legacy_vault_fields(text,uuid,jsonb,uuid,text)
    from public, anon, authenticated;
grant execute on function public.miloom_rewrap_legacy_vault_fields(text,uuid,jsonb,uuid,text) to authenticated;

notify pgrst, 'reload schema';
commit;
