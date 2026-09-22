# Vault Key Foundation Contract

Phase: Collaboration and Vault Phase 3
Date: 2026-09-21

Migration: `migrations/202609210004_vault_key_foundation.sql`

## Boundary

Phase 3 establishes cryptographic formats and storage contracts. It does not migrate existing passwords, enable cross-device approval UI, or grant collaborators access to secrets.

The server stores only:

- public device keys;
- encrypted account-vault-key wraps;
- an encrypted recovery wrap;
- device state and non-secret audit metadata; and
- the active vault key version and algorithm identifiers.

The schema has no plaintext vault key, private device key, or recovery-code column. Authorization shares from Phases 1–2 remain independent from these cryptographic records.

## Client cryptography

- Field envelopes use AES-256-GCM and the versioned `miloom:v1:<key-version>:<combined-ciphertext>` format.
- Authenticated data binds ciphertext to its owner, resource type, resource ID, field name, and key version. Moving ciphertext to another record or field fails authentication.
- Each device has separate P-256 agreement and signing keys. Private keys are stored as non-synchronizing, `WhenUnlockedThisDeviceOnly` Keychain items; only X9.63 public keys are uploaded.
- Account vault keys are wrapped to a device with ephemeral P-256 ECDH, HKDF-SHA-256, and AES-256-GCM.
- Recovery uses a client-generated 256-bit random code, HKDF-SHA-256, and AES-256-GCM. The recovery code is never sent to or stored by Supabase.
- Device signatures provide the primitive Phase 4 will use for approval challenges.

Existing `enc:` ciphertext remains supported and unchanged. The current read/write path does not emit the new envelope until the migration phase can safely decrypt and re-encrypt a record on an already-authorized device.

## Server lifecycle

- `miloom_bootstrap_account_vault` atomically creates the first approved device, its encrypted device wrap, and the encrypted recovery wrap. It accepts no plaintext key material.
- `miloom_register_vault_device` creates only a pending device.
- `miloom_list_vault_devices` and `miloom_get_vault_device_wrap` are owner-scoped.
- `miloom_finalize_vault_device_approval` is service-role-only. Phase 4 must verify a signed, one-time approval challenge from an approved device before invoking it.
- Sensitive enrollment operations require a recently issued access token as an additional replay limit. This is not a substitute for explicit reauthentication or signed device approval.
- Vault tables are client-read-only under owner RLS. Anonymous access and authenticated direct mutation are denied.

## Intentionally deferred

- Face ID/user-presence unlock policy and the native device approval/recovery UI;
- one-time server approval challenges and signature verification at the edge boundary;
- migration of legacy `enc:` values into record-bound `miloom:v1` envelopes;
- account-vault-key rotation and rewrapping after device revocation;
- per-resource data keys and explicit collaborator secret grants; and
- independent security review before production password-manager claims.

The Phase 3 migration and formats must remain inactive until Phase 4 supplies the signed approval and recovery workflow. Applying the schema alone does not change existing password behavior.

## Verified locally

- All 81 focused `PremiumEngineTests` passed on iPhone 17 Pro / iOS 26.4, including field-context authentication, target-device-only unwrap, recovery-code enforcement, and signed-challenge tamper rejection.
- The migration applied cleanly to a disposable PostgreSQL 17 database.
- `tests/vault_key_foundation_contracts.sql` passed bootstrap, duplicate-bootstrap denial, stale-token denial, pending enrollment, owner isolation, direct-write denial, service-only approval, encrypted-wrap retrieval, audit creation, anonymous denial, and plaintext/private-key column exclusion checks. Its fixtures rolled back and the stopped database was deleted.
- No Phase 3 migration, RPC, key material, or client behavior was deployed or activated.
