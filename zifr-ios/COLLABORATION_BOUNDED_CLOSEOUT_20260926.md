# Collaboration, sharing and vault: bounded closeout

Date: 2026-09-26. This reconciles existing evidence; it adds no phases or product
scope. Production deployment and collaborator-secret activation remain closed.

Latest checkpoint, 2026-09-27: clean candidate `09a366ef` (native source unchanged
from `7bf657db`). Personal recovery, three-field safe migration/second-device
decryption, resource-key preparation/replacement and owner post-rotation reveal
passed. Disposable hosted fixture cleanup passed. Live reveal dismissal passed
only for observed timing; deterministic delayed-response verification remains
open. The sections below preserve dated history, including superseded pending/
uncommitted statements. No overall completion or production release is claimed.

## Candidate and fresh verification

Native source: `7bf657db`, branch `codex/collab-staging-candidate-20260923`,
worktree `/private/tmp/miloom-clean-candidate.dKfPen/source`.

- Current-source selected native tests: **42 passed, zero failed/skipped**.
  Suites: ActiveSessionsTests, ResourceVaultCryptographyTests,
  ResourceSecretPreparationTests. Result:
  `/private/tmp/miloom-candidate-bounded-20260926.xcresult`.
- Reconciled three previously staging-tested backend artifacts into that worktree:
  migration `202609230002_skip_vault_audit_for_deleted_owner.sql`, its
  `resource_secret_account_delete_assertions.sql`, and the `owner_delete` scenario
  in `rehearse_scoped_vault_contracts.sh`. Byte comparisons against the canonical
  artifacts passed. No new backend behavior or deployment was introduced.
- All **eight isolated local SQL scenarios passed**, including rotation,
  containment/reversal, scoped update and owner deletion. Evidence:
  `/private/tmp/miloom-scoped-vault.GX3kvd`. Local server stopped on completion.
- Candidate whitespace check passed. Native source remains committed; the three
  backend reconciliation files are **uncommitted**. No push, merge or production
  action. The candidate is not currently a clean final deliverable.

## Existing evidence not to repeat as new implementation

Earlier incremental native evidence includes recovery, post-share-revocation
secret denial, resource-key replacement without grant carryover, and owner reveal
under the replacement key. Clean-candidate `2fd148a4` adds mixed readable/locked
migration preservation, second-device approval/account-field decryption, exact
Editor request/grant/decrypt, Viewer sibling isolation and background clearing.
See `COLLABORATION_UI_ACCEPTANCE_20260922.md` and
`COLLABORATION_CLEAN_CANDIDATE_20260923.md` for their precise limitations.

Latest candidate lifecycle evidence includes delivered email/new-user acceptance,
one-tap covering-sheet handoff, native entity removal, recipient dashboard removal
after return to app, owner blocking and blocked re-invitation rejection. The
latest disposable company/account/block were removed and absence verified.
This does not establish live continuous-foreground/offline cache invalidation.

## Original phase map

Statuses reflect full acceptance, not absence of implementation. No new phases.

| Phase | Status | Remaining acceptance boundary |
| --- | --- | --- |
| 0 Containment | In progress | Minimum-client/cutover evidence and release safety |
| 1 Contracts | In progress | Consolidated backend/native role matrix on candidate |
| 2 Personal vault | In progress | Candidate recovery acceptance reconciled with migration evidence |
| 3 Nonsecret collaboration | In progress | Final lifecycle matrix; foreground/offline limitation disposition |
| 4 Scoped secrets | In progress | Final candidate matrix, including delayed reveal dismissal boundary |
| 5 Revocation/rotation | In progress | Candidate-native recovery/revoke/rotate acceptance reconciliation |
| 6 Management | In progress | Required native management checks within the same final matrix |
| 7 Acceptance/rollout | In progress | Clean committed candidate, bounded checklist and external-review handoff |

Production rollout: **Not started**, separately authorized. Order stays additive
backend/email, flagged personal vault, safe legacy migration, compatible client
before legacy-write closure, nonsecret collaboration, scoped secrets only after
the full security gate, then evidence-backed legacy retirement.

## Remaining bounded checklist and execution order

1. **Gate 6 source reconciliation:** commit only the three verified backend files
   when the user authorizes a commit. Do not include unrelated canonical changes.
2. **Gates 1/2:** finalize the existing role/lifecycle matrix. Run only uncovered
   native permission boundaries; explicitly distinguish server denial from stale
   downloaded/nonsecret UI and offline limitations. No whole-app regression pass.
