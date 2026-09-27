# Bounded second-agent security review result

## Latest checkpoint — verified-email guard, 2026-09-27

Supersedes the earlier acceptance-confirmation uncertainty for the new source
overlay and deployed Staging worker, not production or already-existing grants.
Migration `202609270003` explicitly requires current `auth.users.email_confirmed_at`
and a non-anonymous account before granting invitation access; `FOR SHARE` keeps
the current identity stable in the transaction. Matching, expiry, blocking,
decline and public wrappers remain unchanged. Focused separate-agent static
review passed with no blocking regression identified; this is not a full audit.

Parent executed ordinary synthetic permission contracts locally
(`/private/tmp/miloom-invite-verification.qlgFN8/contracts.log`) and on explicit
Staging `bvtuyzhyospqxvpzcrmv`: unverified ID/token acceptance denied without
grants; anonymous identity denied; verified ID/token acceptance and decline
passed. Transactions rolled back; hosted test user/entity counts are zero.
Catalog confirmed guard/identity lock/private worker and migration history.
No previous blocked security exercise repeated; no production/native changes.
New source remains uncommitted and outside clean candidate `d3b6a457` pending
reconciliation. Final external sign-off, legacy entity-Editor disposition and
compatible-client cutover remain release conditions. Existing native generic
verification-error copy is a noncritical follow-up, not a new polish checkpoint.

Date: 2026-09-27. Reviewer: separate agent `bounded_security_review`.
Read-only static review, not a professional audit or executed exploit test.
Target: clean candidate `7294842e42c7cee9ecad7596461e66b121f96c45` at
`/private/tmp/miloom-clean-candidate.dKfPen/source`. No source changes, tests,
UI, live service access, deployments or secrets were used by the reviewer.

## Disposition: FAIL — P1 document ownership/scope authorization

An exact document Editor can submit a direct `company_documents` UPDATE that
changes `user_id` to the caller or changes `company_id` outside the granted
scope. This violates frozen Gates 1, 3 and 5. Production stays on hold.

Evidence in candidate migrations:

- `202609220006_enable_editor_resource_mutations.sql:225–234`: document UPDATE
  authorizes both old and proposed rows using `miloom_can_edit_resource`.
- `202609220010_all_institutions_scope.sql:116–139`: proposed caller-owned row
  satisfies the owner shortcut; exact document grant still matches after an
  entity change.
- `202609220027_scoped_document_file_removal.sql:5–60`: storage validation does
  not preserve owner/entity and returns for null, empty or external URLs.
- `202609220022_document_storage_exact_read.sql:119–122`: link trigger is
  attached to URL/owner changes, not an entity-only update. Its read helper at
  lines 36–49 derives an audience from the document's entity.
- No independent document owner/entity preservation trigger was found. Private
  receipt restrictions in `202609070001_business_expense_review.sql:83–89`
  do not cover ordinary entity documents.

Static reproduction (not executed): Owner A shares an entity-visible document D
with a null URL to exact Editor B. B updates D's `user_id` to `auth.uid()`.
Old-row authorization passes through the grant; new-row authorization through
the owner shortcut; URL-null validation returns. B becomes canonical owner.
Alternatively, B changes D's entity to another existing entity owned by A;
the exact grant still passes and the new entity can gain a document/file audience.

Required bounded repair: server-side preservation of document owner and entity
for collaborator writes, including direct table updates. Negative regressions
must cover null/external/relative-file documents and exact/collection/Admin
grants, while preserving authorized metadata/file operations and owner behavior.

## Coverage and limits

| Boundary | Result |
| --- | --- |
| Roles/scopes | Fail: document ownership/scope escape |
| Invitation/removal/block | Partial, not complete |
| Document/storage | Fail: above defect |
| Vault/migration/device/grant/revoke/rotation | Partial, not complete |
| Compatibility/containment | Partial, not complete |

Canonical access/invite lifecycle, Admin Viewer delegation, Editor scope guard,
secret redaction/column closure, document upload/finalization/cleanup, loan owner
preservation, resource-secret foundation/grants/rotation/lifecycle/scoped updates,
account device approval/recovery and selected native DataRepository/reveal guards
were inspected. No additional confirmed defect was reported in those excerpts.
Loan preservation eliminated an initially suspected equivalent loan issue.

Invitation acceptance matches `auth.users.email` but has no explicit confirmation
check in `202609210003_invitation_lifecycle.sql:210–301`. Production Auth
configuration was not inspected; verified-email preconditions remain unresolved,
not a demonstrated exploit. Resolve this bounded precondition during follow-up.

Native observations include resource/owner/device/version-bound authenticated
cipher contexts, nonsynchronizing device-only private Keychain storage, explicit
approval and background/dismissal publication invalidation. These are not a
complete vault audit. Previous 47 native/eight SQL passes remain attributed,
not independently rerun. Runtime cleanup/cache races, complete account recovery
and rotation refinements, all native negatives, legacy policy inventory, installed
binary and containment rehearsal were not fully independently reviewed.
Signed URLs request 60-second expiry; downloaded bytes cannot be recalled.

Next checkpoint: reproduce the document escape in an isolated SQL regression,
repair that boundary, verify authorized paths plus denials, then focused re-review.
No whole-app QA, production action or global secret activation is authorized by
this result. Other incomplete review boundaries must remain explicit.

## Targeted local repair and focused re-review — September 27

The defect was reproduced with actual authenticated table UPDATEs in a socket-only
synthetic PostgreSQL cluster: owner takeover on a null-URL document and entity
movement on a relative Storage-linked document both succeeded without the guard.
Evidence: `/private/tmp/miloom-document-scope.xKkxlb/contracts.log`.

