-- Normal permission contract, synthetic transactional fixture. Works locally or
-- on explicitly authorized Staging. No emails, permanent users, or file bytes.
begin;
create temporary table verified_invite_fixture(owner_id uuid, recipient_id uuid, entity_id uuid, by_id uuid, by_token uuid, decline_id uuid, token text);
insert into verified_invite_fixture values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),repeat('a',64));
insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data)
select owner_id,'verify-guard-owner-'||owner_id||'@example.invalid',now(),false,
 jsonb_build_object('fixture','verified-invitation-20260927','test_only',true) from verified_invite_fixture
union all
select recipient_id,'verify-guard-recipient-'||recipient_id||'@example.invalid',null,false,
 jsonb_build_object('fixture','verified-invitation-20260927','test_only',true) from verified_invite_fixture;
insert into public.companies(id,user_id,name,structure)
select entity_id,owner_id,'Verified Invitation Synthetic Entity','LLC' from verified_invite_fixture;
insert into public.resource_invitations(id,resource_id,resource_type,email,role,invited_by,status,token_hash)
select i,entity_id,case when i=by_id then 'company' when i=by_token then 'all_documents' else 'all_subscriptions' end,
 'verify-guard-recipient-'||recipient_id||'@example.invalid','Viewer',owner_id,'Pending',
 case when i=by_token then extensions.digest(token,'sha256')
      when i=decline_id then extensions.digest(repeat('b',64),'sha256') else null end
from verified_invite_fixture cross join lateral unnest(array[by_id,by_token,decline_id]) i;
grant select on verified_invite_fixture to authenticated;
select set_config('request.jwt.claim.sub',(select recipient_id::text from verified_invite_fixture),true);
set local role authenticated;
do $$ begin
 begin
   perform public.miloom_accept_invitation((select by_id from verified_invite_fixture));
   raise exception 'Unverified account accepted by ID';
 exception when insufficient_privilege then
   if sqlerrm<>'INVITATION_EMAIL_VERIFICATION_REQUIRED' then raise; end if;
 end;
 begin
   perform public.miloom_accept_invitation_token((select token from verified_invite_fixture));
   raise exception 'Unverified account accepted by token';
 exception when insufficient_privilege then
   if sqlerrm<>'INVITATION_EMAIL_VERIFICATION_REQUIRED' then raise; end if;
 end;
 perform public.miloom_decline_invitation((select decline_id from verified_invite_fixture));
end $$;
reset role;
do $$ begin
 if exists(select 1 from public.resource_shares r join verified_invite_fixture f on r.user_id=f.recipient_id and r.resource_id=f.entity_id)
 or (select count(*) from public.resource_invitations r join verified_invite_fixture f on r.id in(f.by_id,f.by_token) where r.status='Pending')<>2 then
   raise exception 'Verification-required response changed pending access';
 end if;
 if not exists(select 1 from public.resource_invitations r join verified_invite_fixture f on r.id=f.decline_id
   where r.status='Declined' and r.token_hash is null and r.declined_at is not null) then
   raise exception 'Decline did not finish or clear its token';
 end if;
end $$;
-- Model normal Auth verification, then confirm both public acceptance routes.
update auth.users set email_confirmed_at=now(), is_anonymous=true where id=(select recipient_id from verified_invite_fixture);
set local role authenticated;
do $$ begin
 begin
   perform public.miloom_accept_invitation((select by_id from verified_invite_fixture));
   raise exception 'Anonymous account accepted invitation';
 exception when insufficient_privilege then
   if sqlerrm<>'INVITATION_EMAIL_VERIFICATION_REQUIRED' then raise; end if;
 end;
end $$;
reset role;
update auth.users set is_anonymous=false where id=(select recipient_id from verified_invite_fixture);
set local role authenticated;
do $$ begin
 if public.miloom_accept_invitation((select by_id from verified_invite_fixture))->>'status'<>'accepted'
 or public.miloom_accept_invitation_token((select token from verified_invite_fixture))->>'status'<>'accepted' then
   raise exception 'Verified recipient acceptance failed';
 end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.resource_shares r join verified_invite_fixture f on r.user_id=f.recipient_id and r.resource_id=f.entity_id where r.role='Viewer')<>2
 or (select count(*) from public.resource_invitations r join verified_invite_fixture f on r.id in(f.by_id,f.by_token) where r.status='Accepted' and r.token_hash is null)<>2 then
   raise exception 'Verified acceptance receipt failed';
 end if;
 if has_function_privilege('authenticated','public.miloom_act_on_invitation(uuid,text,boolean)','execute')
 or has_function_privilege('anon','public.miloom_accept_invitation(uuid)','execute') then
   raise exception 'Invitation wrapper privilege boundary changed';
 end if;
end $$;
rollback;
select 'PASS: verification required without granting access; verified ID/token acceptance and decline passed; rolled back' as result;
