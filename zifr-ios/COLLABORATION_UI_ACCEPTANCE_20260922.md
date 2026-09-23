# Collaboration staging UI checkpoint — 2026-09-22 PDT

This is a partial acceptance record, not a production release approval.

## Environment

- Checkout: canonical MILOOM repository, branch `codex/phase-7-notification-experience`.
- Base commit: `f08635e8`, with local changes; not a clean release candidate.
- Backend: **Miloom Staging** (`bvtuyzhyospqxvpzcrmv`) only.
- App: `com.vibing.miloom.staging`, build 12, Debug simulator.
- Disposable iPhone 17 Pro / iOS 26.4: `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`.
- No physical-phone installation, production deployment, Face ID removal,
  project signing change, commit, or push in this checkpoint.

## Simulator launch and secure session storage

The normal Xcode simulator build launches and securely persists its Supabase
session. Native email sign-in, process termination/relaunch, an incremental app
update, and native company creation all succeeded with the session-storage guard
enabled. No database policy was relaxed.

Xcode generated `Zifr.app-Simulated.xcent` containing the staging
`application-identifier` and embedded simulator entitlements in the main Mach-O
executable's `__TEXT,__entitlements` and `__TEXT,__ents_der` sections.
`codesign -d --entitlements -` alone showed an empty dictionary; that is **not**
proof that the simulator app lacks its simulated entitlements. Earlier manually
re-signed copies failed to launch. The exact low-level reason for those launch
denials was not established; manual re-signing is unnecessary for this workflow.

Use Xcode-managed simulator signing, with command-line-only staging overrides:
`CODE_SIGNING_ALLOWED=YES`, `CODE_SIGN_IDENTITY='Apple Development'`,
`DEVELOPMENT_TEAM=WYYJ6FGYRP`, and
`PRODUCT_BUNDLE_IDENTIFIER=com.vibing.miloom.staging`. Supply staging Supabase
configuration through the existing secure build workflow. Do not manually
re-sign the resulting app or embed an iPhone provisioning profile. Do not
install over the original simulator or phone to reproduce these tests.

## Evidence collected

| Case | Result and boundary |
| --- | --- |
| Owner native sign-in and relaunch | Passed; secure session guard accepted the stored session. |
| Native company creation | Passed and confirmed in staging; earlier RLS symptom was not reproduced. |
| Accessible company controls | Native labeled Share/Edit buttons exposed correctly; Share opened the intended sheet. |
| Native Send toolbar action | Not verified. Screen-control coordinate clicks failed; no claim of email delivery or completed send tap-through. |
| Company Viewer | Native dashboard and service/document screens were read-only; no company Edit/Share controls. |
| Viewer credential isolation | Native service hid credentials; authenticated redacted RPC returned neither login nor password. |
| Owner-private document | Owner saw two documents; Viewer and Admin saw only the one entity-visible document. |
| Resource revoke | Owner RPC removed one direct share; the existing Viewer app session lost the company after relaunch. Not a claim of instantaneous foreground/offline cache invalidation. |
| Exact service Editor | Before fix: service edit incorrectly hidden. After fix: only the granted service was visible and its native edit form opened. The unrelated service and both documents remained hidden. Full native Save is still unverified. |
| Entity Admin | Native dashboard showed both services and the entity-visible document. Backend Viewer grant succeeded; an attempted Editor grant through the owner endpoint was denied with `RESOURCE_NOT_OWNED`. |
| Admin removes Viewer | Native management offered only Remove from This Resource, with explanatory scope copy. Removal succeeded and share count changed from 3 to 2. |

Shares used for this test were prepared through the canonical signed-in Owner
and Admin RPCs, not by bypassing role checks with a service-role insert. Fixture
accounts and cleanup used the staging Admin API. All data was synthetic.

## Local corrections

- Preserve the fail-closed sign-in guard when Supabase cannot read back the
  session it just attempted to save. The prior missing-entitlement failure path
  remains separately verified; this checkpoint verifies the successful path.
- Company Edit/Share and service Edit use labeled native buttons and 44-point
  targets, preserving existing premium styling.
- Company role lookup requires an actual company share for the current user;
  collection grants sharing the company ID cannot masquerade as entity roles.
  A resource-only company shell displays Limited access.
- Service cards and their edit form evaluate the exact item/collection grant,
  including company Viewer plus a separate service Editor. Editors do not get
  collaborator-management controls; owner/entity Admin retains them.
- Admin description now reflects implemented Viewer-management rights.

## Automated checks

Simulator build succeeded. `ZifrTests/ActiveSessionsTests` passed **9 tests,
0 failures**, including expanded exact-service, sibling denial, collection
scope, and mixed Viewer/Editor assertions. `git diff --check` passed.
These tests do not cover all UI presentation or save paths.

## Cleanup and next gates

All three disposable Auth users were deleted and returned 404 on lookup. Exact
fixture queries confirmed zero remaining test companies, services, documents,
and shares. No Storage files were created. The disposable app was signed out.
No pre-existing staging account or real vault was reset or removed.

Next: complete per-item/collection Editor permission wiring and native
acceptance for institutions, cards, loans, and documents. Source inspection
found remaining company-wide `canEdit` propagation and first-matching-share
checks in those views; do not assume service results prove those flows.
Also verify collection creation controls, mixed-role native saves, native
Send/universal-link acceptance, foreground revocation and offline caches,
document upload/open/replace/remove and orphan/retry cases, and the separate
two-device scoped-secret/vault rotation/recovery matrix. Initial secret cutover
remains closed; password sharing has not been enabled.

Before release: finish that matrix, old-client compatibility and rollback
rehearsal, independent security review, credential-rotation prerequisites and
monitoring, then produce a clean committed/pushed TestFlight candidate. A
production rollout requires its own explicit approval.

## Continuation — financial/document item permissions

The preceding checkpoint was committed locally as `b80c627d`
(`Fix simulator sign-in safety and scoped service editing`). It was not pushed.
The following continuation is implemented locally after that commit:

- Financial decks resolve each institution, card and loan independently. Loan
  payment/paid-status controls follow the loan grant, not the bank's grant.
  Institution-only editing does not unlock linked cards, loans, or creation.
- Financial edit sheets no longer use the first matching share or assume an
  absent share means editable. Exact/collection Editors work alongside a
  company Viewer share regardless of ordering. Missing identity/access denies
  editing; owners retain existing list-level Free/Pro restrictions and the
  mutation layer continues to enforce them.
- Document editing/deletion follows the exact document/collection grant.
  Owner-private documents remain excluded from collaborator editing and all
  sharing controls. Receipt review remains owner-only. Once reflected in app
  state, empty/removed grants disable an already-presented document form and
  file-upload control; automatic foreground revocation is still unverified.
- Sharing controls require owner or actual entity Admin authority, separate
  from edit authority. The existing ShareEntitySheet still limits Admins to
  Viewer management. Bank sync/unlink/reconnect remains owner-only, consistent
  with the existing server/mutation contract; it was not broadened for Admins.
- Saving a collaborator's card no longer also attempts to save its linked
  bank/credentials. Deleting a shared card does not offer to unlink its bank.
- Institution Edit has a native labeled 44-point target. Existing premium
  materials/styles are retained; no Face ID or password-sharing change.

Final Xcode simulator build/test succeeded on the same disposable staging
simulator. `ZifrTests/ActiveSessionsTests` passed **12 tests, 0 failures**, with
new regression matrices for four exact item types, sibling/type/actor denial,
mixed-role ordering, collection boundaries, sharing authority, owner-private
documents and owner edit restrictions. Result bundle:
`/private/tmp/miloom-ui-financial-scopes-final-20260922.xcresult`.
`git diff --check` passed. The rebuilt app also launched to its signed-out
native login screen. No staging fixtures were created or modified in this
continuation; no production, phone, original simulator, project signing, or
backend changes were made.

