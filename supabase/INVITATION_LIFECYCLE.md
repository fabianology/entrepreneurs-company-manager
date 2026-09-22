# Invitation Lifecycle Contract

Phase: Collaboration and Vault Phase 2
Date: 2026-09-21

Migration: `migrations/202609210003_invitation_lifecycle.sql`

## Lifecycle and security model

- Pending invitations expire seven days after creation or resend.
- Email links carry 256-bit random tokens. Only a SHA-256 digest is stored in the database.
- A token is bound to the authenticated recipient email, becomes invalid after acceptance or decline, and cannot be replayed.
- Signed-in recipients can also act on their own pending invitations from the native inbox without an email token.
- Acceptance locks the invitation, creates or updates the canonical direct `resource_shares` edge, and marks the invitation accepted in one database transaction.
- Decline marks the invitation declined without creating access.
- Owners can resend pending invitations after a one-minute rate limit or cancel them through the Phase 1 resource revoke operation.
- Blocked people cannot preview or accept pending invitations.
- Invitation authorization and future vault key grants remain separate. Accepting a shared resource does not expose a vault secret.

## RPC boundary

- `miloom_issue_invitation_token` is service-role-only. The authenticated edge function first verifies that the caller owns the pending invitation.
- `miloom_list_my_invitations` lists live pending invitations for the authenticated account email.
- `miloom_preview_invitation_token` returns invitation metadata only when the token and authenticated recipient both match.
- `miloom_accept_invitation` and `miloom_decline_invitation` support the native inbox.
- `miloom_accept_invitation_token` and `miloom_decline_invitation_token` support universal links.
- `miloom_list_managed_access` treats expired pending invitations as `Expired` and omits accepted invitation history when the canonical direct share exists.

Anonymous clients cannot list, preview, accept, decline, or issue invitation tokens. Authenticated clients cannot issue tokens directly.

## Native behavior

- Inbox has a native **Invites** segment with pending count, resource/entity context, role, inviter, and 44-point Accept/Decline controls.
- `https://miloom.co/invite?token=…` is handled as a universal link. If the recipient is signed out, Miloom retains the token for the current app session and presents it after authentication.
- The review sheet uses native navigation, confirmation, Material surfaces, semantic destructive styling, and Miloom's dark/gold visual system.
- Collaborators & Sharing gives owners a resend control for pending invitations and labels resource-level deletion as **Cancel This Invitation**.

## Verified locally

The Phase 1 and Phase 2 migrations were applied in order to a disposable PostgreSQL 17 database. `tests/invitation_lifecycle_contracts.sql` passed and rolled back its fixtures. It covers:

- issuance and resend rate limiting;
- recipient inbox and token preview;
- intercepted-token rejection for the wrong account;
- transactional pending-to-direct acceptance;
- single-use replay rejection;
- accepted-share deduplication in owner management;
- decline without access creation;
- expiry enforcement; and
- anonymous/authenticated privilege boundaries.

The iOS app built successfully for iPhone 17 Pro / iOS 26.4. The email helper passed a local Node smoke check for branding, expiry copy, escaping, and allowlists. Deno is not installed in this workspace, so the repository's pure Deno test was reviewed but not executed through the Deno runner here.

## Deployment boundary

No migration, edge function, web asset, or iOS build was deployed during implementation. The required staging/release order is:

1. Apply Phase 1 migration `202609210002_canonical_resource_access.sql` if it is not already present.
2. Apply Phase 2 migration `202609210003_invitation_lifecycle.sql`.
3. Deploy the updated `send-share-email` edge function with `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, and `SHARE_EMAIL_FROM` configured.
4. Publish the updated Apple association file and `/invite` fallback page on `miloom.co`; confirm the association file is served as `application/json` without redirects.
5. Verify invitation creation, resend, wrong-account link opening, acceptance, decline, expiry, cancellation, and block behavior in staging with disposable accounts.
6. Distribute the matching iOS build only after the backend and universal-link assets are live.
