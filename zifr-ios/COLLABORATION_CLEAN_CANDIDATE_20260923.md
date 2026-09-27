# Clean staging candidate attempt

## Current status (2026-09-23)

Latest committed candidate is `7bf657db` on
`codex/collab-staging-candidate-20260923`; its isolated checkout is clean.
It includes the staging-tested invitation handoff fix in `ZifrApp.swift`.
This is **not yet the final accepted build**. Earlier selected tests: 42 passed
on the stated earlier source. The bounded native checks recorded below passed
only to their stated extent. The complete vault, lifecycle and release gates
remain open. Historical build-blocked sections below are superseded by later
results. This report does not authorize or establish production release.

2026-09-26 continuation: candidate now `09a366ef`, clean, containing the
previously staging-tested owner-delete fix and regression. Native source is
unchanged from `7bf657db`; 42 current-source native tests and eight local SQL
scenarios passed. See `COLLABORATION_BOUNDED_CLOSEOUT_20260926.md` for current
identity, remaining gates and the newly prepared guided final-vault fixture.

2026-09-27 checkpoint: that disposable final-vault fixture is now deleted with
absence verified. Recovery, migration/preservation, recovered-device decrypt,
native scoped-key replacement and owner v2 reveal passed; controlled delayed-
response verification remains open. See the closeout record's latest sections.

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

## Native unapproved credential surface and approval request

On the same second simulator and candidate build, Financial showed the mixed
migration bank password as **Locked on this device**. The card detail display
showed only its masked card number; the resource credential edit sheet was not
opened by this check. Face ID-authenticated Request Device Access then changed
the second device to **Approval requested**, still **This Device Needs Access**.
The trusted first simulator showed the specifically named second device as
**Pending** with an Approve control. Approval remains pending; neither cross
device decryption nor broader scoped isolation is claimed. The request and
fixture must be resolved and cleaned up at checkpoint completion.

Source inspection of `SharedItemOverrideBanner.swift` found an operation token
check before publishing a delayed reveal result; dismissal and backgrounding
invalidate that token. This supports the intended guard but is not a native
delayed post-auth response test. Candidate source remains unchanged.

## Native second-device approval and account-field decryption — passed

After user confirmation, first disposable simulator approved only the pending
`Miloom Vault Second Device 20260923` request with simulated Face ID. First
simulator displayed that device as Approved and logged Device approved. The
second simulator refreshed Password Vault to **Vault Unlocked** and listed
itself as Approved.

Financial data loaded before approval stayed visually locked after returning
from vault settings. A fresh process launch (PID 48210) reloaded the data. Its
Synthetic Checking sheet then displayed the migrated synthetic account number
and wire routing number in plaintext, while the deliberately unreadable legacy
routing field remained Locked on this device. This passes account-key delivery,
decryption of those two migrated fields and preservation of the locked field
after a fresh load. Immediate in-session financial refresh after device approval
is a noncritical follow-up; no data loss or access leak was observed.

The separately keyed `Interrupted Reveal Test` card credential has not yet been
revealed on the second device. Approval of the account vault alone is not proof
of collaborator resource-key isolation or the card reveal flow. Fixture and
approved test device remain until the remaining check and cleanup. No source
change, commit, push, production or phone action occurred.

## Native owner resource credential on approved second device — passed

User opened the exact `Interrupted Reveal Test` card edit sheet on the second
simulator. Native Reveal Credentials plus simulated Face ID displayed the exact
synthetic password stored for that card. Hide removed the plaintext and restored
the Reveal Credentials control. This confirms an approved owner second device can
unwrap and decrypt this resource-specific credential on the clean candidate.
It does not prove a collaborator can decrypt only an explicitly granted resource,
or that another scope is denied. Those checks remain bounded gate 4 work.

## Collaborator exact-card grant and sibling isolation — passed, fixture cleaned

On unchanged candidate `2fd148a4`, the guarded staging fixture now includes a
second disposable account (`miloom-vault-boundary-editor-20260923@example.com`),
an exact Editor share for `Interrupted Reveal Test`, a company Viewer share, and
a Viewer-only `Scope Isolation Sibling` card. The sibling has an active v1
resource secret with a different synthetic password; no credential grant was
made to either card. Authenticated backend status using the helper reported the
Editor card as device-needed (the helper's separate login session passes no
device ID) and the sibling as unavailable. This supports the eligibility
boundary, but does not establish native grant/decrypt.

