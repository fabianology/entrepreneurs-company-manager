# Collaboration and vault cutover decision

## Approved prelaunch breaking-cutover policy — 2026-09-27

The owner confirms Miloom has **no external app users yet** and elects a
controlled breaking cutover for this original Phase 7 release gate. TestFlight
builds 13 and 9 are test installations, **not supported clients during the
cutover**. We no longer require a separate old-client-compatible additive
backend bridge or proof that every tester upgraded *before* restrictive
enforcement. A bounded outage for the old test builds is acceptable. This
supersedes the additive-bridge and supported-client-upgrade sequencing proposed
below; those sections remain as dated investigation history, not the current
rollout instruction. It does **not** waive the frozen data-loss, unauthorized-
access, scoped-vault, independent-review or explicit Production-approval gates.

Controlled sequence and stop conditions (planned, **not yet executed**):

1. Freeze the exact candidate source and signed build. Confirm the TestFlight
   tester set and that no external users have been invited or granted access
   since the last read-only inventory. Tell testers old builds will stop working
   temporarily; do not rely on disabling a TestFlight build to terminate an
   already-installed app session. New-build distribution remains separately
   authorized.
2. Reconcile Production-recorded `202609070003` with the candidate migration
   directory using the observed current schema/function, without marking a
   valid remote migration reverted. Re-run the **dry run** against the exact
   candidate and inspect every pending migration and dependency. In particular,
   count and resolve any duplicate share/invitation rows before the deletion
   in `202609210002`; preserve intended grants and capture the decision.
3. Obtain a recoverable Production database backup and a pre-cutover inventory
   of sharing, documents, vault ciphertext/wraps and relevant migration history
   (counts/identifiers only in the handoff, no secrets). Rehearse the ordered
   series against a Production-like schema with synthetic data and both
   acceptance/denial assertions. Stop for any unexplained mismatch, deletion,
   access expansion or failed migration. Do not use a blind whole-series push.
4. With separate upload authorization, submit the already exported build
   1.0 (14) for Apple processing if it is still the frozen matching artifact.
   Do not assign it to testers or call it accepted against Production yet.
   A processed build in advance avoids making the maintenance window depend
   on Apple's processing time.
5. In a separately authorized maintenance window, stop old-build testing,
   apply the reviewed migrations in dependency order, deploy only required
   scoped backend functions/configuration, and verify row preservation,
   authorization denials and vault ciphertext/wrap integrity. A partially
   applied series remains a stop condition; repair forward without restoring
   broad secret reads or resetting the database.
6. With separate TestFlight distribution authorization, install and minimally
   accept build 14 against Production: sign-in, redacted resource reads,
   invitation open/accept, authorized document path, vault-locked/recovery
   behavior and denial after revocation. Only then invite testers back on the
   new build. Old builds may fail closed; they must not bypass the new rules.
   Keep global collaborator-password sharing closed until its full release
   gate is separately cleared.

Current state: policy adopted and local signed IPA exported; migration-history
reconciliation, backup, rehearsal, Production authorization/deployment, Apple
upload/processing, installed-build acceptance and post-cutover checks remain
**not done**. This document does not authorize any Production write, tester
change or upload. Production rollout is **HOLD**, not release-ready.

## Read-only Production migration dry run — 2026-09-27

On the unchanged source candidate `44d186c7`, `supabase migration list
--linked --project-ref xxqdytdbpiqjilhutvhz` showed that Production has
applied through `202609210001_secure_active_sessions` but **none** of the
candidate's collaboration/vault migrations `202609210002` through
`202609270003`. Production also records `202609070003`, which is absent from
the clean candidate's migration directory. A same-named account-deletion
storage migration exists only as an untracked file in the canonical checkout;
its exact original applied SQL cannot be proven from the migration ledger alone.
Read-only catalog inspection did confirm that Production's current
`get_account_deletion_storage_objects(uuid)` function definition matches the
local file's function body/signature and that only `service_role`, not `anon`
or `authenticated`, can execute it. This verifies the currently relevant
function contract, not every historical migration side effect.

