# Tax Opportunities implementation handoff

The main entry is the full-width Tax Opportunities row immediately below Spending by Category in the portfolio Transactions sheet. It is also available when the selected cash-flow period is empty. Transaction details and account transaction rows open the same business-review flow. The feature remains independent of payment accounts and cash-flow calculations.

## Implemented contracts

- One feature-level consent includes all current/future owned accounts; exclusions and per-Entity activity descriptions are optional configuration controls. No automatic business confirmation.
- First-time Screening Settings preselects the screening toggle on locally. Save or Save and scan activates the choice; Cancel leaves server consent unchanged. Previously saved settings, including an explicit off choice, are preserved.
- Separate review, allocation, suggestion, evidence, audit, source-alias, job and export records. All feature writes go through owner-validating RPCs. One active Entity allocation per purchase, with business use in basis points.
- AI processing is server-side, uses only a bounded whitelist of transaction/context fields, validates evidence IDs, and renders explanations from verified evidence rather than model prose. Receipts/OCR and financial credentials never enter this pipeline.
- Pro gating and idempotent usage reservation happen server-side. Manual review, private receipt capture, exceptions and CSV export do not use the Pro edit gate.
- Source mutation/removal and bank deletion preserve review history with explicit validity states. Provider reconciliation uses existing replacement links rather than a new merchant/amount deduplication algorithm.
- The receipt picker retains failed uploads in memory for retry while the sheet remains open; it never reports a local-only file as uploaded. General offline editing and durable upload retries are not implemented.
- Export rows are server snapshots with revisions; CSV handles quoting and spreadsheet formula injection. Optional receipts are individual selected files in the native share sheet. No QuickBooks posting or Quicken-specific format is included.
- CompanyDocument uses `owner_private` visibility for receipt metadata and restrictive RLS, with sharing guards. Receipts use the existing private bucket and a private object-name prefix. Deletion queues storage cleanup for the authenticated cron worker.

## Production status (2026-09-07)

The initial backend is deployed to Miloom (`xxqdytdbpiqjilhutvhz`):

- Applied migrations `202609070001_business_expense_review`, `202609070002_business_expense_scheduler`, and `202609070003_account_deletion_storage` atomically and recorded their migration history.
- Deployed `screen-business-expenses` with gateway JWT verification disabled. The handler validates user JWTs and ownership or the existing cron/service credential. Deployed `delete-user-account` with its existing gateway verification retained; it removes owned files through the Storage API before Auth deletion and uses the deployed company-owner column.
- Configured the Vault screening URL, verified the existing Vault cron secret matches Edge configuration, and activated the two-minute scheduler. A synthetic queued job was picked up by cron without the app driving it.
- Verified that the deployed Gemini key belongs to the Miloom Tier 1 prepay project with positive billing credit. The key was compared by digest without printing or changing its value.
- **AI screening is enabled following explicit approval of the Gemini financial-context disclosure.** Set `BUSINESS_EXPENSE_MODEL=gemini-3.5-flash` and `BUSINESS_EXPENSE_PAID_AI_ENABLED=true`. The existing provider key was retained. Individual users must still enable the feature-level opt-in; activation did not change any existing user's consent.

Account credentials, account numbers, receipt images, and OCR are excluded from the AI pipeline. Manual reviews, receipts, and exports remain available independently of AI screening.

Account deletion removes owned Storage files before unlinking banks and deleting Auth records, stops on file-list/removal failures, and supports retries. The Auth trigger also queues private receipt cleanup as a fallback. Retained backups and downloaded exports follow their separate retention policies.

## Verification

Native domain coverage is in `ZifrTests/BusinessExpenseTests.swift`; existing transaction tests remain in `PremiumEngineTests.swift`. Pure backend policy tests are in `supabase/functions/_shared/business_expenses_test.ts`. Database ownership, immutability, receipt privacy and export tests are in `supabase/tests/business_expense_contracts.sql`; run against a disposable database only.

Future work from the roadmap: explicit merchant-rule invitations, multiple-Entity allocations, manually entered purchases, accountant collaboration, refund/reimbursement matching, and QuickBooks/Quicken adapters. These are not part of the initial release.

### Verification recorded on 2026-09-07

- Zifr simulator build and all 65 Swift tests passed on the available iPhone 17 Pro simulator.
- Nine pure Deno policy tests passed; the screening Edge Function type-check passed with the repository's Deno configuration.
- Both migrations applied successfully to an isolated PostgreSQL 17 fixture database. Contract tests passed for ownership, financial-source preservation, revisions, immutable exports, private receipts, bank removal, source aliases, stale consent, and persistent-account exclusions. This fixture rehearsal does not establish compatibility with the live deployed schema.
- `git diff --check` passed. Existing unrelated working-tree changes were preserved; nothing was staged or committed.
- The simulator opened to sign-in, so no authenticated UI smoke test or live financial-data/model test was performed.

### Live compatibility check and rollout preparation (2026-09-07)

