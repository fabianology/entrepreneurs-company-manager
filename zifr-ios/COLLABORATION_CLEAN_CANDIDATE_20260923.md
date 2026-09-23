# Clean staging candidate attempt

## Current status (2026-09-23)

Candidate source is committed as `2fd148a4` on
`codex/collab-staging-candidate-20260923`; its isolated checkout is clean.
Selected tests: 42 passed. The bounded native checks recorded below passed
only to their stated extent. The complete vault gate and release acceptance
remain open. Earlier build-blocked and not-yet-committed sections are historical
steps, superseded by the later candidate result. This report does not authorize
or establish production release.

## Identity

- Source commit: `0d3099bee2d0b70bd70187cbe56bca314aa335bf`.
- Isolated detached worktree: `/private/tmp/miloom-clean-candidate.dKfPen/source`.
- Git status clean before and after build; no unrelated uncommitted files copied.
- Fresh DerivedData: `/private/tmp/miloom-clean-candidate.dKfPen/derived`.
- Existing pinned Swift packages reused with automatic resolution disabled.
- Existing staging xcconfig and previously authorized simulator-only signing/
  bundle overrides used. No project/signing files modified.
- Target simulator: `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`.
- Log: `/private/tmp/miloom-clean-candidate.dKfPen/build.log`.
- Result: `/private/tmp/miloom-clean-candidate.dKfPen/acceptance.xcresult`.

## Result: build blocked, tests not run

Xcode exited 65. Committed `PlaidLinkButton.swift` accesses
`linkToken.isUpdateMode` (line 114) and `linkToken.value` (line 126), but committed
`PlaidService.createLinkToken` returns `String`. The subsequent closure and
presentation inference errors follow this mismatch. The screen's latest commit
is `87bd174a`, predating the four current checkpoint commits.

The canonical checkout has an uncommitted PlaidService change returning a
`LinkToken` structure; it also changes OAuth redirect and backend response
handling. That file was deliberately excluded from the collaboration commits.
Earlier dirty-worktree builds therefore do not establish this clean baseline's
buildability. The 41 prior test passes remain valid for their recorded source,
not this clean attempt.

No ready candidate produced, installed, pushed or deployed. Gate 6 remains
blocked until the bank-link interface mismatch is reconciled. Do not sweep in
the entire Plaid workstream, loosen vault controls, or claim candidate acceptance.
A narrow compatibility repair or independently approved Plaid integration needs
an explicit scope decision. The isolated source remains unchanged.

## Authorized narrow repair — verified, not yet committed

User authorized the compatibility fix. Only the isolated worktree's
`PlaidService.swift` and `ActiveSessionsTests.swift` changed. Service now returns
the structure already expected by the committed screen. Legacy responses without
mode are treated as create (and rejected by the screen for reconnect); explicit
`create`/`update` modes decode, unknown modes fail. OAuth default, request payload
and backend remain unchanged. Canonical uncommitted Plaid work was not touched.

Final stable-source build and selected tests passed: **42 passed, 0 failed,
0 skipped**. This includes the new compatibility regression. Evidence:
`/private/tmp/miloom-clean-candidate.dKfPen/compatibility-final.xcresult` and
`compatibility-final.log`. `git diff --check` passed. Source hashes:

- PlaidService.swift: `2fc0a0964ec3b9c664069d5b35d046eaa8715c5e6e0e79c5c9eb035cd0f5a25e`.
- ActiveSessionsTests.swift: `67d39ac20cccefd92ddba763a24c5902d47071bab8da30c363cfb769620f6d68`.

This is a verified patch atop the committed candidate, not yet a clean committed
candidate. Commit/integration authorization remains needed. No live Plaid flow,
backend deployment, production or phone action was performed. Remaining native
acceptance and external release gates are unchanged.

## Candidate acceptance continuation

On committed candidate `2fd148a4`, all seven isolated database scenarios passed:
foundation, owner staging, device grant, owner rewrap, rotation/lifecycle/
containment, access status and scoped update. Evidence directory:
`/private/tmp/miloom-scoped-vault.wbDrmk`; local database stopped on completion.
Synthetic database ciphertext is not native cross-device decryption evidence.

