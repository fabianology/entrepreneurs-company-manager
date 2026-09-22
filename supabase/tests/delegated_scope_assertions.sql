-- Run after delegated_scope_fixture.sql, migration 009, and migration 010.
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000002';
    v_company_a uuid := '10000000-0000-0000-0000-000000000001';
    v_bank_a uuid := '30000000-0000-0000-0000-000000000001';
    v_bank_b uuid := '30000000-0000-0000-0000-000000000002';
    v_card uuid := '40000000-0000-0000-0000-000000000001';
    v_loan uuid := '50000000-0000-0000-0000-000000000001';
    v_document uuid := '60000000-0000-0000-0000-000000000001';
    v_service uuid := '20000000-0000-0000-0000-000000000001';
begin
    if public.miloom_resource_owner('all_institutions', v_company_a) <> v_owner
       or public.miloom_resource_company('all_institutions', v_company_a) <> v_company_a
       or public.miloom_resource_title('all_institutions', v_company_a) <> 'All Institutions' then
        raise exception 'institution collection was not mapped to its entity';
    end if;

    perform set_config('request.jwt.claim.sub', v_owner::text, true);
    if public.miloom_share_resource('editor@example.com', 'Editor', v_company_a,
        'all_institutions') ->> 'status' <> 'shared_directly' then
        raise exception 'owner could not grant all institutions';
    end if;
    begin
        perform public.miloom_share_resource('viewer@example.com', 'Admin', v_bank_a, 'institution');
        raise exception 'Admin granted on a single bank';
    exception when invalid_parameter_value then null;
    end;

    perform set_config('request.jwt.claim.sub', v_editor::text, true);
    insert into public.resource_invitations (
        resource_id, resource_type, email, role, invited_by, status
    ) values (
        '10000000-0000-0000-0000-000000000002', 'company',
        'editor@example.com', 'Editor', v_owner, 'Pending'
    );
    if public.miloom_can_read_company('10000000-0000-0000-0000-000000000002', v_owner) then
        raise exception 'pending invitation incorrectly exposed company';
    end if;
    delete from public.resource_invitations
     where email = 'editor@example.com' and resource_id = '10000000-0000-0000-0000-000000000002';
    if not public.miloom_can_read_resource('institution', v_bank_a, v_company_a, v_owner)
       or not public.miloom_can_edit_resource('institution', v_bank_a, v_company_a, v_owner)
       or not public.miloom_can_read_company(v_company_a, v_owner) then
        raise exception 'all-institutions Editor cannot use bank in the granted entity';
    end if;
    if public.miloom_can_read_company('10000000-0000-0000-0000-000000000002', v_owner) then
        raise exception 'all-institutions grant exposed another company';
    end if;
    if public.miloom_can_read_resource('institution', v_bank_b,
        '10000000-0000-0000-0000-000000000002', v_owner)
       or public.miloom_can_edit_resource('card', v_card, v_company_a, v_owner)
       or public.miloom_can_read_resource('card', v_card, v_company_a, v_owner)
       or public.miloom_can_read_resource('loan', v_loan, v_company_a, v_owner)
       or public.miloom_can_read_resource('document', v_document, v_company_a, v_owner)
       or public.miloom_can_read_resource('subscription', v_service, v_company_a, v_owner) then
        raise exception 'all-institutions grant escaped its exact scope';
    end if;

    delete from public.resource_shares where user_id = v_editor;
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_bank_a, 'institution', v_editor, 'Editor');
    if not public.miloom_can_edit_resource('institution', v_bank_a, v_company_a, v_owner)
       or public.miloom_can_read_resource('institution', v_bank_b,
            '10000000-0000-0000-0000-000000000002', v_owner) then
        raise exception 'single-bank scope is incorrect';
    end if;

    delete from public.resource_shares where user_id = v_editor;
    insert into public.resource_shares (resource_id, resource_type, user_id, role)
    values (v_company_a, 'all_financials', v_editor, 'Editor');
    if not public.miloom_can_read_resource('card', v_card, v_company_a, v_owner)
       or not public.miloom_can_read_resource('loan', v_loan, v_company_a, v_owner)
       or public.miloom_can_read_resource('document', v_document, v_company_a, v_owner) then
        raise exception 'all-financials scope changed unexpectedly';
    end if;
end;
$$;