The second disposable simulator signed into that Editor account, dismissed the
optional OS password-save prompt, and natively set up its own account vault
with simulated Face ID. Reopening Password Vault showed Vault Unlocked and this
device Approved. Its one-time recovery code was deliberately not saved for this
disposable account and must not be used as recovery evidence. The exact Editor
card's native edit sheet showed Request Access. After request, the owner vault
showed one pending row naming that Editor and card. With the user's action-time
approval, the owner confirmed the exact grant and simulated Face ID. The Editor
then used Check Again and native Reveal Credentials with Face ID; the correct
synthetic test-card password appeared, and Hide cleared it.

The Viewer-only sibling, also carrying a distinct active resource secret,
remained visible as a card but did not open an edit sheet when the user pressed
and held it. Independent staging row inspection found exactly one active Editor
device grant for the intended card, zero sibling grants and an approved recipient
device. The authenticated status check returned sibling `unavailable`. This is
the bounded native/DB cross-scope pass; it does not claim all rotation or
revocation scenarios were rerun on this fixture.

Guarded fixture cleanup initially deleted the disposable Editor account but
failed to delete the owner: HTTP 500 / SQL 23503, because the resource-secret
purge trigger inserted a key-retirement audit row after Auth had removed the
owner user during cascading account deletion. Added migration
`202609230002_skip_vault_audit_for_deleted_owner.sql`: it retains the audit for
ordinary resource deletion but skips insertion when that owner no longer exists;
key-version purge still runs. Applied **only to staging** with an exact SQL query,
not to production. Rollback-only staging regression probes passed both ordinary
card audit and owner-deletion cascade. Added a repeatable isolated PostgreSQL
`owner_delete` contract; all eight bounded scoped-vault scenarios passed at
`/private/tmp/miloom-scoped-vault.3iD4z7`. Guarded cleanup then removed the owner.
Read-only orphan inventory returned zero for both Auth users, company, bank,
cards, shares, secret versions/wraps/requests/audit, account vaults and devices.
The cleanup is irreversible for these intentionally disposable staging accounts.

The candidate iOS build/source remained unchanged; the staging backend now has
the narrow deletion-trigger fix. The exact direct SQL deployment was then marked
applied as `202609230002` in the staging migration ledger, and a read-only ledger
check verified its name/version alongside `202609230001`.
No app rebuild, commit, push, production or phone action occurred. Gate 4 still
needs the previously frozen recovery/rotation/revocation acceptance evidence
reconciled on the exact candidate; invitation and release-safety gates remain.

## Invitation delivery/link prerequisite inventory — blocked

Fresh staging secret-name inventory still has neither `RESEND_API_KEY` nor
`SHARE_EMAIL_FROM`; no secret value was read and no invitation email was sent.
Read-only HTTPS checks of the live `miloom.co` website returned HTTP 200 for the
script-free `/invite` fallback and HTTP 200 / `application/json` for the Apple
association file. That file lists `WYYJ6FGYRP.com.vibing.miloom` for `/invite`,
but not this candidate's `com.vibing.miloom.staging` app ID. Therefore an actual
delivered email and email-to-staging-app universal-link pass remain blocked.
Adding the staging app to the production host's association file without a
separate link namespace could route production invitations to staging; this
must not be done as an incidental website edit. A staging-only sender/test inbox
and a safe staging link/association arrangement need explicit configuration
before Gate 2 native delivery acceptance. No web deployment was performed.

## Candidate committed

User-authorized commit `2fd148a4` contains exactly the two verified files on
`codex/collab-staging-candidate-20260923`. The isolated checkout is clean and
the source hashes match the 42-pass test run above. Tests were not rerun merely
for committing unchanged source. The canonical working branch remains untouched;
the repair is not merged there, pushed or deployed. Remaining native acceptance
and external gates still prevent an overall completion/release claim.

## Staging invitation isolation prepared — not yet deployed

After owner approval for a staging-only sender/domain, local backend code now
requires `SHARE_INVITE_URL=https://staging-invite.miloom.co/invite` on the exact
staging project and refuses production-domain links there. Staging email also
requires an exact `SHARE_STAGING_RECIPIENTS` allowlist; production keeps its
existing `miloom.co/invite` default. A separate static site directory,
`miloom-staging-invite/`, contains only the staging app ID and `/invite` path in
its Apple association file. Three Deno email tests and Edge Function type-check
passed; static JSON and whitespace checks passed.

