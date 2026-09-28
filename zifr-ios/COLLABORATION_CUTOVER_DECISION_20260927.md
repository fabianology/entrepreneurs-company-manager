# Collaboration and vault cutover decision

### Production SQL cutover resumed; bounded function rollout — 2026-09-28 UTC

The owner approved removing only orphaned share
`152fea3f-0060-4581-8618-f2013cd1aba7` (a subscription `Admin` grant
pointing to a missing subscription). A guarded transaction confirmed its exact
recipient, role, scope and missing target, removed that one row, and left four
direct shares. No other share was removed. This changes Production data and is
recoverable only through the encrypted pre-cutover backup; it was not an
invitation-wide block.

From the unchanged clean `b0d15d83` candidate, the remaining SQL migrations
were byte-checked, dry-run in cumulative batches and applied in order. The
full Production migration history is now 71 rows (28 prior + all 43 planned);
the final exact-candidate `db push --dry-run --skip-vault` reports no pending
migrations. Read-only post-apply inventory remains nine Auth users, nine
companies, three documents, two invitations, two buckets and seven Storage
objects totaling 19,184,602 bytes; there are four direct shares after the
authorized removal. Duplicate/normalization, company Editor, unconfirmed
direct-recipient and nonentity Admin checks are zero. Production has no account
vaults, device/key wraps or resource-secret versions. Catalog checks show no
anonymous/authenticated execute grant on global scoped-secret activation and
no authenticated direct SELECT on sampled legacy credential columns. These are
database checks, **not** installed-app acceptance.

Deployed only the candidate `approve-vault-device` and
`prepare-document-upload` functions with JWT verification on, and
`cleanup-document-files` with JWT gateway verification off but its own service
role/cron-secret authorization. Live metadata shows all three ACTIVE, version
1, with the intended settings. Empty unauthenticated POST requests to each
returned 401. Before enabling cleanup, read-only checks found zero queued,
reserved or orphan-candidate document files. Existing Production Edge and
Vault cron secrets matched by non-displayed SHA-256 digest. Configured the
exact Production cleanup-function URL in Vault and enabled the named
`miloom-document-file-cleanup` job every 15 minutes. Post-write checks show
the job active, its Vault URL exact, and the queue still empty. The first
clock-triggered run and authorized upload/remove flow have **not** been
observed on Production.

Production has no `RESEND_API_KEY` or `SHARE_EMAIL_FROM` secret. The existing
`send-share-email` deployment was left untouched; the reviewed candidate
requires those settings. Production sender/key setup, reviewed email-function
deployment and a disposable live invitation test remain a hold pending
separate owner authorization. The signed build 1.0 (14) has **not** been
uploaded or distributed, and no native flow has been accepted against this
Production backend. Global collaborator-password activation remains closed.
The backend SQL/function work above does **not** make the release ready.

### Production migration safety stop — 2026-09-28 UTC

The owner authorized a prelaunch Production backend maintenance cutover, but
**not** Apple build 14 upload/distribution. After the fresh encrypted v3 backup
and exact 43-migration dry run below, the committed `b0d15d83` SQL was staged
in small cumulative batches. Batch 1 applied `202609210002`–`202609210006`
successfully. Batch 2 applied `202609220001`–`202609220008`, then the explicit
guard in `202609220009_admin_entity_scope_guard.sql` refused to proceed with
`NON_ENTITY_ADMIN_ACCESS_REQUIRES_REVIEW`. No later migration or Edge Function
has been deployed. Production's migration history now has 41 rows (28 prior +
13 newly applied); this is a **partial cutover**, not release-ready.

Read-only post-stop checks found the same nine Auth users, nine companies,
three documents, five direct shares, two invitations, two buckets and seven
Storage objects (19,184,602 bytes), with no duplicate or normalization rows.
The blocking row is exactly one direct `Admin` grant on resource type
`subscription`, for which the referenced subscription ID has no matching row
in `public.subscriptions`; the recipient is the owner's known
`avidyacc@yahoo.com` account. Exact share ID:
`152fea3f-0060-4581-8618-f2013cd1aba7`; missing resource ID:
`627ba667-87e0-4ea8-adc5-f20c831979b1`. The guard checks even such
orphaned records.
No share was deleted or downgraded. Migration work is stopped pending the
owner's explicit decision on this orphaned Production record. Old TestFlight
test builds may now fail against the partially cut-over backend, as allowed by
the approved prelaunch breaking-cutover policy. Do not claim app acceptance or
upload build 14 until separately authorized.

