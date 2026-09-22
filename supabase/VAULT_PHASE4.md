# Vault Activation and Device Trust Contract

Phase: Collaboration and Vault Phase 4
Date: 2026-09-21

Migration: `migrations/202609210005_vault_device_approval_and_recovery.sql`
Edge function: `functions/approve-vault-device/index.ts`

## User flow

- The first trusted iOS device confirms local user presence with Face ID or the
  device passcode, generates the account vault key and recovery code locally,
  and uploads only encrypted wraps, public keys, and a one-way key confirmation.
- The recovery code is shown once. It is never sent to or stored by Supabase.
- A new device registers as pending. An already approved device wraps the vault
  key to the pending device and signs a five-minute, single-use challenge that
  binds the user, both devices, key version, nonce, and exact encrypted wrap.
- The edge function verifies the P-256 signature before its service-role client
  atomically consumes the challenge and finalizes approval.
- Recovery unwraps the vault key locally and submits only a fixed-domain HMAC
  confirmation. The confirmation column is not readable by authenticated clients.
- Legacy migration is user-initiated. It migrates plaintext or locally readable
  `enc:` secrets to record-bound `miloom:v1` envelopes and leaves unreadable
  legacy ciphertext unchanged. Individual failures are retryable.

## Collaboration boundary

Authorization and vault access remain separate. Sharing a company, bank, card,
or subscription does not grant the collaborator the owner's account vault key.
When a collaborator updates a shared record, Miloom preserves the owner's stored
password and account-number fields instead of encrypting them with the
collaborator's device key. Explicit per-resource secret grants remain future work.

## Native UI

Account & Settings includes a Password Vault sheet built with native SwiftUI
navigation, sheets, materials, confirmation dialogs, Face ID/passcode prompts,
Dynamic Type-compatible text, and 44-point controls in Miloom's dark/gold visual
language. It supports setup, one-time recovery-code capture, pending-device
registration, approval, recovery, status, and controlled migration.

## Deployment boundary

Phase 3 and Phase 4 must be deployed together and validated in a staging project
before enabling vault setup for production users. Apply migrations in timestamp
order, deploy `approve-vault-device`, then test two-device approval, recovery,
legacy migration, collaborator edits, sign-out, reinstall, offline/error states,
and rollback behavior. No migration, edge function, or app build was deployed by
this implementation task.

## Verified locally

- All 83 focused `PremiumEngineTests` passed on iPhone 17 Pro / iOS 26.4.
- Phase 3 and Phase 4 migrations applied in order to a disposable PostgreSQL 17
  database. Both vault contract suites passed and their transactions rolled back.
- Contract coverage includes unreadable recovery proof, legacy-bootstrap denial,
  service-only challenge consumption, replay denial, signed-approval finalization,
  incorrect recovery-proof denial, and successful recovery approval.
- `git diff --check` passed. Deno is not installed in this workspace, so the edge
  function received code review and database-boundary testing but not a local
  `deno check`; deployment/staging validation remains required.
