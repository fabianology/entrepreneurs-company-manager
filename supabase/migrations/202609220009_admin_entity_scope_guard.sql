-- Admin is a delegated entity role, never an individual-resource role.
-- This is a fail-closed foundation for scoped collaborative vault grants.
-- Review any pre-existing non-company Admin edges rather than silently
-- converting or deleting their access.

begin;

do $$
begin
    if exists (
        select 1 from public.resource_shares
         where role = 'Admin' and resource_type <> 'company'
    ) or exists (
        select 1 from public.resource_invitations
         where role = 'Admin' and resource_type <> 'company'
    ) then
        raise exception using errcode = '23514', message = 'NON_ENTITY_ADMIN_ACCESS_REQUIRES_REVIEW';
    end if;
end;
$$;

do $$
begin
    if not exists (
        select 1 from pg_constraint
         where conrelid = 'public.resource_shares'::regclass
           and conname = 'resource_shares_admin_entity_only'
    ) then
        alter table public.resource_shares
            add constraint resource_shares_admin_entity_only
            check (role <> 'Admin' or resource_type = 'company');
    end if;

    if not exists (
        select 1 from pg_constraint
         where conrelid = 'public.resource_invitations'::regclass
           and conname = 'resource_invitations_admin_entity_only'
    ) then
        alter table public.resource_invitations
            add constraint resource_invitations_admin_entity_only
            check (role <> 'Admin' or resource_type = 'company');
    end if;
end;
$$;

commit;
