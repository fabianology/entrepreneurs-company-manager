-- Local rehearsal only, after 009–033. All fixture changes roll back.
begin;
do $$
declare
    v_owner uuid := '00000000-0000-0000-0000-000000000001';
    v_editor uuid := '00000000-0000-0000-0000-000000000004';
    v_viewer uuid := '00000000-0000-0000-0000-000000000005';
    v_admin uuid := '00000000-0000-0000-0000-000000000006';
    v_company uuid := '10000000-0000-0000-0000-000000000001';
    v_bank uuid := '30000000-0000-0000-0000-000000000001';
    v_result jsonb;
begin
    insert into auth.users(id,email) values
        (v_editor,'bank-editor@example.com'),(v_viewer,'bank-viewer@example.com'),
        (v_admin,'bank-admin@example.com');
    perform set_config('request.jwt.claim.sub',v_owner::text,true);
    v_result := public.miloom_share_resource('bank-editor@example.com','Editor',v_company,'all_institutions');
    if v_result->>'status' <> 'shared_directly' then raise exception 'Owner collection grant failed'; end if;
    perform set_config('request.jwt.claim.sub',v_editor::text,true);
    if not public.miloom_can_read_resource('institution',v_bank,v_company,v_owner)
       or not public.miloom_can_edit_resource('institution',v_bank,v_company,v_owner)
       or not public.miloom_can_read_company(v_company,v_owner) then
        raise exception 'Bank collection lost bank access/company shell';
    end if;
    if public.miloom_can_edit_resource('company',v_company,v_company,v_owner)
       or public.miloom_can_read_resource('loan',gen_random_uuid(),v_company,v_owner)
       or public.miloom_can_edit_resource('loan',gen_random_uuid(),v_company,v_owner)
       or public.miloom_can_read_resource('card',gen_random_uuid(),v_company,v_owner)
       or public.miloom_can_read_resource('document',gen_random_uuid(),v_company,v_owner)
       or public.miloom_can_read_resource('subscription',gen_random_uuid(),v_company,v_owner)
       or public.miloom_can_read_resource('institution',gen_random_uuid(),gen_random_uuid(),v_owner) then
        raise exception 'Bank-only collection leaked another resource/scope';
    end if;
    begin
        perform public.miloom_share_resource('bank-viewer@example.com','Viewer',v_company,'all_institutions');
        raise exception 'Editor delegated collection access';
    exception when insufficient_privilege then null; end;
    perform set_config('request.jwt.claim.sub',v_owner::text,true);
    perform public.miloom_share_resource('bank-admin@example.com','Admin',v_company,'company');
    begin
        perform public.miloom_share_resource('bank-viewer@example.com','Admin',v_company,'all_institutions');
        raise exception 'Nonentity Admin accepted';
    exception when invalid_parameter_value then null; end;
    perform set_config('request.jwt.claim.sub',v_admin::text,true);
    v_result := public.miloom_admin_share_viewer('bank-viewer@example.com',v_company,'all_institutions');
    if v_result->>'status' <> 'shared_directly' then raise exception 'Admin Viewer grant failed'; end if;
    perform set_config('request.jwt.claim.sub',v_viewer::text,true);
    if not public.miloom_can_read_resource('institution',v_bank,v_company,v_owner)
       or public.miloom_can_edit_resource('institution',v_bank,v_company,v_owner) then
        raise exception 'Collection Viewer permissions incorrect';
    end if;
    -- The fix must not remove the enum boundary or the Admin restriction.
    begin
        insert into public.resource_shares(resource_id,resource_type,user_id,role)
            values(v_company,'unknown_scope',v_viewer,'Viewer');
        raise exception 'Unknown resource type accepted';
    exception when check_violation then null; end;
    begin
        insert into public.resource_shares(resource_id,resource_type,user_id,role)
            values(gen_random_uuid(),'all_institutions',v_viewer,'Admin');
        raise exception 'Direct nonentity Admin accepted';
    exception when check_violation then null; end;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
do $$ declare v_count integer; begin
    update public.institutions set name = 'Collection Editor saved'
     where id = '30000000-0000-0000-0000-000000000001';
    get diagnostics v_count = row_count;
    if v_count <> 1 then raise exception 'Collection Editor UPDATE not applied'; end if;
    update public.institutions set name = 'Must not save'
     where id = '30000000-0000-0000-0000-000000000002';
    get diagnostics v_count = row_count;
    if v_count <> 0 then raise exception 'Cross-company UPDATE allowed'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000005',true);
do $$ declare v_count integer; begin
    update public.institutions set name = 'Must not save'
     where id = '30000000-0000-0000-0000-000000000001';
    get diagnostics v_count = row_count;
    if v_count <> 0 then raise exception 'Collection Viewer UPDATE allowed'; end if;
end $$;
reset role;
rollback;
