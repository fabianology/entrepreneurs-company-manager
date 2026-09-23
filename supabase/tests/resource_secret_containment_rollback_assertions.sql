-- Isolated synthetic DB only, after resource-secret rotation/lifecycle tests.
-- Rehearse privilege containment and reversal without dropping encrypted data.
begin;
create temporary table rollback_secret_snapshot as
select 'versions' as name, coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') as data
from public.resource_secret_versions t
union all
select 'wraps', coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]')
from public.resource_secret_device_wraps t
union all
select 'audit', coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]')
from public.resource_secret_audit_events t;
do $$ begin
    if not exists(select 1 from public.resource_secret_versions) then
        raise exception 'Rollback needs populated secret fixture';
    end if;
    if not has_function_privilege('authenticated',
      'public.miloom_get_resource_secret_for_device(text,uuid,uuid)','EXECUTE') then
        raise exception 'Expected delivery privilege before containment';
    end if;
end $$;
revoke execute on function public.miloom_get_resource_secret_for_device(text,uuid,uuid) from authenticated;
set local role authenticated;
do $$ begin
    begin
        perform public.miloom_get_resource_secret_for_device('card',
            '40000000-0000-0000-0000-000000000001',
            '70000000-0000-0000-0000-000000000001');
        raise exception 'Delivery remained executable during containment';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;
grant execute on function public.miloom_get_resource_secret_for_device(text,uuid,uuid) to authenticated;
do $$ begin
    if not has_function_privilege('authenticated',
      'public.miloom_get_resource_secret_for_device(text,uuid,uuid)','EXECUTE')
       or has_function_privilege('anon',
      'public.miloom_get_resource_secret_for_device(text,uuid,uuid)','EXECUTE') then
        raise exception 'Restoration changed privilege boundary';
    end if;
    if exists (
      select * from rollback_secret_snapshot
      except
      (select 'versions', coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') from public.resource_secret_versions t
       union all select 'wraps', coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') from public.resource_secret_device_wraps t
       union all select 'audit', coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]') from public.resource_secret_audit_events t)
    ) then raise exception 'Containment/restoration modified encrypted records'; end if;
end $$;
rollback;