These checks do **not** verify native financial/document Save, payment
persistence, upload/remove, or the changed screens' visual acceptance with
live roles. Those are the next acceptance step, including mixed company
Viewer + exact Editor and role revocation while a form is open. Collection
creation controls intentionally remain at their existing company-level gate
pending a separate creation-policy/UI pass. The native Send, two-device vault,
old-client, independent security review and production-release gates above
remain open. This continuation is not yet committed or released.

## Continuation — native saves and atomic shared-loan ledger (2026-09-22)

Base commit `b80c627d`, canonical branch `codex/phase-7-notification-experience`.
The user explicitly approved implementing, deploying and testing the discovered
loan backend contract fix on **Miloom Staging only**. No production, physical
phone, original simulator, signing/project/entitlement, Face ID, or password
sharing change was made. Source changes in this continuation are uncommitted
and unpushed; this is not a production release.

### Native mixed-role acceptance

On disposable simulator `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`, staging build 12,
created two synthetic confirmed accounts (no emails) and one company with a
company Viewer grant plus exact bank/card/loan/document Editor grants. Native
sign-in, actual toolbar Save, and server-side exact-row checks verified:

- Bank, card, loan-name and document-name edits persisted. Sibling records
  remained unchanged. The linked read-only bank was not mutated by card Save.
- Read-only card fields/actions were disabled with no Save; a read-only
  document did not open an editor. Owner-private document was excluded.
- Revoking the exact document Editor grant while its form was open prevented
  the attempted new name from reaching the server. The old document form
  dismissed without a visible error; draft/error UX is still a follow-up.
- The first loan Save exposed a real bug: loan metadata updated but the $25
  payment did not persist. Owner-only `loan_payments` policies rejected the
  collaborator's separate request; `try?` swallowed it. This prompted the
  separately approved backend change below.

### Implemented and staged

- Migration `202609220030_atomic_shared_loan_payments` introduces an authorized
  loan+ledger transaction, a consistent one-snapshot read, parent/payment owner
  binding, and a revision token. Owner, exact Editor, financial collection
  Editor, and entity Editor/Admin use the existing scope model; Viewer,
  sibling, suspended, revoked and blocked writes are denied. Shared payment
  reads inherit the loan's read scope. Direct collaborator ledger writes stay
  closed; no broad owner-table access was granted.
- Parent locking plus expected revision prevents an updated client's stale
  snapshot replacing newer history. Legacy owner REST changes also advance the
  revision. Invalid/mismatched/duplicate/nonpositive payments reject the whole
  transaction. A forced late payment-insert failure in the local test restored
  both metadata and the deleted ledger.
- The first hosted stale-save test returned HTTP 504 using SQLSTATE `40001`.
  Forward migration `202609220031_loan_conflict_http_status` changes application
  conflicts to explicit `PT409`/HTTP 409. Retesting, including two simultaneous
  HTTP saves, passed: exactly one accepted, one conflict, no duplicate/lost
  payment. This does not establish the internal cause of the earlier timeout.
- Both migrations were applied individually to `bvtuyzhyospqxvpzcrmv` and
  recorded in its migration ledger. No unrelated pending migration was applied.
- Native repository uses one save RPC and returns authoritative payment/revision
  data. It no longer ignores payment failures or deletes payments separately
  before deleting a loan (the FK cascades atomically). Missing save RPCs fail
  closed; legacy-server read fallback is read-only and has no revision token.
- The main loan editor waits for server confirmation before dismissal; its
  native alert leaves the draft open on conflict/access failure. Existing
  premium styling is retained. Other save entry points also use the RPC, but
  their complete native flows have not all been exercised.

### Verification actually completed

- Local PostgreSQL 17 isolated migration-order rehearsal **009–031 passed**, with
  loan assertions for owner/Admin/Editor/Viewer permissions, precise scopes,
  blocked/revoked/suspended access, ownership spoofing, validation, stale writes,
  late-failure rollback, direct authenticated-role RLS and FK cleanup.
  Log: `/private/tmp/miloom-loan-atomic-final-local-20260922.log`.
- `node supabase/ops/staging_loan_payment_smoke.mjs --staging-only`: **28 hosted
  loan checks passed**, plus exact-fixture cleanup. Covers authenticated owner
  creation, Editor save/reload, Viewer reads/write denial, sibling isolation,
  invalid/duplicate/cross-loan IDs, stale/missing revision, direct-write denial,
  concurrent requests, legacy owner revision invalidation, ledger removal,
  revoke, and all-financials scope. One separate bank-collection prerequisite
  is explicitly reported as blocked below, not silently counted as passed.
  Log: `/private/tmp/miloom-loan-atomic-staging-smoke-20260922.log`.
- Final simulator `ActiveSessionsTests`: **15 passed, 0 failed, 0 skipped**.
  New tests cover request encoding (including explicit null revision), complete
  snapshot decoding, no optimistic overwrite on failure, authoritative revision
  retention, and revoked local edit denial. Result bundle:
  `/private/tmp/miloom-loan-atomic-final-native-20260922.xcresult`.
- Native Editor added a synthetic **$25** payment, saved, relaunched, and reopened
  the loan: the payment was present in both the actual ledger UI and staging.
  Changing the owner's record while the form remained open then produced the
  native conflict alert and preserved the draft. Revoking the exact loan share
  with that form open produced the access-denied alert. Final exact-row checks
  confirmed neither rejected save replaced the name or the $25 payment.
- `git diff --check` passed. All temporary smoke users were deleted and confirmed
  404 on each run, including failed runs. Native fixture company, records, shares
  and loan payments were removed; both native dummy users confirmed 404. No
  Storage objects were created. Simulator was signed out via the app and left
  visibly on its login screen.

### Newly identified follow-ups / release boundaries

1. **Hosted all-institutions sharing is blocked:** migration 010's RPC recognizes
   `all_institutions`, but staging's `resource_shares_resource_type_check` still
   excludes it. The real grant fails `23514`. Bank-collection loan isolation is
   verified locally only; do not call the full hosted collection flow passed.
   This separate backend constraint was not changed under the loan approval.
2. Collection creation controls remain company-gated. A shared-card editor can
   still see a “Create New” bank choice even though its save correctly skips
   bank writes. Bank/card/loan visual association is name-based, so renaming a
   bank can detach its visual children. These remain bounded follow-ups.
3. Old clients still perform legacy multi-request owner saves. Their writes
   invalidate new-client snapshots, but this update does not make old clients'
   workflows atomic. Resolve supported-version/rollout policy before release.
4. Deploy prerequisites before shipping this native save contract; otherwise
   loan saves deliberately report unavailable instead of falling back to partial
   writes. New-loan creation was verified through the API, not every native
   wizard/assistant entry point. Document upload/replace/remove, native Send and
   universal links, foreground/offline revocation, two-device scoped secrets,
   independent security review, and the clean release candidate remain gated.

## Continuation — bank collections, document save errors, native Send (2026-09-22)

Canonical branch `codex/phase-7-notification-experience`, base `b80c627d`;
task `01a0c5a0-e9ff-7fd0-8621-f256aada18f4`. User approved continuing the
recommended bank-collection fix and acceptance checks. Changes remain
uncommitted/unpushed. Only Miloom Staging (`bvtuyzhyospqxvpzcrmv`) and the
previously approved disposable simulator were used. Production, phone FX,
original simulator, project signing/entitlements and Face ID were untouched.
Password-sharing cutover remains closed.

### Implemented and verified

- Applied and recorded **032** on staging: restores `all_institutions` to the
  legacy share-type CHECK constraint. Existing type and entity-only Admin
  restrictions remain intact.
- Hosted verification then exposed a second mismatch: safe bank reads worked,
  but legacy SELECT policies caused collection Editor UPDATEs to affect zero
  rows. Applied and recorded **033**, adding institution SELECT visibility
  through the existing canonical scope helper. No column privileges changed;
  credential-bearing rows remain restricted to the safe RPC. Local tests now
  exercise actual authenticated UPDATEs, not only Boolean scope helpers.