Both Resend and Vercel browser dashboards currently show sign-in screens.
The new staging domain does not resolve yet. No domain, DNS, API key, Supabase
secret, function deployment, live email, native entitlement/build, production
site, phone, commit, or push was changed by this preparation. Gate 2 delivery
and universal-link acceptance remain blocked until account access, a verified
staging sender and test recipient, a separately deployed staging host, and a
retested native staging build are in place. Existing exact candidate
`2fd148a4` remains unchanged and clean.

### Staging sender/site deployment progress (later check)

Owner signed into Resend and Vercel in Chrome. Resend had no domains; created
`mail-staging.miloom.co` with sending enabled, but its DKIM/SPF records are not
yet published or verified and no API key was created. Created a **separate**
Vercel project `miloom-staging-invite` (distinct from the `project-mkcuj`
production website) and deployed the static fallback/AASA as deployment
`dpl_GboeUPR5wvy4Z8pK6uKMwSfiGzBh`. The staging `vercel.app` alias returned
HTTP 200 for `/invite` and an unredirected JSON AASA with only
`WYYJ6FGYRP.com.vibing.miloom.staging`; `.env.local` returned 404. Attached
`staging-invite.miloom.co` to that staging project, but it does not yet resolve.
The domain's public nameservers are Squarespace; Vercel requested an A record
for `staging-invite` to `76.76.21.21`.

Staging Supabase secret name `SHARE_INVITE_URL` was set to the custom staging
URL. Deployed only `send-share-email` to project
`bvtuyzhyospqxvpzcrmv`: function version 4, ACTIVE, JWT verification still
enabled. A secret-name check showed only `SHARE_INVITE_URL`; the sending key,
sender and test-recipient allowlist remain absent, so mail cannot be sent.
Squarespace login currently shows only `yageraviation.com`, not `miloom.co`;
no DNS records were changed. Awaiting access to the account that holds
`miloom.co` and separate native staging-entitlement authorization. No
production project/site, native app/build, phone, commit, or push changed.

### Staging DNS published (later check)

The owner opened the correct `miloom.co` Squarespace account and completed its
reauthentication. Saved only four new staging subdomain records:
`staging-invite` A `76.76.21.21`, `resend._domainkey.mail-staging` TXT
(Resend-provided DKIM), `rsend.mail-staging` CNAME `rsend.forge.rmta.net`, and
`send.mail-staging` CNAME `send.forge.rmta.net`. Squarespace confirmed each save;
public DNS resolves all four. Existing apex, `www`, MX, and DMARC records were
not changed. Resend still reports the sending domain Pending/Checking DNS; the
custom HTTPS staging invite host has not yet completed TLS (curl SSL failure),
so its AASA and `/invite` must be rechecked on the custom host. No API key,
sender, recipient allowlist, or real mail has been configured; the deployed
staging function remains fail-closed. Native staging entitlement/build remains
unmodified, and Gate 2 has not passed.

### Staging host and sender domain verified (later check)

Resend now marks `mail-staging.miloom.co` and all three required DNS records
Verified. The custom `https://staging-invite.miloom.co` host serves `/invite`
with HTTP 200 and its Apple association JSON with HTTP 200, `application/json`,
no redirect, only app ID `WYYJ6FGYRP.com.vibing.miloom.staging` and `/invite`.
Vercel recommends a newer per-project CNAME but states the configured legacy A
record continues to work; no DNS replacement was made. No API key or mail has
been created/sent, and no native staging entitlement/build was changed. Gate 2
still requires the restricted staging sender, exact test-recipient allowlist,
native link handler/entitlement, and end-to-end invitation acceptance.

### Restricted staging sender configured (later check)

After action-time owner approval, created Resend key
`miloom-staging-invitations-20260923` with **Sending access** limited to
`mail-staging.miloom.co`. Copied its one-time value directly into Miloom Staging
project `bvtuyzhyospqxvpzcrmv` as `RESEND_API_KEY`, then cleared the temporary
browser clipboard copy. Set `SHARE_EMAIL_FROM` to
`Miloom Staging <invites@mail-staging.miloom.co>`. Staging dashboard lists both
secret names; no value was written to this repo or chat. `SHARE_STAGING_RECIPIENTS`
is still absent pending an explicit test inbox, so the function remains
fail-closed for email delivery. No email has been sent. Native entitlement and
candidate build still await separate approval.

