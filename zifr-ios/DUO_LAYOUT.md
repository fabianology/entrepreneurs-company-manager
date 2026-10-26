# Duo layout evaluation — 2026-10-23

Worktree: `codex/duo-evaluation`. This is an evaluation, not a release.
The original iPhone checkout, signing, package pins, and deployment target remain unchanged.

## First-pass file checklist

- [x] `RootView.swift`: persistent adaptive entity sidebar, same detail navigation stack.
- [x] `ControlCenterTabSelector.swift`: live container width, not main-screen width.
- [x] `FinancialView.swift`: wallet constrained to its column (three sites).
- [x] `CompanyDetailView.swift`: column-local edge swipe geometry; synchronize legacy entity switching.
- [x] `DocumentListView.swift`: eliminate global key-window inset; respect local safe area.
- [x] `EntityHomeView.swift`: preserve the content's bottom safe area.
- [x] `SpotlightOverlay.swift`: keep tutorial controls inside their local safe area.
- [x] `DashboardView.swift`: global tutorial coordinates; explicit destination identity prevents stale entity state.
- [x] `PremiumExperienceViews.swift`: reserve space for dismissible Undo bars.
- [x] `ZifrApp.swift`: compile-time-only simulator sample-data entry point for QA.
- [x] `Info.plist`: user approved resizing starting with iOS 27.1 in this checkout only.
- [x] `View+Glass.swift`: retain the earlier Xcode 27.1 overlay-overload fix.

## Resizability audit

Apple's bundled App Resizability skill informed the local geometry and safe-area audit.
Five main-screen width reads occur in three files above. No layout-related orientation
or idiom reads were found. SwiftUI `WindowGroup` already owns scene lifecycle; the
app delegate's push setup is not a reason to add a UIKit scene delegate.

Launch screen is declared. The inherited iPad orientation list is portrait-only;
it omits portrait upside-down and both landscape orientations. No orientation
override was searched for as part of that prerequisite check. Multi-window remains off.
`UIRequiresFullScreen` is retained for older releases. The user explicitly chose
`UIRequiresFullScreenIgnoredStartingWithVersion = 27.1` for this isolated evaluation.

## Verification

Normal Debug simulator builds passed with both Xcode 27.1 and 26.4 after the final
changes. Minimum iOS remains 17.0. Project settings and Package.resolved retain
their starting hashes. Final normal 27.1 executable has no sample-preview app
symbol. Diff whitespace check and a second-agent coverage/correctness review pass.
No automated XCTest suite was run for this layout pass.

In the dedicated fresh iOS 27.1 Duo simulator, using synthetic read-only records:

- Open, closed, and partially open poses rendered successfully.
- Sidebar entity switching updates the detail header and data; All Entities returns to the portfolio.
- Financial, Services, and Vault fit their detail column.
- Selecting Services from the sidebar returns from Settings to the correct entity.
- Services selection survives closing/reopening the display.
- An open Search sheet and its typed `fold check` query survive closing/reopening.
- A right-edge swipe inside the detail column changes Services to Vault.

A separate fresh iPhone 17 / iOS 26.4 simulator renders the compact layout without
the entity sidebar. This verifies the navigation structure, not pixel-identical
appearance or all compact flows. The original checkout's tracked-diff fingerprint
still matches its pre-task value; default developer tools remain Xcode 26.4.

Logs and screenshots: `/private/tmp/miloom-duo-setup-20261023.oewGU7/`
(`duo-layout-final-build.log`, `duo-layout-xcode26-final-build.log`,
`duo-preview-final-build.log`, `duo-layout-final.png`, `compact-layout-final.png`).
The Duo simulator is left open with the sample-data preview. No real phone install,
account sign-in, backend mutation, archive, commit, push, merge, or deployment.

## Preview and remaining work

The opt-in preview entry point is compiled only when all three conditions hold:
`DEBUG`, iOS Simulator, and `MILOOM_LAYOUT_PREVIEW`. Append
`-DMILOOM_LAYOUT_PREVIEW` to inherited `OTHER_SWIFT_FLAGS` for a QA build; do not
replace `SWIFT_ACTIVE_COMPILATION_CONDITIONS`, which packages also use.
Use this only on a fresh unauthenticated simulator. No app-level session loader or
push delegate is mounted, sample records have no authenticated owner, and the
Vault's initial expense refresh is excluded from this QA configuration. Other
existing child-screen refresh actions are not a general offline service mock.
Normal Debug and all Release/device builds use the normal authentication entry.

