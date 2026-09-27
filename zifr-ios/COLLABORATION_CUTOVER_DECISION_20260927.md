# Collaboration and vault cutover decision

Date: 2026-09-27. User approved minimum-compatible-release policy; rollout and
deployment remain separately unauthorized.
Part of original Phase 0/7 and frozen release-safety Gate 5; no new phase.

## Approved minimum-compatible-release policy

Require the first production-configured release containing the tested
`7294842e` collaboration/vault implementation (canonical `4cfe9d69`) before
enforcing canonical sharing/revocation and protected-column reads in production.
Exclude build 13 and any other build with the old read/revoke contract from
support at that cutover. Do not restore broad secret-column reads for backwards
compatibility. This changes supported-build policy, not the iOS 17 target.

No numeric minimum release build is assigned yet: a simulator candidate is not
a signed, production-configured TestFlight release. Evidence commit `90714463`
adds documentation only and does not change the candidate binary.

## Evidence and limits

- Known build 13 baseline `d3b05f24` performs full table reads for subscriptions,
  institutions and cards, calls legacy `share_resource`, and directly deletes
  resource invitations. Rechecked against Git source on this date.
- Current DataRepository uses redacted `miloom_visible_*` RPCs and canonical
  sharing/revocation. Legacy read fallback is limited to missing-RPC errors;
  this is not an old-client fix or proof of production server readiness.
- Protected-column read and canonical revoke enforcement would break the known
  build 13 paths. `PRODUCTION_SHARING_COMPATIBILITY_20260922.md` is a dated audit,
  not a live production reinspection on September 27.
- Available TestFlight builds and Apple's tester installation/status summary
  were inspected read-only as recorded below. No compatible tester upgrade has
  occurred yet. Availability alone never proves all supported testers upgraded;
  no force-upgrade mechanism is claimed here.
- Staging candidate native/SQL acceptance and fixture cleanup are recorded in
  `COLLABORATION_BOUNDED_CLOSEOUT_20260926.md`; they do not authorize production.

## Bounded rollout conditions

1. Owner accepted the minimum-compatible-release policy above on September 27.
   Record the chosen
   actual release version/build when a separately authorized release is made.
2. Obtain a read-only TestFlight build/tester inventory. Classify each supported
   build by its source contract; record upgrade evidence. Any unknown contract
   or remaining supported incompatible build keeps enforcement on hold. Retiring
   a build in App Store Connect is a separate authorized mutation.
3. Independent reviewer examines the exact candidate/diffs and recorded bounded
   evidence. Focus only on roles/scopes, invitation acceptance/removal/blocking,
   documents, migration/key/recovery/grant/revoke/rotation isolation, and rollback.
   Record any critical access/data-loss finding as a failed gate. Review remains
   the final external gate; this document is not an independent review.
4. Under separate production authorization, distribute the compatible client
   and additive server/read APIs before incompatible enforcement. Require the
   supported-client inventory and acceptance evidence before legacy write/read
   closure. Do not run an undifferentiated migration push.
5. Keep global collaborator-secret activation closed until the full scoped-vault
   gate and independent review pass. Existing privileged disposable fixture
   activation did not establish normal-client/global activation readiness.

## Rollback disposition

Previously recorded local containment rehearsal revoked delivery RPC execution,
verified authenticated denial, preserved encrypted versions/wraps/audit records,
and restored exactly the tested privilege while keeping anonymous denial.
This is delivery containment, not destructive schema reversal. On a release
security failure: stop delivery/activation, preserve encrypted data, and forward
repair. Never recover service by restoring broad legacy secret reads or plaintext
columns. Do not roll back to an incompatible native build after enforcement.
Containment commands/deployment still require authorization in the actual target.

## Current remaining gate

Policy approval and the read-only TestFlight inventory are complete.
The initial App Store Connect attempt reached Apple sign-in; the user completed
authentication and the live inventory below was then inspected. No credential
or code requested in chat and no build retirement performed. Independent
security review is explicitly recorded as the final external gate. Production rollout
is not authorized or complete. After policy acceptance, next work is the bounded
review handoff and compatible-release distribution conditions, not another
whole-app UI acceptance pass.

## Live read-only TestFlight inventory — September 27

App Store Connect app `6770341276`, version 1.0. Latest uploaded build: 13.
No newer compatible release was listed. Internal group Devs; external group
Family + Friends. Visible build table:

| Builds | Status | Groups |
| --- | --- | --- |
| 13 | Testing | Devs, Family + Friends |
| 12 | Ready to Submit | Devs |
| 11 | Testing | Devs |
| 10 | Ready to Submit | Devs |
| 9, 8 | Testing | Devs, Family + Friends |
| 7 | Ready to Submit | Devs |
| 6 | Testing | Devs |
| 5, 4 | Expired | None shown |

All Testers lists 7 entries: 5 report Installed 1.0 (13), 1 reports Installed
1.0 (9), 1 reports No Builds Available. Tester identities/emails are intentionally
omitted. These are Apple's displayed installation/status records, not proof of
each device's present running binary or a compatible upgrade. Build install
counters are cumulative and not the current tester count. Earlier expired builds
below the first table page were not enumerated; they are not a compatible-release
candidate or a justification to relax enforcement.

Known build 13 is incompatible; build 9 predates the accepted implementation and
is excluded under the approved policy, not newly certified by source inspection.
**Cutover remains HOLD:** no compatible release has been uploaded/distributed and
no tester can yet be counted as upgraded to it. Under separate release authority,
ship the compatible build, verify upgrades or explicitly retire incompatible
support, then enforce backend protection. Nothing in App Store Connect was
changed by this inventory; no export of private tester contacts was made.