- Local isolated PostgreSQL rehearsal **009–033 passed** with loan and bank
  collection contracts, including Editor save, Viewer/cross-company denial,
  entity-only Admin and delegation restrictions. Log:
  `/private/tmp/miloom-bank-collection-local-20260922.log`.
- Hosted smoke passed **42 checks**, plus cleanup: existing loan transaction
  matrix; bank-only direct grant/read/save; exclusion of cards, loans and
  documents; pending invitation grants nothing before acceptance; acceptance
  creates the expected bank Viewer scope; Viewer write and replay are denied.
  No email was sent. Initial fixture INSERT requested protected full-row
  RETURNING data; corrected it to the permitted ID receipt and safe read RPC,
  without relaxing server protections. Log:
  `/private/tmp/miloom-bank-collection-staging-20260922.log`.
- Main document edit sheet now awaits a confirmed save before dismissal,
  disables edits/dismissal while saving, and uses a native alert on failure.
  Draft and saved portfolio state remain separate until persistence succeeds;
  account changes prevent publication into another signed-in user's state.
  Existing premium sheet styling is retained. This does not introduce document
  metadata versioning or rewrite the separate scan/delete flows.
- Focused iOS tests **17 passed, zero failed/skipped**, including document
  failure/success, cached revoked access, offline create, and account-switch
  cases. Result: `/private/tmp/miloom-document-confirmed-native-20260922.xcresult`.
- Native exact-document Editor Save changed only the intended synthetic title.
  With the form open, owner-RPC revocation removed the Editor grant; native
  Save then showed **Document Not Saved**. Dismissing that alert left the
  unsaved draft visible in the editor; exact backend queries showed the previous
  saved title and all siblings unchanged.
- Native company-share **Send** completed both an existing Viewer regrant and
  a fresh Viewer grant to an existing dummy account. Before the fresh Send,
  the exact company grant was absent; afterward exactly one company Viewer
  grant existed for that recipient and the sheet dismissed. This verifies
  the existing-user direct-share path, not email delivery or universal links.
- `git diff --check` passed. All smoke and native fixture records/accounts
  were cleaned, Auth users confirmed 404. No Storage objects were created.
  Disposable simulator left visibly signed out on the login screen.

### Remaining acceptance / release gates

- Native collection entry-point/creation UX: `EntityHomeView` passes
  `hideActionBar: true`, so the financial action bar containing All Institutions
  was not available in the tested entity route. Backend collection acceptance
  is now verified; do not call the native collection invitation path complete.
- Native document file upload/open/replace/remove, interruption/orphan/retry
  cases; new-user invitation email and universal-link login/acceptance.
- Foreground/offline revocation, two-device vault/scoped-secret acceptance,
  remaining loan save entry points and legacy-client rollout policy.
- Previously recorded shared-card bank-create choice/name-based grouping
  issues, independent security review, clean commit/release candidate, and
  separately approved production deployment. This is not production sign-off.

## Continuation — native collection sharing and document files (2026-09-23)

Canonical branch `codex/phase-7-notification-experience`, base `b80c627d`;
task `01a0c5a0-e9ff-7fd0-8621-f256aada18f4`. This continuation changed native
source only and tested disposable fixtures on Miloom Staging. No commit, push,
migration, function deployment, production change or physical-phone install.
Face ID, signing and entitlements were not changed; secret cutover stays closed.

### Implemented and verified

- Entity header now has a native, labeled **Entity actions** menu with a
  44-point material-backed gold button. Owner/entity Admin sharing choices are
  Entire Entity, All Institutions, All Financials, All Services and All
  Documents; existing Financial/Subscription reports remain available.
  This fixes the inaccessible collection entry point in the entity route,
  without changing the still-company-gated record-creation controls.
- Share sheets explain the selected current/future scope, identify the entity
  and explicitly exclude unrelated resources, owner-private documents where
  relevant, and passwords. Existing server role/delegation rules are unchanged;
  collection roles remain Viewer/Editor for owners and Viewer-only for Admins.
- Focused `ActiveSessionsTests`: **18 passed, 0 failed, 0 skipped**, including
  the five distinct server-scope mappings. Native staging build 12 compiled and
  launched on approved disposable simulator
  `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`. Result bundle:
  `/private/tmp/miloom-collection-menu-native-20260922.xcresult`; build log:
  `/private/tmp/miloom-collection-menu-native-20260922.log`.
- Native owner menu -> All Institutions -> Editor -> **Send** dismissed the
  sheet and created exactly the intended `all_institutions`/`Editor` direct
  grant for the existing dummy recipient. The recipient's Entity actions menu
  exposed Reports only, no sharing/delegation choices. This run did not retest
  native sibling-bank Save; hosted collection read/save isolation remains the
  earlier 42-check evidence, not new native evidence.
- Native exact-document Editor **Choose Photo** uploaded the repository app
  icon, finalized the reservation under the owner's Storage prefix, saved and
  opened the actual image in the in-app browser. Replacing it with the repo
  login logo updated the document URL and queued the old object. Cancelling
  the metadata form did not undo that already-confirmed replacement; reopening
  displayed the replacement, consistent with the immediate-save explanation.
- **Remove File** confirmation cancellation preserved the attachment. Confirmed
  removal cleared the UI and server URL and queued the replacement for cleanup;
  sibling and owner-private document URLs remained unchanged. Both old objects
  were still present at immediate inspection: queueing was verified, automatic
  deletion timing was not freshly verified in this run.
- Revoked the exact document Editor grant through the owner's canonical RPC
  while the native form remained open. A further photo upload displayed a 403
  failure. Server URL stayed null; no new reservation or Storage object was
  created. Independent company Viewer access remained, as intended. The error
  is functionally correct but too technical (`Edge Function ... 403`); improve
  it to an actionable access-denied message in a follow-up.
- Signed out through the native app and verified its login screen. Cleanup
  removed only the marked dummy accounts, exact fixture company/resources/
  shares/payments and its two Storage objects via the Storage API. Verified the
  fixture Storage prefix empty, exact records absent and both Auth users 404.
  Two non-sensitive repo images remain in the disposable simulator Photos
  library. The original simulator window was temporarily minimized to avoid
  cross-window coordinate targeting and then restored; its app data was not
  changed. `git diff --check` passed.

### Remaining acceptance / release gates

- Collection record-creation UX and remaining native collection role/save
  combinations; shared-card bank-create choice and name-based grouping.
- Document Files/PDF import, external links, offline/interrupted upload,
  orphan/retry and eventual automatic deletion; polish permission-failure text.
- New-user email/universal-link login and invitation acceptance, foreground/
  offline revocation, two-device vault/scoped-secret checks, remaining loan
  save entry points and legacy-client rollout policy.
- Independent security review, clean scoped commits/release candidate and
  separately authorized production rollout. This is not production sign-off.

## Continuation — checkpoint, collection creation and file errors (2026-09-23)

User requested **commit and continue**. Committed the preceding scoped native
edit/save/sharing work, approved staging migrations 030–033 and their tests as
`5b0381ae` (`Harden scoped collaboration saves and native sharing flows`),
28 intended files only. Unrelated Plaid/account-deletion/project/web/coordination
changes were excluded. No push. The new native changes below are uncommitted.

### Implemented

- Added a separate, tested collection-creation policy. Matching collection
  Editors and company Editor/Admin grants can create only the covered record
  types; an exact-item Editor cannot create siblings. Missing actor, unknown
  types, unrelated companies/recipients and Viewer-only grants fail closed.
  Server authorization remains authoritative; no new server privilege added.
- Entity quick-add menus now use the active tab's creation scope. All
  Institutions offers manual institution creation; All Financials offers
  institutions/cards/loans. Services and documents use their own collection
  scopes. Standalone loan creation no longer requires an existing bank.
  Financial empty-state/action-bar controls use the same policy.
