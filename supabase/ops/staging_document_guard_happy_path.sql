-- Authorized positive workflow only, synthetic data, transaction always rolled back.
-- Execute only against approved Miloom Staging. No file bytes or email delivery.
begin;
create temporary table guard_fixture (owner_id uuid, editor_id uuid, entity_a uuid, entity_b uuid, document_id uuid);
insert into guard_fixture values (gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
insert into auth.users(id,email,raw_user_meta_data)
select owner_id,'document-guard-owner-' || owner_id || '@example.invalid',
 jsonb_build_object('fixture','document-guard-happy-path-20260927','test_only',true) from guard_fixture
union all
select editor_id,'document-guard-editor-' || editor_id || '@example.invalid',
 jsonb_build_object('fixture','document-guard-happy-path-20260927','test_only',true) from guard_fixture;
insert into public.companies(id,user_id,name,structure)
select entity_a,owner_id,'Document Guard Synthetic A','LLC' from guard_fixture
union all select entity_b,owner_id,'Document Guard Synthetic B','LLC' from guard_fixture;
grant select on guard_fixture to authenticated;
select set_config('request.jwt.claim.sub',(select owner_id::text from guard_fixture),true);
set local role authenticated;
insert into public.company_documents(id,user_id,company_id,name,type,visibility)
select document_id,owner_id,entity_a,'Document Guard Positive Workflow','Other','entity' from guard_fixture;
reset role;
insert into public.resource_shares(resource_id,resource_type,user_id,role)
select document_id,'document',editor_id,'Editor' from guard_fixture;
select set_config('request.jwt.claim.sub',(select editor_id::text from guard_fixture),true);
set local role authenticated;
do $$
declare affected integer;
begin
 update public.company_documents set name='Document Guard Editor Saved'
 where id=(select document_id from guard_fixture);
 get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Authorized Editor metadata save did not affect exactly one row'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',(select owner_id::text from guard_fixture),true);
set local role authenticated;
do $$
declare affected integer;
begin
 update public.company_documents set company_id=(select entity_b from guard_fixture)
 where id=(select document_id from guard_fixture);
 get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Authorized Owner move did not affect exactly one row'; end if;
end $$;
reset role;
do $$ begin
 if not exists (select 1 from public.company_documents d join guard_fixture f on d.id=f.document_id
   where d.user_id=f.owner_id and d.company_id=f.entity_b and d.name='Document Guard Editor Saved' and d.url is null) then
   raise exception 'Positive workflow invariant failed';
 end if;
end $$;
rollback;
select 'PASS: authorized owner create/move and exact Editor metadata save; synthetic transaction rolled back' as result;
