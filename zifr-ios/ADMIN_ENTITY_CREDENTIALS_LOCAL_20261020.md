# Owner-controlled Admin entity credentials — local implementation

Date: 2026-10-20. Branch: `codex/admin-entity-credentials`, based on `49449473`.

This is a separately approved enhancement after Phase 7 closure, not a reopening
of the original seven phases. Authorization for this checkpoint: implement and
test locally only. No hosted migration, phone install, real credential grant,
Apple upload, commit, or push was performed.

## User flow

1. An owner shares an entity with role **Admin**. **Include entity credentials**
   starts ON. The owner can switch it OFF before Send. An explicit confirmation
   names the recipient/entity and explains existing/future access and copying.
2. ON requires a trusted, unlocked owner vault and native presence confirmation.
   Existing Admin shares and old invitations remain OFF until explicitly changed.
   The server storage default is deliberately OFF, even though the new UI default
   is ON. Older clients cannot silently create consent.
3. An Admin with an approved account-vault device appears in the owner's
   **Password Vault → Admin Entity Credentials** list. This is initially a pending
   entity-device approval, not a key grant. Devices enrolled later also start pending.
4. The owner chooses **Approve Device & Sync Credentials**, confirms the scope,
   and completes Face ID. Readable credentials in that entity are prepared using
   the existing resource-bound activation protocol, then separate resource keys
   are encrypted for this Admin device. Unreadable/locked resources are reported,
   not overwritten or reported as delivered. Retrying leaves active deliveries intact.
5. The Admin uses the existing per-resource **Reveal Credentials** and Face ID.
   Future resources or replaced keys require another **Sync Entity Credentials**
   on a trusted owner device. This implementation does **not** promise automatic
   background key delivery. The server never receives the owner's plaintext vault key.
6. To remove entity-wide consent while keeping business access, the owner submits
   that same entity Admin share with the toggle OFF. Downgrade, suspension, removal,
   blocking, and device trust/key changes also invalidate the relevant approvals.
   Affected active resource keys lock for replacement; previously copied passwords
   cannot be recalled. Independent per-resource business shares remain separate.

Personal/account vault master keys and other entities are excluded. Existing
Editor/Viewer authority is unchanged; Admins still cannot grant Admin/Editor
authority or switch on this owner-controlled policy themselves. Ordinary explicit
single-resource credential grants remain supported independently of this option.

## Implementation

- `supabase/migrations/202610200001_admin_entity_credentials.sql`: explicit share/
  invitation consent, pending/approved entity-device grants, verified invitation
  acceptance, owner/device-bound discovery/approval/delivery RPCs, and lifecycle
  invalidation. No direct authenticated table writes or broad key-read grants.
