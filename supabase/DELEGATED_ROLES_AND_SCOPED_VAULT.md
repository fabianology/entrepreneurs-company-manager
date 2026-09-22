# Delegated roles and scoped vault implementation contract

Decision accepted by the owner on 2026-09-22. This is the target behavior, **not** a claim that it is deployed. The current account vault key is user-wide and must never be handed to a collaborator to implement a company- or bank-level grant.

## Effective access

Evaluate every request as the intersection of **role**, **resource scope**, and (for secrets) an **active cryptographic grant**. A UI label, an invitation, or a database share alone is not a vault-key grant. Deny by default when any part is missing.

| Principal | Business records in scope | Secrets in scope | Manage people | Reserved owner controls |
| --- | --- | --- | --- | --- |
| Owner | Full read/write for owned entities, subject to product entitlements | Full on trusted owner devices | Grant, change, revoke, and block all roles | Transfer ownership, delete entity, global block, account security/recovery/device approval, billing and external connection credentials |
| Admin | Full entity-wide read/write; entity document vault included | Entity-scoped resource secrets after key grants to their own approved devices | Invite/revoke **Viewer only** within that entity; cannot create or promote Editor/Admin, remove another Admin or Owner, or globally block | None |
| Editor | Full business-record read/write only in explicitly granted resources or collections | Reveal/update only those resources' credentials after explicit owner grant and key delivery; no document vault unless separately shared | None | None |
| Viewer | Read only explicitly granted non-secret business data | None | None | None |

An Admin share is valid only on a `company`/entity. An Editor can receive a single institution, a collection of institutions, a subscription, a document, or another named scope. `all_financials` currently includes banks, cards, and loans, so **all institutions** needs its own explicit scope rather than silently reusing `all_financials`. A company share must not be inferred from a child share. Any overlapping shares grant the union of their explicitly authorized business scopes, but a secret is readable only when its own resource key is wrapped for that collaborator's device.

The Owner may revoke an Admin or Editor at any time. An Admin may not grant a Viewer access to another entity, grant an Editor (which would indirectly delegate secrets), downgrade an Editor/Admin with a Viewer invite, or revoke anyone except a Viewer in the Admin's own entity. An Admin may see who has access to that entity but not mutate higher roles. Admin cannot see or rotate the Owner's account-wide vault key, recovery code, or trusted devices.

## Secret and document boundaries

- Preserve the existing owner account vault for the owner's own devices. Migrate shared credentials to independently versioned **resource data keys**. The owner device creates each random resource key; the server stores ciphertext and public keys/wrapped keys, never a plaintext key or password.
- A bank's credential key is separate from every other bank, subscription, card, and entity. Wrap the relevant resource key to each authorized collaborator device. Admin receives the keys for every secret-bearing resource in the shared entity, not the owner's account master key. Editor receives only keys for explicitly assigned resources. New resources need an explicit, fail-closed key provisioning path before secret access is shown.
- The app must distinguish normal data access from **Reveal/Change Credentials** with an owner-visible warning, and require local user presence to reveal or change a secret. Sharing a bank login can permit action outside Miloom; revocation cannot erase secrets already viewed or copied. Tell the owner to rotate external credentials when appropriate.
- Protect actual document Storage objects and signed-download endpoints, not just `company_documents` rows. Document-vault access is automatic for Admin within their entity, excluded for Editor unless a document or document collection is explicitly granted, and excluded for Viewer unless explicitly shared as non-secret content.
- Revoke database access immediately, remove future key wraps, rotate affected resource keys and re-encrypt stored secrets for remaining principals. A partially completed rotation keeps affected secrets locked, is retryable, and is audited. Never fall back to sending plaintext or the owner account key.

## Phased implementation and acceptance

0. **Contain and establish a safe baseline.** Audit live legacy functions/RLS/grants and old-client compatibility. Production currently lacks the canonical sharing/vault migrations; the legacy `share_resource` overloads are anonymously executable and have no caller ownership check. Treat this as an urgent, separately reviewed production rollout gate. Do not expand collaborator permissions while it remains. Run the existing Phase 1–8 staging contracts and define the minimum supported iOS version before changing production grants.
1. **Server-authorized role/scope contract.** Add an `all_institutions` scope and explicit inheritance rules; reject non-company Admin grants. Add entity-scoped Admin listing and Viewer-only invite/revoke RPCs that reject cross-entity, self, blocked, higher-role, pending-invitation, and stale-share edge cases. Keep global block, ownership, higher-role grants and account controls Owner-only. Add rollback-only SQL authorization tests for every role/scope/action, including direct API calls that bypass the app.
2. **Resource-key foundation.** Add versioned resource-key metadata, device public-key discovery limited to an accepted share, wrapped-key grants and audit rows. Implement local key generation, resource-bound authenticated encryption and an owner-only migration from account-key/legacy fields. Fail closed when a key or wrap is missing. Test ciphertext copy, wrong resource, wrong device, key version and interrupted migration.
3. **Grant experience and scoped reads.** Update iOS role/scope choices using native controls and Miloom materials. Show the exact entity, collection, or item and whether credentials/documents are included before Send. Deliver keys only after acceptance, to approved recipient devices, with owner confirmation for credential grants. Test Admin full entity, Editor one bank, Editor all institutions, Viewer metadata-only, and deliberate document exclusion on two devices.
4. **Revocation and lifecycle.** Coordinate access removal with key rotation, device churn, invitation cancellation, collaborator removal and recovery. Verify that revoked accounts lose live data and future decrypt capability after app foreground/cold launch; disclose that previously viewed external passwords must be changed separately.
5. **Release gate.** Stage with disposable accounts, assess old-client compatibility and Storage/Plaid impacts, then separately approve production migrations, function deployment, key migration and iOS distribution in that order. Do not describe a build or green SQL test as an end-to-end or production verification.

## Unresolved implementation choices, with safe defaults

- Admin cannot delete the whole entity, disconnect an Owner's Plaid link, change billing, or manage the owner's vault devices. These are account/ownership controls, not entity collaboration.
- Admin can grant/revoke Viewers only. An Owner must approve every Editor/Admin invitation and every new secret-bearing scope.
- Viewer has no credential access, even if their business scope is an entire entity.
- If a grant's key provisioning or revocation rotation fails, secret access stays locked. Availability may temporarily decrease; confidentiality does not.
