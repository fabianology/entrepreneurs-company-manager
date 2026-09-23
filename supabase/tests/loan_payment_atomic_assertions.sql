-- Disposable local database only, after 009–031 + loan fixture. Never production.
begin;
create function pg_temp.assert_true(p_value boolean, p_message text)
returns void language plpgsql as $$ begin
    if p_value is distinct from true then raise exception '%', p_message; end if;
end $$;
create function pg_temp.expect_error(p_sql text, p_state text)
returns void language plpgsql as $$ begin
    execute p_sql;
    raise exception 'Expected SQLSTATE %, statement succeeded', p_state;
exception when others then
    if sqlstate <> p_state then raise; end if;
end $$;

insert into public.loans(id,user_id,company_id,name) values
    ('50000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',
     '10000000-0000-0000-0000-000000000001','Sibling');
insert into public.resource_shares(resource_id,resource_type,user_id,role) values
    ('50000000-0000-0000-0000-000000000001','loan','00000000-0000-0000-0000-000000000002','Editor'),
    ('10000000-0000-0000-0000-000000000001','company','00000000-0000-0000-0000-000000000002','Viewer'),
    ('10000000-0000-0000-0000-000000000001','company','00000000-0000-0000-0000-000000000003','Viewer');

do $$
declare
    v_loan jsonb; v_receipt jsonb; v_payments jsonb; v_revision bigint; v_before jsonb;
    v_id uuid := '50000000-0000-0000-0000-000000000001';
