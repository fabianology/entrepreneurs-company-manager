# Frozen collaboration, sharing and vault checkpoint

Date: 2026-09-23. Canonical branch `codex/phase-7-notification-experience`,
base `07499ec1` plus uncommitted changes. This is neither a release approval nor
an independent security review. Detailed evidence remains in
`COLLABORATION_UI_ACCEPTANCE_20260922.md`.

## Closed checkpoint

Native owner recovery and two-device reveal, one readable legacy card password
migration, explicit scoped Editor request/approval/decrypt, plaintext clearing
after backgrounding, denial after exact-share revocation, resource key
replacement without carrying grants forward, and owner reveal after replacement
all have incremental staging evidence. Hosted disposable accounts, records,
files and vault grants were removed and absence verified. Do not recreate them
to repeat these passed checks outside the final candidate acceptance.

## Checkpoint commits

User authorized the scoped commits after review:

- `080bcbb3`: native vault corrections (group 1 below).
- `01009b48`: native save/retry corrections and tests (group 2).
- `53e8adfa`: backend cleanup correction and contract evidence (group 3).
- Evidence documentation is committed separately after these code commits.

No push or deployment is included. The remaining dirty checkout is unrelated
work; a clean candidate has not yet been built from these commits.

Fresh verification: 41 tests passed, zero failed/skipped, across
`ActiveSessionsTests`, `ResourceVaultCryptographyTests` and
`ResourceSecretPreparationTests`. Result bundle:
`/private/tmp/miloom-bounded-checkpoint-20260923-review.xcresult`.
The build used established staging-only simulator overrides. This verifies the
selected regression suites on the dirty checkout, not all native acceptance on
a clean candidate. `git diff --check` also passed.

1. Native vault corrections: `DataRepository.swift`, `AdminSettingsView.swift`,
   `SharedItemOverrideBanner.swift`. ID-only mutation receipts with nonempty-row
   checks; one typed alert presenter; preserve pending reveal through biometric
   inactivity while invalidating it on background/disappearance.
2. Earlier native acceptance corrections: `SupabaseService.swift`,
   `AppViewModel.swift`, `DocumentListView.swift`, `FinancialView.swift`,
   `LoanPaymentHUD.swift`, `AddSubscriptionWizard.swift`, and
   `ActiveSessionsTests.swift`. Confirmed save/retry behavior and staging-only
   failure injection. These are separate from the latest vault fixes.
3. Backend acceptance correction/evidence: migration
   `202609230001_fix_orphan_document_uuid_filter.sql`,
   `document_orphan_uuid_regression.sql`, current-role adjustments in
   `canonical_resource_access_contracts.sql` and
   `invitation_lifecycle_contracts.sql`, plus scoped-vault rehearsal script and
   containment assertions. Orphan migration is already on staging only.
4. Evidence: this reconciliation, native acceptance record and staging runbook.

Exclude unrelated Plaid edits, account-deletion implementation, business-expense
tests, web OAuth files, `.temp` configuration, project/signing changes, workspace
outputs and coordination instructions. A clean candidate must deliberately
exclude these changes rather than blanket-stage the current checkout.

## Remaining completion gates

| Gate | Remaining bounded work |
| --- | --- |
| 1 Roles/scopes | Consolidate recorded role/scope checks into the final candidate matrix; test only uncovered permission boundaries, not general app behavior. |
| 2 Lifecycle | Actual delivered invitation email and native link opening for existing/new users. Staging provider key/sender and staging association/redirect setup are prerequisites. Existing API/native Send results are not this test. Final matrix must retain resource/entity removal, owner block and revoked-access coverage. |
| 3 Documents | Incremental checkpoint passed; rerun the defined upload/open/replace/remove/retry/revocation cases on the final candidate, without adding document features. |
| 4 Scoped vault | Close remaining migration preservation (locked values/account numbers), native cross-scope/device isolation, and in-flight reveal background/dismissal boundaries. Keep global collaborator-secret activation closed. Completed single-card evidence does not prove every boundary. |
| 5 Release safety | Establish minimum supported client and upgrade/cutover handling: old full-row reads are incompatible with current staging restrictions. Preserve containment rollback evidence. Independent security review of exact candidate remains the final external gate. |
| 6 Deliverable | Authorized scoped commits, one clean staging build, bounded checklist on that exact build and final handoff. Do not call dirty incremental builds the candidate. |

Original phases remain 0 containment, 1 contracts, 2 personal vault,
3 nonsecret collaboration, 4 scoped secrets, 5 revocation/rotation,
6 management and 7 acceptance/rollout. All retain **In progress** status against
their full acceptance criteria, not because implementation is absent. Production
rollout is **Not started** and requires separate explicit authorization.

Next execution target: checkpoint verification and authorized commit preparation,
then remaining gate 4 boundary tests on the candidate. Email setup is a separate
gate 2 prerequisite; do not weaken security or enable sharing to bypass it.