- Collaborators create institutions through the existing manual form, not the
  owner-only Plaid/multi-resource wizard; service creation uses the existing
  credential-restricted editor. Related card/loan Add controls resolve their
  own collection permissions and wait until the parent institution is saved.
  Shared-card editing no longer offers the misleading bank **Create New**
  choice; institution writes remain separate. Owner workflows are retained.
- Photo/file upload and shared-file removal errors use a common safe formatter:
  sign-in, permission, conflict, size, rate-limit and network problems have
  recovery guidance. Unknown/finalization failures instruct the user to reopen
  the document before retrying rather than claiming a rollback. Raw backend
  messages, signed tokens and object paths are not displayed. The preparation
  endpoint uses 403 for several reasons, so the copy does not falsely state
  that every 403 means revocation. No backend error contract changed.

### Verification and limitations

- Native staging build 12 and focused tests **23 passed, 0 failed/skipped** on
  disposable simulator `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`. New tests cover
  the creation scope/role matrix, owner gate, mixed-role ordering and safe error
  messages. Result `/private/tmp/miloom-collection-create-native-20260923.xcresult`;
  log `/private/tmp/miloom-collection-create-native-20260923.log`.
- Authenticated staging creation matrix **20 checks passed**: no-collection
  (independent exact-item grants plus company Viewer), then each of the four
  collections, against institution/card/service/document INSERTs. Allowed rows
  were stored under the original owner's company; unrelated types returned
  403/42501 and stored nothing. Each permitted test row was deleted by exact ID.
  First harness attempt used nonexistent subscription `price`; corrected the
  fixture to actual `cost`, then the full matrix passed. No production/schema
  change. Loan creation is earlier atomic-loan evidence, not a new matrix case.
- Native bank-only menu showed **Add Institution Manually** only; its draft
  opened without bank-linking, credential inputs or child Add controls. Native
  all-financials menu showed institution/card/loan creation only. Switching to
  Documents showed the passive cannot-add indicator despite the independent
  exact-document Editor grant. These are genuine native presentation checks.
- **Native new-record Save remains unverified.** Computer control returned
  `windowNotFoundAtPosition` for coordinate clicks on the toolbar Save button;
  the navigation toolbar is absent from its accessibility tree. Indexed form
  and menu controls worked. Restarting only the disposable app dismissed the
  system password-save prompt and discarded the unsaved dummy bank draft, but
  did not resolve toolbar targeting. No API write was counted as native Save.
  File-error text is unit-tested, not freshly reproduced in native upload UI.
- Signed out through the app and verified login. Removed both marked dummy
  users (confirmed 404), company/resources/shares/payments; no Storage objects
  were created this turn. Original simulator window restored after temporary
  minimization; app data, physical phone, production, Face ID, project signing
  and entitlements unchanged. `git diff --check`, script syntax checks and
  checkpoint staged-diff check passed.

Remaining: native create/save and failure/revocation acceptance for each scope,
remaining alternate creation entry points, owner/free-tier regressions, clearer
pre-save manual-institution helper copy, document retry/orphan/PDF checks,
invitation email/universal links, foreground/offline revocation and two-device
vault/scoped secrets. Existing name-based grouping and legacy-client rollout
risks, independent security review and separate production approval still apply.
Password-sharing cutover remains closed. This is not release sign-off.

## Continuation — collection failure audit (2026-09-23)

Active goal: finish native creation/save coverage for each collection and
connection-loss/revocation-with-open-form checks. Canonical branch
`codex/phase-7-notification-experience`, base `5b0381ae`. This run added tests
and evidence only; it did not fix the newly identified form behavior, commit,
push, deploy, modify production, or install on the physical phone.

### Additional verified evidence

- Native service-collection Editor: Financial shows cannot-add; Services
  exposes Add Service and opens the existing credential-restricted service
  editor. Entered a synthetic name; the Save button visibly enabled. A
  keyboard shortcut did not submit it and coordinate Save failed in the
  computer-control service. Exact staging query confirmed no service row.
- Native document-collection Editor: Financial and Services cannot-add;
  Documents exposes Add Document and opens a draft. Only the two nonprivate
  fixture documents were listed. The new document form disables file upload
  before first save, but its owner-only explanatory copy is misleading for
  a collaborator who can upload after saving. No native Save was completed.
- After all collection grants were revoked and the app relaunched, the
  independent item grants/company Viewer remained readable, and document
  Add was hidden. This is relaunch acceptance, not foreground-with-open-form
  revocation acceptance.
- Added three focused tests. Confirmed document/loan coordinators propagate
  injected disconnected, connection-lost and timeout errors for both creates
  and edits, do not publish unconfirmed state, and retain caller drafts.
  Stale cached collection grants do not override injected server denial.
  Bank/card/service coordinators reject edits when their local grant is
  already gone. Those tests do not prove the UI retains its form.
- Native build/test result: **26 passed, 0 failed, 0 skipped**, including all
  previous focused tests. Result:
  `/private/tmp/miloom-scope-failure-audit-20260923.xcresult`; log:
  `/private/tmp/miloom-scope-failure-audit-20260923.log`.
- Hosted staging **12 checks passed**: six creation attempts while allowed
  (bank-only institution; all-financials institution/card/loan; service;
  document) and six denied attempts after the owner revoked each collection.
  The same Editor JWT was reused throughout, with independent item grants
  and company Viewer retained. Successful rows belonged to the original
  owner/company; revoked writes returned 403/42501 and created no rows.
  Each synthetic row was removed by exact ID. These are API checks, not
  native Save or offline-network acceptance.

### Confirmed code-level blocker and remaining native test blocker

- `EditInstitutionSheet`, `EditCardSheet`, and `EditSubscriptionSheet` call
  fire-and-forget `saveInstitution` / `saveCard` / `saveSub`, then dismiss
  unconditionally. The coordinator publishes optimistically and rolls back
  after an asynchronous server failure. Unlike the document and loan sheets,
  these three forms cannot wait for a receipt or preserve their open draft
  on a rejected save. Code inspection establishes this behavior; this run
  did not reproduce a failed toolbar Save in the simulator. Fix and test
  these forms before release; don't call the injected coordinator tests a
  passing whole-form failure flow.
- `windowNotFoundAtPosition` remained reproducible after window positioning,
  full-screen enter/exit, bringing windows forward, and resetting/rebinding
  computer control. Indexed native fields/buttons continue to work; toolbar
  Save/Cancel are absent from the exposed tree. Requested a user-assisted
  move of the disposable simulator onto the main display. No alternative
  input-injection technology or security/signing changes were used.
- Native per-collection new-record Save, full open-form failure/retry and
  actual isolated connection-loss checks remain **unverified**. The active
  two-step goal is not complete; these narrower checks do not replace it.

Cleanup: signed out in native UI and verified login; removed marked fixture
users (Auth 404 confirmed), exact company/resources/shares/payments, with
subscriptions included in the cleanup verification. No Storage files were
created. Original simulator restored after temporary minimization; original
app data, Face ID and signing/entitlements unchanged. `git diff --check` and
fixture script syntax check passed. All new tests/evidence remain uncommitted.

## Continuation — native creation and open-form revocation (2026-09-23)

User-assisted repositioning restored coordinate input on **Miloom UI Acceptance
2026-09-22**. Actual native toolbar Save/Cancel now work. This supersedes the
earlier input blocker and unverified new-record Save status, not the remaining
connection-loss or release gates. Same disposable staging simulator, build 12,
branch `codex/phase-7-notification-experience`, base `5b0381ae`.

### Native creation results

Each row below used the app's actual form and Save button. A separate exact
staging query confirmed one saved record with the original owner's user ID and
company ID, not the Editor's. Collection grants were rotated on the marked dummy
fixture; independent company Viewer and exact-item Editor grants remained.

| Editor collection | Native-created record | Result |
| --- | --- | --- |
| All Institutions | Native Bank Collection Create | Passed |
| All Services | Native Service Collection Create | Passed |
| All Documents | Native Document Collection Create | Passed |
| All Financials | Native Financial Bank Create | Passed |
| All Financials | Native Financial Card Create (linked institution) | Passed |
| All Financials | Native Financial Loan Create ($1,000, one year) | Passed |

