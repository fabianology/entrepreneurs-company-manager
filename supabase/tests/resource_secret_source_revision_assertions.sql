-- Run in a disposable database after delegated_scope_fixture.sql, 009-011,
-- resource_secret_foundation_fixture.sql, and migrations 012-016.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_subscription uuid := '20000000-0000-0000-0000-000000000001';
    v_device uuid := '70000000-0000-0000-0000-000000000003';
    v_wrap text := replace(encode(convert_to(repeat('x', 60), 'utf8'), 'base64'), E'\n', '');
    v_confirmation text := encode(convert_to(repeat('k', 32), 'utf8'), 'base64');
    v_fields jsonb;
begin
    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    perform set_config('request.jwt.claim.session_id',
        '80000000-0000-0000-0000-000000000001', true);
    perform set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);

    update public.financial_cards set password = 'first' where id = v_card;
    if (select secret_revision from public.financial_cards where id = v_card) <> 1 then
        raise exception 'Card credential change did not advance revision';
    end if;
    v_fields := jsonb_build_object('password', 'miloom-resource:v1:1:' || v_wrap);
    perform public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    if (select source_secret_revision from public.resource_secret_versions
         where resource_type = 'card' and resource_id = v_card) <> 1 then
        raise exception 'Staging did not capture the current source revision';
    end if;

    update public.financial_cards set name = 'Renamed Card', secret_revision = 99
     where id = v_card;
    if (select secret_revision from public.financial_cards where id = v_card) <> 1 then
        raise exception 'Metadata edit or client revision value changed the credential revision';
    end if;
    update public.financial_cards set password = 'second' where id = v_card;
    if (select secret_revision from public.financial_cards where id = v_card) <> 2
       or (select source_secret_revision from public.resource_secret_versions
            where resource_type = 'card' and resource_id = v_card) <> 1 then
        raise exception 'An edited source still looked current to the staged copy';
    end if;
    if (select source_secret_revision = current_secret_revision
          from public.miloom_get_owner_resource_secret(
              'card', v_card, v_device, v_confirmation
          )) then
        raise exception 'Owner readback failed to flag stale ciphertext';
    end if;
    perform public.miloom_stage_resource_secret(
        'card', v_card, 1, 1, v_wrap, v_fields, v_device, v_confirmation
    );
    if not (select source_secret_revision = current_secret_revision
              from public.miloom_get_owner_resource_secret(
                  'card', v_card, v_device, v_confirmation
              )) then
        raise exception 'Restaging did not capture the new source revision';
    end if;

    update public.institutions
       set accounts_data = '[{"id":"account-1","accountNumber":"123"}]'::jsonb
     where id = v_bank;
    if (select secret_revision from public.institutions where id = v_bank) <> 1 then
        raise exception 'Bank account-number change did not advance revision';
    end if;
    update public.subscriptions set password = 'changed' where id = v_subscription;
    if (select secret_revision from public.subscriptions where id = v_subscription) <> 1 then
        raise exception 'Subscription credential change did not advance revision';
    end if;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    begin
        perform public.miloom_get_owner_resource_secret(
            'card', v_card, v_device, v_confirmation
        );
        raise exception 'Collaborator read owner credential revision metadata';
    exception when insufficient_privilege then null;
    end;
end;
$$;
