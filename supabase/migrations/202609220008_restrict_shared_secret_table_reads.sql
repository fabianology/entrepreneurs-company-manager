-- Release gate: apply only after all supported iOS builds use the visible-record
-- RPCs introduced in 007. Older builds still issue SELECT * on these tables.
-- RLS controls rows, not columns, so the old shared-row policies alone cannot
-- protect credentials from direct PostgREST requests.

begin;

revoke select on table public.subscriptions from public, anon, authenticated;
revoke select on table public.financial_cards from public, anon, authenticated;
revoke select on table public.institutions from public, anon, authenticated;

-- Direct mutations need identifier projection for WHERE and RETURNING id.
-- Full records, including owner credentials, come only from checked RPCs.
grant select (id, user_id, company_id) on public.subscriptions to authenticated;
grant select (id, user_id, company_id) on public.financial_cards to authenticated;
grant select (id, user_id, company_id) on public.institutions to authenticated;

notify pgrst, 'reload schema';

commit;
