-- Preserve canonical document authority independently of permissive RLS checks.
-- Collaborators may edit metadata/files, never acquire ownership or move scope.
begin;
create function public.miloom_guard_document_identity_scope()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
    if tg_op = 'UPDATE' then
        if new.id is distinct from old.id or new.user_id is distinct from old.user_id then
            raise exception using errcode = '42501', message = 'DOCUMENT_IDENTITY_IMMUTABLE';
        end if;
        if new.company_id is distinct from old.company_id
           and auth.uid() is distinct from old.user_id then
            raise exception using errcode = '42501', message = 'DOCUMENT_SCOPE_OWNER_REQUIRED';
        end if;
    end if;
    -- A new document or owner-requested move must remain in that owner's entity.
    if (tg_op = 'INSERT' or new.company_id is distinct from old.company_id)
       and new.company_id is not null
       and not exists (select 1 from public.companies c
           where c.id = new.company_id and c.user_id = new.user_id) then
        raise exception using errcode = '42501', message = 'DOCUMENT_ENTITY_OWNER_MISMATCH';
    end if;
    return new;
end;
$$;
revoke all on function public.miloom_guard_document_identity_scope() from public, anon, authenticated;
create trigger miloom_document_identity_scope_guard
before insert or update on public.company_documents
for each row execute function public.miloom_guard_document_identity_scope();
notify pgrst, 'reload schema';
commit;
