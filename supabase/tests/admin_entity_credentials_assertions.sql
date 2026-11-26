-- Synthetic local-only keys/ciphertext. This tests authorization and lifecycle,
-- not native encryption or hosted deployment. Every expected denial is asserted.
do $$
declare
    owner_id uuid := '00000000-0000-0000-0000-000000000001';
    admin_id uuid := '00000000-0000-0000-0000-000000000002';
    viewer_id uuid := '00000000-0000-0000-0000-000000000003';
    company_a uuid := '10000000-0000-0000-0000-000000000001';
    company_b uuid := '10000000-0000-0000-0000-000000000002';
    card_id uuid := '40000000-0000-0000-0000-000000000001';
    service_id uuid := '20000000-0000-0000-0000-000000000001';
    bank_b uuid := '30000000-0000-0000-0000-000000000002';
    owner_device uuid := '70000000-0000-0000-0000-000000000003';
    admin_device uuid := '70000000-0000-0000-0000-000000000001';
    grant_id uuid; invite_id uuid; result jsonb; recipient_mode text;
    confirmation text := encode(convert_to(repeat('k',32),'utf8'),'base64');
    wrapped text := replace(encode(convert_to(repeat('x',60),'utf8'),'base64'),E'\n','');
    public_key text := encode(decode('04'||repeat('11',64),'hex'),'base64');
