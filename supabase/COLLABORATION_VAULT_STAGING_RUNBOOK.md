# Collaboration and Vault Staging Rollout

Track: Collaboration and Vault, staging acceptance gate

Baseline: `0cdaf4cbf43e54f9808d397dc4552ae4a2d1907d`

Update, 2026-09-22: The gates below record the **initial** staging rollout and
are not a claim about current live state. The last documented live backend
check reached migration `202609220008`; live state must be queried again
before any mutation. Local source now includes migrations through
`202609220029` and native checkpoint `69574861`. The read-only preflight checks
the local artifacts and staging CLI link, not migration drift or readiness.

This runbook is the first phase after source implementation. It deliberately
separates staging validation from production release and does not authorize a
production deployment.

## Current safety boundary

- The verified Phase 5 baseline is pushed to
  `origin/codex/phase-7-notification-experience`.
- The checkout's existing Supabase link points to project
  `xxqdytdbpiqjilhutvhz`, named **Miloom**. Repository operations identify this
  as production. Do not use that link for this staging pass.
- Supabase project `bvtuyzhyospqxvpzcrmv`, named **Miloom Staging**, was
  created in `us-east-1` with Data API enabled, automatic exposure of new tables
  disabled, and automatic RLS enabled. It began healthy with no migrations or
  production data.
- Supabase CLI `2.117.0` and Deno `2.9.7` are installed on the current host.
  The checkout is linked to Miloom Staging and the staging-only preflight passed
  on 2026-09-21. The production link was replaced rather than reused.
- The generated staging database password was not written to the repository or
  logs. Reset or retrieve it through the approved secure credential workflow
  before a CLI operation that requires it.
- On 2026-09-22, the audited production `public` and `private` schema was copied
  into staging without table rows, auth users, Storage objects, secrets, or cron
  jobs. The combined schema artifact was 244,514 bytes with SHA-256
  `ea59128bbda4cffcdb21b67544bbcd9c1c6e7bc5bf05e69483b75fe4019468d3`.
- Staging now has migrations through
  `202609220004_disable_automatic_invitation_acceptance.sql`. The five planned
  collaboration/vault migrations, the invitation-status forward repair, and
  the legacy-client security wrapper all passed their current rollback-only
  contract suites. The auth-trigger repair restores the app-owned profile and
  account-cleanup triggers attached to `auth.users`, which are not included in
  a public/private schema-only export, while intentionally disabling the legacy
  signup trigger that bypassed explicit invitation acceptance.
- `send-share-email` deployment `2001e494-be58-42d8-9d80-998cc102df20` and
  `approve-vault-device` deployment `df2277ed-2f9c-4428-bb69-eba7b95e1831`
  are active in staging with gateway JWT verification enabled. Anonymous HTTP
  requests return 401.
- Staging custom secrets are still empty. Invitation delivery therefore remains
  intentionally unavailable until a staging-only Resend key and sender are
  configured. No website asset or production system was deployed or changed.

## Gate 1 — create and identify staging

1. Use only **Miloom Staging** (`bvtuyzhyospqxvpzcrmv`). Do not reuse the Miloom
   production project.
2. Confirm the project remains healthy and empty before each rollout attempt.
3. Install the current Supabase CLI and Deno through the team's approved
   package-management process.
4. Link the CLI to the staging ref, then run:

   ```sh
   supabase/ops/collaboration_vault_staging_preflight.sh bvtuyzhyospqxvpzcrmv
   ```

The preflight is read-only. It accepts only the approved staging ref, rejects
the known production ref, requires the explicit ref to match the CLI link,
confirms the verified Phase 5 commit is in history, rejects uncommitted rollout
artifacts, and checks the universal-link contract.

### Resolved staging baseline

The first staging dry run on 2026-09-21 correctly performed no deployment, but
it proposed all 33 tracked migrations because the new staging project has no app
schema or migration history. Production's read-only catalog shows the complete
app schema and migration history through `202609210001`; migrations
`202609210002` through `202609210006` are not present there. Do not push the
33-migration plan and do not mark unapplied versions as repaired.

The audited schema-only staging baseline now matches production through
`202609210001`. Exact verification after the rehearsal reported 52 public
tables, zero rows across all 52, zero auth users, zero Storage objects, and no
cron job table. Migration history contains all 37 repository migrations through
`202609220004`, and the final dry run reports no pending migrations.

## Gate 2 — schema rehearsal and dry run

1. Capture a restorable staging backup or recreate point.
2. Export schema, policies, grants, functions, and migration history from
   staging. Compare them with the assumptions in the six migrations. Do not
   export production user data into staging.
3. Run Deno checks for both edge functions and execute
   `functions/_shared/share_email_test.ts`. Stop on any type-check or test
   failure.
