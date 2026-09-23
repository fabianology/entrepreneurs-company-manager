-- Run after source-revision assertions and migration 017 in a disposable DB.
-- The superuser simulates a future release-authorized owner call. No app role
-- is granted EXECUTE by migration 017.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_subscription uuid := '20000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_fields jsonb := jsonb_build_object('password',
        'miloom-resource:v1:1:' || replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', ''));
    v_revision bigint;
begin
    if has_function_privilege('authenticated',
       'public.miloom_activate_staged_resource_secret(text,uuid,integer,bigint,jsonb,text,uuid,text)',
       'EXECUTE') or has_function_privilege('anon',
       'public.miloom_activate_staged_resource_secret(text,uuid,integer,bigint,jsonb,text,uuid,text)',
       'EXECUTE') then
        raise exception 'App roles can activate secrets before client rollout';
    end if;
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);

    -- A source edit after staging is a hard stop, not a plaintext overwrite.
    select secret_revision into v_revision from public.financial_cards where id = v_card;
    update public.financial_cards set password = 'newest' where id = v_card;
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, v_revision, v_fields, v_wrap, v_device, v_confirmation
        );
        raise exception 'Stale card source was activated';
    exception when insufficient_privilege then null;
    end;
    if (select password from public.financial_cards where id = v_card) <> 'newest' then
        raise exception 'Rejected activation damaged the source credential';
    end if;
    perform public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    select secret_revision into v_revision from public.financial_cards where id = v_card;
    begin
        perform public.miloom_activate_staged_resource_secret(
            'card', v_card, 1, v_revision, '{}'::jsonb, v_wrap, v_device, v_confirmation
        );
        raise exception 'Unverified ciphertext argument was accepted';
    exception when insufficient_privilege then null;
    end;
    if public.miloom_activate_staged_resource_secret(
        'card', v_card, 1, v_revision, v_fields, v_wrap, v_device, v_confirmation
    ) ->> 'status' <> 'active' then
        raise exception 'Verified card cutover failed';
    end if;
    if (select password from public.financial_cards where id = v_card) is not null
       or (select state from public.resource_secret_versions
           where resource_type = 'card' and resource_id = v_card) <> 'active' then
        raise exception 'Card source was not scrubbed atomically';
    end if;
    begin
        update public.financial_cards set password = 'legacy-write' where id = v_card;
        raise exception 'Legacy plaintext card write succeeded after cutover';
    exception when insufficient_privilege then null;
    end;
    update public.financial_cards set name = 'Safe Metadata' where id = v_card;
    if (select name from public.financial_cards where id = v_card) <> 'Safe Metadata' then
        raise exception 'Safe card metadata edit was blocked';
    end if;

    -- Incomplete bank ciphertext cannot erase account numbers. A complete
    -- staged copy preserves account metadata while scrubbing only secrets.
    v_fields := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap);
    perform public.miloom_stage_resource_secret(
        'institution', v_bank, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    select secret_revision into v_revision from public.institutions where id = v_bank;
    begin
        perform public.miloom_activate_staged_resource_secret(
            'institution', v_bank, 1, v_revision, v_fields, v_wrap, v_device, v_confirmation
        );
        raise exception 'Incomplete bank ciphertext erased an account number';
    exception when check_violation then null;
    end;
    if (select accounts_data -> 0 ->> 'accountNumber'
          from public.institutions where id = v_bank) <> '123' then
        raise exception 'Rejected bank activation damaged account data';
    end if;
    v_fields := jsonb_build_object('accounts_data', 'miloom-resource:v1:1:' || v_wrap);
    perform public.miloom_stage_resource_secret(
        'institution', v_bank, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    perform public.miloom_activate_staged_resource_secret(
        'institution', v_bank, 1, v_revision, v_fields, v_wrap, v_device, v_confirmation
    );
    if (select accounts_data -> 0 ->> 'accountNumber'
          from public.institutions where id = v_bank) is not null
       or (select accounts_data -> 0 ->> 'id'
          from public.institutions where id = v_bank) <> 'account-1' then
        raise exception 'Bank cutover did not preserve safe account metadata';
    end if;
    begin
        update public.institutions
           set accounts_data = '[{"id":"account-1","routingNumber":"021000021"}]'::jsonb
         where id = v_bank;
        raise exception 'Legacy bank-number write succeeded after cutover';
    exception when insufficient_privilege then null;
    end;

    v_fields := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap);
    perform public.miloom_stage_resource_secret(
        'subscription', v_subscription, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    select secret_revision into v_revision from public.subscriptions where id = v_subscription;
    perform public.miloom_activate_staged_resource_secret(
        'subscription', v_subscription, 1, v_revision, v_fields, v_wrap,
        v_device, v_confirmation
    );
    if (select password from public.subscriptions where id = v_subscription) is not null
       or (select two_factor_auth from public.subscriptions where id = v_subscription) <> 'None' then
        raise exception 'Subscription cutover failed';
    end if;
    if (select count(*) from public.resource_secret_audit_events
         where event_type = 'key_activated' and owner_user_id = v_owner) <> 3 then
        raise exception 'Cutover audit events missing';
    end if;
end;
$$;
