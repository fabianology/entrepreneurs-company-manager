-- Run after the Storage fixture, migration 022, and migration 025.
insert into public.company_documents (id, user_id, company_id, name, url)
values ('60000000-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001', 'Empty attachment', null);

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000003', false);
do $$
begin
    begin
        update public.company_documents
           set url = '00000000-0000-0000-0000-000000000001/sibling.pdf'
         where id = '60000000-0000-0000-0000-000000000007';
        raise exception 'Collaborator attached an existing owner file';
    exception when insufficient_privilege then null;
    end;
    begin
        insert into public.company_documents (id, user_id, company_id, name, url)
        values ('60000000-0000-0000-0000-000000000008',
            '00000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000001', 'Unsafe attachment',
            '00000000-0000-0000-0000-000000000001/sibling.pdf');
        raise exception 'Collaborator inserted an owner-file document';
    exception when insufficient_privilege then null;
    end;
end;
$$;
do $$
begin
    if (select url from public.company_documents
         where id = '60000000-0000-0000-0000-000000000007') is not null
       or exists (select 1 from public.company_documents
           where id = '60000000-0000-0000-0000-000000000008') then
        raise exception 'Denied attachment persisted';
    end if;
end;
$$;

select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000001', false);
update public.company_documents
   set url = '00000000-0000-0000-0000-000000000001/sibling.pdf'
 where id = '60000000-0000-0000-0000-000000000007';
do $$
begin
    if (select url from public.company_documents
         where id = '60000000-0000-0000-0000-000000000007')
       <> '00000000-0000-0000-0000-000000000001/sibling.pdf' then
        raise exception 'Owner lost the ability to attach their own file';
    end if;
end;
$$;
