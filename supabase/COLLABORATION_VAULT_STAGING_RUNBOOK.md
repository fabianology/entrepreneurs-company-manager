# Collaboration and Vault Staging Rollout

Track: Collaboration and Vault, staging acceptance gate

Baseline: `0cdaf4cbf43e54f9808d397dc4552ae4a2d1907d`

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
- The Supabase CLI and Deno are not installed on the current host. PostgreSQL
  client tooling is available.
- The generated staging database password was not written to the repository or
  logs. Reset or retrieve it through the approved secure credential workflow
  before a CLI operation that requires it.
- Migrations, functions, website assets, secrets, and production data were not
  changed while preparing this runbook.

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

## Gate 2 — schema rehearsal and dry run

1. Capture a restorable staging backup or recreate point.
2. Export schema, policies, grants, functions, and migration history from
   staging. Compare them with the assumptions in the six migrations. Do not
   export production user data into staging.
3. Run Deno checks for both edge functions and execute
   `functions/_shared/share_email_test.ts`. Stop on any type-check or test
   failure.
4. Run a Supabase migration dry run and inspect every proposed version. The
   collaboration/vault sequence must be exactly:

   1. `202609210001_secure_active_sessions.sql`
   2. `202609210002_canonical_resource_access.sql`
   3. `202609210003_invitation_lifecycle.sql`
   4. `202609210004_vault_key_foundation.sql`
   5. `202609210005_vault_device_approval_and_recovery.sql`
   6. `202609210006_vault_rotation_and_device_revocation.sql`

5. Stop if the dry run includes an unexpected migration, destructive statement,
   legacy-RPC removal, or monetization-enforcement change. Reconcile migration
   history before continuing.
6. Rehearse the SQL contracts against a disposable database and retain the
   pass/fail output. The suites must roll back their fixtures.

## Gate 3 — staging backend and web assets

1. Apply migrations `001` through `006` in timestamp order.
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
- A collaborator can edit allowed non-secret fields but receives no password,
  account number, account vault key, device wrap, or recovery material.

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