4. Run a Supabase migration dry run and inspect every proposed version. With
   the approved current-production baseline, the pending collaboration/vault
   sequence must be exactly:

   1. `202609210002_canonical_resource_access.sql`
   2. `202609210003_invitation_lifecycle.sql`
   3. `202609210004_vault_key_foundation.sql`
   4. `202609210005_vault_device_approval_and_recovery.sql`
   5. `202609210006_vault_rotation_and_device_revocation.sql`
   6. `202609220001_expand_resource_invitation_statuses.sql`
   7. `202609220002_harden_legacy_resource_access.sql`
   8. `202609220003_restore_auth_user_triggers.sql`
   9. `202609220004_disable_automatic_invitation_acceptance.sql`

   The September 22 migrations are forward repairs discovered by staging:
   the first expands production's older invitation-status constraint; the
   second keeps older client RPC signatures while routing them through the
   canonical owner-authorized implementation and denying anonymous execution;
   the third restores app-owned profile and account-cleanup triggers attached to
   the managed `auth.users` table while disabling legacy invitation auto-claim;
   the fourth is a forward repair for staging environments that briefly
   restored that incompatible legacy trigger.

5. Stop if the dry run includes an unexpected migration, destructive statement,
   legacy-RPC removal, or monetization-enforcement change. Reconcile migration
   history before continuing.
6. Rehearse the SQL contracts against a disposable database and retain the
   pass/fail output. The suites must roll back their fixtures.

## Gate 3 — staging backend and web assets

1. Confirm the audited baseline includes `001`, then apply migrations `002`
   through `006` followed by the September 22 forward repairs in timestamp
   order.
2. Configure staging function secrets using a secure secret source, never shell
   history or a tracked file:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
   `RESEND_API_KEY`, and `SHARE_EMAIL_FROM`.
3. Use a staging-only Resend credential and sender. Restrict test recipients so
   acceptance testing cannot email real customers.
4. Deploy `send-share-email`, then `approve-vault-device`, to the explicit
   staging project ref. Do not rely only on the current CLI link.
5. Publish the reviewed Apple association file and script-free `/invite`
   fallback. Confirm `https://miloom.co/.well-known/apple-app-site-association`
   returns HTTP 200, `application/json`, and no redirect before testing links.
6. Record migration versions, function deployment identifiers, website commit,
   UTC time, operator, and staging project ref.

## Gate 4 — staged acceptance matrix

Use disposable Owner and Collaborator accounts plus two physical iOS devices.
Do not use production accounts or real financial records.

### Collaboration

- Direct share to a registered recipient and invitation to an unregistered one.
- Inbox and universal-link accept/decline; wrong-account, expired, and replayed
  token denial.
- Resend rate limit, cancellation, Viewer/Editor/Admin role behavior, and owner
  management isolation.
- Revoke only this resource, all access in the entity, and all access for the
  person; verify invitation and direct-share rows are both removed at the chosen
  scope.
- Block, prevented re-invite, unblock, collaborator leave, and older-client
  compatibility while legacy RPCs remain available.

### Vault

- First-device setup, one-time recovery-code capture, sign-out, relaunch, and
  unlock with Face ID or device passcode.
- Second-device pending request, five-minute signed approval, replay rejection,
  recovery-based approval, and reinstall behavior.
- Legacy plaintext/readable-ciphertext migration and explicit preservation of
  unreadable legacy values.
- Pending-request cancellation and approved-device revocation with exact
  remaining-device wraps.
- Key rotation with multiple remaining devices; interruption after server-side
  rotation; resume after relaunch; recovery during the transition; completion
  only after every old-version field is migrated.
- Linked-session revocation, current-session preservation, stale-token behavior,
  replacement recovery code, audit events, offline/error recovery, and retry
  idempotence.
- Before the separate scoped-secret cutover, a collaborator can edit allowed
  non-secret fields but receives no password or account number. After cutover,
  only an explicitly approved Editor/Admin device may reveal credentials for
  its exact granted resource; no collaborator receives the account vault key or
  recovery material. Viewer and unapproved devices remain credential-blind.

Capture the exact app commit/build, device/OS versions, staging project ref, and
evidence for every case. A successful build alone is not acceptance evidence.

## Stop and rollback rules

- Stop immediately for cross-owner data visibility, anonymous RPC access,
  plaintext secret material in Supabase/logs, reusable invitation/challenge
  tokens, missing key wraps, or an unrecoverable rotation.
- Disable distribution of the staging client and redeploy the last known-good
  edge functions before investigating.
- Prefer revoking execute/table privileges or disabling the new UI over dropping
  tables. Do not delete vault or sharing data as incident response.
- Restore staging from its recreate point if fixture cleanup or migration state
  is uncertain. Production remains untouched.

## Production entry criteria

Production planning can begin only after all gates pass, an independent security
review closes its findings, the previously exposed email-provider credential is
rotated, rollback is rehearsed, monitoring is defined, and an internal TestFlight
candidate is built from one clean, pushed commit. Production deployment remains
a separate, explicit owner decision.

## Continuation gate — scoped credentials and document files

This is the next staging gate, not evidence that it has passed. Obtain explicit
approval for staging-only changes before any migration, Edge Function deployment,
secret change, Storage configuration, or scheduled job. Confirm the project ref
is `bvtuyzhyospqxvpzcrmv` at every write step; never use the production ref.

