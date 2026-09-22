# Sharing and Vault Phase 0 Security Review

Date: 2026-09-21

This record captures the source and deployment evidence reviewed before the unified collaboration and vault redesign. Phase 0 closes the invitation-email vulnerability in source without changing the current sharing authorization model or encrypted-field format.

## Phase 0 implementation status

Implemented in source:

- `send-share-email` requires a valid Supabase user token even if gateway JWT verification is disabled.
- The function accepts only an invitation ID. Recipient, role, resource type, and invitation status are loaded from `resource_invitations` after the authenticated user is matched to `invited_by`.
- Email role and resource values are allowlisted; dynamic HTML is escaped.
- Provider credentials and the sender identity come only from deployment secrets (`RESEND_API_KEY` and `SHARE_EMAIL_FROM`). There is no source-code fallback.
- Provider responses and secrets are not returned to clients or written to logs.
- Invitation email content and links use Miloom and `https://miloom.co`.
- The iOS client no longer submits email content or a user-editable sender identity to the email function. It sends only the invitation ID and reports partial email-delivery failure separately from successful invitation creation.

Required operational work before release:

- Rotate the email-provider credential that was previously present in tracked source. Removing it from the current tree does not invalidate it or remove it from Git history.
- Configure `RESEND_API_KEY` and `SHARE_EMAIL_FROM` in the target Supabase project.
- Deploy `send-share-email`, then verify unauthenticated, wrong-owner, non-pending, invalid-role, and valid-owner requests against a non-production invitation fixture.
- Review provider delivery/domain authentication for the configured Miloom sender.

No production secret, function, database policy, or customer record was changed as part of this source-only pass.

## Current sensitive-data inventory

Observed iOS encryption behavior:

- `SecurityService` creates one random 256-bit AES-GCM key per device and stores it in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Ciphertext is stored as `enc:` followed by the Base64-encoded AES-GCM combined sealed box.
- Subscription, financial-card, and institution passwords are encrypted before persistence and decrypted after fetch.
- Institution account, routing, and wire-routing numbers are encrypted before persistence and decrypted after fetch.
- `FinancialCard.cardNumber` is a persisted field but is not passed through the current `SecurityService` save/fetch transforms. Treat it as plaintext until a migration proves otherwise.
- Login names, institution usernames/emails, two-factor notes, document metadata, and general notes are not covered by this encryption layer.

Consequences for the vault plan:

- Current ciphertext is device-bound. Another device or collaborator cannot decrypt it because the key is neither synchronized nor wrapped for another principal.
- An app reinstall or Keychain loss can make records appear as `Locked on this device`; there is no account recovery key.
- The format has no explicit algorithm/key-version envelope beyond the `enc:` prefix, so a versioned migration format is required before adding multi-device recovery or vault sharing.
- The future vault architecture must not reuse database sharing rows as cryptographic access. Authorization and key wrapping must be separate, coordinated operations.

## Current sharing and authorization inventory

Observed source behavior:

- `share_resource` is called by the iOS app and can produce either a direct `resource_shares` row or a `resource_invitations` row. Its deployed definition is not present in the tracked migration set, so its validation, idempotency, and exact role semantics are not reproducible from this repository.
- `leave_resource` is also used by the app without a tracked canonical definition.
- The current collaborator-management screen reads `resource_invitations` only. It does not enumerate direct `resource_shares`.
- The current revoke client deletes one `resource_invitations` row. It does not remove a corresponding direct share and is not a full block operation.
- Historical SQL files contain multiple generations of sharing policies, including an explicit debug script that disables RLS. File presence is not proof of deployed state.
- The current canonical company read helper accepts company-level direct shares and company invitations matched by email. The invitation branch does not constrain invitation status.
- Tracked Storage policies for `CompanyDocuments` are owner-oriented. Database access to a document row does not by itself prove that a collaborator can fetch its private Storage object.

Deployment observation on 2026-09-21:

- An unauthenticated request reached the deployed `send-share-email` function handler and returned an application-level `400`, rather than being rejected at the gateway with `401`. The revised handler therefore performs its own token verification and must still be deployed before the exposure is closed.

Unknowns that must be resolved before Phase 1 schema work:

- Export the deployed definitions for `share_resource`, `leave_resource`, both sharing tables, their triggers, grants, constraints, and all active RLS policies.
- Export active `CompanyDocuments` bucket and `storage.objects` policies.
- Confirm whether accepted invitations are retained, converted to direct shares, or both.
- Confirm case normalization and uniqueness rules for invitation email addresses.
- Confirm whether `Admin` currently grants re-sharing/revocation rights server-side or is only a client-facing label.

## Threat model baseline

| Threat | Current exposure | Phase 0 treatment | Required later control |
| --- | --- | --- | --- |
| Database theft | Several secrets use device-only AES-GCM, but metadata and some sensitive fields remain plaintext; the single device key protects all encrypted rows. | Inventory documented; no format change. | Versioned envelopes, per-resource data keys, account/device key wrapping, and card-number migration. |
| Account takeover | A valid session can exercise whatever RLS/RPC permissions the account has; vault ciphertext may still be unreadable on a new device. | Email function independently validates the session and invitation owner. | Reauthentication for sensitive actions, device enrollment, session/device revocation, and security notifications. |
| Device compromise | Keychain accessibility permits decryption after first unlock on that device; decrypted values enter app memory. | No change. | User-presence policy for vault access, minimize plaintext lifetime, screenshot/app-switcher protections where appropriate. |
| Invitation interception or forgery | The old email function trusted caller-provided recipient, role, resource text, and sender identity. | Function now derives authoritative invitation data server-side and escapes content. | Signed, single-use, expiring acceptance tokens with recipient binding. |
| Revoked collaborator | Deleting an invitation does not guarantee removal of a direct share or previously distributed vault key material. | Gap documented; no authorization behavior change. | One transactional, scope-explicit revoke operation plus key rotation/re-wrapping for encrypted shared resources. |
| Recovery-key theft | No recovery key exists today. | Design boundary documented. | Offline recovery code generated client-side, strongly protected wrapping, rotation, and recovery audit trail. |
| Malicious Admin | `Admin` semantics are not proven server-side; future Admin key access could expose vault secrets. | Email role is allowlisted but permissions are unchanged. | Separate management permissions from secret-access grants; require explicit vault access and auditable key wraps. |

## Phase boundary and next gates

Phase 0 intentionally does not introduce account vault keys, device enrollment, recovery, invitation acceptance tokens, unified revoke RPCs, or new RLS policies. Phase 1 should begin only after the deployed schema/policy export is checked into a canonical migration and the email credential is rotated and the secured function is deployed and verified.