### Fresh pre-cutover backup receipt — 2026-09-28 UTC

After the Mac was unlocked, the exact clean candidate `b0d15d83` was restored in
a new isolated worktree; the previous temporary checkout had been cleared. The
existing v2 encrypted archive was decrypted with the Apple Passwords key and its
tar contents validated locally. A fresh read-only Production export then captured
the database roles/schema/data and all seven Storage objects (19,184,602 bytes),
with object sizes matched against Storage metadata. The new encrypted archive is
`Downloads/Miloom-Backups/20260928T0313Z-precutover/Miloom-Production-Precutover-v3.tar.gz.aesgcm`,
SHA-256 `493aa476b1776ce37247b2e504da8de8a23e802bfe7528e940d03e54d247838b`,
29,092,953 bytes, mode 600. It uses the **same** key saved in the owner's Not
Shared Apple Passwords entry; no new key was generated. Decryption, byte-for-byte
tar comparison, and tar integrity check passed. The v3 archive is local only;
the older verified v2 remains the encrypted iCloud copy. No independent cloud
download was attempted, per owner decision.

The fresh transaction-read-only counts were nine Auth users, nine companies,
three documents, five direct shares, two invitations, two buckets and seven
Storage objects. Duplicate share/active-invitation, role/status/email
normalization, company Editor and unconfirmed/anonymous direct-recipient checks
were all zero. An authenticated dry run from the exact clean candidate again
listed 43 pending migrations, `202609210002`–`202609270003`, with no historical
`202609070003` replay. Temporary plaintext, service/API credentials and the
clipboard key were removed after verification. No Production migration, Edge
Function, Apple upload or tester change occurred during this receipt.

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

Current state: policy adopted, local signed IPA exported, schema-only and
synthetic-row full-order rehearsals passed, the candidate migration manifest
was reconciled, and a local encrypted Production logical backup passed an
isolated database restore check. Fresh at-cutover inventory, separately
authorized Production deployment, Apple upload/processing, installed-build
acceptance and post-cutover checks remain **not done**. This document does not
authorize any Production write, tester change or upload. Production rollout is
**HOLD**, not release-ready.

### Apple upload timing decision — 2026-09-28 UTC

Read-only App Store Connect inventory still showed build 13 as the latest
upload; build 14 was not listed. The internal **Devs** group has one tester and
its Build Distribution setting is **Automatic for Xcode Builds**. The external
**Family + Friends** group has six testers and no automatic-distribution setting
shown. An advance upload cannot safely be described as processing-only because
it may make the new build available to the internal tester before the backend
cutover. The owner chose **wait until the cutover** rather than permit that
early distribution. Step 4 above is therefore deferred to the authorized
maintenance sequence; do not upload before checking current group behavior and
obtaining the separate upload/distribution authorization. Apple processing
time is now a possible maintenance-window dependency. No group setting,
tester assignment, upload, or Production service was changed during this check.

### Encrypted local rollback backup — 2026-09-28 UTC

Supabase's read-only physical-backup listing returned no CLI-visible physical
backup and reported PITR disabled. A manual logical backup was therefore
captured to a private folder **outside Git**:
`/Users/yager/Downloads/Miloom-Backups/20260928T0313Z-precutover/`.
The current AES-256-GCM archive is
`Miloom-Production-Precutover-v2.tar.gz.aesgcm`, SHA-256
`54c6d1240a3fdaeb650866ea76521bd0716d03e4dfa929941050e828363f8c75`.
Its random decryption key is in this Mac's login Keychain and in the owner's
**Not Shared** Apple Passwords entry `Miloom Production backup — 2026-09-28`,
not in the archive; `RECOVERY.md` and a keyless decryption tool are alongside
it. The saved Passwords value was checked byte-for-byte against the replacement
Keychain key and used to decrypt the archive. Apple Passwords showed iCloud
Passwords On on this Mac, but availability on another Apple device was not
independently verified. Access is mode 700 on directories and mode 600 on the
archive. The original archive and its old Keychain key were deleted after
rotation; only the v2 pair should be used. With owner approval, an encrypted-
only copy was placed in the private `Miloom Backups` iCloud Drive folder; it
matched the local archive byte-for-byte and by SHA-256. The Mac's CloudDocs
container reported caught up and listed the item without a pending-upload
marker. Download from another device or iCloud.com remains untested, so this
is not yet an independently proven device-loss recovery path. No plaintext
archive or key was copied to the folder. Apple Passwords and iCloud Drive
share the owner's Apple account; the owner also reports a paper key copy.

