-- The expression index on company_documents(url) evaluates this immutable
-- normalizer during authenticated document writes. Revoking EXECUTE in 029
-- unintentionally made those writes fail with SQLSTATE 42501. The function
-- only transforms its text argument; it reads no tables or private state.
begin;

grant execute on function public.miloom_document_storage_path(text)
    to authenticated;

commit;
