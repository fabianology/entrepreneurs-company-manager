-- UPDATE/DELETE also require SELECT visibility. Legacy institution SELECT
-- policies know only exact/company/all_financials shares, so a bank-collection
-- Editor could read the safe RPC but silently update zero rows over REST.
begin;
drop policy if exists miloom_institution_scoped_select on public.institutions;
create policy miloom_institution_scoped_select
on public.institutions for select to authenticated
using (public.miloom_can_read_resource('institution', id, company_id, user_id));
-- No column privileges change: credential-bearing rows remain RPC-only.
notify pgrst, 'reload schema';
commit;