3. **Gate 4/Phase 5:** one final-candidate vault batch for recovery,
   revoke/rotation/preservation and delayed post-auth reveal after dismissal.
   Existing crypto/SQL tests support, but do not replace, native acceptance.
4. **Gate 3:** the defined document upload/open/replace/remove/retry/revocation
   final-candidate batch only. Incremental staging document evidence already exists.
5. **Gate 5:** record supported-client/upgrade inventory, containment rollback
   evidence and exact candidate security-review packet. Independent review is
   outstanding and must be recorded as the final external gate, never replaced
   by self-review. No unresolved critical access/data-loss issue may be waived.
6. **Gate 6 handoff:** identify the exact build and commits, attach bounded pass/
   fail evidence, clean its fixtures, and report complete or the exact failed gate.

Next executable gate: verified source reconciliation, followed by the bounded
final-candidate vault batch. No general polish, additional feature or production
deployment is part of this closeout.

## Continuation: reconciliation committed, guided vault fixture prepared

Committed only the three verified backend artifacts as `09a366ef`; candidate
checkout is clean. `git diff 7bf657db..09a366ef -- zifr-ios` is empty, so the
native source tested above is unchanged. Neither commit was pushed/merged and
no hosted deployment occurred. The eight SQL scenarios ran on the exact
reconciled file contents before committing; committing did not alter them.

Prepared marked disposable staging owner
`miloom-final-vault-owner-20260926@example.com`, synthetic entity
`Final Vault Acceptance 20260926`, one bank and one card only. Initial inspection
confirmed these three rows and no vault devices or resource-secret versions.
Helper `/private/tmp/miloom-final-vault-20260926.mjs` has exact-target/marker
guards, preservation assertion and checkpoint cleanup. Generated credentials
and manifest are private local mode-0600 files, not repository contents.

Current tested native simulator binary hash:
`5a0702e6c521ec1b7ad8c9108c6816e519d1a4eeb83b88651f3bf352b36df8e6`.
Installed the same staging-only app on existing second-device simulator
`59D3304A-CD59-4F65-8416-8806D6DE1A0B` and launched it and recipient
`3C813101-B8C2-4566-9AB1-1AA041BCE2D9`. CLI launch is not native sign-in evidence.
Guided first-device sign-in/vault setup/recovery-code local saving are pending.
No FX, production, global activation or collaborator credential grants changed.
This new final-candidate fixture must be cleaned at checkpoint completion.

Guided first-device setup: user reported vault ready and recovery code saved
locally. Read-only staging inspection confirmed exactly one approved vault
device, label Miloom Invite Recipient 20260923, and no resource-secret versions.
Second-device recovery remains pending; no recovery code was read or logged.

At the user's explicit request, entered the existing disposable account password
and completed second-simulator sign-in using UI control. Visually verified the
Final Vault Acceptance dashboard and dismissed Save Password with Not Now.
Stopped before recovery-code entry; sign-in alone does not approve the device.

Recovery paste troubleshooting: user reported invalid-code alert and requested
clipboard paste verification. Pasted through simulator UI, inspected only length/
format without displaying the secret: 44 characters, no whitespace/padding,
all base64URL alphabet. Generator emits 32 random bytes as 43 unpadded characters;
the pasted value cannot pass the 32-byte decoder. No guessing/truncation, recovery
submission, rotation or device approval performed. Original saved code needs
recopying; native recovery remains unverified on this checkpoint.

2026-09-27: user replaced recovery code on the trusted simulator and reported
copying it. Trusted-device UI shows Recovery code replaced activity. Selected
second-device window through Simulator Window menu, attempted clipboard paste,
but field remained 44 characters and subsequent UI/menu input was unresponsive.
Cannot establish that the replacement Mac clipboard reached the simulator;
earlier format findings apply to the field value, not proof the user's new
saved code is malformed. No recovery submitted or guessed correction made.
Handed off exact manual replacement/paste and recovery; checkpoint remains open.

User subsequently approved clipboard-sync adjustment and final device recovery.
Toggled Simulator sync once for diagnosis, brought the window into active focus
with its exposed Raise action (restoring screenshots), and retried on the target
device. Recovery field visibly focused but empty; Paste/Get/Send Pasteboard
remained disabled. Repeated the toggle to restore the prior preference. Recover
stayed disabled; no recovery submitted or device approved. Needs the user's saved
replacement code through a local text-file path, not chat, to avoid the failed
clipboard transport. This is an input/transport blocker, not an established vault
cryptography failure.

