# Phase 6 Production Contract Runbook

This runbook covers the five production migrations from `202608280001` through
`202608280005`. They add the missing Miloom foundation and Owner Briefing
contract. Do not include later versions in a repair operation: their objects
were independently verified and their history has already been reconciled.

## Safety properties

- The migrations create missing tables, indexes, columns, RLS policies, and
  functions. They do not delete user-owned rows.
- All monetization-enforcement triggers remain dropped.
- `maintain_miloom_downgrades()` is intentionally a no-op. It cannot suspend a
  Plaid Item, erase an access token, or suspend a share.
- An account without a server entitlement receives
  `MILOOM_ENTITLEMENT_NOT_INITIALIZED`, which preserves the app's existing
  StoreKit fallback. A verified purchase or restore initializes the row.
- Authenticated access is least-privilege and owner-scoped by RLS. Delivery
  claim tables and server refresh RPCs remain service-role-only.
- Supabase migrations run transactionally. A statement failure rolls back the
  current migration rather than leaving a partially applied version.

## Preflight gate

Before production apply:

1. Obtain a restorable Supabase backup/PITR point, or explicitly accept the
   lack of a physical backup based on the additive/no-delete scope.
2. Rehearse all five migrations against an isolated PostgreSQL/Supabase
   database and run SQL lint. The production-shaped PostgreSQL fixture and
   contract assertions are in `supabase/tests`; the migrations must pass twice
   to prove idempotent replay.
3. Confirm `supabase db push --dry-run --include-all` lists only versions
   `202608280001` through `202608280005`.
4. Confirm no `enforce_miloom_*` trigger will be created and downgrade
   maintenance contains no writes.
5. Record current table/function/policy presence and aggregate counts without
   exporting user data.

## Apply and verify

Apply through the linked Supabase CLI only after the preflight gate passes.
Immediately verify:

- all eight foundation tables exist with RLS enabled;
- required authenticated and service-role grants match the migration;
- anonymous users cannot execute Miloom RPCs or access foundation tables;
- an authenticated user with no entitlement falls back to StoreKit;
- Owner Briefing refresh is owner-scoped and returns without timeout;
- push-token registration can insert and delete only the caller's token;
- `send-briefings` succeeds with `{"dry_run":true}` and reports only aggregate
  contract counts; the dry-run path must not refresh data, create delivery
  claims/notifications/alerts, call APNs, or run downgrade maintenance;
- no enforcement trigger exists and no Plaid Item or share changed state.

## Non-destructive rollback

If verification fails, first stop the scheduler invoking `send-briefings` and
redeploy the last known-good Edge Function bundle. Then revoke authenticated
execute access from the new app RPCs and authenticated access from the new
tables. Keep all new tables and columns in place so any rows written after the
apply remain recoverable. Ensure all `enforce_miloom_*` triggers are dropped
and replace `maintain_miloom_downgrades()` with its no-op body.

Do not drop foundation tables or columns as an incident response. Physical
removal is a separate destructive migration that requires a verified backup
and an explicit data-retention decision.