### Repeat read-only preflight — 2026-09-28 UTC

The owner elected to skip the independent iCloud download/checksum test and
continue cutover preparation. The iCloud Drive sync observation above is not
an independent restore-from-cloud test; this residual device-loss recovery
uncertainty is recorded rather than treated as verified.

The exact isolated candidate remained clean at `b0d15d83`. Its manifest-only
historical migration addition did not change the already-exported native IPA;
the local build 1.0 (14) still matched SHA-256
`3a70ca183ede47ecf45db0886271efdb33fcf8b1fa96aa7b031347f51e3061ce`.
An authenticated `supabase db push --dry-run --skip-vault` against explicit
Production ref `xxqdytdbpiqjilhutvhz` again listed exactly 43 pending
migrations, `202609210002` through `202609270003`, and did not propose
reapplying the reconciled historical `202609070003`. No SQL was executed.
The CLI's generated version marker was restored to its exact prior bytes,
leaving the candidate clean. Aggregate counts, duplicate/normalization
checks, backup freshness and supported-tester state are time-sensitive and
must be rechecked immediately before an explicitly authorized cutover.
No Production service, Apple distribution setting or tester was changed.

### Authorized maintenance preflight paused — 2026-09-28 UTC

The owner authorized starting the Production maintenance/backend cutover, but
**not** uploading build 14 or changing tester distribution. The rollout has
not begun: no migration, function or configuration was deployed. A fresh
authenticated dry run still listed the same 43 pending migrations from the
clean candidate. Transaction-read-only Production inventory found nine Auth
users, nine companies, three company documents, five direct shares, two
invitations, two Storage buckets and seven Storage objects totaling 19,184,602
bytes. It found zero duplicate share/active-invitation rows, zero role/status/
email normalization rows, zero company-level Editor edges and zero direct
recipients with unconfirmed/anonymous Auth identity. These are aggregate
observations only, not a data-fidelity or backup proof.

A fresh private logical database export and all seven Storage file bytes were
captured without displaying contents; file sizes matched Storage metadata.
Encryption with the already-escrowed backup key could not complete because
Mac Keychain access waited for unlock. The waiting processes were stopped and
the temporary plaintext export, archive, API key and ephemeral database login
files were removed. The previously verified encrypted v2 backup remains local
and in iCloud Drive, but the new capture was **not** retained. The helper's
source/binary were updated and a synthetic-key seal/open round trip passed;
that does not verify a fresh Production backup. **Stop condition:** do not
apply Production migrations until the Mac is unlocked and a new encrypted
snapshot is captured and verified, with the time-sensitive checks repeated.

The archive contains role definitions, current `public`, `auth`, `storage`,
`extensions` and migration-history schema definitions; data for `public`,
`auth`, `storage` and migration history; plus actual bytes of all seven Storage
objects. At capture, read-only counts were nine Auth users, nine companies,
three company documents, five direct shares, two invitations, two Storage
buckets and seven Storage objects. Downloaded Storage bucket/key/size inventory
matched the database inventory exactly; total file bytes were 19,184,602.

Recovery was tested from the **encrypted archive**: Keychain decryption
produced a byte-identical tarball, which extracted successfully; its SQL
restored to an isolated local PostgreSQL 17.11 instance, and all listed row
counts plus 28 migration-history rows matched. The test did not restore into
Supabase, re-upload files through Storage API, validate project settings or
Edge Function configuration, or prove a live Production rollback. Separate
schema exports were taken over a short interval, not one cross-schema snapshot;
refresh this backup and inventory immediately before cutover if data changes.
The temporary plaintext SQL, downloaded files and local restore database were
removed after verification. No Production data/schema write occurred.

### Synthetic-row preservation and manifest reconciliation — 2026-09-27

A fresh schema-only Production snapshot of `public`, `auth`, `storage` and
`extensions` was restored to a disposable PostgreSQL 17.11 instance on a
private local Unix socket. No Production rows or Storage bytes were exported.
Synthetic fixtures comprised three Auth users, two companies, two services
with placeholder legacy credential strings, one document reference, two
independent direct shares (company Viewer and service Editor), and two pending
invitations. Before/after assertions checked exact ownership, record identity,
scope, role, invitation state, document URL and placeholder credential values.

All **43 pending migrations** applied in version order and the preservation
assertions passed. The first attempt at migration `202609220029` failed while
indexing the seeded document because the *local rehearsal runner* had created
prior migration functions as `yager` but the restored Production table was
owned by `postgres`. After aligning the disposable instance's migration-owned
objects and running as `postgres`, migration 029 and every remaining migration
passed. This is a runner-ownership mismatch, not an observed candidate SQL
failure under the Production owner. The rehearsal does not prove live data
behavior, restoreability or authorization flows.

