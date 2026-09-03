# Phase 6 — Reliability and Data Integrity

Phase 6 closes verified production-contract gaps, makes encrypted-record failures recoverable, and improves startup reliability without weakening Miloom's privacy boundaries.

## 6.0 Production reliability audit

- [x] Create the dedicated `codex/phase-6-reliability` branch from the completed Phase 5 baseline.
- [x] Compare the local migration ledger with the linked production ledger.
- [x] Inventory production Miloom/Plaid tables and RPCs used by the iOS app and Edge Functions.
- [x] Confirm the missing Owner Briefing RPC is a production contract gap rather than an iOS decoding failure.
- [ ] Capture a production schema/policy backup before any repair.
- [x] Verify dependency and aggregate row-count assumptions without exporting user data.

### Verified findings

- The initial migration ledger was divergent: fourteen local migrations were not recorded remotely, while four older remote versions had no matching local migration file. Several newer objects were applied outside the recorded migration history.
- The four remote-only migration files are now restored locally. Nine newer versions whose complete object contracts were verified in production were repaired as applied in the remote history. The ledger now isolates five genuinely missing Miloom foundation migrations instead of mixing them with already-present Plaid and alert work.
- Production contains the Plaid reconciliation/sync and alert-rule contracts, but the Miloom foundation tables are absent: `user_entitlements`, `usage_buckets`, `resource_connections`, `obligations`, `device_push_tokens`, `product_events`, `briefing_deliveries`, and `critical_alert_deliveries`.
- Production is missing the foundation and Owner Briefing functions, including `get_miloom_access_snapshot`, `consume_miloom_usage`, `refresh_miloom_connections`, `refresh_miloom_obligations`, `refresh_my_miloom_obligations`, `refresh_miloom_subscription_insights`, and `maintain_miloom_downgrades`.
- The deployed `send-briefings` function depends on missing tables and RPCs, so weekly production push delivery is not release-ready even though the function itself is active.
- Production SQL lint reports one pre-existing `share_resource` function error: its `ON CONFLICT` clause does not match a unique or exclusion constraint. No matching function definition exists in the current repository, so it must be captured from production and repaired in a new migration rather than guessed.
- Replaying the old foundation migrations unchanged is unsafe: they also install entitlement-enforcement triggers and can immediately alter free-tier write behavior. Phase 6 will use an explicit reconciliation migration and activate enforcement only after a separate product decision.
- Aggregate-only verification found 9 users, 8 companies, 13 subscriptions, 11 institutions, 16 cards, 3 loans, 3 documents, 19 Plaid Items, and 63 alert rules. No user-owned row contents were exported.
- The CLI schema-only backup is currently blocked because Docker/`pg_dump` is unavailable on this Mac. The linked Supabase project also reports no physical backups and PITR disabled. No production mutation will run until an alternative verified recovery path is established or the repair is proven additive, transactional, and reversible with a rehearsed rollback.

## 6.1 Reconcile the production contract

- [x] Prepare the missing additive tables, indexes, RLS policies, least-privilege grants, and briefing/connection RPCs for reconciliation.
- [x] Keep monetization enforcement triggers and destructive downgrade maintenance disabled until entitlement behavior is reviewed and approved.
- [x] Rehearse the migration twice against an isolated production-shaped PostgreSQL fixture and run contract/security assertions.
- [ ] Capture a restorable production backup/PITR point (not available on the current Supabase plan).
- [x] Apply the reviewed additive migrations transactionally after explicit risk acceptance.
- [x] Restore remote-only migration files locally and reconcile the nine verified, already-present production versions in migration history.
- [x] Apply and record the five genuinely missing foundation versions.
- [x] Verify authenticated Owner Briefing refresh, access snapshot, and push-token registration with a rollback-only production smoke test.
- [x] Add and deploy a no-write `send-briefings` dry-run path; production version 5 is active with privacy-safe diagnostics.
- [ ] Invoke the deployed `send-briefings` dry run from the scheduler/secret holder and retain the aggregate-only result.

### Rehearsal evidence

- Supabase preview branching was unavailable on the current organization plan;
  the attempted branch creation returned `402` and created no resource.
- PostgreSQL 17 was installed as a local development tool. A temporary database
  under `/private/tmp` used schema fixtures only and was removed after testing.
- All five migrations executed successfully inside per-migration transactions,
  then executed successfully a second time to verify idempotency.
