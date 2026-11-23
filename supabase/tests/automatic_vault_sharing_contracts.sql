-- Run in an isolated database with the delegated-scope and scoped-vault fixtures.
begin;

create temporary table vault_automatic_fixture (
    owner_id uuid, editor_id uuid, viewer_id uuid, owner_device uuid,
    viewer_device uuid, editor_device uuid, company_id uuid, other_company uuid,
    resource_id uuid, other_resource uuid, confirmation text, owner_wrap text,
    device_public text, next_ciphertext text, ciphertext jsonb
);
insert into vault_automatic_fixture
select '00000000-0000-0000-0000-000000000001',
       '00000000-0000-0000-0000-000000000002',
       '00000000-0000-0000-0000-000000000003',
       '70000000-0000-0000-0000-000000000003',
       '70000000-0000-0000-0000-000000000002',
       '70000000-0000-0000-0000-000000000001',
       '10000000-0000-0000-0000-000000000001',
       '10000000-0000-0000-0000-000000000002',
       '42000000-0000-0000-0000-000000000001',
       '42000000-0000-0000-0000-000000000002',
       encode(convert_to(repeat('k', 32), 'utf8'), 'base64'),
       replace(encode(decode(repeat('31',60),'hex'),'base64'), chr(10),''),
       replace(encode(decode('04'||repeat('22',64),'hex'),'base64'), chr(10),''),
       'miloom-resource:v1:1:' || encode(decode(repeat('21',32),'hex'),'base64'),
       jsonb_build_object('password', 'miloom-resource:v1:1:' || encode(decode(repeat('20',32),'hex'),'base64'));
grant select on vault_automatic_fixture to authenticated;
grant update, insert on public.financial_cards to authenticated;

update auth.users set email_confirmed_at = now()
 where id in (select viewer_id from vault_automatic_fixture union select editor_id from vault_automatic_fixture);
update public.financial_cards set password = 'older stored value'
 where id = '40000000-0000-0000-0000-000000000001';
update public.vault_devices set status = 'approved',
    auth_session_id = '80000000-0000-0000-0000-000000000003'
 where id = (select viewer_device from vault_automatic_fixture);
select set_config('request.jwt.claim.iat', extract(epoch from now())::bigint::text, true);
select set_config('request.jwt.claim.sub', (select owner_id::text from vault_automatic_fixture), true);
select set_config('request.jwt.claim.session_id', '80000000-0000-0000-0000-000000000001', true);
set local role authenticated;

do $$
declare
    f vault_automatic_fixture%rowtype;
    v_record jsonb;
begin
    select * into f from vault_automatic_fixture;
    v_record := jsonb_build_object('id',f.resource_id,'name','Protected card',
                                  'user_id',f.owner_id,'company_id',f.company_id);
    begin
        perform public.miloom_save_owned_protected_resource(
            'card',v_record,true,1,f.owner_wrap,jsonb_build_object('password','plaintext'),
            f.owner_device,f.confirmation);
        raise exception 'Unencrypted payload accepted';
    exception when invalid_parameter_value then null;
    end;

    perform public.miloom_share_resource('viewer@example.com','Viewer',f.company_id,'company');

    -- A second insert at the same UUID proves the earlier failure rolled back
    -- both the resource and the staged credential.
    perform public.miloom_save_owned_protected_resource(
        'card',v_record,true,1,f.owner_wrap,f.ciphertext,f.owner_device,f.confirmation);
    perform public.miloom_save_owned_protected_resource(
        'card',v_record,true,1,f.owner_wrap,f.ciphertext,f.owner_device,f.confirmation);
    perform public.miloom_save_owned_protected_resource(
        'card',v_record || jsonb_build_object('id',f.other_resource,'company_id',f.other_company),
        true,1,f.owner_wrap,f.ciphertext,f.owner_device,f.confirmation);
    begin
        insert into public.financial_cards (id,user_id,company_id,name,password)
        values (gen_random_uuid(),f.owner_id,f.company_id,'Direct write','plaintext');
        raise exception 'Direct plaintext write accepted';
    exception when insufficient_privilege then
        if sqlerrm <> 'USE_RESOURCE_SECRET_UPDATE' then raise; end if;
    end;
    perform public.miloom_share_resource_with_credentials('editor@example.com','Editor',f.resource_id,'card',true);
    perform public.miloom_share_resource_with_credentials('editor@example.com','Editor',f.other_resource,'card',false);
    perform public.miloom_queue_resource_key_deliveries(f.owner_device, f.confirmation);

    -- Both users can be provisioned without requesting the password.
    if (select count(*) from public.miloom_list_resource_secret_requests(f.owner_device,f.confirmation)
        where resource_id in (f.resource_id,f.other_resource)) <> 2 then
        raise exception 'Wrong device provisioning scope';
    end if;
    perform public.miloom_approve_resource_secret_access(
        request_id, f.owner_device,f.confirmation,f.device_public,f.owner_wrap
    ) from public.miloom_list_resource_secret_requests(f.owner_device,f.confirmation)
      where resource_id = f.resource_id;
end;
$$;

reset role;
insert into public.vault_devices (id,user_id,status,auth_session_id,label,agreement_public_key)
select '70000000-0000-0000-0000-000000000009', viewer_id, 'approved',
    '80000000-0000-0000-0000-000000000009', 'Viewer’s second phone', device_public
