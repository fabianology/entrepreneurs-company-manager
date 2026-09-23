-- Run against the disposable Storage fixture after migrations 022 and 028.
-- Deliberately permissive policies must not override the restrictive guard.
begin;
grant insert, update, delete on storage.objects to authenticated;
create policy broad_insert on storage.objects for insert to authenticated with check (true);
create policy broad_update on storage.objects for update to authenticated
using (true) with check (true);
create policy broad_delete on storage.objects for delete to authenticated using (true);

set local role authenticated;
do $$
declare
    v_owner text := '00000000-0000-0000-0000-000000000001';
    v_viewer text := '00000000-0000-0000-0000-000000000003';
    v_linked text := '00000000-0000-0000-0000-000000000001/shared.pdf';
    v_affected integer;
begin
    perform set_config('request.jwt.claim.sub', v_viewer, true);
    if current_user <> 'authenticated' or auth.uid()::text <> v_viewer
       or not row_security_active('storage.objects'::regclass) then
        raise exception 'Viewer test is not running with authenticated RLS';
    end if;
    insert into storage.objects (bucket_id, name, owner_id)
    values ('CompanyDocuments', v_viewer || '/own.pdf', v_viewer);
    begin
        insert into storage.objects (bucket_id, name, owner_id)
        values ('CompanyDocuments', v_owner || '/intruder.pdf', v_viewer);
        raise exception 'Broad insert policy bypassed owner-folder boundary';
    exception when insufficient_privilege then null;
    end;
    update storage.objects set owner_id = v_viewer
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then
        raise exception 'Viewer overwrote linked owner object';
    end if;
    delete from storage.objects
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then
        raise exception 'Viewer deleted linked owner object';
    end if;
    perform set_config('request.jwt.claim.sub', v_owner, true);
    update storage.objects set owner_id = v_owner
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    if not found then
        raise exception 'Owner cannot update linked object';
    end if;
    delete from storage.objects
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    if found then
        -- Owner deletion itself is allowed; restore the disposable fixture
        -- before checking without affecting production data.
        insert into storage.objects (bucket_id, name, owner_id)
        values ('CompanyDocuments', v_linked, v_owner);
    else
        raise exception 'Owner cannot delete linked object';
    end if;
end;
$$;
reset role;

grant usage on schema storage, auth to anon;
grant select, insert, update, delete on storage.objects to anon;
create policy broad_anon_select on storage.objects for select to anon using (true);
create policy broad_anon_insert on storage.objects for insert to anon with check (true);
create policy broad_anon_update on storage.objects for update to anon
using (true) with check (true);
create policy broad_anon_delete on storage.objects for delete to anon using (true);
set local role anon;
do $$
declare
    v_linked text := '00000000-0000-0000-0000-000000000001/shared.pdf';
    v_affected integer;
begin
    perform set_config('request.jwt.claim.sub', '', true);
    if auth.uid() is not null or not row_security_active('storage.objects'::regclass) then
        raise exception 'Anonymous test is not running under RLS';
    end if;
    if exists (select 1 from storage.objects
        where bucket_id = 'CompanyDocuments' and name = v_linked) then
        raise exception 'Broad anonymous read exposed private document';
    end if;
    begin
        insert into storage.objects (bucket_id, name)
        values ('CompanyDocuments', '00000000-0000-0000-0000-000000000003/anon.pdf');
        raise exception 'Broad anonymous insert bypassed write boundary';
    exception when insufficient_privilege then null;
    end;
    update storage.objects set owner_id = 'anonymous'
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then raise exception 'Anonymous update changed private document'; end if;
    delete from storage.objects
     where bucket_id = 'CompanyDocuments' and name = v_linked;
    get diagnostics v_affected = row_count;
    if v_affected <> 0 then raise exception 'Anonymous delete removed private document'; end if;
end;
$$;
reset role;
rollback;
