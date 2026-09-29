-- Run after 202609290001 in the disposable document fixture.
begin;

do $$
begin
    if not has_function_privilege('authenticated',
        'public.miloom_document_storage_path(text)', 'EXECUTE') then
        raise exception 'Authenticated document writes lack path normalizer EXECUTE';
    end if;
    if has_function_privilege('anon',
        'public.miloom_document_storage_path(text)', 'EXECUTE') then
        raise exception 'Path normalizer was exposed to anon';
    end if;
end $$;

grant select, update on public.company_documents to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',
    '00000000-0000-0000-0000-000000000001', true);

-- A non-null URL exercises the expression index as the actual app write does.
update public.company_documents
   set url = 'https://example.test/document-write-probe.pdf'
 where id = '60000000-0000-0000-0000-000000000001';

do $$
begin
    if (select url from public.company_documents
        where id = '60000000-0000-0000-0000-000000000001')
        <> 'https://example.test/document-write-probe.pdf' then
        raise exception 'Authenticated document URL update did not persist';
    end if;
end $$;

rollback;