Bank-only Add offered only manual institution creation. Service-only and
document-only roles exposed their corresponding forms, not financial creation.
Financial Editor Add offered institution/card/loan; Services and Documents
showed **Cannot add items**. The owner-private fixture document stayed excluded.
No Plaid linking, shared credential fields, or owner-only bank side writes were
used in these creation flows.

### Revocation while the native form stayed open

The owner revoked the relevant collection through the canonical staging RPC
after each draft was entered and before its native Save was tapped. The app was
not relaunched between revocation and Save.

| Open draft | Native result | Persistence check |
| --- | --- | --- |
| New bank | **Failed:** form dismissed; global “Failed to add bank.”; draft lost | No new row |
| Existing service name edit | **Failed:** form dismissed; global “Failed to update service.”; draft lost | Original name retained; rejected name absent |
| Existing document name edit | **Passed:** “Document Not Saved”; form and edited name retained after OK | Original name retained; rejected name absent |
| New card | **Failed:** form dismissed; global “Failed to add card.”; draft lost | No new row |
| New loan | **Passed:** “Loan Not Saved”; name, principal and term retained after OK | No new row |

The retained loan draft was then retried **without re-entry** after restoring
the dummy financial collection grant. Native Save dismissed on success, and
the exact row was verified under the original owner. No loan payments were
added in this continuation. Backend authorization held in all denied cases;
the three form-dismissal failures are native UX/data-entry loss, not evidence
of a permission bypass.

### Additional issue and remaining work

- New shared-card helper text says the card may remain standalone, but Save
  stays disabled with no institution selected, and the menu has no standalone
  choice. Selecting an existing institution enables Save. Source confirms
  `canSave` requires a nonempty institution name. Resolve that inconsistency
  explicitly; the linked-card pass is not a standalone-card pass.
- Bank/card/service confirmed-save and draft-retention fixes remain required.
  An asynchronous approval request was sent for those native fixes and an
  opt-in, isolated simulator-only connection-failure test hook. No runtime fix
  or test hook was implemented in this test-only continuation.
- Whole-form connection-loss/retry remains unverified. Prior 26/26 focused
  tests cover injected coordinator errors, not actual network interruption of
  the running form. No Mac-wide network/security setting was changed.
- Alternate creation paths, owner/free-tier regressions, document file
  interruption/orphan/PDF, invitation email/universal links, two-device vault
  and scoped-secret checks, legacy-client policy, independent security review,
  and separate production authorization remain release gates. Secret-sharing
  cutover remains closed; this is not release sign-off.

Cleanup verified: native sign-out returned to the login screen; the exact
marked dummy users were deleted and returned Auth 404; fixture companies,
institutions, cards, loans, services and documents were absent. The fixture had
no Storage objects, upload reservations or cleanup queue entries. No original
simulator data, phone FX, production, Face ID, signing or entitlements changed.
This continuation changed only this evidence file, the shared handoff and the
temporary fixture assertion helper. No build/test-suite rerun, runtime source
edit, commit, push, migration or deployment was performed.

## Continuation — confirmed main-form saves and native failure/retry (2026-09-23)

User accepted the recommended native fixes and isolated simulator failure checks.
Same canonical checkout, branch `codex/phase-7-notification-experience`, base
`5b0381ae`, disposable simulator `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`,
staging bundle `com.vibing.miloom.staging`, build 12. Changes remain local,
uncommitted and unpushed. No backend schema/function deployment was needed.

### Implemented

- Main bank/card/service sheets await confirmed persistence before publishing
  portfolio state or dismissing. Rejection keeps the value-type draft and shows
  a local native alert; pending saves disable duplicate Save, Cancel and interactive
  dismissal. Cancel no longer issues DELETE for an unsaved draft.
- Confirmed coordinators recheck original-company owner binding, exact edit vs
  collection creation scope, owner Free-plan restrictions, and active account
  identity before publishing a successful receipt. Errors no longer trigger a
  second global alert for these three forms.
- Card owner-side institution changes are awaited and use a stable draft ID
  across retries. Copy acknowledges separately confirmed institution changes if
  the card then fails. Collaborators still cannot write institution data through
  card Save. Native owner partial-save coverage remains a follow-up.
- Bank/card/service/document errors use safe, actionable copy without raw SQL,
  payloads or a claim that uncertain responses rolled back. Loan-specific safe
  conflict/ledger/access messages are preserved by the same formatter.
- Shared-card helper copy now matches the existing requirement to select an
  institution. This resolves misleading copy; it does not implement standalone
  card creation in that sheet.

### Failure injection boundary

`StagingSaveFailureProtocol` is compiled only for DEBUG simulator builds and is
enabled only with the exact staging URL, staging bundle and explicit launch
argument. An explicitly named temporary instruction file selects one allowed
save endpoint and URL error. Authentication, reads, other endpoints and other
hosts are not intercepted. No phone, production, Mac networking, TLS, Face ID,
signing or entitlement changes. Device and Release builds exclude this helper.

These tests use the real native Save button, form, coordinator, repository and
URLSession error path. Requests fail **before transmission**. They verify native
error handling and same-draft retry, not real Wi-Fi disruption, mid-flight server
commit ambiguity, file-upload interruption, or offline vault revocation.

### Native results with exact staging persistence checks

| Main form | Controlled connection failure | Open-form revocation | Same-draft retry |
| --- | --- | --- | --- |
| New bank | Offline error; draft retained; no row | Denied; draft retained; no row | One original-owner row |
| New card linked to test bank | Connection-lost error; draft retained; no row | Denied; draft retained; no row | One original-owner row |
| New service | Timeout; draft retained; no row | Denied; draft retained; no row | One original-owner row |
| Existing service edit | Offline error; original row unchanged | Denied; original row unchanged | Same ID updated, no duplicate |
| Existing document metadata | Offline error; edited title absent | Passed in prior continuation, not repeated here | Same ID updated |
| Existing loan metadata | Connection-lost error; edited title absent | Passed in prior continuation, not repeated here | Same ID updated |

The first four rows used owner RPC revocation/restoration while the native form
remained open, with no relaunch or re-entry between failure and retry. These
fresh passes supersede the prior bank/card/service main-form draft-loss failures.
Bank/card existing-record edits are covered by coordinator tests, not a new
native edit pass in this continuation. No new payments or file attachments were
created. Document and loan error copy were rechecked in rebuilt native apps.

Fixture titles: `Native Bank Failure Retry`, `Native Card Failure Retry`,
`Native Service Failure Retry` -> `Native Service Edited Retry`,
`Native Document Verified Retry`, and `Native Loan Verified Retry`.
All successful server assertions checked original-owner/company identity.
Initial hook setup attempts saved two additional dummy banks normally because
the temporary-path guard was inactive; those attempts are **not** counted as
failure passes. Foundation's existing/nonexistent /tmp alias behavior was fixed,
guard-tested, and the failure cases above were rerun successfully.

### Verification and cleanup

- Final focused suite: **31 passed, 0 failed, 0 skipped** in
  `/private/tmp/miloom-confirmed-saves-final-copy-20260923.xcresult`.
  Coverage includes create/edit network errors and permission rejection,
  unchanged state on failure, same-draft retry, account-switch receipt rejection,
  original-owner and Free-plan gates, safe messages, preserved loan errors, and
  staging hook restrictions. An intermediate path-guard test failed and was
  corrected before the final successful suites; intermediate results are not
  final acceptance evidence.
- `git diff --check` passed. Final build installed only on the disposable
  simulator. Existing project signing/configuration changes were not edited.
- Native sign-out reached login. Marked dummy users were deleted and verified
  Auth 404; exact company/resources/shares and loan-payment cleanup completed.
  Storage objects, upload reservations and cleanup queue were empty.