- Assertions verified required tables, disabled enforcement triggers,
  least-privilege RPC/table grants, owner-scoped entitlement RLS, StoreKit
  fallback for uninitialized entitlements, and non-mutating downgrade behavior.
- An authenticated production smoke test refreshed Owner Briefing obligations,
  confirmed the expected StoreKit fallback, and exercised push-token
  insert/read/delete access inside a rolled-back transaction.
- `send-briefings` version 5 is deployed with a `dry_run` request mode that
  validates its secrets and read contracts without performing RPC or table
  writes and without contacting APNs. Invocation remains pending because the
  cron secret is intentionally not stored in the repository or local shell.

## 6.2 Encrypted-record recovery

- [x] Inventory which encrypted fields fail authentication after reinstall or device-key loss without logging ciphertext or plaintext.
- [x] Render affected values as locked/unavailable instead of repeatedly emitting generic decryption errors.
- [x] Add an owner-driven replace-or-clear recovery flow; never silently discard encrypted data.
- [x] Add unit coverage for current, legacy, corrupted, and unavailable-key payloads.

### Verified encryption findings

- AES-GCM protects subscription passwords, institution passwords, card passwords,
  and institution account, routing, and wire-routing numbers.
- The symmetric key is device-only Keychain data. Records can therefore become
  unreadable after device/key loss even though their encrypted database values
  remain intact.
- Authentication failure currently becomes `nil` plus a generic console line,
  which makes a locked secret indistinguishable from a field the owner never
  entered. Malformed `enc:` Base64 can also flow back to the UI as ciphertext.
- Recovery must preserve the original encrypted value until the owner explicitly
  replaces or clears it; automatic re-save of a locked field would cause data loss.
- Failed decryption now retains the original `enc:` payload in memory, so an
  unchanged save preserves the database ciphertext. UI helpers render a locked
  label and prevent copying, sharing, revealing, or reading the payload aloud.
- Institution, subscription, card, and bank-account editors support explicit
  replacement and clear actions. Four focused CryptoKit tests cover round-trip,
  legacy plaintext, malformed payload, and wrong-key preservation behavior.

## 6.3 Startup performance and resilience

- [x] Measure authenticated first paint and identify the slowest production queries.
- [x] Consolidate five overlapping `companies` SELECT policies into one indexed,
  owner/share/invitation-aware policy after company reads repeatedly took about
  10–12 seconds and timed out.
- [x] Preserve immediate company rendering while moving noncritical domains behind progressive loading.
- [x] Add bounded retry/backoff and visible partial-data state for recoverable company-load failures.
- [x] Evaluate a privacy-safe local snapshot only if query/index work cannot meet the startup target; it is not currently needed because the corrected production query executes in about 11 ms.

### Startup evidence

- Before policy consolidation, the authenticated company request repeatedly took
  about 10–12 seconds and could leave the dashboard empty after sign-in.
- After consolidation, `EXPLAIN (ANALYZE, BUFFERS)` under the authenticated role
  returned both accessible companies in 11.423 ms.
- The app now retries the first-paint company request twice with bounded backoff,
  preserves already-rendered companies on refresh failure, and exposes a compact
  retry banner instead of silently showing an empty portfolio.

## 6.4 Observability and release validation

- [x] Add structured, privacy-safe diagnostics for auth, sync, briefing, push, and decryption failures.
- [x] Add contract smoke tests that fail when required production tables/RPCs are absent.
- [x] Run backend tests, the iPhone 17 Pro suite, signed archive/export, and the FX physical-device smoke test.

### Release-validation evidence

- The production-shaped PostgreSQL contract rehearsal passed twice and its
  disposable database was removed afterward.
- The iPhone 17 Pro iOS 26.4 test suite passes.
- A signed Release archive and development IPA export completed with team
  `WYYJ6FGYRP` and bundle identifier `com.vibing.miloom`.
- The archived app installed and launched successfully on the paired FX iPhone;
  the Miloom process remained running after launch.
- Diagnostics use OSLog-style structured fields and numeric error codes only;
  they do not record emails, user/resource identifiers, tokens, ciphertext,
  merchant details, account details, or credential values.

## Completion criteria

Phase 6 is complete when production schema history is trustworthy, every deployed app/function dependency exists and is permissioned correctly, encrypted-record failures are recoverable without disclosure or silent loss, authenticated startup remains responsive under partial failure, and signed simulator/physical-device validation passes.