begin
    if exists(select 1 from public.resource_shares where include_entity_credentials)
       or exists(select 1 from public.admin_credential_devices) then raise exception 'Existing Admin was upgraded'; end if;
    perform set_config('request.jwt.claim.iat',extract(epoch from now())::bigint::text,true);
    perform set_config('request.jwt.claim.sub',owner_id::text,true);
    perform set_config('request.jwt.claim.session_id','80000000-0000-0000-0000-000000000001',true);
    begin
        perform public.miloom_share_admin_entity('editor@example.com',company_a,true,null,null);
        raise exception 'Consent enabled without trusted owner proof';
    exception when insufficient_privilege then null; end;
    perform public.miloom_share_admin_entity('editor@example.com',company_a,true,owner_device,confirmation);
    select id into grant_id from public.admin_credential_devices where device_id=admin_device;
    if grant_id is null or (select status from public.admin_credential_devices where id=grant_id)<>'pending' then
        raise exception 'Admin device not pending explicit approval'; end if;
    begin
        perform public.miloom_list_admin_credential_deliveries(grant_id,owner_device,confirmation);
        raise exception 'Pending device received delivery material';
    exception when insufficient_privilege then null; end;

    perform public.miloom_stage_resource_secret('card',card_id,1,1,wrapped,
        jsonb_build_object('password','miloom-resource:v1:1:'||wrapped),owner_device,confirmation);
    perform public.miloom_stage_resource_secret('institution',bank_b,1,1,wrapped,
        jsonb_build_object('password','miloom-resource:v1:1:'||wrapped),owner_device,confirmation);
    update public.resource_secret_versions set state='active',activated_at=now();
    perform public.miloom_approve_admin_credential_device(grant_id,owner_device,confirmation);
    -- Exercise the native sync's resource-discovery RPC before key delivery.
    -- Return-column names must not shadow table columns in PL/pgSQL.
    if (select count(*) from public.miloom_list_admin_credential_resources(grant_id,owner_device,confirmation))<>3 then
        raise exception 'Wrong entity resource discovery scope'; end if;
    if exists(select 1 from public.miloom_list_admin_credential_resources(grant_id,owner_device,confirmation)
              where resource_id not in (service_id,card_id,'30000000-0000-0000-0000-000000000001'::uuid)) then
        raise exception 'Resource discovery crossed entity boundary'; end if;
    if (select count(*) from public.miloom_list_admin_credential_deliveries(grant_id,owner_device,confirmation))<>1 then
        raise exception 'Wrong entity delivery scope'; end if;
    begin
        perform public.miloom_deliver_admin_credential(grant_id,'institution',bank_b,1,owner_device,confirmation,public_key,wrapped);
        raise exception 'Cross-company key delivered';
    exception when insufficient_privilege then null; end;
    begin
        perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,2,owner_device,confirmation,public_key,wrapped);
        raise exception 'Stale key version delivered';
    exception when insufficient_privilege then null; end;
    -- Exercise Admin delivery with the deployed activation eligibility helper,
    -- not only the older helper from the base vault migrations.
    foreach recipient_mode in array array['unverified','anonymous'] loop
        update auth.users set
            email_confirmed_at=case when recipient_mode='unverified' then null else now() end,
            is_anonymous=(recipient_mode='anonymous') where id=admin_id;
        if public.miloom_resource_secret_user_eligible(admin_id,'card',card_id) then
            raise exception 'Ineligible % Admin passed final eligibility', recipient_mode; end if;
        begin
            perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,1,owner_device,confirmation,public_key,wrapped);
            raise exception 'Credential delivered to % Admin', recipient_mode;
        exception when insufficient_privilege then null; end;
        if exists(select 1 from public.resource_secret_device_wraps where recipient_device_id=admin_device) then
            raise exception 'Denied % delivery left a wrap', recipient_mode; end if;
    end loop;
    update auth.users set email_confirmed_at=now(),is_anonymous=false where id=admin_id;
    perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,1,owner_device,confirmation,public_key,wrapped);
    perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,1,owner_device,confirmation,public_key,wrapped);
    if (select count(*) from public.resource_secret_device_wraps where recipient_device_id=admin_device)<>1 then raise exception 'Retry duplicate'; end if;

    -- A revoked same-version wrap is an error, never silently reported delivered.
    update public.resource_secret_device_wraps set grant_status='revoked' where recipient_device_id=admin_device;
    begin
        perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,1,owner_device,confirmation,public_key,wrapped);
        raise exception 'Revoked wrap silently delivered';
    exception when insufficient_privilege then null; end;
    -- Restore only the synthetic fixture to continue independent scenarios.
    update public.resource_secret_device_wraps set grant_status='active' where recipient_device_id=admin_device;

    -- New resource uses a different key, within existing consent, no new per-item approval.
    perform public.miloom_stage_resource_secret('subscription',service_id,1,1,wrapped,
        jsonb_build_object('password','miloom-resource:v1:1:'||wrapped),owner_device,confirmation);
    update public.resource_secret_versions set state='active',activated_at=now() where resource_id=service_id;
    if (select count(*) from public.miloom_list_admin_credential_deliveries(grant_id,owner_device,confirmation))<>1 then raise exception 'Future resource missing'; end if;
    perform public.miloom_deliver_admin_credential(grant_id,'subscription',service_id,1,owner_device,confirmation,public_key,wrapped);
    perform set_config('request.jwt.claim.sub',admin_id::text,true);
    perform set_config('request.jwt.claim.session_id','80000000-0000-0000-0000-000000000002',true);
    if (select count(*) from public.miloom_get_resource_secret_for_device('card',card_id,admin_device))<>1 then raise exception 'Approved Admin cannot read'; end if;
    foreach recipient_mode in array array['unverified','anonymous'] loop
        update auth.users set
            email_confirmed_at=case when recipient_mode='unverified' then null else now() end,
            is_anonymous=(recipient_mode='anonymous') where id=admin_id;
        begin
            perform public.miloom_get_resource_secret_for_device('card',card_id,admin_device);
            raise exception 'Existing grant readable by % Admin', recipient_mode;
        exception when insufficient_privilege then null; end;
    end loop;
    update auth.users set email_confirmed_at=now(),is_anonymous=false where id=admin_id;
    if (select count(*) from public.miloom_get_resource_secret_for_device('card',card_id,admin_device))<>1 then
        raise exception 'Verified non-anonymous Admin cannot read after denial checks'; end if;
    begin
        perform public.miloom_share_admin_entity('viewer@example.com',company_a,true,admin_device,confirmation);
        raise exception 'Admin delegated Admin credential authority';
    exception when insufficient_privilege then null; end;

    -- Toggle off revokes even with an independent Editor share; business access survives.
    insert into public.resource_shares(resource_id,resource_type,user_id,role) values(card_id,'card',admin_id,'Editor');
    perform set_config('request.jwt.claim.sub',owner_id::text,true);
    perform set_config('request.jwt.claim.session_id','80000000-0000-0000-0000-000000000001',true);
    perform public.miloom_share_admin_entity('editor@example.com',company_a,false);
    if exists(select 1 from public.admin_credential_devices where id=grant_id)
       or exists(select 1 from public.resource_secret_device_wraps where recipient_device_id=admin_device and grant_status='active')
       or exists(select 1 from public.resource_secret_versions where company_id=company_a and state='active') then
        raise exception 'Opt-out retained grant or unlocked key'; end if;
    if (select state from public.resource_secret_versions where resource_id=bank_b)<>'active' then raise exception 'Other entity rotated'; end if;
    begin
        perform public.miloom_deliver_admin_credential(grant_id,'card',card_id,1,owner_device,confirmation,public_key,wrapped);
        raise exception 'Stale delivery after toggle off';
    exception when insufficient_privilege then null; end;
    perform public.miloom_share_admin_entity('editor@example.com',company_a,true,owner_device,confirmation);
    if exists(select 1 from public.admin_credential_devices where status='approved') then raise exception 'Reenable restored device approval'; end if;

    -- Replacing a recipient public key invalidates old approvals and locks keys.
    select id into grant_id from public.admin_credential_devices where device_id=admin_device;
    perform public.miloom_approve_admin_credential_device(grant_id,owner_device,confirmation);
    update public.resource_secret_versions set state='active' where resource_id=card_id;
    update public.resource_secret_device_wraps set grant_status='active',revoked_at=null where resource_id=card_id and recipient_device_id=admin_device;
    update public.vault_devices set agreement_public_key=encode(decode('04'||repeat('22',64),'hex'),'base64') where id=admin_device;
    if exists(select 1 from public.admin_credential_devices where status='approved')
       or (select state from public.resource_secret_versions where resource_id=card_id)<>'rotation_required' then
        raise exception 'Changed device key retained old grant'; end if;

    -- Role downgrade, suspension and revoke must not retain owner consent.
    perform public.miloom_share_resource('editor@example.com','Viewer',company_a,'company');
    if exists(select 1 from public.resource_shares where user_id=admin_id and include_entity_credentials)
       or exists(select 1 from public.admin_credential_devices) then raise exception 'Role downgrade retained policy'; end if;
    perform public.miloom_share_admin_entity('editor@example.com',company_a,true,owner_device,confirmation);
    update public.resource_shares set suspended_at=now() where resource_id=company_a and user_id=admin_id;
    if exists(select 1 from public.admin_credential_devices) then raise exception 'Suspension retained device approval'; end if;
    perform public.miloom_share_admin_entity('editor@example.com',company_a,true,owner_device,confirmation);
    update public.vault_devices set status='revoked' where id=admin_device;
    if exists(select 1 from public.admin_credential_devices) then raise exception 'Device revoke retained approval'; end if;
    update public.vault_devices set status='approved' where id=admin_device;
    if exists(select 1 from public.admin_credential_devices where status='approved') then raise exception 'Reapproval automatically trusted entity'; end if;
    insert into public.resource_access_blocks(owner_user_id,blocked_email,blocked_user_id) values(owner_id,'editor@example.com',admin_id);
    if exists(select 1 from public.admin_credential_devices) then raise exception 'Block retained entity device approval'; end if;

    -- New-user consent transfers only after real verified-email acceptance.
    result := public.miloom_share_admin_entity('new-admin@example.com',company_b,true,owner_device,confirmation);
    invite_id := (result->>'invitation_id')::uuid;
    insert into auth.users(id,email,email_confirmed_at) values('00000000-0000-0000-0000-000000000004','new-admin@example.com',null);
    perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
    begin
        perform public.miloom_act_on_invitation(invite_id,null,true);
        raise exception 'Unverified invitation accepted';
    exception when insufficient_privilege then null; end;
    update auth.users set email_confirmed_at=now() where id=auth.uid();
    perform public.miloom_act_on_invitation(invite_id,null,true);
    if not exists(select 1 from public.resource_shares where user_id=auth.uid() and resource_id=company_b and include_entity_credentials) then
        raise exception 'Accepted consent was lost'; end if;
    -- No device yet means no key or entity-device grant.
    if exists(select 1 from public.admin_credential_devices ad join public.resource_shares rs on rs.id=ad.share_id where rs.user_id=auth.uid()) then
        raise exception 'Invitation itself granted a device'; end if;

    if has_function_privilege('anon','public.miloom_share_admin_entity(text,uuid,boolean,uuid,text)','EXECUTE')
       or has_function_privilege('authenticated','public.miloom_require_admin_credential_device(uuid)','EXECUTE')
       or has_table_privilege('authenticated','public.admin_credential_devices','SELECT')
       or has_table_privilege('authenticated','public.resource_shares','UPDATE') then raise exception 'Privilege boundary widened'; end if;
end;
$$;