- Verified the linked project is Miloom (`xxqdytdbpiqjilhutvhz`), PostgreSQL 17.6, and the existing Supabase CLI login is usable. Inspected catalog metadata without reading application transaction rows or secret values.
- Captured 208 column definitions across 14 relevant public/Storage tables, 61 public constraints, the document/Storage policies, and the policy helper definitions. Reconstructed these locally, with stub Auth identity functions, and successfully applied all three migrations. This is a focused compatibility rehearsal, not a full Supabase environment clone.
- All database contract scripts passed, including normal shared-document visibility versus private-receipt isolation, owner-scoped deletion inventory, denied anonymous/client inventory access, and account-deletion cascades while reviewed transactions exist. The fixtures now satisfy live Plaid foreign keys and required fields.
- All 13 Deno tests passed (nine screening policy tests and four Storage-cleanup failure/pagination tests). Both Edge Functions type-check. Native code did not change during this activation check; the earlier native test result above was not rerun.
- The live `CompanyDocuments` bucket is private and both relevant tables have RLS enabled. `pg_cron`, `pg_net`, and Vault are installed. Existing `briefing_cron_secret`, `CRON_SECRET`, and `GEMINI_API_KEY` configuration was preserved.
- Prepared an atomic three-migration script with migration-history entries, a duplicate guard, and a five-second lock timeout at `/private/tmp/miloom-tax-activate.sql`. The deployed deletion-handler backup and schema metadata are also in task-specific temporary files. Regenerate the activation script if a migration changes.
- The subsequent request to keep implementing authorized the database, function, and scheduler rollout described above. The user subsequently approved the Gemini disclosure and AI activation.

### Live end-to-end verification (2026-09-07)

- Passed 25 checks using two marked synthetic Auth identities and synthetic financial/document records: free manual mixed-use review, source preservation, receipt completeness, mutation retries, export validation and immutable snapshots, signed receipt download, cross-owner receipt/review/worker isolation, ordinary shared-document visibility, one feature-level consent, Pro enforcement, anonymous worker rejection, background cron pickup, and zero AI usage while paused.
- Deletion checks exercised the deployed account-deletion endpoint for both synthetic identities and verified removal of their Auth identities, reviews, exports, document metadata, companies, and receipt object. The fake Plaid item was removed before invoking deletion so no synthetic token reached Plaid. Temporary test credentials were removed after cleanup.
- A normal simulator build passed with the existing signing configuration. Authenticated visual checks confirmed the Tax Opportunities row immediately below Spending by Category, a loading-error-free feature home, and a single feature-level opt-in that remains off. No review or consent was saved for the existing simulator user.
- The earlier 65 Swift tests and 13 Deno tests remain the applicable code-test results; native implementation did not change during rollout. AI activation and inference verification are recorded separately below.

Supabase documents the Storage ownership prerequisite for Auth deletion at https://supabase.com/docs/guides/auth/managing-user-data.

### Approved AI activation verification (2026-09-07)

- Following the user's explicit approval, enabled the paid-provider gate and `gemini-3.5-flash` on the existing billing-verified project. Existing user consent settings were unchanged.
- The real background scheduler completed a synthetic two-purchase scan with one AI suggestion. The manually confirmed purchase remained unchanged, and the generated suggestion remained unreviewed without an allocation.
- Verified the screened-input fingerprint, Entity/evidence references, and model version. Exactly one batch reservation and one AI action were recorded; retrying the completed job consumed no additional action.
- All 29 checks in this activation run passed: 16 review/privacy/export/access checks, six AI completion/validation/usage checks, and seven account/receipt cleanup checks. Both marked test accounts and their receipt were removed through the deployed deletion endpoint. Temporary credentials were removed after cleanup.
- No source implementation changed during this activation; the handoff was updated. No commit was created.

### Vault receipt organization (2026-09-07)

- Expense refresh now reconciles the owner's private CompanyDocument records into the Vault immediately after upload, unlink, and Entity reassignment. It preserves unrelated/shared documents and references the original file without creating a second copy. The existing backend assigns the receipt to the business allocation Entity and updates that assignment when changed.
- Receipts has search, year/category filters, and month groups ordered by purchase date. Linked cards show merchant, expense category, original paying Entity/account, purchase amount, business portion, and review status, with signed file opening and a direct expense-review link. Standard Vault receipts remain visible as unlinked/uncategorized and use upload dates when available; missing dates stay undated. Multiple files are counted as receipts, without summing the same purchase repeatedly.
- Six focused Swift expense tests passed, including purchase-date grouping, business Entity versus paying Entity, mixed-use amounts, search, standalone receipts, and undated ordering. Simulator verification confirmed a receipt under Yager with Fabian retained as payment source, and its PDF opened successfully. No real review or receipt was modified for this check.
- Backend contracts and sharing policies did not change. Files remain owner-private; accountant sharing still uses the explicit export flow. No commit was created.