Before any release: authenticated create/edit/share flows and their sheets during
folding, long populated portfolios, Dynamic Type, VoiceOver, keyboard editing,
scanner hardware, onboarding spotlights, and Undo bars need runtime regression
testing. Sign-in and resource editors have not been redesigned for wide displays.
No iPad orientation expansion or multi-window support was added. This checkout
starts at main `49449473`, not the user's dirty iPhone checkout or later build-17
feature source; integration with those changes requires a separate reviewed step.

## 2026-10-26: entity cards and top controls

Owner clarified that the closed picker should match the larger green-and-gold
cards on the open screen, not the compact left-sidebar rows. The closed picker
now uses the same `PortfolioCompanyCard` / `CompanyCardView` component as the open
portfolio. Counts, ownership/share-role checks, edit/share availability, and the
Financial/Services/Documents callbacks come from one shared wrapper. Wide sidebar
rows remain compact; the initial compact column is the entity picker.

Removed the top All Entities control. The shared header now presents Executive
Brief with the unread-aware Inbox bell to its right. MILOOM appears once at the
very top, above the split view, without duplicating the old dashboard wordmark.
The lower Jump to Entity / All Entities menu is intentionally retained.

Header requests are queued in AppViewModel and consumed once by the stable detail
stack. Existing briefing, Inbox, company edit/share, and premium sheets are hosted
on that stack so the picker can open them even when the compact detail was hidden.
Existing entitlement checks and persistence services were not changed. The QA-only
sample-data label now sits under MILOOM in the header rather than altering a safe
area, which had clipped controls during the first visual check.

Verification after final corrections:

- Normal Debug builds passed with Xcode 27.1 and Xcode 26.4; iOS minimum remains 17.
- Two focused ExecutiveBriefingTests passed under Xcode 26.4: repeat/consume-once
  presentation requests and edit/share targets preserving the selected detail.
- Dedicated Duo sample build passed. Open and closed renders show the requested
  cards, top wordmark, Executive Brief, bell, and no top All Entities button.
- Executive Brief opens the existing briefing sheet. The bell opens Inbox;
  invitation loading then reports an error in the unsigned unauthenticated sample
  session. Real invitation data/loading is not accepted by this check.
- A visible-touch Services shortcut opens Northstar Studio's Services section.
  No real account sign-in, edit/save/share mutation, or physical phone test.
- Whitespace check passes; Xcode project and package-pin hashes are unchanged.
  Original checkout tracked-diff fingerprint remains the pre-task value and the
  global developer directory still selects Xcode 26.4.

Evidence/logs: `/private/tmp/miloom-duo-entity-header-20261026.kmOW0k/`, including
`preview-build.log`, `xcode27-normal-build.log`, `xcode26-final-tests.log`,
`after-closed.png`, and `after-open.png`. These changes remain uncommitted/unpushed;
no merge, deployment, archive, Apple upload, or backend mutation.

## 2026-10-26: latest card/header revision undone

At the owner's request, the card/header revision immediately above is rolled back.
The entity sidebar again uses compact rows and the All Entities control, with the
previous dashboard wordmark and receipt/bell controls restored. Removed the shared
card/header wrappers, picker presentation queue, and its two added tests. Retained
the earlier Duo split view, local geometry/safe-area changes, iOS 27.1 resizing
choice, and simulator-only sample preview. The original iPhone checkout and Xcode
default remain untouched. The preceding section is historical, not current UI.

## 2026-10-26: no sidebar on All Entities

The All Entities dashboard now forces the split view to detail-only and removes
its sidebar toggle/back entry. Entering an entity restores the wide sidebar;
the existing detail NavigationStack stays mounted throughout. Card styling,
dashboard logo/actions, data, and existing entity navigation remain unchanged.
RootView owns visibility, and DashboardView hides the portfolio root's automatic
sidebar/back controls. The simulator-only sample label is a sibling of RootView
instead of a nested safe-area inset, preventing preview header clipping when the
system sidebar toolbar disappears. No production authentication path was changed.

