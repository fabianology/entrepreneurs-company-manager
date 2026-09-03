-- Consolidate years of overlapping company SELECT policies. Multiple policies
-- are ORed by PostgreSQL, so every legacy share/invitation check was part of the
-- query plan and could push this tiny lookup past the statement timeout.

create index if not exists resource_shares_company_reader_idx
    on public.resource_shares (user_id, resource_type, resource_id)
    where suspended_at is null;

create index if not exists resource_invitations_company_email_idx
    on public.resource_invitations (lower(email), resource_type, resource_id);

create or replace function public.miloom_can_read_company(
    p_company_id uuid,
    p_owner_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select
        p_owner_user_id = (select auth.uid())
        or exists (
            select 1
              from public.resource_shares rs
             where rs.user_id = (select auth.uid())
               and rs.resource_type = 'company'
               and rs.resource_id = p_company_id
               and rs.suspended_at is null
        )
        or exists (
            select 1
              from public.resource_invitations ri
             where lower(ri.email) = lower(coalesce((select auth.jwt() ->> 'email'), ''))
               and ri.resource_type = 'company'
               and ri.resource_id = p_company_id
        );
$$;

revoke all on function public.miloom_can_read_company(uuid, uuid) from public, anon;
grant execute on function public.miloom_can_read_company(uuid, uuid) to authenticated;

drop policy if exists "Allow shared users to read companies" on public.companies;
drop policy if exists "Granular companies access" on public.companies;
drop policy if exists "Users can view companies they own or are shared with" on public.companies;
drop policy if exists "Users can view own companies" on public.companies;
drop policy if exists "Users can view shared companies" on public.companies;
drop policy if exists "Miloom company read access" on public.companies;

create policy "Miloom company read access"
on public.companies
for select
to authenticated
using (public.miloom_can_read_company(id, user_id));

notify pgrst, 'reload schema';
