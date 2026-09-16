# Cached Plaid sync: phases 1 and 2

## Behavior

- Link and routine/manual/recovery sync use `/accounts/get` for cached balances.
- Neither path calls `/accounts/balance/get` or `/transactions/refresh`, including
  on errors. Auth and Liabilities enrichment remain enabled as before.
- The post-Link sync remains in place to initialize transaction import.
- Webhook routing and serialized cursor-based transaction import are preserved.
  Production verification also exposed the documented empty initial cursor case:
  recovery sync now reports `transactions_pending` until Plaid prepares data,
  without advancing the cursor or transaction freshness timestamp. Invalid/missing
  cursors with existing data still fail safely.
- Account identity/history reconciliation, encrypted account fields, card/loan
  updates, and reconnect handling remain in the existing sync function.
- iOS calls the same `plaid-nightly-sync` endpoint with the same request/response
  shape. Older app versions get the cost reduction after backend deployment.
- `institutions.last_synced_at` means account data retrieved by Miloom.
  `plaid_items.last_synced_at` means transaction data imported by Miloom.
  Neither is a guarantee of when the bank last refreshed its data.
- iOS displays separate transaction-sync and balance-retrieval information and
  says "Sync Available Data" instead of promising a fresh bank check.

No pricing, plan limits, forced-refresh quotas, product subscriptions for existing
Items, entitlements, or database schema are changed by this release.

## Verification completed locally

- iPhone 17 Pro, iOS 26.4 simulator build passed (2026-09-15). Existing project
  warnings remain. Build log: `/private/tmp/miloom-cached-sync-build.log`.
- 29 backend tests passed: 14 transaction sync, 6 alerts, 9 handler integration.
  The handler tests exercise the real Edge Function handlers with mocked HTTP
  services; they do not contact Plaid or write production data.
- Integration coverage: Link response and enrichment; cached account/card/loan
  persistence; encrypted fields; user/institution scope; initial cursor import;
  a reauth failure isolated from another bank; null balance preservation; invalid
  sessions; malformed account responses; initial-data preparation; scheduler
  authentication and rejected secrets; and no paid refresh fallback.
- No authenticated app/Plaid Sandbox end-to-end smoke test has been performed.

Run from the repository root with Deno available:

```sh
deno test --config supabase/functions/deno.json --no-lock \
  --import-map supabase/tests/plaid_sync_import_map.json --allow-env \
  supabase/tests/plaid_cached_sync_test.ts \
  supabase/functions/_shared/plaid_test.ts \
  supabase/functions/_shared/alerts_test.ts
```

The test import map replaces only the HTTP server listener so the actual handlers
can run without opening a port. Do not use the test import map for deployment.

## Production findings before deployment (2026-09-15)

Linked project: `xxqdytdbpiqjilhutvhz`.

`cron.job` contains two active jobs: `send-briefings-every-15-minutes` and
`business-expense-screening`. There is no job referencing Plaid in its name or
command. The old `003_plaid_transactions.sql` scheduler is only a commented
example, not an active deployment. Its anonymous-key example is not authorized
to perform a service-wide sync and must not be used.

Vault initially contained `briefing_cron_secret` and `business_expense_function_url`;
no Plaid scheduler credential was configured. Only secret names were inspected
during this initial review.
An external scheduler outside Supabase has not been ruled out.

## Deployment and remaining verification

1. Record the pre-deployment Plaid Dashboard Balance request count and daily
   charges, along with billable Item counts. This dashboard data was not
   accessible during local implementation; no savings have been measured yet.
2. Deploy `exchange-public-token` and `plaid-nightly-sync`. No schema migration is
   needed. Keep the existing JWT/auth settings. Shared alert wording is bundled
   into deployed functions; redeploy other alert consumers only after reviewing
   their existing unrelated changes.

   ```sh
   supabase functions deploy exchange-public-token --project-ref xxqdytdbpiqjilhutvhz
   supabase functions deploy plaid-nightly-sync --project-ref xxqdytdbpiqjilhutvhz
   ```

3. Check for any external scheduler already invoking this function. Set a dedicated
   random `PLAID_SYNC_CRON_SECRET` Edge Function secret and store the same value in
   Vault as `plaid_sync_cron_secret`. Store the project's anon JWT in Vault as
   `plaid_sync_anon_key` for platform JWT verification. Run
   `ops/schedule_plaid_recovery.sql` to configure one 02:00 UTC daily recovery sweep.
   The script keeps credentials out of cron source and logs. If the named job was
   paused, explicitly reactivate it after the smoke test using `cron.alter_job`.
   Deploy the cheaper backend first so enabling recovery cannot invoke the old
   paid Balance path. This schedule is a Miloom recovery interval, not a promise
   about how often Plaid contacts banks.
4. Verify an authenticated sync's HTTP response and per-Item `success` results.
   A cron job reporting success only proves that the HTTP request was queued;
   inspect Edge Function execution/results as well. Monitor timeouts and Item
   failures before relying on an all-Items sweep at larger scale.
5. Smoke-test Link, initial transaction import, ordinary refresh, reconnection,
   and card/loan values in a matching Plaid Sandbox environment. Confirm a webhook
   still imports transactions without waiting for the daily recovery job.
6. Release the iOS build with the new labels. Check the institution sheet's text
   at small screen sizes and larger accessibility text settings. Do not describe
   the displayed retrieval timestamp as a real-time balance timestamp.
7. After deployment, compare Balance request counts over equivalent periods.
   These two paths should generate zero new Balance requests. Investigate any
   remaining traffic from other deployed integrations before attributing savings.
   Transactions, Auth, Liabilities, hosting, and AI costs still apply as used.

## Deployment record

The user approved production deployment and daily recovery setup in this task.
Both `exchange-public-token` and `plaid-nightly-sync` were deployed. Platform JWT
verification remains enabled. The daily job uses a dedicated scheduler secret;
normal app calls still validate the signed-in user and scope requests to them.

The initial test with a dashboard service-role JWT passed the gateway but failed
the handler's exact match against the runtime service-role key. The job was paused
while dedicated-secret authentication was implemented and tested. The unused
Vault copy of the service-role credential created during setup was removed; this
did not delete or rotate the project's API key. Scheduler credentials were passed
through process input and were not written to local files or printed.

The first authenticated database HTTP smoke request (6960) returned HTTP 200 with
5 successful Items and one initial-data cursor error. That error prompted the
initial-cursor fix described above. The final request (6963), using the exact
scheduled command and Vault credentials, returned HTTP 200 with 6 Items processed,
0 failures, no timeout, and 0 new transactions. One Item correctly reported that
Plaid was still preparing its initial data. This does not claim that every Item
has completed its initial transaction import.

Job 3, `miloom-plaid-nightly-sync`, was enabled after this successful check. Its
schedule is `0 2 * * *` (02:00 UTC daily). The scheduled command was manually
verified through `pg_net`; the first clock-triggered daily run has not yet occurred.

Previous production sources are retained at
`/private/tmp/miloom-plaid-predeploy.X7FtZV` for rollback. Existing unrelated edits
in `create-link-token` and `plaid-webhook` were not deployed. The shared initial
cursor fix is bundled into the newly deployed recovery function; other consumers
will receive it when separately deployed from reviewed sources.

The iOS update has been built but not released. Plaid Dashboard billing comparison
and an authenticated app/Plaid Sandbox Link smoke test remain outstanding.

## Rollback

Retain the previous deployed function versions before release. If reverting to a
version that calls paid Balance, pause the newly created recovery job first to
avoid introducing daily Balance charges. Do not revert unrelated local work.
