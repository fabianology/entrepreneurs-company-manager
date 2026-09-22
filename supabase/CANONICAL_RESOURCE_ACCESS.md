# Canonical Resource Access Contract

Phase: Collaboration and Vault Phase 1
Date: 2026-09-21

Migration: `migrations/202609210002_canonical_resource_access.sql`

## Security model

- The authenticated resource owner is the only principal allowed to grant, enumerate, revoke, block, or unblock collaborator access.
- Caller-supplied inviter IDs and sender identities are not part of the canonical RPC contract.
- Roles are exactly `Viewer`, `Editor`, and `Admin`. Phase 1 does not grant collaborator-management authority to `Admin`; management remains owner-only.
- Resource types are exactly `company`, `all_subscriptions`, `subscription`, `all_documents`, `document`, `all_financials`, `institution`, `card`, and `loan`.
- A registered email becomes a direct `resource_shares` edge. An unknown email becomes a pending `resource_invitations` edge.
- One active edge exists per person/resource. Re-sharing updates the role instead of creating another active edge.
- Sharing tables are read-only to authenticated clients. Mutations pass through security-definer RPCs with explicit grants; anonymous execution is denied.
- The older `share_resource` overloads remain callable by authenticated clients,
  but are thin compatibility wrappers around `miloom_share_resource`; forged
  inviter/sender values are ignored and anonymous execution is denied. The
  legacy one-argument `leave_resource` RPC is likewise authenticated-only.
- Authorization rows and future vault key wraps remain separate. This phase creates no cryptographic grants.

## Canonical RPCs

### `miloom_share_resource`

Inputs: collaborator email, role, resource ID, resource type.

Returns either:

- `{"status":"shared_directly"}`
- `{"status":"invitation_created","invitation_id":"…"}`

The function normalizes email/resource type, validates ownership and allowlists, rejects self-sharing and blocked people, and records the authenticated account email as the sender.

### `miloom_list_managed_access`

Returns invitations and direct shares through one owner-scoped result shape. Every row includes its access kind, entity ID, subject email/user ID, role, status, and creation time. The native collaborator screen uses this function, so direct shares are no longer invisible.

### `miloom_revoke_access`

Inputs: access ID, access kind, and scope.

- `resource`: removes matching invitation/direct access only for the selected resource.
- `entity`: removes that person's access to the entity and all child resources in it.
- `person`: removes that person's access across the owner's portfolio and adds a block preventing new grants.

The operation removes both invitation and direct-share forms for the selected scope.

### Block and leave operations

- `miloom_list_access_blocks` lists the owner's blocked people.
- `miloom_unblock_collaborator` removes one owner-scoped block.
- `miloom_leave_resource` removes the authenticated collaborator's own direct share and matching invitation for an exact resource type/ID pair.

## Native behavior

- Collaborators & Sharing shows direct and invited access in the same entity/resource hierarchy.
- Status is explicit (`Active`, `Pending`, `Accepted`, or `Suspended`).
- The trash action opens a native confirmation dialog with the three revoke scopes.
- Blocked people appear in a separate premium card and can be unblocked with confirmation.
- Controls retain 44-point interaction targets, semantic destructive colors, native confirmation UI, Material surfaces, and the existing Miloom dark/gold styling.

## Verified locally

The migration was applied to a disposable PostgreSQL 17 database using the repository's production-shaped rehearsal baseline. `tests/canonical_resource_access_contracts.sql` passed and rolled back its fixtures. It covers:

- registered direct shares and unregistered invitations;
- unified management listing and entity resolution;
- role validation and cross-owner denial;
- resource-only, entity-wide, and portfolio-wide revoke behavior;
- block enforcement and unblock recovery;
- cross-owner listing/revoke isolation; and
- anonymous execute denial.

The iOS app also built successfully for iPhone 17 Pro / iOS 26.4.

## Rollout order

This source change is not backward-compatible with a database that lacks the new RPCs. Release in this order:

1. Rotate the exposed email-provider credential and configure `RESEND_API_KEY` plus `SHARE_EMAIL_FROM`.
2. Review a deployed schema/policy export for conflicts with the canonical migration.
3. Apply `202609210002_canonical_resource_access.sql` and run the SQL contract against a disposable/staging database.
4. Deploy the secured `send-share-email` function.
5. Verify valid owner, wrong owner, anonymous, direct-share, pending-invitation, each revoke scope, block, unblock, and leave flows with disposable accounts.
6. Distribute the matching iOS build.
7. After the minimum supported client uses the canonical RPCs, remove the
   authenticated-only legacy compatibility wrappers in a separate audited
   migration.

Do not deploy the client before the migration. Do not remove legacy RPCs until active older clients are accounted for.

## Deferred to later phases

- recipient acceptance, decline, token, expiry, resend, and cancellation lifecycle is implemented by Phase 2 in `INVITATION_LIFECYCLE.md`;
- downstream RLS consolidation for every resource and Storage object;
- vault account/device/recovery keys and per-resource key wrapping;
- cryptographic rekeying after revocation; and
- administrative access to vault secrets, which must be granted separately from the `Admin` application role.