### Staging inbox configured; native universal link signing blocked (later check)

Owner approved `avidyaclothing@gmail.com` as the sole disposable invitation
test inbox and a staging-simulator-only associated-domain build. Added that
exact address to Miloom Staging `SHARE_STAGING_RECIPIENTS`; dashboard confirmed
the secret name. No email has been sent.

In isolated candidate worktree `/private/tmp/miloom-clean-candidate.dKfPen/source`
at base commit `2fd148a4`, changed `ZifrApp.swift` so bundle ID
`com.vibing.miloom.staging` accepts only `staging-invite.miloom.co/invite`,
while the production bundle retains `miloom.co/invite`. Added a staging-only
entitlements plist with `applinks:staging-invite.miloom.co`. Source diff and plist
lint pass. A Debug iPhone 17 Pro simulator build compiled with normal Swift
settings. The original candidate app bundle was copied to
`/private/tmp/miloom-clean-candidate.dKfPen/prior-candidate-Zifr.app` before
building. Temporary Xcode project Debug-setting edits used to test signing were
reverted; project file has no diff.

On disposable simulator `EFAF2008-6AD5-4D66-BD6A-452EADFB0AB3`, the new
app launches when ad-hoc signed without Associated Domains. The same binary
with the staging entitlement (minimal, Xcode-generated simulator entitlement,
or development-identity manual signature) installs but SpringBoard denies
launch (`FBProcessExit launch-failed`, POSIX 163). The working no-entitlement
copy is installed. A synthetic invalid `miloom://staging-invite.miloom.co/invite`
URL reached the system “Open in Miloom?” prompt; the simulator is signed out,
so this does not prove authenticated invitation acceptance. Apple’s association
CDN returns HTTP 200 with only the staging app ID and `/invite`. Universal-link
opening, delivery, and acceptance are **not verified**. Asked for explicit
approval before any Apple Developer staging App ID/provisioning change. No
production app/phone, real email, commit or push was changed.

### Staging provisioning verified; simulator entitlement remains blocked

Owner approved modifying only the disposable staging App ID/provisioning if
needed, with production and the phone untouched. Existing development profile
`1ae9d33c-6125-44c0-b8ce-68aa52d175d6` already identifies
`WYYJ6FGYRP.com.vibing.miloom.staging`, permits Associated Domains and is valid
through 2027-09-22. No Apple Developer portal change was necessary. A Debug
`generic/platform=iOS` build succeeded with the development identity, embedded
profile, and exact `applinks:staging-invite.miloom.co` entitlement; it was not
installed on a phone.

The simulator build also succeeded, but its Xcode signature contains empty
entitlements. On the original disposable iOS 26.4 simulator, re-signing the
same binary without entitlements launched, while adding just the staging
Associated Domains entitlement caused launchd security-policy error 163.
Adding DER entitlements, or signing with the development identity and embedded
staging profile, did not change that result. A new disposable iOS 17.5 simulator
reproduced the same contrast; it was then deleted. The launchable no-entitlement
build was restored to the original disposable simulator. Temporary Xcode
project Debug edits were reverted; only `ZifrApp.swift` and the staging plist
remain uncommitted in the isolated candidate worktree.

This is a simulator launch-policy blocker, not evidence of a missing staging
Apple App ID or incorrect AASA. No real invitation email was sent, and native
universal-link acceptance remains unverified. Gate 2 stays open; an explicitly
authorized staging-signed physical-device test or a verified alternative
simulator signing solution is needed before this checkpoint can pass. No
production, phone, commit, push, or deployment change occurred.

### FX physical staging build installed; backend isolation corrected

With explicit owner approval, the existing staging development profile was
confirmed to include FX (iPhone 15 Pro Max). A signed staging app initially
installed and launched, but immediate metadata inspection found its Supabase
URL/key substitutions empty: the pre-existing client fallback would point at
the production project. The staging process was terminated before any invite
test or app UI action. No production write was observed, but production
requests during that brief launch were not independently ruled out.