from vault_automatic_fixture;
set local role authenticated;
do $$
declare f vault_automatic_fixture%rowtype;
begin
    select * into f from vault_automatic_fixture;
    perform public.miloom_queue_resource_key_deliveries(f.owner_device,f.confirmation);
    if not exists (select from public.miloom_list_resource_secret_requests(f.owner_device,f.confirmation)
        where resource_id=f.resource_id and recipient_device_id='70000000-0000-0000-0000-000000000009') then
        raise exception 'New device did not inherit the credential share';
    end if;
end
$$;

reset role;
select set_config('request.jwt.claim.sub', (select viewer_id::text from vault_automatic_fixture), true);
select set_config('request.jwt.claim.session_id', '80000000-0000-0000-0000-000000000003', true);
set local role authenticated;
do $$
declare f vault_automatic_fixture%rowtype;
begin
    select * into f from vault_automatic_fixture;
    if not exists (select from public.miloom_resource_credential_status('card',f.resource_id,f.viewer_device)
                   where status = 'ready' and not can_edit)
       or (select encrypted_fields from public.miloom_get_resource_secret_for_device('card',f.resource_id,f.viewer_device))
            is distinct from f.ciphertext then
        raise exception 'Viewer could not read the included company resource';
    end if;
    if not exists (select from public.miloom_visible_financial_cards_with_credentials() as r(row)
        where (r.row->>'id')::uuid = f.resource_id
          and (r.row->>'has_scoped_credentials')::boolean
          and r.row->>'password' is null) then
        raise exception 'Search did not get safe credential availability';
    end if;
    begin
        perform public.miloom_update_resource_secret(
            'card',f.resource_id,1,f.ciphertext,jsonb_build_object('password',f.next_ciphertext),f.viewer_device);
        raise exception 'Viewer changed a credential';
    exception when insufficient_privilege then
        if sqlerrm <> 'RESOURCE_SECRET_ACCESS_NOT_GRANTED' then raise; end if;
    end;
    if not exists (select from public.miloom_resource_credential_status('card',f.other_resource,f.viewer_device)
                   where status = 'unavailable') then
        raise exception 'Company share exposed a different company';
    end if;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', (select editor_id::text from vault_automatic_fixture), true);
select set_config('request.jwt.claim.session_id', '80000000-0000-0000-0000-000000000002', true);
set local role authenticated;
do $$
declare f vault_automatic_fixture%rowtype;
begin
    select * into f from vault_automatic_fixture;
    if not exists (select from public.miloom_resource_credential_status('card',f.resource_id,f.editor_device)
                   where status = 'ready' and can_edit)
       or not exists (select from public.miloom_resource_credential_status('card',f.other_resource,f.editor_device)
                   where status = 'unavailable') then
        raise exception 'Editor access ignored the exclusion or included share';
    end if;
    perform public.miloom_update_resource_secret(
        'card',f.resource_id,1,f.ciphertext,jsonb_build_object('password',f.next_ciphertext),f.editor_device);
    begin
        perform public.miloom_update_resource_secret('card',f.resource_id,1,f.ciphertext,'{}',f.editor_device);
        raise exception 'Stale credential edit was accepted';
    exception when insufficient_privilege then
        if sqlerrm <> 'RESOURCE_SECRET_CHANGED' then raise; end if;
    end;
end;
$$;

reset role;
select set_config('request.jwt.claim.sub', (select owner_id::text from vault_automatic_fixture), true);
select set_config('request.jwt.claim.session_id', '80000000-0000-0000-0000-000000000001', true);
set local role authenticated;
select public.miloom_share_resource_with_credentials('viewer@example.com','Viewer',resource_id,'card',false)
    from vault_automatic_fixture;
select public.miloom_share_resource_with_credentials('editor@example.com','Viewer',resource_id,'card',true)
    from vault_automatic_fixture;

reset role;
do $$
declare f vault_automatic_fixture%rowtype;
begin
    select * into f from vault_automatic_fixture;
    if public.miloom_resource_secret_user_eligible(f.viewer_id,'card',f.resource_id)
       or public.miloom_resource_secret_role_allowed(f.editor_id,'card',f.resource_id,true)
       or not public.miloom_resource_secret_user_eligible(f.editor_id,'card',f.resource_id)
       or (select state from public.resource_secret_versions where resource_id=f.resource_id) <> 'rotation_required' then
        raise exception 'Exact exclusion or role change did not take effect';
    end if;
    if (select password from public.financial_cards where id = '40000000-0000-0000-0000-000000000001')
         is distinct from 'older stored value' then
        raise exception 'The new storage changed legacy data';
    end if;
end;
$$;

-- Invitations carry the choice through verified-email acceptance.
select set_config('request.jwt.claim.sub', (select owner_id::text from vault_automatic_fixture), true);
set local role authenticated;
select public.miloom_share_resource_with_credentials('invitee@example.com','Viewer',other_resource,'card',false)
  from vault_automatic_fixture;
reset role;
insert into auth.users(id,email,email_confirmed_at)
values ('00000000-0000-0000-0000-000000000099','invitee@example.com',now());
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000099',true);
select public.miloom_act_on_invitation(
    (select id from public.resource_invitations where email='invitee@example.com'),null,true);
do $$
begin
    if (select include_credentials from public.resource_shares
        where user_id='00000000-0000-0000-0000-000000000099') is distinct from false then
        raise exception 'Invitation acceptance lost the credential exclusion';
    end if;
end
$$;

rollback;