Built app metadata confirms `com.vibing.miloom.staging` and the staging project.
Debug binary SHA-256:
`18e4e886bd3c510030956b97b9bd4c3b92e24492557bb552d3af5a7f57923b4b`.
Installed/launched on disposable acceptance simulator only. It initially retained
the deleted fixture account's local session; native Sign Out completed and login
screen was verified. No claim of automatic session invalidation from this check.

Read-only staging secret-name inventory still lacks `RESEND_API_KEY` and
`SHARE_EMAIL_FROM`. Actual invitation delivery/link acceptance remains blocked.
Native in-flight reveal interruption, mixed locked/readable migration and final
cross-scope device checks remain unverified, despite the existing cryptography
unit and backend contract passes. Candidate checkout remains clean. No source
edits, commits, production deployment or live email performed this continuation.

## Native mixed readable/locked migration — passed

Candidate `2fd148a4`, disposable acceptance simulator. Created one dedicated
staging account `miloom-vault-boundaries-20260923@example.com` (marker
`candidate-vault-boundaries-20260923`), company
`ba230000-0000-4000-8000-000000000001` and bank ending `0002`. Account ID
`27a3f71c-df0a-4067-abb2-7e7743b0027c`. Guarded helper:
`/private/tmp/miloom-candidate-vault-boundaries.mjs`.

Native vault setup and Face ID succeeded. This disposable recovery code was not
copied/saved; recovery is not being retested with this account. Native Encrypt
Existing Passwords + Face ID reported **2 fields encrypted / 2 locked legacy
fields left unchanged**. Read-only backend assertion independently verified
account/wire routing fields have vault-envelope prefixes; inaccessible legacy
bank-password/routing values remain exactly unchanged; account ID/name remain
unchanged. This tests intentionally unreadable legacy-envelope sentinels, not
successful decryption of an actual other-device legacy key. No ciphertext/key
values logged. Post-migration decrypt and interruption tests remain separate.

Fixture retained for the next vault boundary checks; guarded cleanup action is
available and must run at checkpoint completion. Candidate source remains clean;
no app/backend implementation changes or production/phone actions. Email and
release-safety stages have not begun.

## Native reveal authentication interruption — passed

Candidate `2fd148a4`, same disposable simulator and boundary account. Owner-only
card `ba230000-0000-4000-8000-000000000003` was natively prepared; guarded
privileged staging setup activated only that fixture v1, without collaborators
or global activation grants. Native preparation also skipped the locked bank.

Started Reveal Credentials, left simulated Face ID pending, pressed Home, and
foregrounded the same process (PID 43385). The edit sheet showed Reveal
Credentials and no plaintext. A new reveal required Face ID again and displayed
the correct synthetic value. Home then foreground again cleared that value.
Authentication-interruption and subsequent retry passed. This does not cover a
delayed post-auth network response arriving after sheet dismissal; that boundary
and remaining device/scope isolation remain separate. No source changes or
rebuild; fixtures retained for remaining tests and still require cleanup.

## Native unapproved second-device status — passed

Candidate `2fd148a4` installed on disposable simulator
`59D3304A-CD59-4F65-8416-8806D6DE1A0B` (Miloom Vault Second Device 20260923).
Signed out obsolete fixture session and signed into the current boundary account.
Dismissed the optional Save Password prompt with Not Now. Password Vault loaded
**This Device Needs Access**, with Request Device Access and recovery controls;
it did not report unlocked or offer creation of a replacement vault. No device
approval or recovery was performed. This confirms the native account-login/device
status boundary only, not a resource-decryption denial or approved-device transfer.
Existing fixture remains retained for remaining checks and cleanup. No source,
production, phone, or permission changes.

## Candidate committed

User-authorized commit `2fd148a4` contains exactly the two verified files on
`codex/collab-staging-candidate-20260923`. The isolated checkout is clean and
the source hashes match the 42-pass test run above. Tests were not rerun merely
for committing unchanged source. The canonical working branch remains untouched;
the repair is not merged there, pushed or deployed. Remaining native acceptance
and external gates still prevent an overall completion/release claim.
