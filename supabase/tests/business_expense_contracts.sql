-- Run against a disposable database with the feature migration applied.
begin;
insert into auth.users(id) values('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002');
insert into public.companies(id,user_id,name,structure) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Yager Aviation','LLC'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Other owner','LLC');
insert into public.plaid_items(id,user_id,company_id) values('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',null);
insert into public.plaid_transactions(id,user_id,plaid_item_id,plaid_transaction_id,account_id,amount,currency,date,merchant_name) values
('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','adobe-source','personal-chase',100,'USD','2026-09-01','Adobe');
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$ declare rid uuid; first_revision integer; exported jsonb; a jsonb:=jsonb_build_object('company_id','20000000-0000-0000-0000-000000000001','business_basis_points',6000,'purpose','Client design','category','Software','receipt_exception','Vendor receipt unavailable'); begin
 rid:=public.save_business_expense('40000000-0000-0000-0000-000000000001',null,1,'50000000-0000-0000-0000-000000000001','confirmed',a,false);
 if (select amount<>100 or account_id<>'personal-chase' or company_id is not null from public.plaid_transactions where id='40000000-0000-0000-0000-000000000001') then raise exception 'Financial source mutated'; end if;
 if jsonb_array_length(public.get_business_expense_reviews()->0->'missing')<>0 then raise exception 'Receipt exception did not satisfy readiness'; end if;
 perform public.save_business_expense('40000000-0000-0000-0000-000000000001',rid,1,'50000000-0000-0000-0000-000000000001','confirmed',a,false);
 if (select revision from public.business_expense_reviews where id=rid)<>2 then raise exception 'Retry duplicated mutation'; end if;
 begin
   perform public.save_business_expense(null,rid,1,gen_random_uuid(),'confirmed',a,false);
   raise exception 'Expected stale revision rejection';
 exception when raise_exception then if sqlerrm<>'EXPENSE_REVISION_CONFLICT' then raise; end if; end;
 begin
   perform public.save_business_expense(null,rid,2,gen_random_uuid(),'confirmed',jsonb_set(a,'{company_id}','"20000000-0000-0000-0000-000000000002"'),false);
   raise exception 'Expected cross-owner Entity rejection';
 exception when raise_exception then if sqlerrm<>'Entity not owned' then raise; end if; end;
 exported:=public.prepare_business_expense_export('20000000-0000-0000-0000-000000000001','2026-01-01','2026-12-31',false,'60000000-0000-0000-0000-000000000001');
 if exported->'items'->0->'allocation'->>'business_basis_points'<>'6000' then raise exception 'Incorrect export allocation'; end if;
 perform public.save_business_expense(null,rid,2,gen_random_uuid(),'confirmed',jsonb_set(a,'{purpose}','"Changed purpose"'),false);
 if (select items->0->'allocation'->>'purpose' from public.business_expense_exports where id=(exported->>'id')::uuid)<>'Client design' then raise exception 'Export snapshot mutated'; end if;
 begin
   insert into public.business_expense_reviews(user_id,source_snapshot) values('10000000-0000-0000-0000-000000000001','{}');
   raise exception 'Direct client insert allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.plaid_transactions set amount=120 where id='40000000-0000-0000-0000-000000000001';
do $$ begin
 if (select source_state from public.business_expense_reviews where transaction_id='40000000-0000-0000-0000-000000000001')<>'changed' then raise exception 'Source change not detected'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$ begin
 if jsonb_array_length(public.get_business_expense_reviews())<>0 then raise exception 'Cross-owner review leak'; end if;
 if exists(select 1 from public.business_expense_exports) then raise exception 'Cross-owner export leak'; end if;
 begin
   perform public.save_business_expense('40000000-0000-0000-0000-000000000001',null,1,gen_random_uuid(),'personal',null,false);
   raise exception 'Cross-owner transaction accepted';
 exception when raise_exception then if sqlerrm<>'EXPENSE_SOURCE_NOT_FOUND' then raise; end if; end;
end $$;
reset role;
insert into public.company_documents(id,user_id,company_id,name,type,url,visibility) values('70000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Private receipt','Receipts','owner/receipt.pdf','owner_private');
set local role authenticated;
do $$ begin
 if exists(select 1 from public.company_documents where id='70000000-0000-0000-0000-000000000001') then raise exception 'Permissive policy leaked private receipt'; end if;
