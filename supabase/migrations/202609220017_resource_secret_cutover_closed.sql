-- Atomic source-column cutover, deliberately NOT executable by app roles.
-- A later, separately reviewed release migration must grant EXECUTE after
-- every supported client reads/updates resource ciphertext and old clients
-- have been handled. Merely applying this migration cannot activate secrets.
begin;

create or replace function public.miloom_source_accounts_have_credentials(p_accounts jsonb)
returns boolean
language sql immutable set search_path = ''
as $$
    select coalesce(jsonb_typeof(p_accounts) = 'array' and exists (
        select 1 from jsonb_array_elements(
            case when jsonb_typeof(p_accounts) = 'array' then p_accounts else '[]'::jsonb end
        ) as a(account)
         where nullif(btrim(coalesce(a.account ->> 'accountNumber', '')), '') is not null
            or nullif(btrim(coalesce(a.account ->> 'routingNumber', '')), '') is not null
            or nullif(btrim(coalesce(a.account ->> 'wireRoutingNumber', '')), '') is not null
            or nullif(btrim(coalesce(a.account ->> 'account_number', '')), '') is not null
            or nullif(btrim(coalesce(a.account ->> 'routing_number', '')), '') is not null
            or nullif(btrim(coalesce(a.account ->> 'wire_routing_number', '')), '') is not null
    ), false);
$$;
revoke all on function public.miloom_source_accounts_have_credentials(jsonb)
    from public, anon, authenticated;

create or replace function public.miloom_block_legacy_secret_rewrite()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    if not exists (
        select 1 from public.resource_secret_versions sv
         where sv.resource_type = case tg_table_name
             when 'financial_cards' then 'card'
             when 'subscriptions' then 'subscription'
             when 'institutions' then 'institution' end
           and sv.resource_id = new.id
           and sv.state in ('active', 'rotation_required')
    ) then return new; end if;
    if tg_table_name = 'subscriptions' then
        if nullif(new.login_id, '') is not null or nullif(new.password, '') is not null
           or nullif(new.recovery_method, '') is not null
           or new.two_factor_auth is distinct from 'None' then
            raise exception using errcode = '42501', message = 'USE_RESOURCE_SECRET_UPDATE';
        end if;
    elsif tg_table_name = 'financial_cards' then
        if nullif(new.login, '') is not null or nullif(new.password, '') is not null
           or nullif(new.card_number, '') is not null or nullif(new.expiry, '') is not null then
            raise exception using errcode = '42501', message = 'USE_RESOURCE_SECRET_UPDATE';
        end if;
    elsif tg_table_name = 'institutions' then
        if nullif(new.login_url, '') is not null or nullif(new.username, '') is not null
           or nullif(new.email, '') is not null or nullif(new.password, '') is not null
           or nullif(new.two_factor, '') is not null
           or public.miloom_source_accounts_have_credentials(new.accounts_data) then
            raise exception using errcode = '42501', message = 'USE_RESOURCE_SECRET_UPDATE';
        end if;
    end if;
    return new;
end;
$$;
create trigger zzy_miloom_block_legacy_secret_rewrite
before update on public.subscriptions
for each row execute function public.miloom_block_legacy_secret_rewrite();
create trigger zzy_miloom_block_legacy_secret_rewrite
before update on public.financial_cards
for each row execute function public.miloom_block_legacy_secret_rewrite();
create trigger zzy_miloom_block_legacy_secret_rewrite
before update on public.institutions
for each row execute function public.miloom_block_legacy_secret_rewrite();
revoke all on function public.miloom_block_legacy_secret_rewrite()
    from public, anon, authenticated;

