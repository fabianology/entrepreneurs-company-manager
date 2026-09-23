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