The isolated candidate now fails closed when the staging bundle lacks the
explicit `https://bvtuyzhyospqxvpzcrmv.supabase.co` URL or public key. A new
Debug iOS build injected the staging URL and public anon key at build time.
Verification of its Info.plist, decoded key claims, signed entitlement,
provisioning profile and strict code signature passed. The corrected build was
installed and launched on FX; the production `com.vibing.miloom` app remains
separately installed. Temporary project Debug settings were reverted after
building. Candidate source status is `SupabaseService.swift`, `ZifrApp.swift`,
and `Zifr.staging.entitlements` only, uncommitted; `git diff --check` passed.

The current staging `send-share-email` is ACTIVE v7; downloaded deployed source
matches local sender code with exact staging recipient and URL guards, and all
four expected secret names are configured. No real invitation email has been
sent, so native universal-link acceptance is still open. iPhone Mirroring
would forward FX notifications to this Mac; owner preference/approval was
requested before enabling it. No Mirroring setup, production app update,
backend deployment, commit or push occurred.

### Gate 2 physical email/deep-link check (latest)

On FX, native staging Share sent a Viewer entity invitation for synthetic
Miloom Collaboration Fixture to disposable Gmail alias
`avidyaclothing+miloominvite@gmail.com`; Resend reported Delivered. The
message arrived in Spam, was moved to Inbox, and its Review Invitation link
opened Miloom staging. On the first build, an already-open Collaborators &
Sharing sheet stayed over the invitation until Done; then the signed-in owner
received expected recipient-bound `Invitation Unavailable`. The app had not
yet demonstrated automatic sheet dismissal or invited-user acceptance.

A subsequent candidate attempted to dismiss the covering sheet immediately
when the link arrived. Physical retest showed the Invitation screen briefly,
then Dashboard. Exact staging-app crash reports at 19:53 and 20:07 show a
SwiftUI missing-`AuthViewModel` environment assertion. The precise view is
not identified; simultaneous sheet transition is a plausible trigger.

The isolated candidate now queues the link until Collaborators & Sharing has
completed `onDismiss`, explicitly passes the auth environment to the
invitation sheet, and preserves the token across biometric reauthentication.
Signed Debug iOS build and `git diff --check` passed. The bundle ID, staging
Supabase URL, nonempty public key, and exact staging Associated Domains
entitlement were checked before installing this revised staging build on FX
at 20:19. The live email-link retest is still pending, so Gate 2 remains open.
The disposable invitation/fixture must be removed after acceptance testing.
`SHARE_STAGING_RECIPIENTS` was restored to the prior sole inbox
`avidyaclothing@gmail.com`; therefore the pending alias cannot be resent,
but the original delivered link remains available. No commit, push or
production app/backend/site change.

The next physical retest on FX at 21:12 visibly kept the Invitation sheet open
after Gmail's Review Invitation link. It showed `Invitation Unavailable` for
the owner account, which is expected recipient-bound denial rather than proof
of expiry. A read-only staging query confirmed the exact disposable Viewer
company invite remains Pending until 2026-10-01 02:13:51 UTC; no token was
read or logged. This passes basic stable email-to-app routing, but not
automatic dismissal when Collaborators & Sharing is already open, nor
recipient acceptance. Disposable simulator `3C813101-B8C2-4566-9AB1-1AA041BCE2D9`
now runs the same candidate source against staging with Associated Domains
omitted solely because the simulator denies that entitlement at launch. It is
at the Create Account screen awaiting owner go-ahead and hands-on credential
entry/Terms acceptance for the invited alias. FX owner session stays intact.

The user-requested iOS checkpoint commit is `8524b50f` on isolated branch
`codex/collab-staging-candidate-20260923`. It includes only the staging
configuration guard, staging Associated Domains entitlement, invitation-host
routing, and deferred sheet presentation. The branch is clean, but the commit
is not merged, pushed, or production-deployed. Recipient acceptance, the
already-open-sheet overlap retest, and disposable fixture cleanup remain open.

### Disposable recipient signup and native acceptance (22:02 PDT)

Owner created the invited alias account in the disposable simulator, personally
entered its temporary password, and submitted Create Account. The recipient's
Supabase Auth verification email arrived and its confirmation link was opened
with action-time approval. Initial sign-in failed safely because the first
simulator build lacked simulated application-identifier signing and could not
persist its Supabase session. Rebuilding the **same committed source** with
Xcode-managed simulator signing, staging URL/public key, and the staging
application identifier (but no Associated Domains on this simulator) passed.
The owner personally re-entered the password; native sign-in then succeeded.