Normal Debug simulator builds passed with Xcode 27.1 and 26.4 after the final
source changes; the explicit Duo sample build also passed. Sample UI checks:
wide and closed dashboard without sidebar or sidebar/back button; original header
visible; dashboard edge swipe does not reveal the sidebar; an entity card opens
the matching detail, and opening the display shows its entity sidebar. All
Entities and the existing entity back gesture return to the full-width dashboard.
No XCTest suite or authenticated-flow regression was run this pass.

Evidence: `/private/tmp/miloom-duo-dashboard-only-20261026.CTyN9f/` (before/after open screenshots,
closed dashboard screenshot, final normal build logs, and preview build logs).
Original checkout fingerprint and Xcode 26.4 default remain unchanged; project,
package pins, deployment target, signing and backend contracts are untouched.
All changes remain local/uncommitted; no push, merge, deployment, archive,
Apple upload, real-phone install, account sign-in, or backend mutation.

## 2026-10-26: automatic receipt on expanded Duo dashboard

Owner's clarified placement is implemented only in the Duo evaluation checkout:
open and partially open landscape show the existing executive receipt on the
left and existing entity cards on the right; both expanded portrait poses show
cards above the receipt. Closed uses the existing single-panel cards and modal
receipt. Non-Duo devices have no hinge and never mount the inline receipt.
Xcode 26.4 compiles the original list path; new SDK APIs are compiler/OS guarded.

Panel placement uses local geometry and Apple's division reserved region, with
fixed panel viewports. The same card-list child remains first in the layout
across rotations. Only a closed/open eligibility change updates hinge state;
continuous angle updates do not rebuild briefing calculations. Existing green
and gold cards, receipt contents, header, navigation and entitlement gate remain.

Preparation copies the existing Sendable search snapshot, then calculates the
receipt on a dedicated actor. It coalesces publications for 100 ms, cancels
superseded work, retains the last valid same-context report during refresh, and
caches up to four scope/month/revision reports. Account/access changes invalidate
cached figures. No added bank refresh, AI request, dependency or backend change.
A one-time 0.45-second top-down mask reveals the receipt; it does not animate
layout height or rows. Reduce Motion and Low Power Mode skip that reveal.

Verification performed:
- Normal Debug builds passed on Xcode 27.1 and 26.4. The 29-test executive
  briefing suite passed on both versions, including seven new layout, cache,
  cancellation/privacy and immutable 1,000-transaction off-main-thread tests.
- Labeled synthetic preview rendered all four expanded pose/orientation pairs,
  automatically loaded the receipt, switched Personal/Business controls, and
  returned to the visually matching closed dashboard without an inline receipt.
- Whitespace check passed. Original checkout's tracked-diff fingerprint remains
  cd0d60b30fe62c33283421074af6ac0d2fc98abe22985a76110ab0eb5632f6fa;
  project/package hashes and global Xcode 26.4 selection remain unchanged.

Limits: native simulator automation did not reliably forward swipe scrolling,
so independent touch scrolling still needs manual acceptance. xctrace could not
attach to the simulator process; no frame-time or zero-stutter claim is made.
Real populated portfolios, physical hardware, Reduce Motion/Low Power runtime,
Dynamic Type/VoiceOver, locked access and authenticated navigation remain to
check. Screen-reference review did not establish an exact foldable arrangement;
the owner's specified layout and MILOOM's existing visual components govern it.

Evidence: /private/tmp/miloom-duo-briefing-20261026.Cr6JDw/ (normal/preview
build logs, xcode26-tests-refactor.log, xcode27-tests.log, and pose screenshots).
Local/uncommitted/unpushed; no merge, deployment, archive, Apple upload,
real-phone install, account sign-in or production mutation.

## 2026-10-26: owner-approved local checkpoint

The owner approved committing the Duo work so far on `codex/duo-evaluation`.
This checkpoint includes the earlier adaptive navigation/geometry work, the
dashboard-only sidebar removal, the expanded dashboard receipt, and their tests
and notes. Earlier uncommitted-status statements above describe those historical
implementation passes; the resulting commit is recorded in the canonical
project-management UPDATES.md. No push, merge, release or original iPhone
checkout change is authorized by this checkpoint. The verification and remaining
manual acceptance limits above still apply; builds/tests are not rerun merely
for this Git checkpoint.