User provided `/Users/yager/Downloads/recovery.rtf` as the saved code. Read-only
textutil conversion and metadata-only validation found exactly 44 base64URL
characters (one line, no whitespace/padding), decoding to 33 bytes. This saved
input fails the required 32-byte recovery-code format independently of simulator
clipboard transport. No secret emitted or submitted, no truncation/guessing.
Need user-generated replacement left on its once-only code screen so its existing
displayed value can be transferred privately and tested without manual copying.

### Final-candidate native recovery: passed (2026-09-27)

User generated replacement and left its once-only screen open. Read its existing
value privately through source simulator accessibility state: exactly one
43-character base64URL code. Transferred directly through the target recovery
field's setValue action and checked exact equality without emitting the code.
Under the user's preceding recovery/device-trust approval, tapped Recover This
Device and supplied simulated Matching Face. Target native UI showed Vault
Unlocked, two Approved devices and Device recovered activity. Independent staging
inspection confirmed both exact named simulators approved, no resource-secret
versions. Cleared temporary code-bearing UI-control variables. No code trimmed,
guessed, logged or saved by the agent; source once-only code screen remains for
the user to save the current replacement locally. Downloads/recovery.rtf remains
unchanged and contains the obsolete invalid value, not the working replacement.

This closes candidate-native personal recovery, not scoped-resource rotation or
the whole vault gate. Next bounded subcheck: readable-field migration/preservation
on this fixture followed by recovered-device decrypt. Candidate/source unchanged
at `09a366ef`; fixture retained for acceptance and exact cleanup.

### Final-candidate migration fixture correction (2026-09-27)

After user completed simulator passcode authentication, the native migration
receipt showed zero fields encrypted. Read-only authenticated-owner RPC and
service-role classifications established that the original fixture had no stored
credentials and an empty accounts array. This is a fixture-preparation error,
not evidence of owner RPC redaction or migration data loss: service-role REST
inserts lacked the owner auth.uid required by credential-preservation guards.

Corrected only these empty synthetic fields through the exact disposable owner's
authenticated PATCH, with select=id receipts compatible with restricted column
reads. No existing values overwritten, access grants widened, app/backend source
changed, or deployment performed. Retried the native migration on the source
simulator; it is again awaiting the simulator passcode. Three-field encryption,
two locked-field preservation and recovered-device decryption remain unverified.
The private temporary fixture helper gained guarded seeding and metadata-only
diagnostics; no account password or recovery code was emitted. Candidate remains
`09a366ef`; source recovery-code screen and disposable fixture are retained.

### Final-candidate migration and recovered bank decrypt passed (2026-09-27)

After the user completed retry passcode authentication, source native receipt
showed 3 fields encrypted and 2 locked legacy fields left unchanged. Independent
guarded stored-row assertions passed for all three encrypted fields, both exact
locked sentinels and account identity. Restarted only the second disposable
staging app to reload its pre-seeding cached records. Opened Synthetic Checking
on the recovered second device and privately compared displayed account number
and wire routing with the exact synthetic inputs: both matched. The locked-bank
warning remained and bank-password reveal was disabled (Locked on this device).

Card-password encryption is verified at rest, but its native second-device
decrypt still needs opening Final Rotation Card through the long-press gesture.
No source/build change, grant, commit, push or deployment. Candidate `09a366ef`
unchanged; fixture retained for remaining bounded checks and cleanup.

### Recovered-device migrated card decrypt passed (2026-09-27)

User opened Final Rotation Card's edit sheet via long press. That sheet does not
display its login/password; cancelled without saving, tapped the card to expand,
then Reveal Details and Reveal password. Privately compared displayed password
with the synthetic fixture value: exact match, Hide password control present.
Immediately hid it again and confirmed plaintext absent and Reveal password
restored. No secret output or clipboard use; temporary plaintext-bearing AX
variables cleared. Together with the prior bank checks, all three migrated
synthetic fields now have native recovered-second-device decryption evidence.

This closes this migration/recovery subcheckpoint only. Scoped resource rotation,
remaining bounded acceptance and release-safety gates remain open. Candidate
`09a366ef` unchanged; no source implementation, grants, commit, push, deployment,
FX or production action. Fixture retained for remaining checks and exact cleanup.