- Native share sheet: default-on setting, confirmation, trusted-owner proof and
  fail-closed new RPC (no silent fallback that loses the owner's choice).
- Native vault screen: entity/device approval and explicit sync, partial-failure
  reporting, existing per-resource encryption/reveal and recovery preserved.

## Verification actually performed

- Debug iOS simulator build: **BUILD SUCCEEDED**, signing disabled; log
  `/private/tmp/miloom-admin-credentials-build.log`.
- Final focused native test build/run: **15 tests, zero failures** across
  `AdminCredentialConsentTests` (4), `ResourceCredentialRevealGateTests` (4),
  `ResourceSecretPreparationTests` (3), `ResourceVaultCryptographyTests` (4).
  New isolated iPhone 17 Pro / iOS 26.4 simulator; no existing simulator/phone data used.
  Log: `/private/tmp/miloom-admin-credentials-tests.log`.
  Result: `/private/tmp/miloom-admin-credentials-derived/Logs/Test/Test-Zifr-2026.10.20_00-57-29--0700.xcresult`.
- `sh supabase/ops/rehearse_scoped_vault_contracts.sh`: **10/10 scenarios passed**,
  including the new `admin_credentials` scenario and existing bounded vault
  regressions. Local evidence: `/private/tmp/miloom-scoped-vault.z2rvls`.
  Each database is disposable; the local PostgreSQL server was stopped afterward.
- New SQL assertions cover existing Admin opt-out, required owner proof, pending
  device denial, different-entity/version denial, idempotent delivery, rejected
  revoked wrap reuse, future resources, recipient read eligibility, no Admin
  delegation, opt-out with overlapping Editor access, stale-grant rejection,
  public-key replacement, downgrade/suspension/device revocation/blocking, actual
  verified-email acceptance, and restricted privileges.
- `git diff --check` passed. SQL ciphertext is synthetic; tests are not proof of
  a new two-phone hosted acceptance flow or an independent security sign-off.

## Remaining bounded release gate (not authorized/executed here)

Review the final diff before any hosted enablement. On Staging only, with synthetic
credentials and explicit deployment permission, verify these five cases on one
identified native build:

1. New Admin toggle ON and OFF, existing Admin unchanged, invited-new-user consent.
2. Owner device approval + sync of two resources; Admin Face ID reveals both.
3. Add a third resource and sync; other entity and Viewer remain excluded.
4. Switch OFF/revoke: denial and key-lock behavior; rotate and verify owner access.
5. Clean up only synthetic records/grants and record evidence.

Any Production migration and distribution of a compatible native build require
separate authorization. Reverting the UI alone does not revoke already delivered
keys. To contain access, clear consent using the supported owner flow and replace
affected keys; do not drop tables as a rollback shortcut.

## Staging preparation and installation — 2026-10-20

The user subsequently authorized Staging deployment and installation on both
phones. Final SQL/native diff was self-reviewed; this is not independent sign-off.
Read-only Staging preflight (`bvtuyzhyospqxvpzcrmv`) found migration 202610200001
absent, one resource share, zero invitations, zero scoped secret versions and
zero device wraps. Activation migration 202610010001 is present.

After the user's explicit action-time approval, ran the exact migration plus
transactional migration-ledger registration in Miloom Staging. SQL Editor returned
`Success. No rows returned`. The prepared SQL had been byte-for-byte checked
against `/private/tmp/miloom-admin-staging-deploy.sql`.

Eight read-only postchecks passed: migration registered exactly once; existing
share count remains one with consent OFF; no invitations; no scoped keys, wraps
or Admin device grants; both consent columns NOT NULL/default FALSE; all seven
public RPCs executable by authenticated but not anon; all seven internal helpers
not executable by authenticated/anon; new device table has RLS and neither role
has direct SELECT/INSERT/UPDATE/DELETE. These checks verify deployment boundaries,
not the pending native acceptance flow. Evidence screenshot:
`/private/tmp/miloom-admin-staging-postcheck-20261020.jpg`.

Signed Debug Staging build **17** built successfully and installed on both FX and
FABIAN's iPhone using existing development signing. Verified bundle
`com.vibing.miloom.staging`, Staging Supabase URL/public key, isolated Staging
keychain group, `miloom-staging` URL scheme and Staging associated domain.
`codesign --verify --deep --strict` passed; both device IDs occur in the embedded
profile. Process launch succeeded on both phones; this is not proof of the signed-in flow.
Build log: `/private/tmp/miloom-admin-staging-build.log`.
Executable SHA-256: `a5873b01465719625364dab892c82753fbb8cec726845be8a53810c1398abcde`.

The five-case hosted acceptance above remains pending. No Production deployment,
Apple upload, real credential grant, commit or push occurred.

## First hosted acceptance — resource discovery defect

User confirmed Staging owner `fabianology@icloud.com` on FX and Admin
`avidyaclothing@gmail.com` on FABIAN's iPhone, both vaults unlocked. The new Admin
toggle appeared and sending with consent ON succeeded. User confirmed the fixture
contains only dummy credentials, then approved/synced its Admin device. Recipient
did not receive credentials; FX showed a generic connection error.

Read-only Staging query for that exact fixture/recipient confirms device status
`approved`, approval timestamp present, role Admin, consent true, but zero scoped
key versions and zero wraps. The approval succeeded; the subsequent sync did not.
The displayed pending button was stale after the exception, not proof approval failed.

Added a local regression invoking `miloom_list_admin_credential_resources` in the
native sequence. It reproduces SQLSTATE 42702: unqualified `resource_id` conflicts
with the RETURNS TABLE output parameter. Prior SQL tests exercised approval and
delivery but missed this intermediate resource-discovery call. Failure evidence:
`/private/tmp/miloom-scoped-vault.nSJf5M/vault_admin_credentials.log`.

Prepared follow-up migration `202610200002_admin_credential_resource_discovery.sql`
qualifying that lookup with alias `rs`, preserving all authorization, encryption,
scope and ACL behavior. Original deployed migration remains unchanged. New test
also checks the exact three in-entity resource IDs and excludes the other entity.
Focused scenario and all 10 local scoped-vault scenarios pass after the fix;
full-run evidence `/private/tmp/miloom-scoped-vault.jOPBYM`. Diff whitespace check
passes. After explicit user approval, applied only 002 plus transactional ledger
registration to Staging. Preflight confirmed absent; SQL Editor returned success.
Readback confirms exact source recorded once (MD5 comparison), qualified lookup,
unchanged authenticated/anon execution ACL, one already-approved Admin device,
and still zero scoped keys/wraps. Evidence screenshot:
`/private/tmp/miloom-admin-staging-fix-20261020.jpg`.
Fix remains uncommitted; Production untouched. Next: reopen owner vault and retry
native sync on already installed Staging build 17, recording the sync counts.

The canonical checkout has unrelated uncommitted UI work, including credential
guidance edits in `EditCompanySheet.swift`. Those files were preserved. Reconcile
that overlap explicitly before a future merge/release; do not overwrite them.

## Two-phone acceptance and cleanup — 2026-10-20

On Staging build 17 after correction 002, user reported initial sync with zero
deliveries/one empty resource skipped. After creating synthetic Test A, sync
delivered one credential key; the Admin revealed both dummy fields with Face ID.
After subsequently adding Test B and syncing with the existing device approval,
the Admin also revealed its two fields. This verifies initial and subsequent
resource delivery, not automatic background delivery or a literal third-resource
native test. No credential values were collected.

User switched entity credential consent OFF and observed the owner-key-replacement
message. After replacing both resource keys, user confirmed owner reveal works
and recipient has only Request Access, not Reveal. No new request was approved.
Through Mirroring, the exact recipient was then downgraded to Viewer. Read-only
SQL confirmed Viewer, consent false, zero Admin device approvals and zero active
credential wraps for the fixture/recipient. User confirmed no Edit on FABIAN's
iPhone. Evidence: `/private/tmp/miloom-admin-viewer-downgrade-20261020.jpg`.

With explicit user approval, deleted only these services through the native app:

- `Admin credential test a`: `f422b7fc-51a4-47f8-a31b-1d0495ea9cb5`.
- `Admin credentials test B`: `362174a2-3d7b-4c05-83ad-6d615761513b`.

Native list returned to only Editor Test Service. Read-only SQL by the two exact
IDs returned zero services, key versions, device wraps and direct shares;
preserved Editor Test Service count 1 and fixture Viewer share count 1. Evidence:
`/private/tmp/miloom-admin-cleanup-20261020.jpg`. Deletion is permanent in the app.

Outstanding boundaries: new-user invitation consent and cross-entity isolation
have local SQL evidence, not hosted/native evidence for this enhancement. The
final enhancement diff still needs independent review, reconciliation with the
canonical UI overlap, and a release decision. The five-case checklist above is
not claimed fully passed on hosted devices. Production is unchanged; feature
changes remain uncommitted and unpushed. Original Phase 7 remains closed.

## Independent automated review and test-gap correction — 2026-10-20

Read-only review chat `01a158a2-7b73-7b23-8d59-70bedb2c8e2c` returned HOLD for
release, with no confirmed unauthorized-access, data-loss or release-blocking
implementation defect. It reviewed the original nine scoped source/test files
and this evidence document at base `49449473`; its recorded manifest fingerprint
was `04f9a3afa38bb44712a31ceeaa8aacce73aec138248abe67c54531afc8525e04`.
That fingerprint predates the test-only correction below and this update.

Established gap: the Admin SQL scenario omitted deployed activation migration
`202610010001`, exercising an older eligibility helper. Added that prerequisite
after the local Auth fixture and verified-email migration, before the Admin
migrations. Added assertions that unverified and anonymous Admin recipients
cannot receive a key or read an existing active grant; verified non-anonymous
access still succeeds. No application or hosted contract changed.

Focused Admin scenario passed (`/private/tmp/miloom-scoped-vault.t3xbRa`); all ten
bounded SQL scenarios then passed (`/private/tmp/miloom-scoped-vault.6zaTs6`).
`git diff --check` and shell syntax check passed. These are fresh local results,
not independent approval of the correction or hosted/native acceptance. Synthetic
versions are still staged/marked active by the SQL fixture; this is not a native
activation/decryption test. No additional native build/test was run.

Remaining release gates from the review: bounded Staging/native new-user
invitation consent and other-entity exclusion; preserve canonical Editor wording
while integrating this enhancement and verify the resulting build; then a
separately authorized compatible Production rollout. This is automated code
review, not an external human security certification. No commit, push, merge or
Production change occurred. The original Phase 7 is not reopened.

## Reconciled build and final acceptance preparation — 2026-10-20

Preserved the canonical Editor explanation in the feature ShareEntitySheet:
owners approve password access separately for each resource and device. No other
canonical dirty changes were imported or overwritten. Signed Staging build 17
rebuilt successfully, passed strict deep codesign verification, installed on FX
after one transient transport retry, and opened to its existing signed-in fixture
dashboard. Log: `/private/tmp/miloom-admin-final-staging-build.log`. Executable
SHA-256: `38f16c9c3b6b8fc42a5201fade2dd762ddee455875cd4c2803383b66fba2a9fb`.
The wording change does not alter permission behavior; the earlier two-phone
acceptance was on the preceding build-17 binary, not this exact executable.

Matching simulator build succeeded (signing disabled) and installed/launched on
the existing disposable `Miloom Invite Recipient 20260923` simulator, at signup.
Log: `/private/tmp/miloom-admin-final-simulator-build.log`. No phone was signed out;
no new native test suite was run. Feature `git diff --check` passed.

Read-only Staging preflight found zero users and zero pending invitations for
`avidyaclothing+miloominvite@gmail.com`. User approved the exact fixture Admin
invitation with credential consent ON. Native confirmation was pressed, but the
subsequent readback still found zero pending invitations and Mirroring reported
iPhone in Use. Asked the user to complete the owner-presence/send step privately
on FX and report success/error. Do not treat the invitation as sent or accepted.
No password was entered or account created in the prepared simulator.

Implementation checkpoint is ready to commit; release remains HOLD pending
hosted/native invitation-consent and other-entity exclusion, fixture cleanup,
and explicit Production rollout approval. No Production change or Apple upload.