The already-applied historical `202609070003_account_deletion_storage.sql` was
added byte-for-byte from the canonical checkout to clean candidate branch
`codex/collab-staging-candidate-20260923` in commit `b0d15d83`. Prior read-only
catalog inspection found its function signature/body and execute privileges
match Production's current state; the historical ledger alone cannot prove
every side effect of the originally applied file. An exact-candidate
`supabase db push --dry-run --skip-vault` succeeded and listed **43 unique
pending migrations**, `202609210002` through `202609270003`, without proposing
to reapply `202609070003`. The candidate is clean. This migration-manifest-only
commit does not alter the iOS source or the previously exported build 14 IPA.

The later encrypted-backup receipt above completes the local backup and
isolated database restore check. Fresh aggregate inventory, Storage/API restore
planning, exact candidate/build provenance and separate rollout authorization
remain before any Production maintenance cutover. No Production SQL was applied
here.

### Production-schema-only full-order rehearsal — 2026-09-27

Supabase's container-based schema export failed locally because no Docker
socket was running; it did not change Production. A direct, non-echoing
`pg_dump --schema-only` route then copied only the current `public`, `auth`,
`storage` and `extensions` schema definitions into a mode-700 temporary
directory. No table rows or actual Storage objects were exported. The
short-lived CLI login script stayed in that directory and was removed after
the dumps; its credential was not displayed in this attempt.

Those definitions were restored to an isolated PostgreSQL 17.11 instance
bound only to a private Unix socket. Standard local UUID/crypto extensions
were added, and Auth triggers whose public functions load later were completed
after the public schema restore. The database contained zero Auth users. All
**43 pending migrations** from the exact candidate's migration directory
then applied successfully in version order, `202609210002` through
`202609270003`. The transactional synthetic verified-email invitation contract
passed, including unverified/anonymous denial and verified ID/token acceptance
and decline; afterward local Auth users, direct shares and invitations were all
zero. The local instance was stopped and the schema dumps, logs, temporary
script and cluster were deleted. This was a schema/empty-data rehearsal, **not**
a Production write, restoreable backup, data-preservation proof or full app
acceptance. The candidate source/IPA stayed unchanged.

The later synthetic-row and manifest receipt above supersedes those two local
preparation gaps. A recoverable Production backup and fresh aggregate checks
remain required before any separately authorized maintenance cutover.

### Read-only preflight receipt — 2026-09-27

The canonical checkout's migration directory is byte-for-byte identical to
clean candidate `44d186c7` **except** for its untracked historical
`202609070003_account_deletion_storage.sql`. Production already records that
version, and its current helper definition plus role privileges matched the
file's relevant SQL. Running `supabase db push --dry-run --skip-vault` from the
canonical checkout against explicit Production ref `xxqdytdbpiqjilhutvhz`
completed and listed exactly **43 pending migrations**, from `202609210002`
through `202609270003`, in version order. This was a no-write listing, **not**
a successful migration execution, and does not establish SQL compatibility
with Production's schema. Do not perform a history repair or use the dirty
canonical checkout for an actual push.

Aggregate Production checks at this point found five direct share rows, two
invitation rows, **zero duplicate rows** that the first pending migration's
deduplication would remove, and zero rows requiring its share-role,
invitation-role/status or invitation-email normalization. No identities or
record contents were retrieved. These counts may change and must be repeated
immediately before a live cutover; they are not a backup.

The existing local Unix-socket PostgreSQL rehearsal of migrations
`202609220009`–`033` and its loan/institution-collection assertions passed on
synthetic fixtures. The first sandboxed attempt failed before setup because
PostgreSQL shared memory was denied; the permitted local-only retry passed.
That earlier script did **not** cover the whole 43-file Production sequence or
live Storage/Auth behavior. The later schema-only full-order result above
supersedes its syntax/order gap, but a data-bearing preservation rehearsal,
recoverable backup and post-apply invariants remain before a Production write.

The attempted `supabase db dump --dry-run` printed a temporary CLI database
login password in tool output. No schema or data dump was executed. Do not
repeat this CLI dry-run or copy its output into project records. Supabase's
documented `cli_login_postgres` password normally expires within a few hundred
seconds; treat the displayed value as exposed until expiry, and use a method
that does not echo credentials for any later schema-only rehearsal. The value
is not reproduced here.

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