- Removed the temporary failure-instruction file and relaunched signed out
  **without** the opt-in argument/environment. The app is left in normal mode.

### Remaining release gates

The primary collection creation matrix and controlled main-form save failure/
retry checks are now verified. This is **not release sign-off**. Alternate and
nested save entry points still include optimistic wrappers; owner/Free native
regressions and card/institution partial-save acceptance remain. Also outstanding:
document file interruption/orphan/PDF, email/universal links, actual foreground/
offline revocation, two-device vault/scoped-secret matrix, older-client rollout
policy, independent security review, checkpoint/release candidate and separately
authorized production deployment. Password-sharing cutover remains closed.

## 2026-09-23 — Nested save checkpoint and staged photo-upload retry

The previous verified checkpoint is committed as `07499ec1` (`Preserve scoped
editor drafts and verify native save retries`), not pushed. This continuation is
local/uncommitted native code plus test/evidence changes on top of that commit.
No migration, function deployment, production, phone FX, original-simulator,
Face ID, signing, entitlement or secret-sharing-cutover change occurred.

### Changed behavior

- The overview Add Payment sheet now awaits the existing atomic loan save and
  keeps its draft on rejection. Its coordinator retains the original revision,
  ledger and payment ID, rejects incomplete/duplicate/mismatched payments, and
  does not silently rebase a stale ledger. The same HUD inside Edit Loan still
  adds only to the parent draft until the parent Save is confirmed.
- Both owner service-wizard save actions await confirmation, keep the current
  step/draft on failure, and prevent duplicate saves or dismissal while pending.
  The final step says Ready to save rather than incorrectly announcing success.
- Photo selection resets after success or failure, allowing the same image to
  be selected again without reopening the document editor.
- The existing opt-in DEBUG staging-simulator fault hook now allowlists the
  prepare-upload, signed CompanyDocuments upload, and finalize-upload endpoints.
  Tests enforce the exact staging host/bundle and exclude reads, deletes, other
  buckets, other paths and non-opt-in launches. No production/device hook exists.

### Verification actually performed

- Final focused native suite: **34 passed, 0 failed, 0 skipped**, result
  `/private/tmp/miloom-nested-save-upload-copy-20260923.xcresult`, staging build
  12, iOS 26.4, disposable simulator
  `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`. Earlier same-source save/upload suite
  before the wording-only correction also passed 34/34 at
  `/private/tmp/miloom-nested-save-upload-final-20260923.xcresult`.
- Actual owner-wizard toolbar Save and final Done each showed Service Not Saved
  under the controlled connection fault, kept their step and entered name, and
  left no service row. Retrying with the hook off saved exactly one row per
  draft under the original owner/company. Titles: `Native Owner Wizard Retry`
  and `Native Owner Wizard Done Retry`. No credentials or linked emails entered.
- Rebuilt wording was visibly verified at the final step using
  `Native Unsaved Wizard`; Cancel returned to the list and the server query
  confirmed that draft was absent. The wording-only rebuild was not counted as
  a new repetition of both save-failure passes.
- Native nested Edit Loan -> Add Payment retained a $25 payment in the parent
  draft, while an exact server query returned zero payments. Canceling the
  parent left zero payments. **This is not the overview quick-payment flow.**
  The overview context-menu Add Payment action could not be invoked through the
  available native-control long-press/AX interface; its network/denial/stale
  failure and stable-ID retry are coordinator-tested, not native-flow verified.

Native upload checks used the exact shared fixture document and repository logo
images, never personal files. Staging queries checked its URL, reservations,
actual Storage objects and cleanup queue after each step:

| Controlled stage failure | Native/backend result | Same-image retry |
| --- | --- | --- |
| Prepare offline | Editor stays open, safe error, no reservation/object/attachment | Same image selected again successfully reaches the next tested stage |
| Signed upload interrupted before transmission | Unfinalized reservation, no object or attachment | Same-image selection triggers another request |
| Finalize timeout before transmission | Bytes exist but document URL remains null; unattached object retained for cleanup | With faults off, one attachment finalized and shown in native UI |
| Replacement finalize timeout | Existing attachment remains in UI and backend; it is not queued for removal | Same replacement image succeeds, new URL shown; only then is previous attachment queued |

The failure hook intercepts each selected request **before transmission**.
For finalize faults, preparation and byte upload genuinely completed first,
so real orphaned test objects existed. This does not prove recovery from a lost
response after the server has already committed, real packet loss, Files/PDF
import, or automatic cleanup of newly abandoned objects after the 24-hour grace.
Sibling/private document URLs remained unchanged. All uploaded paths belonged
to the original owner, not the Editor.

### Cleanup and boundaries

Native sign-out and login were verified. Four test Storage objects, five upload
reservations, the old-file cleanup entry, exact fixture records/shares and both
marked dummy accounts were removed; absence was verified, including Auth 404s
and zero loan payments. Service-role company deletion initially hit the intended
`DOCUMENT_FILE_OWNER_REQUIRED` guard and rolled back. Cleanup then used the
existing authenticated fixture owner, preserving the guard; no schema bypass.
This manual cleanup is not evidence that the scheduled orphan worker passed.
Removed the temporary fault-instruction file and relaunched the disposable app
without the fault argument/environment; normal signed-out login remains visible.

### Frozen completion boundary and original phase map

**Correction, 2026-09-23:** the previous table reused later implementation
milestone labels and incorrectly called them the original phases. The original
plan was Phases 1–7 plus initial Phase 0. Historical commits `1d4693ff`,
`e6d91120`, `9619af5b`, and `0cdaf4cb` are implementation checkpoints, not proof
that the original phase acceptance criteria are complete. The original phases,
assessed against their full acceptance and the frozen gates, are:

| Original phase | Status | Remaining completion boundary |
| --- | --- | --- |
| 0 — Security containment | In progress | Final compatibility/cutover verification |
| 1 — Shared security schema/contracts | In progress | Final role/scope backend and native acceptance |
| 2 — Personal cross-device vault | In progress | Final migration/recovery acceptance on candidate build |
| 3 — Collaboration authorization without secrets | In progress | Lifecycle/deep-link and revoked-access acceptance |
| 4 — Collaborator access to protected fields | In progress | Scoped-secret two-device/isolation gate; sharing remains disabled |
| 5 — Revocation and cryptographic rotation | In progress | Scoped key rotation/removal/revocation acceptance |
| 6 — Unified management experience | In progress | Required native management flows on candidate build |
| 7 — Testing and controlled rollout | In progress | Clean build/checklist, rollback and independent review gate |

These statuses do not mean no implementation exists. Phase 4 originally
proposed Admin-only protected access; the user subsequently approved scoped
Editor secret access. Rollout order remains additive backend/email, flagged
personal vault, safe readable-legacy migration, new client before legacy-write
closure, nonsecret collaboration, scoped-secret sharing only after the entire
security gate, then evidence-backed legacy retirement. Production deployment
and production secret sharing remain separately authorized, with independent
security review an explicit final external gate.

The later user-approved delegated Admin/Editor model, resource-key sharing and
staging acceptance remain **In progress**. Production release is **Not started**
for this rollout and remains separately authorized. The remaining bounded gates
are:

1. **Roles/scopes — In progress:** close final native/direct-backend permission
   evidence for Owner, entity Admin (Viewer management only), exact/collection
   Editor and credential-blind Viewer. Restrict further save-path fixes to these
   boundaries, critical data loss or unauthorized access; general app QA is not
   an added phase.
2. **Collaboration lifecycle — In progress:** actual invitation email/deep-link
   acceptance for existing/new users, resource/entity removal, owner-only block
   and foreground/offline revoked-access checks on staging. Prior native Send
   and API acceptance do not substitute for the email-opening flow.
3. **Documents — Incremental staging checkpoint passed (2026-09-23):**
   native upload/open/replace/remove, controlled retry and revoked operations
   have recorded evidence; orphan discovery/worker correction is verified below.
   Final acceptance on the clean candidate build remains part of gate 6.
   Controlled request failures are not a claim of real packet-loss or
   post-commit lost-response testing.