end $$;
reset role;
update public.business_expense_reviews set source_state='active';
delete from public.plaid_items where id='30000000-0000-0000-0000-000000000001';
do $$ begin
 if not exists(select 1 from public.business_expense_reviews where source_state='disconnected' and transaction_id is null and source_snapshot->>'merchant'='Adobe') then raise exception 'Bank removal lost reviewed snapshot'; end if;
end $$;
rollback;

-- Durable source identity, stale-model protection and owner decision precedence.
begin;
insert into auth.users(id) values('11000000-0000-0000-0000-000000000001');
insert into public.companies(id,user_id,name,structure) values('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','Design','LLC');
insert into public.business_expense_settings(user_id,enabled,revision) values('11000000-0000-0000-0000-000000000001',true,1);
insert into public.business_expense_profiles(company_id,user_id,activity) values('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','Design');
insert into public.plaid_transactions(id,user_id,plaid_transaction_id,account_id,amount,currency,date,merchant_name) values
('41000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','old-source','personal',100,'USD','2026-09-01','Adobe'),
('41000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000001','new-source','personal-reconnected',100,'USD','2026-09-01','Adobe');
select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000001',true);
select public.save_business_expense('41000000-0000-0000-0000-000000000001',null,1,'51000000-0000-0000-0000-000000000001','personal',null,false);
update public.plaid_transactions set is_superseded_duplicate=true,superseded_by_transaction_id='41000000-0000-0000-0000-000000000002' where id='41000000-0000-0000-0000-000000000001';
do $$ declare rid uuid; jid uuid; lease jsonb; result jsonb; begin
 rid:=public.ensure_business_expense_review('11000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000002');
 if(select count(*) from public.business_expense_reviews)<>1 then raise exception 'Reconnection duplicated review'; end if;
 delete from public.plaid_transactions where id='41000000-0000-0000-0000-000000000001';
 if(select source_state from public.business_expense_reviews where id=rid)<>'active' then raise exception 'Deleting historical alias invalidated current source'; end if;
 if(select decision from public.business_expense_reviews where id=rid)<>'personal' then raise exception 'Reconnection erased dismissal'; end if;
 insert into public.business_expense_jobs(user_id,date_from,date_to,consent_revision) values('11000000-0000-0000-0000-000000000001','2026-01-01','2026-09-07',1) returning id into jid;
 lease:=public.claim_business_expense_job(jid);
 result:=jsonb_build_array(jsonb_build_object('transaction_id','41000000-0000-0000-0000-000000000002','input_version',public.business_expense_input_version('41000000-0000-0000-0000-000000000002'),'fingerprint','test','model','test','candidates',jsonb_build_array(jsonb_build_object('company_id','21000000-0000-0000-0000-000000000001','score',0.9,'confidence','worth_reviewing','explanation','Review','evidence_ids','[]'::jsonb))));
 perform public.commit_business_expense_batch(jid,(lease->>'lease_token')::uuid,result,'2026-09-01','41000000-0000-0000-0000-000000000002',1,true);
 if exists(select 1 from public.business_expense_suggestions) then raise exception 'AI overwrote personal decision'; end if;
 update public.business_expense_jobs set state='queued' where id=jid;
 lease:=public.claim_business_expense_job(jid);
 update public.business_expense_settings set enabled=false,revision=2;
 begin
   perform public.commit_business_expense_batch(jid,(lease->>'lease_token')::uuid,result,'2026-09-01','41000000-0000-0000-0000-000000000002',1,true);
   raise exception 'Revoked consent accepted stale AI result';
 exception when raise_exception then if sqlerrm<>'EXPENSE_STALE_JOB' then raise; end if; end;
end $$;
rollback;

-- Exclusions survive verified account ID replacement.
begin;
insert into auth.users(id) values('12000000-0000-0000-0000-000000000001');
insert into public.business_expense_settings(user_id,enabled,excluded_account_ids) values('12000000-0000-0000-0000-000000000001',true,array['persistent:stable-account']);
insert into public.plaid_accounts(id,user_id,account_id,canonical_account_id,persistent_account_id) values
('32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','new-plaid-account-id','new-plaid-account-id','stable-account');
do $$ begin
 if not public.business_expense_account_excluded('12000000-0000-0000-0000-000000000001','new-plaid-account-id','new-plaid-account-id') then raise exception 'Reconnect lost exclusion'; end if;
 if public.business_expense_account_excluded('12000000-0000-0000-0000-000000000001','different-account','different-account') then raise exception 'Exclusion affected unrelated account'; end if;
end $$;
rollback;