create or replace function public.miloom_activate_staged_resource_secret(
    p_resource_type text, p_resource_id uuid, p_key_version integer,
    p_expected_source_secret_revision bigint,
    p_expected_encrypted_fields jsonb, p_expected_owner_wrapped_resource_key text,
    p_actor_device_id uuid, p_key_confirmation text
)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := lower(btrim(p_resource_type));
    v_secret public.resource_secret_versions%rowtype;
    v_source_revision bigint;
    v_accounts jsonb;
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if v_type not in ('subscription', 'card', 'institution')
       or public.miloom_resource_owner(v_type, p_resource_id) is distinct from auth.uid() then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    select * into v_secret from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = p_resource_id
       and sv.key_version = p_key_version and sv.owner_user_id = auth.uid()
     for update;
    if v_secret.resource_id is null or v_secret.state <> 'staging'
       or v_secret.source_secret_revision < 0
       or v_secret.source_secret_revision <> p_expected_source_secret_revision
       or v_secret.encrypted_fields is distinct from p_expected_encrypted_fields
       or v_secret.owner_wrapped_resource_key is distinct from p_expected_owner_wrapped_resource_key then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_STAGE_CHANGED';
    end if;

    if v_type = 'subscription' then
        select s.secret_revision into v_source_revision from public.subscriptions s
         where s.id = p_resource_id and s.user_id = auth.uid() for update;
        if v_source_revision is distinct from v_secret.source_secret_revision then
            raise exception using errcode = '42501', message = 'RESOURCE_SECRET_SOURCE_CHANGED';
        end if;
        if exists (select 1 from public.subscriptions s where s.id = p_resource_id
            and ((nullif(s.login_id, '') is not null and not v_secret.encrypted_fields ? 'login_id')
              or (nullif(s.password, '') is not null and not v_secret.encrypted_fields ? 'password')
              or (s.two_factor_auth is not null and s.two_factor_auth not in ('', 'None')
                  and not v_secret.encrypted_fields ? 'two_factor_auth')
              or (nullif(s.recovery_method, '') is not null
                  and not v_secret.encrypted_fields ? 'recovery_method'))) then
            raise exception using errcode = '23514', message = 'RESOURCE_SECRET_FIELDS_INCOMPLETE';
        end if;
        update public.subscriptions
           set login_id = null, password = null, two_factor_auth = 'None', recovery_method = null
         where id = p_resource_id and user_id = auth.uid();
    elsif v_type = 'card' then
        select c.secret_revision into v_source_revision from public.financial_cards c
         where c.id = p_resource_id and c.user_id = auth.uid() for update;
        if v_source_revision is distinct from v_secret.source_secret_revision then
            raise exception using errcode = '42501', message = 'RESOURCE_SECRET_SOURCE_CHANGED';
        end if;
        if exists (select 1 from public.financial_cards c where c.id = p_resource_id
            and ((nullif(c.login, '') is not null and not v_secret.encrypted_fields ? 'login')
              or (nullif(c.password, '') is not null and not v_secret.encrypted_fields ? 'password')
              or (nullif(c.card_number, '') is not null and not v_secret.encrypted_fields ? 'card_number')
              or (nullif(c.expiry, '') is not null and not v_secret.encrypted_fields ? 'expiry'))) then
            raise exception using errcode = '23514', message = 'RESOURCE_SECRET_FIELDS_INCOMPLETE';
        end if;
        update public.financial_cards
           set login = null, password = null, card_number = null, expiry = null
         where id = p_resource_id and user_id = auth.uid();
    else
        select i.secret_revision, i.accounts_data into v_source_revision, v_accounts
          from public.institutions i
         where i.id = p_resource_id and i.user_id = auth.uid() for update;
        if v_source_revision is distinct from v_secret.source_secret_revision
           or jsonb_typeof(v_accounts) is distinct from 'array' then
            raise exception using errcode = '42501', message = 'RESOURCE_SECRET_SOURCE_CHANGED';
        end if;
        if exists (select 1 from public.institutions i where i.id = p_resource_id
            and ((nullif(i.login_url, '') is not null and not v_secret.encrypted_fields ? 'login_url')
              or (nullif(i.username, '') is not null and not v_secret.encrypted_fields ? 'username')
              or (nullif(i.email, '') is not null and not v_secret.encrypted_fields ? 'email')
              or (nullif(i.password, '') is not null and not v_secret.encrypted_fields ? 'password')
              or (nullif(i.two_factor, '') is not null and not v_secret.encrypted_fields ? 'two_factor')
              or (public.miloom_source_accounts_have_credentials(i.accounts_data)
                  and not v_secret.encrypted_fields ? 'accounts_data'))) then
            raise exception using errcode = '23514', message = 'RESOURCE_SECRET_FIELDS_INCOMPLETE';
        end if;
        select coalesce(jsonb_agg(
            account - 'accountNumber' - 'routingNumber' - 'wireRoutingNumber'
                    - 'account_number' - 'routing_number' - 'wire_routing_number'
            order by ordinal), '[]'::jsonb)
          into v_accounts
          from jsonb_array_elements(v_accounts) with ordinality as a(account, ordinal);
        update public.institutions
           set login_url = null, username = null, email = null,
               password = null, two_factor = null, accounts_data = v_accounts
         where id = p_resource_id and user_id = auth.uid();
    end if;

    update public.resource_secret_versions
       set state = 'active', activated_at = now()
     where resource_type = v_type and resource_id = p_resource_id
       and key_version = p_key_version and state = 'staging';
    if not found then
        raise exception using errcode = '42501', message = 'RESOURCE_SECRET_STAGE_CHANGED';
    end if;
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    ) values (
        auth.uid(), auth.uid(), v_type, p_resource_id, p_key_version, 'key_activated'
    );
    return jsonb_build_object('status', 'active', 'key_version', p_key_version);
end;
$$;
revoke all on function public.miloom_activate_staged_resource_secret(
    text, uuid, integer, bigint, jsonb, text, uuid, text
) from public, anon, authenticated;
comment on function public.miloom_activate_staged_resource_secret(
    text, uuid, integer, bigint, jsonb, text, uuid, text
) is 'Closed until a reviewed client-read/write and old-client rollout explicitly grants execution.';

notify pgrst, 'reload schema';
commit;