The CLI's documented `supabase db push --dry-run --skip-vault --linked
--project-ref xxqdytdbpiqjilhutvhz` stopped with
`LegacyDbPushMissingLocalError` for that remote-only version. It did not apply
SQL or update Vault secrets. **Do not follow the CLI's generic suggestion to
mark that Production migration reverted**: the ledger may correctly describe
live schema. Reconcile the historical SQL and candidate manifest first.

Even after ledger reconciliation, a whole-series push is unsafe. The *first*
pending file, `202609210002_canonical_resource_access.sql`, adds versioned
RPCs but also normalizes existing rows, deletes duplicate share/invitation
records, replaces all three access-table policies, and revokes direct mutation
grants. That is a mixed additive/restrictive/data-changing migration, not an
old-client-compatible bridge. Later `202609220008` explicitly revokes broad
SELECT on protected subscription/card/institution tables; known installed
builds 13/9 depend on legacy reads. The current ordered files therefore do
not provide a safe additive-only prefix that can be applied before those
clients upgrade.

Required bounded preparation, still **proposed / not implemented**:

1. Verify the applied `202609070003` schema/function against the untracked
   canonical source, then reconcile the clean candidate without deleting or
   falsifying Production migration history. Preserve the exact reviewed source
   and produce a new signed candidate if source changes.
2. Extract only the minimum old-client-compatible tables/functions/read APIs
   needed by build 14 into a reviewed additive migration. Keep legacy reads
   and writes available during the transition, and explicitly check its
   dependencies against Production. Do not copy the mixed first migration
   wholesale or bypass its data reconciliation without a reviewed alternative.
3. Rehearse that bridge on a Production-like schema with old and new client
   contract checks, including row-count/no-loss assertions and migration
   rollback/forward-repair instructions. Obtain separate approval before
   applying it to Production.
4. After bridge deployment and a separately authorized TestFlight upload,
   verify build 14 against Production and retire/upgrade incompatible supported
   builds. Then review and separately authorize restrictive migrations in
   dependency order, including guards 002/003; keep collaborator-secret
   activation closed throughout.

The read-only inventory/dry run did not inspect identities or content, apply
any migration, upload a build or change Production data. The CLI changed only
its tracked `.temp/cli-latest` cache marker in the candidate; that specific
tool-generated marker was restored to HEAD, leaving the candidate clean.
Production rollout remains **HOLD**. This is Phase 7 release preparation, not
a new implementation phase.

## Local cloud-managed distribution export — 2026-09-27

With the owner's approval for signing setup only, Xcode automatically signed a
Release archive from unchanged clean candidate `44d186c7`, then exported a local
App Store Connect IPA with **destination `export`**, never `upload`:
`/private/tmp/miloom-auto-sign.4AlL71/export/Miloom.ipa` (SHA-256
`3a70ca183ede47ecf45db0886271efdb33fcf8b1fa96aa7b031347f51e3061ce`).
The archive was development-signed; the exported IPA was re-signed as **Cloud
Managed Apple Distribution** according to Xcode's `DistributionSummary.plist`.
That summary records team `WYYJ6FGYRP`, a store provisioning profile, production
push/CloudKit entitlements, `get-task-allow=false` and build 1.0 (14). The IPA's
Info contains bundle `com.vibing.miloom`, full production Supabase URL and a
present public `anon` key with matching production project claim. Key value was
not displayed or committed. Xcode export completed successfully.

Local `codesign --verify --deep --strict` returned `CSSMERR_TP_NOT_TRUSTED` for
the extracted IPA because the cloud-managed distribution certificate is not a
locally trusted signing identity on this Mac; do **not** describe this as an
independently validated Apple upload. Xcode's signed export receipt is positive,
but Apple's App Store Connect processing/acceptance and an installed compatible
build remain unverified. No TestFlight upload, tester change, Production backend
mutation or global collaborator-secret activation occurred. Whether Xcode created
new Apple signing assets versus reused existing managed ones was not established;
the owner authorized either, and no manual certificate/profile deletion occurred.

**Next separate authorization:** upload this exact IPA to TestFlight for Apple's
validation and compatible-client acceptance, after confirming that build 14 is
still available and that the approved additive-backend sequencing is ready.
Known builds 13/9 remain incompatible with restrictive backend enforcement.
Production/global activation stay HOLD.

## Production-configured archive preflight — 2026-09-27

Supersedes the earlier empty-key/`https:` rehearsal archive below. From clean
candidate `44d186c7`, a local **unsigned** Release archive completed using the
existing ignored production `Secrets.local.xcconfig`, cached packages and local
version override 1.0 (14):
`/private/tmp/miloom-ready-config.whG9z2/Miloom.xcarchive`. Built Info verifies
`com.vibing.miloom`, full production Supabase URL and a present public `anon` key
whose project claim matches `xxqdytdbpiqjilhutvhz`; the key value was not
printed or committed. Executable SHA-256:
`578c2e0c90ca8b2bb7b13c234b070743c6bab0cb690a52731dca56a7db3a1de6`.
The local ignored xcconfig URL was minimally corrected from literal `https://`
to Xcode-safe `https:/$()/`; `xcodebuild -showBuildSettings` and packaged Info
both verified the resolved full URL. No tracked source changed, candidate remains
clean. This is a compile/configuration receipt, not device or TestFlight acceptance.