Native Inbox > Invites showed exactly one pending Viewer invitation for
Miloom Collaboration Fixture. With separate action-time approval, Accept
succeeded and the list became `0 PENDING`. The fixture appeared on the
recipient dashboard labeled `VIEWER`. Its Financial view said the recipient
cannot add items; its service card showed `Credentials are owner-only` and
did not display login/password controls. This is new-user native acceptance
and a visible Viewer boundary, not a recipient universal-link acceptance:
the recipient simulator omits Associated Domains. The already-open owner
sharing-sheet link-overlap retest, owner-side revoke/recipient denial, and
disposable fixture/account cleanup remain. No source change, new commit, push,
production deployment, or FX owner-session change.

### Disposable alias entity removal and recipient denial (22:21 PDT)

On FX in the staging owner session (`fabianology@icloud.com`), Collaborators
& Sharing showed three company-access rows for Miloom Collaboration Fixture:
an active Viewer share for the disposable invited alias, its accepted Viewer
invitation, and the pre-existing active Viewer share for
`avidyaclothing@gmail.com`. The owner chose **Remove from This Entity** for
`avidyaclothing+miloominvite@gmail.com`. After the operation, the native list
showed **one** share: the pre-existing `avidyaclothing@gmail.com` Viewer. No
block was selected. This verifies that this removal cleared both the alias's
direct share and accepted invitation while preserving the independent share.

The recipient simulator initially retained a nonsecret, in-memory dashboard
and service card while the app remained open. The service card still hid its
credentials. After terminating and relaunching only the disposable staging
app, its signed-in dashboard no longer showed Miloom Collaboration Fixture
and instead showed the add-company empty state. Thus fresh recipient loading
denied the revoked entity, but immediate foreground/cache invalidation was
**not** demonstrated and remains a Gate 2 observation to reconcile. The
disposable Auth account still exists pending explicit deletion approval; the
synthetic fixture and pre-existing Viewer share were deliberately preserved.
No source change, new commit, push, production deployment, or production app
change was made.

### Disposable Auth cleanup (22:28 PDT)

With specific action-time approval, the disposable
`avidyaclothing+miloominvite@gmail.com` Auth user was permanently deleted
from **Miloom Staging** (`bvtuyzhyospqxvpzcrmv`) in Supabase Authentication.
The confirmation dialog named that exact alias. A fresh exact-email search
returned `No users found` / `Total: 0 users`; the unfiltered list retained
the owner and the pre-existing `avidyaclothing@gmail.com` account. This
cannot be restored through the product's normal recovery flow. The Gmail
alias, original Viewer share, and long-lived synthetic fixture were not
deleted. The already-open sharing-sheet email-link retest is still pending
the owner's physical tap because iPhone Mirroring does not activate the
button. No source change, new commit, push, or production action.

### Covering-sheet link overlap and narrow retest build (22:50 PDT)

With Collaborators & Sharing open on FX, the owner tapped the original staging
email's Review Invitation link. The first tap closed the open windows without
leaving the Invitation review visible; the second tap opened a stable
`Invitation Unavailable` sheet. That is the expected denial for the old,
revoked/accepted link, but **not** a one-tap handoff pass. No sign-in or access
change occurred.

In the isolated candidate worktree at base `8524b50f`, only
`zifr-ios/Zifr/ZifrApp.swift` was changed. The invitation token is now saved
*before* requesting dismissal of the covering Collaborators sheet, avoiding a
lost token if its dismissal callback arrives synchronously. Presentation is
then queued for the next main-actor update after dismissal. `git diff --check`,
generic iOS Simulator build, and signed Debug iOS build passed. The iOS binary
SHA-256 is `92d1d0c368f7000aaef95b313e30f7f52144d6c54129423844beb839a88c43d2`.
Verified built bundle ID `com.vibing.miloom.staging`, Staging Supabase URL,
and `applinks:staging-invite.miloom.co` entitlement. Installed it over only
the staging app on FX; production was untouched. Local `codesign -v` reports
the same untrusted-chain result as the prior installed staging build, so a
strict local signature pass is not claimed. iPhone Mirroring disconnected
during navigation, so the owner opened the staging Collaborators sheet and
tapped the old Gmail link physically. On this exact installed build,
`Invitation Unavailable` **remained open after the first tap**. The covering-
sheet one-tap handoff and expected old-link denial therefore passed. This
does not establish the remaining Gate 2 revoked-access/cache behavior or
complete release acceptance. No commit, push, merge, backend deployment, or
production action.

