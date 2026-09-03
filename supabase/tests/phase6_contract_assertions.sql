do $$
declare
    v_table text;
    v_trigger_count integer;
begin
    foreach v_table in array array[
        'user_entitlements', 'usage_buckets', 'resource_connections',
        'obligations', 'device_push_tokens', 'product_events',
        'briefing_deliveries', 'critical_alert_deliveries'
    ] loop
        if to_regclass('public.' || v_table) is null then
            raise exception 'missing Phase 6 table: %', v_table;
        end if;
    end loop;

    select count(*) into v_trigger_count
      from pg_trigger
     where not tgisinternal and tgname like 'enforce_miloom_%';
    if v_trigger_count <> 0 then
        raise exception 'monetization enforcement triggers are active';
    end if;

    if has_function_privilege('anon', 'public.get_miloom_access_snapshot()', 'EXECUTE') then
        raise exception 'anon can execute access snapshot';
    end if;
    if not has_function_privilege('authenticated', 'public.get_miloom_access_snapshot()', 'EXECUTE') then
        raise exception 'authenticated cannot execute access snapshot';
    end if;
    if has_function_privilege('authenticated', 'public.refresh_miloom_obligations(uuid)', 'EXECUTE') then
        raise exception 'authenticated can execute service refresh';
    end if;
    if not has_function_privilege('service_role', 'public.refresh_miloom_obligations(uuid)', 'EXECUTE') then
        raise exception 'service role cannot execute service refresh';
    end if;
    if has_table_privilege('authenticated', 'public.briefing_deliveries', 'SELECT') then
        raise exception 'authenticated can read briefing delivery claims';
    end if;
    if (select count(*) from pg_policies where schemaname = 'public' and tablename = 'companies' and cmd = 'SELECT') <> 1 then
        raise exception 'company read policies were not consolidated';
    end if;
end;
$$;

insert into auth.users(id) values
    ('00000000-0000-0000-0000-000000000001'),
    ('00000000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);

do $$
begin
    begin
        perform public.get_miloom_access_snapshot();
        raise exception 'uninitialized entitlement did not preserve StoreKit fallback';
    exception
        when sqlstate 'P0001' then
            if sqlerrm <> 'MILOOM_ENTITLEMENT_NOT_INITIALIZED' then raise; end if;
    end;
end;
$$;

insert into public.user_entitlements(user_id)
values ('00000000-0000-0000-0000-000000000001');

do $$
declare v_snapshot jsonb;
begin
    v_snapshot := public.get_miloom_access_snapshot();
    if v_snapshot->>'tier' <> 'free' then
        raise exception 'initialized free entitlement returned the wrong tier';
    end if;
end;
$$;

insert into public.companies(id, user_id) values
    ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
    ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002');
insert into public.plaid_items(id, user_id, status, access_token) values
    ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'active', 'preserve-me'),
    ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'active', 'preserve-me-too');
insert into public.resource_shares(id, resource_id, resource_type, user_id) values
    ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'company', '00000000-0000-0000-0000-000000000002');

select public.maintain_miloom_downgrades();

do $$
begin
    if (select count(*) from public.plaid_items where status = 'active' and access_token like 'preserve-me%') <> 2 then
        raise exception 'downgrade maintenance modified Plaid Items';
    end if;
    if (select suspended_at from public.resource_shares where id = '30000000-0000-0000-0000-000000000001') is not null then
        raise exception 'downgrade maintenance suspended a share';
    end if;
end;
$$;

set role authenticated;
do $$
begin
    if (select count(*) from public.user_entitlements) <> 1 then
        raise exception 'entitlement RLS did not isolate the current owner';
    end if;
    begin
        insert into public.briefing_deliveries(user_id, local_date)
        values ('00000000-0000-0000-0000-000000000001', current_date);
        raise exception 'authenticated role wrote a server-only delivery claim';
    exception when insufficient_privilege then null;
    end;

    perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
    if (select count(*) from public.companies) <> 2 then
        raise exception 'owner/shared company read access was not preserved';
    end if;
end;
$$;
reset role;
