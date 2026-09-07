begin;

do $$
begin
    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'subscriptions'
          and column_name = 'service_type'
          and is_nullable = 'NO'
          and column_default = '''automatic''::text'
    ) then
        raise exception 'subscriptions.service_type contract is missing';
    end if;

    begin
        insert into public.subscriptions (user_id, company_id, name, service_type)
        values (gen_random_uuid(), gen_random_uuid(), 'Invalid type', 'other');
        raise exception 'Invalid service type was accepted';
    exception
        when check_violation then null;
    end;
end
$$;

rollback;