### Checkpoint commit (22:59 PDT)

Committed the one-file invitation handoff fix in the isolated candidate as
`7bf657db` (`Fix one-tap invitation handoff over sharing sheet`). The
candidate checkout is clean. This commit identifies the source of the exact
staging build tested on FX above; it is not pushed, merged, or deployed to
production. Remaining bounded gates are unchanged.

### Guided Gate 2 revocation fixture — 2026-09-26

Resumed without computer-use automation. Candidate `7bf657db` remains clean.
Created only staging synthetic company `Gate 2 Revocation Test 20260926`
(`cc260926-0000-4000-8000-000000000001`) under the existing staging owner and
marked disposable Viewer `miloom-gate2-viewer-20260926@example.com`. Privileged
fixture setup inserted one Viewer company edge; it is not native sharing
acceptance. Authenticated backend check confirmed exactly one visible company,
one active Viewer edge and no block. No secret/document/financial data added.
Private credential manifest and guarded helper are in `/private/tmp/` only.

Rebuilt `7bf657db` for disposable recipient simulator
`3C813101-B8C2-4566-9AB1-1AA041BCE2D9` using the existing approved simulator
signing overrides and no Associated Domains. Build passed; staging bundle/project
identity verified; install and launch returned PID 90836. Native sign-in,
foreground/offline revocation and owner-only blocking checks are pending guided
user actions. The synthetic company/account/edge require exact cleanup at this
checkpoint's end. No source change, commit, push, phone update or production action.

User-requested sign-in exception: entered the existing disposable password with
simulator UI control, tapped Sign In, and dismissed Save Password with Not Now.
The native dashboard visibly showed the intended Gate 2 company with VIEWER
badge and zero financial/service/document counts. Sign-in passed; revocation,
blocking and cleanup remain pending. FX and production were untouched.

After the user reported completing native entity removal on FX, the guarded
staging `check-denial` assertion passed: zero Viewer share edges, zero fixture
companies visible through authenticated Viewer RLS, and zero blocks. Backend
revocation passed; recipient foreground refresh still awaits guided observation.

The user's recipient dashboard screenshot at 19:30:51 shows the add-company
empty state, with the revoked fixture absent, after the requested return-to-app
check. Native recipient removal passed in this guided sequence; this is not
evidence of live invalidation while continuously foregrounded or offline denial.
Restored only the synthetic Viewer edge for the next owner-blocking test through
guarded privileged fixture setup, not native invitation acceptance.

After the user completed owner Block All Access on FX, guarded staging inspection
confirmed one owner-to-disposable-Viewer block and no remaining fixture shares.
Authenticated Viewer denial passed (zero visible fixture companies). Native
re-invitation rejection and exact cleanup remain pending; no full Gate 2 pass
is inferred from this subcheck.

The user reported native re-invitation returned **Collaborator blocked**. This
completes this checkpoint's owner-block/re-invitation subcheck. Guarded cleanup
removed the exact synthetic company, disposable Viewer Auth account and test
block; fresh inspection confirmed companyPresent false, viewerPresent false,
shares empty and blockCount 0. These deletions are not normally recoverable;
the owner and independent collaborators were preserved. No production action.
Gate 2 overall remains subject to final bounded checklist reconciliation; no
offline or continuous-foreground revocation pass is claimed here.

### 2026-09-26 bounded evidence reconciliation

Fresh tests on native source `7bf657db`: 42 passed, zero failed/skipped; result
`/private/tmp/miloom-candidate-bounded-20260926.xcresult`. Found that the already
staging-tested owner-deletion fix was absent from the candidate source. Copied
only migration 230002, its account-delete regression and the rehearsal's
owner_delete scenario into the isolated candidate; byte comparisons passed.
All eight isolated SQL scenarios passed at
`/private/tmp/miloom-scoped-vault.GX3kvd`; server stopped. Candidate diff check
passed. These three backend files remain uncommitted; no hosted deployment.
Current bounded phase/checklist reconciliation is in
`COLLABORATION_BOUNDED_CLOSEOUT_20260926.md`. No overall completion/release claim.