### Final-candidate scoped-key preparation passed (2026-09-27)

Opened vault settings on recovered second simulator, used native Prepare
Encrypted Copies and confirmed its no-new-access warning. Simulated Matching
Face completed authentication. Native receipt showed one resource prepared and
verified and one locked resource left unchanged. Independent staging metadata
confirmed only Final Rotation Card v1 in staging; both devices remain approved.
No collaborator was granted access, global activation privileges remain closed,
and existing encrypted source fields were not intentionally changed.

Next rotation prerequisite is privileged test-only activation/rotation-required
setup for this exact disposable card; this is fixture setup, not normal-client
activation evidence. It needs explicit authorization before execution. No
source/build changes, commit, push, deployment, FX or production action.

### Final-candidate native scoped-key rotation passed; reveal pending (2026-09-27)

User explicitly approved exact fixture activation/rotation-required setup.
Executed one transactional, marker/owner/company/card/device-guarded staging SQL
file: invoked the real closed activation function as the exact fixture owner
context, then marked only that card v1 rotation_required. Asserted no collaborator
wraps/shares and closed authenticated/anon activation privileges beforehand. No
permission grant or schema change. This is privileged fixture setup, not evidence
of normal-client activation or collaborator revocation.

Refreshed native vault management, saw Final Rotation Card / Replace Key,
confirmed its exact scope/no-grant-carryover warning and supplied simulated
Matching Face. Locked-resource row disappeared. Independent checks passed:
v1 retired, v2 active, resource ciphertext and owner wrap differ, legacy card
credential columns cleared, zero collaborator wraps, bank encrypted account
fields and locked sentinels preserved. Restarted only second staging app before
post-rotation reveal to avoid using pre-cutover cached legacy credentials. It is
at Final Rotation Card, awaiting user long-press to open the owner scoped-secret
reveal controls. Native preservation/decrypt under v2 remains pending.

Candidate `09a366ef` unchanged. No implementation, commit, push, deployment, FX
or production action; global password sharing remains closed. Fixture retained.

### Native post-rotation owner decryption passed (2026-09-27)

After user opened the card edit sheet on the freshly restarted second simulator,
Secure Credentials / Reveal Credentials was available. Triggered reveal and
simulated Matching Face; after asynchronous loading, privately verified the exact
synthetic password under the active resource key. Independent rotation assertions
still passed, including cleared legacy source, so this is not a cached legacy
password reveal. Used Hide, verified plaintext absent and Reveal Credentials
restored, then cleared temporary plaintext-bearing AX variables. No password,
key material or ciphertext emitted.

This closes owner password preservation/decryption after native resource-key
replacement on candidate `09a366ef`. The fixture had zero collaborator grants;
do not count it as final-candidate collaborator revoke/no-carryover acceptance.
Delayed post-auth reveal/dismissal boundary and remaining frozen gates are still
open. No implementation, commit, push, deployment, FX or production change.

### Live interruption attempt and checkpoint cleanup (2026-09-27)

On the owner scoped card sheet, started Reveal Credentials, supplied simulated
Matching Face and immediately clicked the previously observed Cancel position.
The sheet dismissed. After an independent metadata query allowed the request to
settle, native UI remained on the financial screen with the card present, no
scoped reveal sheet and no synthetic plaintext. This passes the observed live
interruption attempt. It does NOT prove the HTTP response arrived after dismissal;
there was no controlled response delay or timestamp instrumentation. The exact
delayed-post-auth response boundary remains an explicit Gate 4 acceptance gap,
not an established defect and not a completed test.

Guarded cleanup deleted only the marker-validated disposable final-vault Auth
owner. Independent absence checks passed for its Auth identity, company, bank,
card, account vault, devices, device/recovery wraps, approval challenges, key
transitions, personal/resource audit rows, resource versions/wraps/requests and
scoped shares. These hosted deletions are permanent; the fixture can be recreated
with new synthetic data if needed. Local simulator/keychain storage and the user's
Downloads/recovery.rtf were not erased; local saved recovery codes for this
deleted test account no longer provide hosted access. No production data touched.

Checkpoint closed with this evidence limitation. Candidate `09a366ef` unchanged;
no commit/push/deployment. Next bounded Gate 4 action: deterministic delayed-response
verification, followed by reconciliation of uncovered roles/document acceptance
and release-safety/external-review gates. No adjacent phases or whole-app QA.