Local migration `202609270002_document_identity_scope_guard.sql` rejects all ID
and owner changes, collaborator entity moves (including detachment), and inserted
or moved documents referencing an entity owned by someone else. Ordinary metadata
edits and owner-requested moves to their own entities remain allowed. The trigger
runs on every INSERT/UPDATE independently of URL shape and RLS helper shortcuts.
Ownership transfer is deliberately prohibited; service writes also encounter it.
It does not rewrite existing documents.

Final targeted regression passed:
`/private/tmp/miloom-document-scope.5fhAMK/contracts.log`. Coverage includes exact
Editor, collection Editor and entity Admin across null/external/relative URLs;
owner/scope/identity denials, metadata saves, collection/Admin null-scope denial,
owner moves, foreign-entity insertion denial, legitimate owner creation and Viewer
immutability. Four existing contracts passed: upload/finalization/retry, file
removal, Storage write boundary and legacy-reference cleanup. Local clusters were
stopped; no hosted database was contacted.

The separate reviewer inspected the three repair files and earlier reproduction/
fixed logs, finding no remaining bypass of this document guard. This focused
static PASS applies only to the repair overlay, not the original candidate or
the entire security review. Later added INSERT/null-scope/identity negatives also
passed locally. Existing exact-read assertions were not counted: their expected
fixture file count differs after the full migration/fixture chain. No native
build or live Storage acceptance was rerun for this SQL-only repair.

Status: implemented and verified locally, uncommitted and undeployed. Candidate
`7294842e` remains unchanged and still requires the guard. Next: commit the bounded
repair, apply only this migration to Staging under deployment authority, verify
deployed authenticated denials/authorized paths, and reconcile the final candidate
and remaining explicitly incomplete security-review boundaries. Production stays
on hold; global collaborator-secret activation stays closed.

## Defensive staging deployment — September 27

Repair committed as canonical `dca3c625`, reconciled into clean candidate
`d3b6a457` (parent `7294842e`). Only backend/test/review files changed; installed
native binary is unchanged. User authorized normal defensive staging work after
a Codex cybersecurity notice; no blocked advanced security testing was repeated.

Applied only `202609270002_document_identity_scope_guard.sql` with explicit
Staging reference `bvtuyzhyospqxvpzcrmv`; recorded version/name in migration history.
Catalog receipt: exactly one enabled BEFORE INSERT OR UPDATE document trigger;
security-definer function with empty search path; anonymous/authenticated direct
function execution denied. Function-definition MD5 `da780e4683ee850a611bfeb8479c4c32`
is an identity receipt, not a security proof. No document rows rewritten.

`supabase/ops/staging_document_guard_happy_path.sql` passed on deployed Staging:
authorized Owner document creation, exact Editor metadata save, and Owner movement
between owned entities. Synthetic Auth/entities/document were in one rolled-back
transaction; subsequent counts found zero retained fixture rows. No file bytes
or email delivered, no production access, no general migration push.

This verifies deployed presence and normal authorized paths, not a hosted
adversarial regression or complete independent security audit. Local negative
regression and focused static repair review remain the denial-boundary evidence.
Other review omissions stay explicit; global activation and production cutover
remain closed. Final external review must accept this evidence or perform
separately approved remaining security checks before release.

## Remaining-boundary defensive static review — September 27

Separate reviewer completed read-only source/evidence continuation for clean
`d3b6a45722699dfd542b18fe19a300e4916d6c7c`. No additional confirmed source defect
identified; no tests, defect exercises, live access, UI or deployments by reviewer.
This is not a professional audit or production sign-off.

| Boundary | Disposition |
| --- | --- |
| Current roles/scopes and canonical scoped removal/block | Pass based on static review |
| Document identity/scope repair | Pass based on static review |
| Personal vault approval/recovery/re-enrollment/account rotation | Pass based on static review |
| Readable migration and locked-value preservation | Pass based on static review |
| Resource grant/isolation/revoke/rotation and native publication guards | Pass based on static review |
| Compatibility/containment design | Pass based on static review |
| Verified-email assurance across all identity paths | Unverified |
| Actual production cutover and global activation | Unverified; HOLD |

Continuation inspected invitation/legacy-access migrations 210003/220002/220004;
vault approval/recovery 210005, rotation/revocation 210006, re-enrollment 220005;
owner rewrap/source revision 220015/016, grant/lifecycle/status 220014/019/020;
document guard 270002; native AppViewModel migration, DataRepository account
rotation/recovery/key transitions and publication, AuthViewModel sign-out;
local containment SQL and dated acceptance/cutover evidence. Previous source list
and evidence attribution still apply. No test counts are newly claimed.

Parent separately read only public Staging `/auth/v1/settings`: email/password
signup enabled and `mailer_autoconfirm=false`; phone autoconfirm also false.
This narrows current signup uncertainty, but acceptance itself matches
`auth.users.email` without explicit confirmation. Production/OAuth/email changes/
admin-created identity assurance was not established. Next targeted release
decision: verify every supported identity path or add an explicit server invariant
with separate implementation authority; do not mark this row passed from signup
settings alone.

Existing company Editor edges are deliberately retained by 270001. Applicable
live legacy-edge inventory/disposition remains a cutover prerequisite. Current
containment rehearsal covers local recipient-delivery RPC privileges and preserves
encrypted data; it is not proof every hosted vault path can be disabled. Historical
provider-credential rotation/monitoring prerequisites also need operational
reconciliation, not another whole-app QA phase.

Final external disposition must accept these static/runtime limits. Compatible
production-configured distribution, upgrades or retirement of incompatible support,
and separately authorized backend rollout remain required. Global collaborator
secret activation remains closed. No assurance can recall previously delivered
bytes or keys.