begin
    perform pg_temp.assert_true(not has_function_privilege('anon',
        'public.miloom_save_loan(jsonb,jsonb,bigint)', 'EXECUTE'), 'Anonymous save privilege');
    perform pg_temp.assert_true(not has_function_privilege('authenticated',
        'public.miloom_loan_actor_allowed(uuid,uuid,uuid,boolean)', 'EXECUTE'), 'Internal helper exposed');
    select to_jsonb(l) into v_loan from public.loans l where id = v_id;
    v_payments := jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),
        'user_id',v_loan->>'user_id','loan_id',v_id,'date','2026-09-22T12:00:00Z',
        'amount',25,'source','Synthetic'));
    perform set_config('request.jwt.claim.sub','','true');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,0)',v_loan,v_payments),'42501');
    perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,0)',v_loan,v_payments),'42501');
    perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
    v_loan := v_loan || '{"name":"Editor saved","remaining_balance":975}';
    v_receipt := public.miloom_save_loan(v_loan,v_payments,0);
    v_revision := (v_receipt->'loan'->>'revision')::bigint;
    perform pg_temp.assert_true(v_revision > 0 and jsonb_array_length(v_receipt->'payments') = 1,
        'Missing authoritative save receipt');
    perform pg_temp.assert_true((select name = 'Editor saved' and remaining_balance = 975
        from public.loans where id = v_id), 'Loan metadata not saved');
    perform pg_temp.assert_true((select jsonb_array_length(payments) = 1
        from public.miloom_read_loans() where loan->>'id' = v_id::text), 'Editor cannot reload ledger');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,0)',v_loan,v_payments),'PT409');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,null)',v_loan,v_payments),'PT409');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan || '{"user_id":"00000000-0000-0000-0000-000000000002"}',v_payments,v_revision),'42501');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan || '{"company_id":"10000000-0000-0000-0000-000000000002"}',v_payments,v_revision),'42501');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan || '{"plaid_account_id":"spoof"}',v_payments,v_revision),'42501');
    v_before := v_receipt;
    v_loan := v_loan || '{"name":"Must roll back"}';
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,jsonb_set(v_payments,'{0,amount}','-1'),v_revision),'22023');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,jsonb_set(v_payments,'{0,amount}','"NaN"'),v_revision),'22023');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,jsonb_set(v_payments,'{0,loan_id}','"50000000-0000-0000-0000-000000000002"'),v_revision),'22023');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,jsonb_set(v_payments,'{0,user_id}','"00000000-0000-0000-0000-000000000002"'),v_revision),'22023');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,v_payments || v_payments,v_revision),'22023');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,null,%s)',v_loan,v_revision),'22023');
    perform pg_temp.assert_true((select jsonb_build_object('loan',loan,'payments',payments) = v_before
        from public.miloom_read_loans() where loan->>'id' = v_id::text), 'Failed save partially wrote');
    -- Force a late failure AFTER metadata update and ledger deletion. The
    -- enclosing RPC transaction must restore both, not just prevalidate.
    execute $trigger$create function pg_temp.reject_test_payment() returns trigger language plpgsql as $fn$
        begin raise exception using errcode='23514', message='Synthetic late insert failure'; end $fn$ $trigger$;
    execute 'create trigger synthetic_payment_failure before insert on public.loan_payments
        for each row execute function pg_temp.reject_test_payment()';
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',
        v_loan,v_payments,v_revision),'23514');
    execute 'drop trigger synthetic_payment_failure on public.loan_payments';
    perform pg_temp.assert_true((select jsonb_build_object('loan',loan,'payments',payments) = v_before
        from public.miloom_read_loans() where loan->>'id' = v_id::text), 'Late failure partially wrote');
    -- Legacy owner writes advance the token so an older client cannot cause silent lost history.
    perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
    insert into public.loan_payments(user_id,loan_id,amount) values
        ('00000000-0000-0000-0000-000000000001',v_id,10);
    perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',v_loan,v_payments,v_revision),'PT409');
    select revision into v_revision from public.loans where id = v_id;
    v_receipt := public.miloom_save_loan(v_before->'loan','[]',v_revision);
    perform pg_temp.assert_true(v_receipt->'payments' = '[]', 'Ledger removal failed');
    v_revision := (v_receipt->'loan'->>'revision')::bigint;
    delete from public.resource_shares where resource_type='loan';
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',v_loan,v_payments,v_revision),'42501');
    insert into public.resource_shares(resource_id,resource_type,user_id,role) values
        ('10000000-0000-0000-0000-000000000001','all_institutions','00000000-0000-0000-0000-000000000002','Editor');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',v_loan,v_payments,v_revision),'42501');
    update public.resource_shares set resource_type='all_financials' where resource_type='all_institutions';
    v_receipt := public.miloom_save_loan(v_before->'loan',v_payments,v_revision);
    v_revision := (v_receipt->'loan'->>'revision')::bigint;
    update public.resource_shares set suspended_at=now() where resource_type='all_financials';
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',v_loan,v_payments,v_revision),'42501');
    update public.resource_shares set suspended_at=null where resource_type='all_financials';
    insert into public.resource_access_blocks(owner_user_id,blocked_email,blocked_user_id) values
        ('00000000-0000-0000-0000-000000000001','EDITOR@example.com',null);
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,%s)',v_loan,v_payments,v_revision),'42501');
    perform pg_temp.assert_true((select count(*) = 0 from public.miloom_read_loans()), 'Blocked user reads loans');
    delete from public.resource_access_blocks;
    delete from public.resource_shares where resource_type='all_financials';
    update public.resource_shares set role='Admin' where resource_type='company'
        and user_id='00000000-0000-0000-0000-000000000002';
    perform public.miloom_save_loan(v_before->'loan',v_payments,v_revision);
    -- Creating through company authority binds ownership to the actual company.
    v_loan := v_before->'loan' || '{"id":"50000000-0000-0000-0000-000000000010"}';
    v_receipt := public.miloom_save_loan(v_loan,'[]',null);
    perform pg_temp.assert_true(v_receipt->'loan'->>'user_id'='00000000-0000-0000-0000-000000000001',
        'Admin created a loan with the wrong owner');
    perform pg_temp.expect_error(format('select public.miloom_save_loan(%L,%L,null)',
        v_loan || '{"id":"50000000-0000-0000-0000-000000000011","user_id":"00000000-0000-0000-0000-000000000002"}',
        '[]'::jsonb),'42501');
end $$;

-- Use the real authenticated SQL role, not a superuser, to exercise RLS.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
select pg_temp.assert_true((select count(*)=1 from public.loan_payments), 'Viewer cannot read shared ledger');
select pg_temp.expect_error($sql$insert into public.loan_payments(user_id,loan_id,amount)
    values ('00000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000001',1)$sql$,'42501');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select pg_temp.expect_error($sql$insert into public.loan_payments(user_id,loan_id,amount)
    values ('00000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',1)$sql$,'42501');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
insert into public.loan_payments(user_id,loan_id,amount)
    values ('00000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',1);
reset role;
select pg_temp.assert_true((select count(*)=2 from public.loan_payments), 'Legacy owner insert lost');
delete from public.loans where id='50000000-0000-0000-0000-000000000001';
select pg_temp.assert_true((select count(*)=0 from public.loan_payments), 'Parent delete did not cascade');
rollback;