Local keychain inventory under normal permitted access shows one Apple Development
identity and **no Apple Distribution identity**; no provisioning profile directory
was present. `codesign` confirms this archive is unsigned. Do not upload or call it
distribution-ready. Next authorized work must establish distribution signing,
verify final signed entitlements/profile and archive configuration, then obtain
separate approval for additive backend changes and TestFlight distribution. Do not
create Apple certificates/profiles or change production merely to satisfy this
preflight. Production/global secret activation remain HOLD.

## Compatible-release preparation — 2026-09-27

Local compile receipt: unsigned Release archive completed from exact clean candidate
`44d186c7` using cached dependencies and build-number override **14**, stored at
`/private/tmp/miloom-release-prep.ooES0u/Miloom.xcarchive`. Built Info reports
`com.vibing.miloom`, version `1.0 (14)` and the intended Production Supabase URL;
its `SupabaseAnonKey` field is empty, so runtime would use the source fallback.
Archive executable SHA-256 is
`578c2e0c90ca8b2bb7b13c234b070743c6bab0cb690a52731dca56a7db3a1de6`.
`codesign` confirmed the app is **not signed**. This establishes compilation only:
do not export, upload, install or call it a compatible TestFlight build. The
first sandboxed attempt failed before compilation on Xcode service/package
network access; retry using the existing package cache completed with warnings,
no reported build error. No native source, signing or Production service changed.

This is a **preparation checklist**, not authority to sign, upload, retire a
build, alter Production or activate collaborator secrets. Exact reviewed source:
clean staging candidate `44d186c7440017149094200d7751cccd0de2576b`;
implementation checkpoint `0fb1bfdc`. Native binary accepted on Staging is
unchanged by the backend guards; a production-configured device archive has not
yet been accepted or distributed.

Current source preflight: Release targets `com.vibing.miloom`, uses the production
`miloom.co` associated domain and `miloom` URL scheme; target iOS 17. Checked-in
app build number is **11**, while read-only TestFlight inventory already showed
build **13**. A future upload needs a newly available, monotonically higher
number (14 is only a local rehearsal candidate, not an assigned release).
The isolated candidate has no `Secrets.local.xcconfig`; app source contains a
production Supabase URL/anonymous-key fallback, which is not evidence that an
archive was explicitly configured. Entitlement source says `aps-environment`
`development`; verify the final **distribution-signed** entitlements and profile
before upload. Do not change signing/bundle/entitlement settings on assumption.

Ordered authorized rollout, with stop gates:

1. Freeze exact source/build number. Obtain explicit production Supabase public
   configuration through the approved build secret workflow; verify built Info
   values, bundle ID, universal link and distribution signing/entitlements. A
   local unsigned compile/archive may prove compilation only, not TestFlight
   readiness. Preserve source hash and archive/export receipt.
2. Separately authorize and apply only reviewed **additive** production APIs
   needed by the compatible client; verify old-client paths remain supported
   during the transition. Capture backup/recreate and a scoped migration dry run;
   do not use an undifferentiated migration push or expose protected secrets.
3. With separate distribution approval, upload the compatible build to TestFlight,
   install and minimally smoke-test sign-in, entity navigation, redacted reads,
   invitation/deep link and vault-locked behavior against its intended backend.
   Do not mistake simulator/staging acceptance for this production step.
4. Verify every **supported** tester/client has upgraded or explicitly retire
   incompatible support. Merely making a build available is not proof. Known
   installed builds 13 and 9 are incompatible with enforcement.
5. Only after that evidence and explicit production authorization, apply reviewed
   restrictive collaboration/document/vault migrations in dependency order,
   including guards 002/003, verify authorization/denials and the preservation
   of existing ciphertext/wraps. Stop on any unexpected migration, data loss or
   unauthorized access. Keep global collaborator-secret activation closed until
   the scoped-vault release gate is fully approved.
6. On failure, stop delivery/activation, preserve encrypted data and perform a
   forward repair or approved non-destructive containment. Do not restore broad
   legacy secret reads or roll clients back behind the enforced contract.

The fresh bounded independent source/evidence review passed, but was not a
professional audit or production sign-off. Current aggregate Production inventory
has zero company-level Editor edges and zero unconfirmed direct recipients; this
does not replace Auth/provider assurance or the supported-client upgrade gate.

Latest source reconciliation (2026-09-27): candidate `0fb1bfdc` contains the
tested native implementation plus document guard 002 and verified-email guard
003; canonical verified-email commit `d80669ab`. Both guards are deployed and
verified only on Staging. The existing native binary is unchanged. References
to `7294842e` below identify the native baseline, not the latest backend source.
No compatible production-configured build number or release authority is assigned.
Final external review disposition and cutover HOLD remain unchanged.
Read-only Production aggregate inventory later found no company Editor
direct/invitation edges, no unconfirmed/anonymous direct recipients, five direct
shares across two users and no pending invitations. Guards 002/003 have not been
deployed there. This clears current legacy-grant inventory only; it does not
authorize changing live access or relax the compatible-build/ordered-rollout hold.

Date: 2026-09-27. User approved minimum-compatible-release policy; rollout and
deployment remain separately unauthorized.
Part of original Phase 0/7 and frozen release-safety Gate 5; no new phase.

## Approved minimum-compatible-release policy

Require the first production-configured release containing the tested
`7294842e` collaboration/vault implementation (canonical `4cfe9d69`) before
enforcing canonical sharing/revocation and protected-column reads in production.
Exclude build 13 and any other build with the old read/revoke contract from
support at that cutover. Do not restore broad secret-column reads for backwards
compatibility. This changes supported-build policy, not the iOS 17 target.

No numeric minimum release build is assigned yet: a simulator candidate is not
a signed, production-configured TestFlight release. Evidence commit `90714463`
adds documentation only and does not change the candidate binary.

## Evidence and limits

- Known build 13 baseline `d3b05f24` performs full table reads for subscriptions,
  institutions and cards, calls legacy `share_resource`, and directly deletes
  resource invitations. Rechecked against Git source on this date.
- Current DataRepository uses redacted `miloom_visible_*` RPCs and canonical
  sharing/revocation. Legacy read fallback is limited to missing-RPC errors;
  this is not an old-client fix or proof of production server readiness.
- Protected-column read and canonical revoke enforcement would break the known
  build 13 paths. `PRODUCTION_SHARING_COMPATIBILITY_20260922.md` is a dated audit,
  not a live production reinspection on September 27.
