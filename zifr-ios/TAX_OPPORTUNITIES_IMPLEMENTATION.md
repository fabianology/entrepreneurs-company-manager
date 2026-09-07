# Tax Opportunities implementation handoff

The main entry is the full-width Tax Opportunities row immediately below Spending by Category in the portfolio Transactions sheet. It is also available when the selected cash-flow period is empty. Transaction details and account transaction rows open the same business-review flow. The feature remains independent of payment accounts and cash-flow calculations.

## Implemented contracts

- One feature-level consent includes all current/future owned accounts; exclusions and per-Entity activity descriptions are optional configuration controls. No automatic business confirmation.
- Separate review, allocation, suggestion, evidence, audit, source-alias, job and export records. All feature writes go through owner-validating RPCs. One active Entity allocation per purchase, with business use in basis points.
- AI processing is server-side, uses only a bounded whitelist of transaction/context fields, validates evidence IDs, and renders explanations from verified evidence rather than model prose. Receipts/OCR and financial credentials never enter this pipeline.
- Pro gating and idempotent usage reservation happen server-side. Manual review, private receipt capture, exceptions and CSV export do not use the Pro edit gate.
- Source mutation/removal and bank deletion preserve review history with explicit validity states. Provider reconciliation uses existing replacement links rather than a new merchant/amount deduplication algorithm.
- The receipt picker retains failed uploads in memory for retry while the sheet remains open; it never reports a local-only file as uploaded. General offline editing and durable upload retries are not implemented.
- Export rows are server snapshots with revisions; CSV handles quoting and spreadsheet formula injection. Optional receipts are individual selected files in the native share sheet. No QuickBooks posting or Quicken-specific format is included.
- CompanyDocument uses `owner_private` visibility for receipt metadata and restrictive RLS, with sharing guards. Receipts use the existing private bucket and a private object-name prefix. Deletion queues storage cleanup for the authenticated cron worker.

## Backend activation (not performed by the source implementation)

1. Rehearse and apply `202609070001_business_expense_review.sql`, then `202609070002_business_expense_scheduler.sql`. Review deployed schema compatibility first; the repository has historical ad-hoc SQL scripts as well as migrations.
2. Deploy `screen-business-expenses` with gateway JWT verification disabled so the existing `x-cron-secret` mechanism works. The handler itself validates user JWTs and ownership, or the configured cron secret/service credential.
3. Keep the existing `GEMINI_API_KEY`, and set `BUSINESS_EXPENSE_MODEL` to the provisioned, supported Gemini structured-output model. Explicitly set `BUSINESS_EXPENSE_PAID_AI_ENABLED=true` only after verifying a billing-enabled provider project and the applicable data terms. Missing configuration pauses screening without breaking manual reviews.
4. Reuse the existing Edge Function `CRON_SECRET` and Vault `briefing_cron_secret`. Add Vault secret `business_expense_function_url` with this project's `/functions/v1/screen-business-expenses` URL. When pg_cron, pg_net and Vault are available, the scheduler migration registers the two-minute job. Without the URL/secret it makes no requests.
5. Verify the scheduler completes work while the app is closed. It also services private-file deletion requests. An open Tax Opportunities screen can process the authenticated owner's scan batches, but this is not a substitute for background scheduling.
6. Inspect the deployed `delete-user-account` function, whose source is absent from this checkout. The new auth.users deletion trigger queues private receipt files; verify the actual account-deletion path deletes auth.users and that the cron cleanup worker succeeds. Retained backups and downloaded exports follow their separate retention policies.

No live migration, model call, function deployment, or production scheduler change was performed during implementation. Do not claim AI is live until the above activation and provider checks have passed.

## Verification

Native domain coverage is in `ZifrTests/BusinessExpenseTests.swift`; existing transaction tests remain in `PremiumEngineTests.swift`. Pure backend policy tests are in `supabase/functions/_shared/business_expenses_test.ts`. Database ownership, immutability, receipt privacy and export tests are in `supabase/tests/business_expense_contracts.sql`; run against a disposable database only.

Future work from the roadmap: explicit merchant-rule invitations, multiple-Entity allocations, manually entered purchases, accountant collaboration, refund/reimbursement matching, and QuickBooks/Quicken adapters. These are not part of the initial release.

### Verification recorded on 2026-09-07

- Zifr simulator build and all 65 Swift tests passed on the available iPhone 17 Pro simulator.
- Nine pure Deno policy tests passed; the screening Edge Function type-check passed with the repository's Deno configuration.
- Both migrations applied successfully to an isolated PostgreSQL 17 fixture database. Contract tests passed for ownership, financial-source preservation, revisions, immutable exports, private receipts, bank removal, source aliases, stale consent, and persistent-account exclusions. This fixture rehearsal does not establish compatibility with the live deployed schema.
- `git diff --check` passed. Existing unrelated working-tree changes were preserved; nothing was staged or committed.
- The simulator opened to sign-in, so no authenticated UI smoke test or live financial-data/model test was performed.
