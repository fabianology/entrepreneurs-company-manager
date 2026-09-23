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