4. **Scoped vault — In progress:** safe readable-credential migration, two
   approved devices and exact-resource decrypt isolation, recovery/rotation and
   removal/revocation. Keep collaborator password sharing disabled until all of
   this gate passes. Account-vault two-device evidence alone is insufficient.
5. **Release safety — In progress:** older-client compatibility/rollback and no
   unresolved critical data-loss/unauthorized-access defect. Independent security
   review is **Not started** in this task and remains an explicit external gate.
6. **Final deliverable — In progress:** identifiable commits, one clean staging
   build, the bounded acceptance checklist on that exact build and updated
   evidence/handoff. Current native checks are incremental dirty-worktree builds,
   not the clean release candidate. State the exact incomplete gate, not that the
   overall goal is complete.

Noncritical adjacent discoveries (general owner/Free-tier regressions, unrelated
inline save polish, wider visual cleanup) are follow-ups, not new phases. The
overview payment native check stays tied only to the scoped loan save/data-loss
gate. All unresolved security/release gates above remain required.

## 2026-09-23 — Bounded Documents continuation: PDF and revoked operations

Same canonical branch, HEAD `07499ec1`, existing staging simulator build 12
from `/private/tmp/miloom-staging-owner-build.2Qprr8`. No runtime source change,
rebuild, suite rerun, commit, push or backend deployment in this continuation.
Prior 34/34 focused suite evidence remains prior evidence, not a new run.

| Check | Result and evidence |
| --- | --- |
| Native Files/PDF upload | Passed: selected `Miloom-Staging-Document-Test.pdf` from On My iPhone in the native picker; finalized 1,728-byte object under the original owner's prefix, exact document only. |
| Native PDF open | Passed: actual PDF rendered in the in-app browser, marker `DOC-GATE-20260923`, page 1 of 1. Synthetic document created/render-verified using the PDF skill; no personal files. |
| Revocation between bytes and finalize | Passed via API: Editor prepared/uploaded replacement, Owner revoked exact document Editor grant, finalize returned 403/42501; original attachment unchanged. New reservation remained unfinalized. |
| Native removal after revocation | Passed: editor form opened before revoke; Remove File confirmed afterward displayed safe authorization error and retained attachment/form. Backend original URL unchanged; no cleanup queued for it. |
| Native opening after full read revocation | Passed: Owner also removed independent company Viewer grant; stale paperclip returned “Could not open document” / access-changed message rather than a new signed URL/PDF. Already downloaded copies and previously issued short-lived URLs are not remotely erased by this test. |
| Abandoned upload cleanup | **Failed gate prerequisite:** live staging function `miloom_queue_orphan_document_uploads()` has a malformed UUID-path regex. Actual abandoned object does not match it and therefore cannot become a cleanup candidate even after the grace period. No worker or simulated aging run claimed. |

The deployed filter expects a six-group owner identifier and a four-group
filename identifier, rather than standard five-group UUIDs for both. Read-only
`pg_get_functiondef` confirmed the live staging definition matches migration
`202609220029_preserve_legacy_document_file_references.sql`; SQL against the
actual unfinalized object returned `attached=false` and
`matches_deployed_cleanup_filter=false`. This is a cleanup/storage-retention
blocker, not observed unauthorized access or deletion of an attached file.
Earlier detached-file cleanup passes do not establish orphan discovery, and
legacy-linked-object exclusion tests alone do not detect a filter matching no
valid uploads. Requested permission for a narrow backend correction, positive
orphan regression test after migration 029, and staging-only deployment/test.

Cleanup complete: native sign-out/login screen verified; two synthetic Storage
objects, two reservations, cleanup queue, exact fixture rows/shares/payments and
both marked dummy accounts removed (Auth 404 checks). The copied PDF was removed
from the disposable simulator Files container. This deliberately deletes only
disposable test data, permanently; no real-user data was removed. No production,
phone FX, original simulator, signing, entitlement, Face ID or password-sharing
cutover changes.

**Next bounded gate action:** correct and verify orphan cleanup after explicit
backend approval. Documents remains In progress, not complete. Do not advance
to lifecycle/vault or add adjacent QA while this gate remains open.

## 2026-09-23 — Documents orphan-cleanup correction: checkpoint passed

User explicitly authorized the narrow backend correction and staging test.
Added migration `202609230001_fix_orphan_document_uuid_filter.sql`; only the
UUID-path predicate changes. The 24-hour grace, owner binding, normalized
relative/legacy live-reference protection, bounded batch and service-only
privileges are preserved. Applied only this migration to Miloom Staging
`bvtuyzhyospqxvpzcrmv` and recorded/verified its migration ledger entry. No broad
database push, Edge redeployment, production or phone change.

- **SQL regression passed:** isolated local PostgreSQL, actual migration 029
  followed by the correction. Positive aged orphan discovery; fresh-upload
  grace; preservation of relative and encoded absolute legacy references;
  wrong-owner/unrelated-bucket/non-app-filename exclusion; idempotency and
  service-only execution. Reproducible test:
  `supabase/tests/document_orphan_uuid_regression.sql` (disposable database only).
- **Worker unit test passed, 1/1:** `deno test --no-config --cached-only
  supabase/functions/_shared/document_file_cleanup_test.ts`. The initial command
  inherited unrelated compiler configuration and could not resolve `Deno`;
  rerunning without that config passed type checking and execution.
- **Hosted worker passed:** three actual synthetic PDF uploads through the
  existing scoped upload contract. Fresh run removed 0/failed 0. Simulated
  25-hour `created_at` applied only to the exact orphan and attached fixture
  objects; next run removed 1/failed 0. Attached PDF and fresh unfinalized upload
  remained, document URL unchanged, queue empty. Repeat removed 0/failed 0.
  This exercises the real deployed worker, not a 24-hour real-time wait or a
  new clock-triggered scheduler proof. Preflight checked for unrelated queued
  or aged-unreferenced objects before every invocation; none were processed.
- First direct service-key invocation returned 401 and performed no cleanup;
  successful runs used the existing scheduler's `x-cron-secret` configuration,
  validated to the exact staging URL, held only in memory and never printed.
- **Cleanup verified:** all marked fixture records/shares/payments, Storage
  objects, reservations and cleanup entries absent; both dummy users Auth 404.
  Only disposable data was permanently deleted. Local test PostgreSQL stopped.
  Native simulator remained signed out; no native source/build changes needed.

The previously reported orphan-filter blocker is resolved on staging. Documents
incremental acceptance is passed; it is not final clean-build release signoff.
Original phase numbering and six frozen gates remain unchanged. **Next bounded
checkpoint: collaboration lifecycle — actual email/deep-link acceptance for
existing/new users and remaining removal/block/revoked-access evidence.**
Scoped-vault security, compatibility/rollback, external independent review and
the clean committed candidate/checklist remain required afterward. Password
sharing remains disabled. No commit or push this turn; the migration, regression
test and evidence are local changes, with the migration applied to staging only.

## 2026-09-23 — Lifecycle current-state verification (not complete)

Current staging secret metadata lists no `RESEND_API_KEY` or `SHARE_EMAIL_FROM`.
The sender function requires both, so actual invitation delivery remains blocked.
Requested staging-only secure configuration and an approved test inbox; no
provider credential was obtained, no email was sent, no secret was changed.
Read-only HTTPS retrieval of the live Apple association file returned only
`WYYJ6FGYRP.com.vibing.miloom` with `/invite` paths, not the installed disposable
`com.vibing.miloom.staging` app. Thus this build cannot establish real
email-to-app universal-link acceptance with the current website association.
No website, bundle identifier, entitlement or signing change was made.

Two rollback-only SQL suites ran against the current staging schema and passed:

