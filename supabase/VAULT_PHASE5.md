# Vault Device Revocation and Rotation Contract

Phase: Collaboration and Vault Phase 5
Date: 2026-09-21

Migration: `migrations/202609210006_vault_rotation_and_device_revocation.sql`

## Revocation behavior

- A pending-device request can be canceled without rotating the vault key.
- Revoking an approved device requires an unlocked approved device, a recently
  refreshed access token, and proof of the current account vault key.
- The server atomically revokes the target, removes its active key wraps, rotates
  the account key, installs a wrap for every remaining approved device, replaces
  the recovery wrap, and records non-secret audit events.
- Vault devices bind to their current Supabase auth session. Revoking an approved
  device deletes that linked session when available. Its current access token may
  remain usable until expiration, but it receives no new vault-key wrap.
- Revocation cannot erase plaintext a device already displayed or exported. The
  native confirmation states this limitation explicitly.

## Resumable key migration

The previous account key is encrypted under the new key and stored as a temporary
transition wrap. Remaining approved devices can therefore resume record migration
after an interruption without Supabase learning either key.

The transition closes only after the client reports that no old-version vault
fields remain and no record update failed. Until then, the native Password Vault
screen shows **Resume Key Rotation**. Completed transitions are no longer returned
to clients on a fresh unlock.

## Recovery and audit

- Every account-key rotation creates a new one-time recovery code and invalidates
  the old recovery wrap.
- Users can independently replace a recovery code without rotating the account
  key. The old wrap is revoked before the replacement becomes active.
- Password Vault shows recent security events for device requests, approvals,
  revocations, recovery, key rotation, and rotation completion.

## Collaboration boundary

Ordinary company/resource roles grant no vault key and no password/account-number
access. Phase 5 deliberately does not add a cosmetic `secret_access` flag: a real
future grant must introduce a resource-specific data key, wrap that key only to
explicitly selected collaborator devices, support independent revocation/rotation,
and require a separate owner confirmation. Until that complete cryptographic path
exists, the native UI accurately reports that collaborator secret access is off.

## Deployment and verification boundary

Deploy migrations 004, 005, then 006 before distributing the matching client.
Deploy and validate the Phase 4 approval edge function as part of the same staging
rollout. Exercise interruption after server-side rotation, resume after relaunch,
recovery during an active transition, multiple remaining devices, stale access
tokens, and linked/unlinked auth sessions. No migration or client was deployed by
this implementation task.

## Verified locally

- All 85 focused `PremiumEngineTests` passed on iPhone 17 Pro / iOS 26.4,
  including transition-wrap authentication and mixed-version keyring decryption.
- Migrations 004 through 006 applied in order to a disposable PostgreSQL 17
  database. Phase 3, 4, and 5 contract suites passed and rolled back.
- Phase 5 contracts cover incorrect key-proof denial, exact remaining-device wrap
  sets, linked-session revocation, current-session preservation, recovery rotation,
  pending-request cancellation, audit events, transition completion, completed-wrap
  hiding, and anonymous denial.
- `git diff --check` passed. Existing unrelated project warnings remain.