Read-only inventory on 2026-09-22: the linked staging migration ledger ends at
`202609220008`. Active Edge Functions are `send-share-email` v1 and
`approve-vault-device` v2; neither document-file function is deployed.
Metadata-only SQL confirmed the relevant public and Storage tables exist, but
the `CompanyDocuments` bucket does not. Aggregate counts were zero documents,
zero document objects, zero invitations, and one company Viewer share. This
inventory is dated; repeat it before any write. A schema-only CLI dump could
not run because Docker was unavailable, so the synthetic database rehearsal
does not prove compatibility with every live constraint, trigger, or policy.
The staging policy inventory showed no `storage.objects` policies and multiple
legacy `company_documents` policies; test the new restrictive Storage policies
and document mutation triggers against those existing grants after rollout.

1. Record a fresh, read-only inventory of the staging migration ledger, active
   function versions, required secrets, private `CompanyDocuments` bucket
   configuration, and any migration drift. Resolve discrepancies before writes.
   The local preflight cannot establish this state.
2. Run `sh supabase/ops/rehearse_collaboration_vault_pending_migrations.sh`
   for the repeatable synthetic migration-order check. Then rehearse the exact
   pending migrations `202609220009`–`202609220029`, in order, against a
   disposable production-shaped database with representative
   legacy shares, credentials, documents, and full-URL file references. Check
   SQL assertions and rollback/recreate steps. Keep migration `017`'s initial
   resource-secret cutover closed until its separate acceptance gate passes.
3. On approved staging only, apply the reviewed migrations and create the
   private `CompanyDocuments` bucket (25 MB maximum). Deploy and configure
   `prepare-document-upload` and `cleanup-document-files`; verify their
   authorized service credentials and health without logging tokens or files.
4. Use two disposable accounts and two devices to exercise upload, open,
   replace, remove, entity deletion, revocation, orphan cleanup, and retry.
   Check both metadata and the actual `storage.objects` rows, including
   `owner_id`, while ensuring an external document link opens without a Storage
   request. Viewer and unrelated-resource access must be denied. Run the
   cleanup worker manually first; only then install the schedule from
   `supabase/ops/schedule_document_file_cleanup.sql` and observe a real run.
5. Separately exercise scoped credential grants: exact resource and device
   approval, Editor/Admin reveal and edit, Viewer denial, revoke/rotation,
   recovery, and legacy migration. No collaborator may receive the owner's
   account vault key or another resource's secret. Record the client build,
   migration state, role, device, and outcome for every case.

Do not distribute a client that assumes this backend until these checks pass.
The previously installed build 13 has a different sharing contract; inventory
test devices and coordinate an upgrade before enabling new flows. Production
requires its own explicit decision and release gate above.

### Staging continuation checkpoint — 2026-09-22 PDT

This is evidence for **Miloom Staging only**, not production acceptance. The
read-only preflight, migration ledger inspection, and dry run identified exactly
`202609220009`–`202609220029` as pending. Those 21 migrations were applied to
`bvtuyzhyospqxvpzcrmv`; the post-push ledger showed no pending migration.
The `CompanyDocuments` bucket was created through the Storage API as private,
with a 25 MiB file-size limit. The scoped-secret activation function remains
closed to the authenticated role.

`prepare-document-upload` v2 is active with gateway JWT verification.
`cleanup-document-files` v1 is active without gateway JWT verification and
requires a staging-only `x-cron-secret` in its handler. Both rejected anonymous
requests with HTTP 401. The cron secret was stored in staging Edge secrets and
encrypted database Vault; the cleanup URL is a staging-only Vault secret.
No secret value was recorded here. The manually invoked worker returned
`removed=0, failed=0` before scheduling. `pg_net` and `pg_cron` are enabled in
staging. The single active `*/15 * * * *` cleanup job is installed; a
database-origin `net.http_post` returned HTTP 200 and
`{"removed":0,"failed":0}`. The first actual clock-triggered run succeeded at
2026-09-23 02:30 UTC (`cron.job_run_details` job 1); its `pg_net` response was
HTTP 200 with `{"removed":0,"failed":0}`.

The disposable hosted smoke in `supabase/ops/staging_document_file_smoke.ts`
passed on three separate signed-in staging accounts. An exact document Editor
uploaded, finalized, read, and replaced a file; the old file was queued and
removed. A company Viewer could read but not upload. Direct Editor upload into
the owner's folder was denied. Revoking the exact Editor share denied a new
signed read URL while the independent company Viewer share still worked.
Owner document deletion queued and removed the replacement file. Owner entity
deletion then cascaded a second document row and its file was removed by the
worker. The smoke inspected
the actual `storage.objects` row: `owner_id` was null for the service-issued
signed upload, while the owner folder and stored byte count matched. The
implementation checks the owner folder when `owner_id` is null. Post-test
counts were zero disposable users, companies, document rows, Storage objects,
and cleanup queue rows. This automated smoke is not a substitute for the
two-physical-device UI matrix or every legacy/orphan/retry case above.

Remaining before the staging gate can pass: test hosted orphan/retry and
external-link behavior; test the
separate scoped-secret/device/role matrix while cutover stays closed; and
record a compatible native build plus two-device acceptance. An independent
security review and separate production authorization remain required.
