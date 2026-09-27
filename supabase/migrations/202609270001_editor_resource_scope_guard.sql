-- New Editors must have an explicit resource or collection, never an entity.
-- Existing company Editor rows remain unchanged pending an explicit disposition.
begin;

create or replace function public.miloom_guard_editor_resource_scope()
returns trigger language plpgsql set search_path = '' as $$
declare
    v_new jsonb := to_jsonb(new);
    v_old jsonb;
    v_reject boolean := tg_op = 'INSERT';
begin
    if new.role <> 'Editor' or lower(new.resource_type) <> 'company' then
        return new;
    end if;
    if tg_op = 'UPDATE' then
        v_old := to_jsonb(old);
        v_reject := v_old->>'role' is distinct from v_new->>'role'
            or v_old->>'resource_type' is distinct from v_new->>'resource_type'
            or v_old->>'resource_id' is distinct from v_new->>'resource_id'
            or v_old->>'user_id' is distinct from v_new->>'user_id'
            or v_old->>'email' is distinct from v_new->>'email'
            or (tg_table_name = 'resource_shares'
                and v_old->>'suspended_at' is not null
                and v_new->>'suspended_at' is null)
            or (tg_table_name = 'resource_invitations'
                and v_old->>'status' is distinct from v_new->>'status'
                and lower(v_new->>'status') in ('pending', 'accepted'));
    end if;
    if v_reject then
        raise exception using errcode = '22023', message = 'EDITOR_RESOURCE_OR_COLLECTION_REQUIRED';
    end if;
    return new;
end;
$$;
revoke all on function public.miloom_guard_editor_resource_scope() from public, anon, authenticated;
create trigger miloom_editor_resource_scope_guard
before insert or update on public.resource_shares
for each row execute function public.miloom_guard_editor_resource_scope();
create trigger miloom_editor_resource_scope_guard
before insert or update on public.resource_invitations
for each row execute function public.miloom_guard_editor_resource_scope();
notify pgrst, 'reload schema';
commit;