- `invitation_lifecycle_contracts.sql`: token issuance/rate limit, wrong-account
  preview/accept denial, new-recipient inbox, token acceptance producing one
  direct grant, replay rejection, decline without grant, expiry and privileges.
- `canonical_resource_access_contracts.sql`: existing-user direct grant,
  cross-owner denial, legacy RPC response/sender authorization, resource-only
  revoke, entity revoke preserving other entities, person block preventing
  regrant, unblock, owner isolation and anonymous privilege denial.

Updated both historical test fixtures from unsupported company Editor to company
Viewer, matching the approved entity roles. Exact-resource Editor tests remain
separate. The first lifecycle run exposed migration 011 listing accepted
invitation history alongside the canonical direct grant. This is recorded as a
**noncritical follow-up: deduplicate accepted history in owner management**,
not a security fix or a passed display check. The suite now explicitly checks
one canonical direct edge; it does not claim the management list is deduplicated.
All other lifecycle assertions remain. Post-run staging counts confirmed zero
fixture Auth users and companies for both suites; no persistent test records.

This advances backend evidence, not native email/deep-link/foreground-offline
acceptance. Lifecycle gate remains In progress. Next available work is the
remaining bounded native/security evidence while email/link prerequisites are
resolved; no whole-app QA or additional phase is authorized. No commit, push,
deployment, native rebuild or production change in this continuation.

## 2026-09-23 — Scoped-vault bounded contract checkpoint

Added repeatable local-only `supabase/ops/rehearse_scoped_vault_contracts.sh`:
seven fresh isolated database scenarios run actual migrations 009–021 and the
existing scoped-vault assertions. **All seven passed**: foundation, owner
staging, device grant, owner rewrap, source-revision/cutover/rotation/lifecycle,
access status and scoped update. Logs retained under
`/private/tmp/miloom-scoped-vault.X5trS7`; local PostgreSQL shut down on exit.
No hosted fixtures or credentials are used by this runner.

Coverage includes request-before-approval denial, Viewer and wrong-device
denial, approval replay, source-revision preservation, closed activation
privileges, block-induced wrap revocation/rotation-required state, and blocked
cross-owner rebinding. These tests intentionally use synthetic ciphertext and
privileged isolated fixture activation: they do **not** prove real cryptographic
decryption, the native device workflow, or hosted post-revocation behavior.

Read-only staging verification separately confirmed both `authenticated` and
`anon` lack EXECUTE on `miloom_activate_staged_resource_secret`; collaborator
password activation remains disabled. No schema/Edge deployment, native build,
signing/device change, commit or push. Native two-device decrypt/isolation,
recovery/migration/rotation and final candidate acceptance remain open. Existing
SQL and native crypto-unit evidence must not be combined into a false end-to-end
pass. Next work must target the actual two-device path, not more repetitions of
these now-green contract scenarios. Email/link prerequisites remain separate
open lifecycle items.

## 2026-09-23 — Native recovery, migration and owner cross-device reveal

- User completed recovery on disposable second device `59D3304A-CD59-4F65-8416-8806D6DE1A0B`; native UI shows Vault Unlocked, two trusted devices and Device recovered activity.
- Actual migration of one synthetic card password exposed a blocker: the SDK's default full-row update representation conflicts with migration 008's column SELECT restrictions. Staging same-value PATCH reproduced full projection 403/42501 and ID projection 200. No permissions loosened.
- Fixed six native migration/rotation updates (services/cards/banks) to select only ID and require a nonempty mutation receipt, preserving failure accounting. Simulator build passed with existing warnings and established staging configuration; installed only on second disposable device. No backend deployment or signing/project changes.
- Native Face ID-authenticated retry reports **1 field encrypted**; read-only helper confirmed the exact dummy card holds `miloom:v1:` ciphertext. First disposable device `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`, still on its prior build, relaunched and revealed the exact synthetic plaintext from that migrated card, then hid it. This is owner account-vault cross-device decryption, NOT collaborator resource-key decryption.
- Remaining gate 4: broader migration preservation boundaries, actual scoped collaborator decryption/isolation and rotation/revocation. Password sharing remains disabled. Fixtures retained for these checks; no commit/push, production or phone changes. These incremental builds are not gate 6's final clean candidate.

### Native resource preparation follow-up

Second disposable simulator completed Prepare Encrypted Copies with Face ID: **1 resource prepared and verified**. Staging confirms card `891612a8-9f24-4c20-ae53-512633b29103` at version 1/source revision 2 in `staging`; its existing account-encrypted password remains present. This tests native resource-key encryption/read-back verification without granting collaborator access. Fixture-only activation authorization is the next prerequisite; collaborator decrypt/isolation and rotation/revocation remain unverified.

## 2026-09-23 — Scoped native decrypt, revoke and key replacement checkpoint

- Subsequently, user-authorized privileged activation was limited to the exact dummy card above. Global client activation privileges were not opened. This is fixture preparation, not proof of normal-client activation.
- Native Editor Request Access, owner explicit Grant Credential Access confirmation and Face ID succeeded. After fixing competing alert presenters and biometric inactive-transition cancellation, Editor Reveal Credentials displayed the exact synthetic password. No secret was visible before approval.
- Home/background followed by foregrounding the recipient app cleared the displayed plaintext. This verifies clearing of an already displayed value; interruption during an in-flight reveal and sheet-dismissal races remain unverified.
- Authenticated owner helper revoked only the exact card Editor share (one share removed; independent shares preserved). A fresh native recipient reveal, including Face ID, did not expose the password; the card became read-only and credential controls disappeared. This revocation step used the owner RPC helper, not the native revoke confirmation.
- Owner reopened Password Vault and saw Locked Resource Credentials for Editable Test Card. Native Replace Key displayed its explicit scope/no-grant-carryover warning. Confirmation and simulated Face ID completed; the locked-resource row disappeared.
- Read-only staging metadata verified version 1 retired, version 2 active, and the recipient version-1 wrap revoked, with no version-2 recipient wrap. No ciphertext or key material was logged. Post-rotation owner native reveal remains unverified.
- Incremental staging simulator builds only, not the final clean candidate. Entire gate 4 remains open: remaining isolation/preservation checks, post-rotation owner reveal, and checkpoint cleanup are not claimed complete. Fixtures retained without an active card recipient grant. No production/phone changes, commit or push. `git diff --check` passed; unit tests were not rerun in this checkpoint.

### Post-rotation denial follow-up

Authenticated disposable Editor checks returned `unavailable` for the revoked card, Viewer-only sibling card and Viewer-only bank. Direct reads of resource-secret versions and device wraps both returned HTTP 403 / SQLSTATE 42501. These are hosted authorization checks, not proof of cross-scope cryptographic isolation; no payloads or keys were retrieved. Owner simulator is at Editable Test Card —1111 awaiting the manual long-press needed to open its edit sheet for post-rotation reveal. Fixtures are retained until that check completes, then require cleanup.

### Owner post-rotation reveal and checkpoint cleanup — completed

- Owner second simulator was updated to the same existing reveal-fix staging build used by the recipient (debug dylib SHA-256 `544432fac1b092b835f935265831aaad7edc958dd95b6c054407b79a3fa2de65`). After user opened its edit sheet, native Reveal Credentials plus simulated Face ID displayed the original synthetic password under the rotated resource key. Hide removed plaintext. Post-rotation owner access/preservation passes for this exact card.
- Guarded fixture cleanup removed the exact test company/resources, loan payments, Storage objects, upload reservations/cleanup queue and both marker-validated disposable accounts; account lookups returned 404. Additional read-only staging query returned zero resource-secret versions, device wraps, access requests, vault devices and shares for the fixture identifiers. Hosted checkpoint fixtures are now absent; local simulator app/keychain storage was not erased.
- No source change, new build, commit/push, schema/function deployment or production/phone action. This closes the fixture checkpoint, not the entire gate 4 or final-build acceptance. Prior broader cryptographic-isolation/migration-boundary and release prerequisites remain as recorded; do not recreate this fixture merely to repeat passed checks.
