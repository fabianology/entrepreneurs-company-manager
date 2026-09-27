-- Real authenticated table updates, not merely helper calls. Old UPDATE policy
-- from 006 is reproduced here because the lightweight fixture begins at 009.
begin;
select set_config('miloom.review_mode', :'review_mode', true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
alter table public.company_documents enable row level security;
grant select, insert, update on public.company_documents to authenticated;
create policy review_document_read on public.company_documents for select to authenticated
using (public.miloom_can_read_resource('document', id, company_id, user_id));
create policy miloom_document_editor_update on public.company_documents for update to authenticated
using (public.miloom_can_edit_resource('document', id, company_id, user_id))
with check (public.miloom_can_edit_resource('document', id, company_id, user_id));
create policy miloom_document_editor_insert on public.company_documents for insert to authenticated
with check (public.miloom_can_edit_resource('document', id, company_id, user_id));
insert into auth.users(id,email) values ('00000000-0000-0000-0000-000000000004','admin@example.com');
insert into public.companies values ('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','Other owner');
insert into public.company_documents(id,user_id,company_id,name,url)
select ('60000000-0000-0000-0000-' || lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Scope probe',
 case n when 10 then null when 11 then 'https://example.com/test.pdf'
 else '00000000-0000-0000-0000-000000000001/shared.pdf' end
from generate_series(10,12) n;
insert into public.resource_shares(resource_id,resource_type,user_id,role)
select id,'document','00000000-0000-0000-0000-000000000002','Editor'
from public.company_documents where name='Scope probe';
insert into public.resource_shares(resource_id,resource_type,user_id,role)
values ('10000000-0000-0000-0000-000000000001','company','00000000-0000-0000-0000-000000000004','Admin');
set local role authenticated;
do $$
declare d uuid; changed integer;
begin
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 if current_setting('miloom.review_mode') = 'vulnerable' then
   update public.company_documents set user_id=auth.uid() where id='60000000-0000-0000-0000-000000000010';
   get diagnostics changed = row_count;
   if changed <> 1 then raise exception 'Owner takeover did not reproduce'; end if;
   update public.company_documents set company_id='10000000-0000-0000-0000-000000000002' where id='60000000-0000-0000-0000-000000000012';
   get diagnostics changed = row_count;
   if changed <> 1 then raise exception 'Scope escape did not reproduce'; end if;
   raise notice 'REPRODUCED authenticated document takeover and Storage-linked entity escape';
   return;
 end if;
   for d in select id from public.company_documents where name like 'Scope probe%' loop
     begin
       update public.company_documents set user_id=auth.uid() where id=d;
       raise exception 'Exact Editor owner takeover accepted: %',d;
     exception when insufficient_privilege then null; end;
     begin
       update public.company_documents set company_id='10000000-0000-0000-0000-000000000002' where id=d;
       raise exception 'Exact Editor scope escape accepted: %',d;
     exception when insufficient_privilege then null; end;
     begin
       update public.company_documents set id=gen_random_uuid() where id=d;
       raise exception 'Identity change accepted';
     exception when insufficient_privilege then null; end;
     update public.company_documents set name='Scope probe edited' where id=d;
     get diagnostics changed=row_count;
     if changed<>1 then raise exception 'Authorized metadata edit failed'; end if;
   end loop;
end $$;
reset role;
delete from public.resource_shares where user_id='00000000-0000-0000-0000-000000000002' and resource_type='document';
insert into public.resource_shares(resource_id,resource_type,user_id,role)
values ('10000000-0000-0000-0000-000000000001','all_documents','00000000-0000-0000-0000-000000000002','Editor');
-- Repeat negatives for collection Editor and entity Admin (all three URL shapes).
set local role authenticated;
do $$
declare actor uuid; d uuid; changed integer;
begin
 if current_setting('miloom.review_mode')='vulnerable' then return; end if;
 foreach actor in array array['00000000-0000-0000-0000-000000000002'::uuid,'00000000-0000-0000-0000-000000000004'::uuid] loop
   perform set_config('request.jwt.claim.sub',actor::text,true);
   for d in select id from public.company_documents where name like 'Scope probe%' loop
     begin update public.company_documents set user_id=actor where id=d;
       raise exception 'Delegated owner takeover accepted'; exception when insufficient_privilege then null; end;
     begin update public.company_documents set company_id='10000000-0000-0000-0000-000000000002' where id=d;
       raise exception 'Delegated scope move accepted'; exception when insufficient_privilege then null; end;
     begin update public.company_documents set company_id=null where id=d;
       raise exception 'Delegated scope detachment accepted'; exception when insufficient_privilege then null; end;
     begin update public.company_documents set id=gen_random_uuid() where id=d;
       raise exception 'Delegated identity change accepted'; exception when insufficient_privilege then null; end;
     update public.company_documents set name='Scope probe edited' where id=d;
     get diagnostics changed=row_count;
     if changed<>1 then raise exception 'Delegated metadata edit failed'; end if;
   end loop;
 end loop;
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
 update public.company_documents set company_id='10000000-0000-0000-0000-000000000002'
 where name like 'Scope probe%';
 get diagnostics changed=row_count;
 if changed<>3 then raise exception 'Owner same-owner entity move failed'; end if;
 begin update public.company_documents set company_id='10000000-0000-0000-0000-000000000003' where name like 'Scope probe%';
   raise exception 'Owner cross-owner entity move accepted'; exception when insufficient_privilege then null; end;
 begin update public.company_documents set user_id='00000000-0000-0000-0000-000000000002' where name like 'Scope probe%';
   raise exception 'Ownership transfer accepted'; exception when insufficient_privilege then null; end;
 -- INSERT must not use the owner shortcut to attach a caller-owned row to
 -- someone else's entity; legitimate owner creation remains supported.
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
 begin
   insert into public.company_documents(id,user_id,company_id,name) values
     (gen_random_uuid(),auth.uid(),'10000000-0000-0000-0000-000000000001','Forged insert');
   raise exception 'Caller-owned foreign entity insert accepted';
 exception when insufficient_privilege then null; end;
 insert into public.company_documents(id,user_id,company_id,name) values
   (gen_random_uuid(),auth.uid(),'10000000-0000-0000-0000-000000000003','Authorized owner creation');
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
 update public.company_documents set name='Viewer mutation' where id='60000000-0000-0000-0000-000000000001';
 get diagnostics changed=row_count;
 if changed<>0 then raise exception 'Viewer metadata mutation accepted'; end if;
end $$;
rollback;
