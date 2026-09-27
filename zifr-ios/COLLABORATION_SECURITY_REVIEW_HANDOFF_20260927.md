# Bounded collaboration and vault independent-review handoff

Date: 2026-09-27. Prepared for an independent reviewer; no review has occurred.
Final external Gate 5 of the frozen goal. No general app QA is requested.

## Exact review target

- Clean isolated Staging candidate `7294842e`, branch
  `codex/collab-staging-candidate-20260923`, worktree
  `/private/tmp/miloom-clean-candidate.dKfPen/source`.
- Original baseline `0cdaf4cbf43e54f9808d397dc4552ae4a2d1907d` is a verified
  ancestor of this candidate. Use its task-relevant diff through `7294842e`,
  not merely the last scope-guard commit: the latter omits earlier lifecycle,
  vault and document implementation. Exclude unrelated feature changes from
  this review. Inspect relevant existing helpers/policies even if unchanged.
- Corresponding canonical implementation checkpoint `4cfe9d69`;
  `90714463` records acceptance evidence only, no new native implementation.
- Installed simulator native binary SHA-256:
  `664cc5592c0b007b5cf96ce5a42714b78a3bc7292168362d0401530fd560e8bc`.
- Evidence: `COLLABORATION_BOUNDED_CLOSEOUT_20260926.md`,
  `COLLABORATION_UI_ACCEPTANCE_20260922.md`,
  `COLLABORATION_CLEAN_CANDIDATE_20260923.md`, and
  `../supabase/COLLABORATION_VAULT_STAGING_RUNBOOK.md`.
- Minimum-release decision/live inventory:
  `COLLABORATION_CUTOVER_DECISION_20260927.md`.

## Only the frozen security boundaries

1. Owner/Admin/Editor/Viewer server and native enforcement: entity-only Admin,
   Viewer-only Admin delegation, owner-only block/ownership authority, exact or
   collection Editor scopes, Viewer immutability/no secrets. Inspect negative
   paths, not just displayed role options.
2. Invitation acceptance binds verified identity/email and scope; Pending alone
   grants nothing. Canonical resource/entity/person revocation removes applicable
   invitation and direct edges without removing independent out-of-scope grants.
3. Document upload/open/replace/remove/retry authorizations, ownership/path
   validation, cleanup and denial after revocation. Account for already downloaded
   bytes and signed-URL/cache lifetime; do not promise instantaneous recall.
4. Safe readable legacy migration preserves locked fields. Account/device/recovery
   keys stay private; resource/device-bound ciphertext and wraps cannot cross
   scopes. Review approved-device/auth-session checks, grant confirmation,
   stale-sheet/background/dismissal publication guards, canonical share/device
   revocation, rotation and absence of old-grant carryover.
5. Delivery containment preserves encrypted data and cannot restore broad secret
   reads. Legacy client incompatibility is deliberate and gated by approved
   cutover, not worked around through unsafe column grants.

## Evidence already performed, not substitutes for review

47 selected native tests passed, eight isolated scoped-vault SQL scenarios passed,
plus scoped role/document contracts and dated native acceptance. Final current
batch includes exact Editor request/grant/decrypt/save, Viewer sibling denial,
resource revoke/stale-sheet denial, native v1-to-v2 rotation and fresh Owner v2
decrypt. Disposable accounts/records and document files cleaned and verified.
Keep source/build differences and historical evidence limits explicit.

Global client activation is closed; exact disposable privileged activation was
test-only and is not global-release proof. Production-shaped compatibility and
distribution decisions must not be inferred from a simulator or SQL success.
Live inventory still has only legacy installed builds (5 testers build 13,
1 build 9, 1 No Builds Available); production cutover stays on hold.

## Expected reviewer result

Return reviewed commit/build, exact files/paths and evidence examined, any
reproducible unauthorized-access/data-loss defects, severity, and acceptance or
required repairs. A critical defect fails the gate; noncritical unrelated findings
become follow-ups. Never mark independent review complete merely because this
packet exists. Production deployment, reviewer access grants, publishing and
tester/build changes require separate authorization.

## Reviewer disposition template

- Reviewer identity/independence and review date:
- Exact source commit/build and paths examined:
- Role/scope boundary: Pass / Fail / Not reviewed
- Invitation/removal/block boundary: Pass / Fail / Not reviewed
- Document/storage boundary: Pass / Fail / Not reviewed
- Vault/migration/device/grant/revoke/rotation boundary: Pass / Fail / Not reviewed
- Compatibility/containment rollback: Pass / Fail / Not reviewed
- Critical findings with reproduction/evidence:
- Noncritical follow-ups outside the frozen goal:
- Overall disposition and required repairs:

All fields currently unfilled. A review must report omissions explicitly and
cannot claim a clean audit from staging acceptance or this packet alone.