- Available TestFlight builds and Apple's tester installation/status summary
  were inspected read-only as recorded below. No compatible tester upgrade has
  occurred yet. Availability alone never proves all supported testers upgraded;
  no force-upgrade mechanism is claimed here.
- Staging candidate native/SQL acceptance and fixture cleanup are recorded in
  `COLLABORATION_BOUNDED_CLOSEOUT_20260926.md`; they do not authorize production.

## Bounded rollout conditions

1. Owner accepted the minimum-compatible-release policy above on September 27.
   Record the chosen
   actual release version/build when a separately authorized release is made.
2. Obtain a read-only TestFlight build/tester inventory. Classify each supported
   build by its source contract; record upgrade evidence. Any unknown contract
   or remaining supported incompatible build keeps enforcement on hold. Retiring
   a build in App Store Connect is a separate authorized mutation.
3. Independent reviewer examines the exact candidate/diffs and recorded bounded
   evidence. Focus only on roles/scopes, invitation acceptance/removal/blocking,
   documents, migration/key/recovery/grant/revoke/rotation isolation, and rollback.
   Record any critical access/data-loss finding as a failed gate. Review remains
   the final external gate; this document is not an independent review.
4. Under separate production authorization, distribute the compatible client
   and additive server/read APIs before incompatible enforcement. Require the
   supported-client inventory and acceptance evidence before legacy write/read
   closure. Do not run an undifferentiated migration push.
5. Keep global collaborator-secret activation closed until the full scoped-vault
   gate and independent review pass. Existing privileged disposable fixture
   activation did not establish normal-client/global activation readiness.

## Rollback disposition

Previously recorded local containment rehearsal revoked delivery RPC execution,
verified authenticated denial, preserved encrypted versions/wraps/audit records,
and restored exactly the tested privilege while keeping anonymous denial.
This is delivery containment, not destructive schema reversal. On a release
security failure: stop delivery/activation, preserve encrypted data, and forward
repair. Never recover service by restoring broad legacy secret reads or plaintext
columns. Do not roll back to an incompatible native build after enforcement.
Containment commands/deployment still require authorization in the actual target.

## Current remaining gate

Policy approval and the read-only TestFlight inventory are complete.
The initial App Store Connect attempt reached Apple sign-in; the user completed
authentication and the live inventory below was then inspected. No credential
or code requested in chat and no build retirement performed. Independent
security review is explicitly recorded as the final external gate. Production rollout
is not authorized or complete. After policy acceptance, next work is the bounded
review handoff and compatible-release distribution conditions, not another
whole-app UI acceptance pass.

## Live read-only TestFlight inventory — September 27

App Store Connect app `6770341276`, version 1.0. Latest uploaded build: 13.
No newer compatible release was listed. Internal group Devs; external group
Family + Friends. Visible build table:

| Builds | Status | Groups |
| --- | --- | --- |
| 13 | Testing | Devs, Family + Friends |
| 12 | Ready to Submit | Devs |
| 11 | Testing | Devs |
| 10 | Ready to Submit | Devs |
| 9, 8 | Testing | Devs, Family + Friends |
| 7 | Ready to Submit | Devs |
| 6 | Testing | Devs |
| 5, 4 | Expired | None shown |

All Testers lists 7 entries: 5 report Installed 1.0 (13), 1 reports Installed
1.0 (9), 1 reports No Builds Available. Tester identities/emails are intentionally
omitted. These are Apple's displayed installation/status records, not proof of
each device's present running binary or a compatible upgrade. Build install
counters are cumulative and not the current tester count. Earlier expired builds
below the first table page were not enumerated; they are not a compatible-release
candidate or a justification to relax enforcement.

Known build 13 is incompatible; build 9 predates the accepted implementation and
is excluded under the approved policy, not newly certified by source inspection.
**Cutover remains HOLD:** no compatible release has been uploaded/distributed and
no tester can yet be counted as upgraded to it. Under separate release authority,
ship the compatible build, verify upgrades or explicitly retire incompatible
support, then enforce backend protection. Nothing in App Store Connect was
changed by this inventory; no export of private tester contacts was made.
