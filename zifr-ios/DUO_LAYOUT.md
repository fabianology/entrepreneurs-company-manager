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

## 2026-10-26: show owned-card controls in the labeled preview

The edit/share controls were already present in CompanyCardView and correctly
gated by ownership, but the unauthenticated QA entry point made both synthetic
entities look like limited-access shared entities. The preview now defines its
fixture owner ID once and uses it solely for dashboard card presentation under
DEBUG + simulator + MILOOM_LAYOUT_PREVIEW. No AuthViewModel session is created;
normal Debug/Release builds still derive permissions from the signed-in user.
Existing pencil/share buttons and sheet callbacks are unchanged.

Verified normal Debug builds with Xcode 26.4 and 27.1 and the explicit 27.1
preview build. Visually confirmed both icons at the right of each black header
in open landscape and partially open portrait. Northstar Studio's edit/share
buttons open the matching existing sheets; canceled both without saving or
sending an invitation. No XCTest rerun or authenticated save/sharing acceptance.
Evidence: /private/tmp/miloom-duo-card-controls-20261026.8ZXt6M/.
Original iPhone checkout, real-user access rules, project/package settings and
global toolchain unchanged. This follow-up is uncommitted/unpushed; checkpoint
228a9cd0 remains intact. No backend mutation or physical-phone installation.

## 2026-10-26: Duo entity sheet and pinned Add Accounts

NewEntitySheet (also used for editing) now detects a non-nil hinge under the
new SDK guard, including the closed Duo display. On Duo only it uses system
form sizing and the large detent, and provides symbol-bearing Cancel/Save labels
so the system places those controls in the outer display's side bar. The legacy
iPhone still uses the 0.84 detent and its original text toolbar controls.

The existing Add Accounts button is shared by both paths. Only on Duo, it is
outside the ScrollView in a bottom safe-area inset, above the keyboard when
present. Fields remain scrollable on shorter layouts; button validation,
navigation, authentication, bank connection and persistence code are unchanged.

Verified normal Debug builds in Xcode 26.4 and 27.1, plus explicit preview build.
On the synthetic Duo simulator: closed sheet shows every identity field and the
complete Add Accounts button without scrolling; Cancel/Save are clear of the
status area. Keyboard leaves the name and pinned action visible; typing a local
test name enables the action. Opening, partially folding and rotating to portrait
preserve that unsaved name and the visible action. Cleared the test name without
saving or invoking Add Accounts. No XCTest rerun or authenticated creation/bank
connection acceptance. Evidence: /private/tmp/miloom-duo-entity-sheet-20261026.rDlKXr/.

Only EditCompanySheet.swift and these notes changed in this pass; prior pending
preview-icon changes are preserved. Original iPhone checkout fingerprint,
project/package hashes and default Xcode 26.4 remain unchanged. Uncommitted and
unpushed; no merge, deployment, archive, account mutation or real-phone install.

## 2026-10-26: dashboard actions in the Duo side toolbar

On the dashboard, Duo's active vertical toolbar now contains Admin at its top
and Gemini above Plus at its bottom. Existing glass styling, callbacks, haptics
and tutorial targets are reused. The bottom row then contains only Search,
expanding into the freed width with the same horizontal margins. The system's
toolbarVerticalEdge and a non-nil device hinge gate this behavior; no global
screen bounds or status-strip offsets are used. On open/partial portrait without
a vertical toolbar, the original Admin/Search/Gemini/Plus row returns. Non-Duo
devices and Xcode 26.4 retain that original layout. The entity-detail controls
are unchanged; the new toolbar items are dashboard-root-only.

Verified normal Debug builds on Xcode 26.4 and 27.1 plus the explicit preview
build. Synthetic simulator checks: closed, open/partial landscape, open/partial
portrait, correct Admin/Gemini/Plus ordering, no duplicate portrait controls,
Plus opening New Entity, Admin opening Settings and returning, and Search opening
global search. Dismissed without changing settings or saving an entity. Gemini
was not activated, so no voice session, permission grant or metered call tested.
No XCTest rerun or authenticated-flow acceptance. Evidence and build logs:
/private/tmp/miloom-duo-toolbar-20261026.lQM4Qr/.

This pass changes DashboardView.swift and these notes only; pending preview
ownership and entity-sheet fixes are retained. Original iPhone checkout's diff
fingerprint, project/package hashes and global Xcode 26.4 are unchanged.
Uncommitted/unpushed; checkpoint 228a9cd0 remains. No merge, deployment, archive,
upload, production mutation or real-phone installation.

## 2026-10-26: full-height landscape briefing and right-pane chrome

Only on the expanded (open/partially open) landscape Duo dashboard, the MILOOM
wordmark/header and Search now belong to the right entity pane. The left receipt
uses the full available safe-area height instead of losing space to global
header/search rows. Its existing margins, independent ScrollView, worker/cache,
loading behavior and reveal animation are unchanged. Gemini takes Admin's upper
native toolbar slot; Admin stays available in Gemini's former lower slot above
Plus. Search's actual center follows the measured native Plus center, including
the bottom safe-area overlap, without hard-coded screen or status-strip offsets.

The legacy outer header and bottom safe-area row remain in closed/portrait
layouts. Portrait continues cards above receipt with horizontal controls. Empty
receipt/header/footer layout slots use concrete containers so closed placement
does not collapse. Root hinge/geometry state is reconciled on navigation return
to avoid duplicate header/Search rows after Settings. No NavigationStack swap,
data-loader changes, permission changes or new dependencies.

Verification: final normal Xcode 26.4 and 27.1 builds/test products succeeded;
33 ExecutiveBriefingTests passed on each, including four new chrome/alignment
regressions. Explicit preview build succeeded. Visually checked open/partial
landscape, open/partial portrait, closed, Search opening global search, Plus
opening New Entity (dismissed without saving), and Admin/Settings return without
duplicate rows. Gemini was not activated. Automated receipt scroll gestures did
not establish movement; real touch scrolling and measured frame-time acceptance
remain open, as do authenticated workflows. Evidence/build/test logs:
/private/tmp/miloom-duo-landscape-chrome-20261026.zuh0TV/.

This pass changes DashboardView, ExecutiveBriefingViews, ExecutiveBriefingModels,
ExecutiveBriefingTests and these notes only. Prior preview ownership/entity-sheet
changes are retained. No original iPhone source edits by this task. Canonical
diff changed concurrently with the separately recorded startup-loading task;
it is not claimed unchanged globally. Duo project/package hashes and global
Xcode 26.4 default remain unchanged. Local/uncommitted/unpushed; checkpoint
228a9cd0 remains. No merge, deployment, archive, upload, production mutation or
real-phone installation.

## 2026-10-26: match closed Duo toolbar order to landscape

The dashboard's native vertical toolbar now always places Gemini at the top
and Admin above Plus at the bottom, including closed Duo. Only the former
pose-dependent ordering in DuoDashboardSideToolbar changed. Closed header,
cards, Search placement, portrait horizontal controls, detail pages and all
callbacks remain unchanged. Original iPhone source was not edited by this task.

Verified normal Debug builds in Xcode 26.4 and 27.1 and the explicit simulator
preview build. Visually confirmed the requested closed ordering, unchanged
landscape ordering, and unchanged open-portrait horizontal controls. No XCTest
rerun or live Gemini session. Evidence: /private/tmp/miloom-duo-closed-toolbar-20261026.PCEdcA/.
This pass changes DashboardView.swift and these notes only, preserving all
pending Duo work. Project/package hashes and global Xcode 26.4 are unchanged.
Uncommitted/unpushed; no merge, deployment, archive, upload or real-phone install.

## 2026-10-26: align closed dashboard Search with Plus

Closed Duo Search now follows Plus's vertical center without changing the row's
reserved layout height, header, cards or horizontal margins. Non-interactive
window-coordinate reporters measure the unshifted row and native Plus: collapsed
toolbar/content hosts do not consistently share a SwiftUI global origin. Reports
are coalesced on the main queue and publish only changed centers; adjustments
larger than one control height are ignored as stale fold/rotation pairs. The
offset applies only with a Duo side toolbar outside expanded landscape. Existing
landscape pane positioning and portrait/legacy horizontal controls are retained.

Repeated rotation also exposed the side toolbar gating its own creation on an
emitted edge that can transiently vanish. Eligibility now follows the existing
hinge/device and local orientation state (closed or expanded landscape); native
placement remains system-managed. Navigation return reconciles toolbar eligibility
along with landscape state, avoiding missing controls after a fold.

Verified final normal Debug builds in Xcode 26.4 and 27.1 plus explicit preview
build. Synthetic UI: closed centerline, actual coordinate tap on the shifted bar
opens global search and dismisses normally, retained open-landscape alignment,
portrait horizontal row, and repeated rotations/folds returning the native
toolbar and closed alignment. Gemini was not activated; no data was entered or
saved. No XCTest rerun or physical-device/performance acceptance. Evidence/logs:
/private/tmp/miloom-duo-closed-search-20261026.vy0e2m/ (closed-aligned.png).

This pass changes DashboardView.swift and these notes only. All earlier pending
Duo work remains. Canonical non-coordination diff fingerprint stayed
e450a9d332a542091d21a33831318a9c271988c2dd7d075acc4aa0cb03473b2f;
no original iPhone source edits by this task. Project/package hashes and global
Xcode 26.4 unchanged. Uncommitted/unpushed; no merge, deployment, archive, upload,
production mutation or real-phone install by this task.

## 2026-10-26: Plus below Gemini; Admin in bottom slot

The dashboard's Duo side toolbar now stacks Gemini then Plus at the top, with
Admin alone in the former bottom Plus slot. Search remains on the bottom row:
its closed-window and landscape alignment measurements now follow Admin rather
than the relocated Plus. Renamed only these alignment bindings/parameters to
describe the bottom control. Portrait horizontal controls, entity detail and
regular iPhone layout paths remain unchanged.

Two separate top toolbar group items disappeared in the closed simulator host
after rotation/folding. Keeping Gemini/Plus in one native item with a 16-point
vertical stack retained both through the repeated fold/rotation check.

Final normal Debug simulator builds succeeded with Xcode 26.4 and 27.1; the
explicit 27.1 sample preview also built. Visually checked closed, open/partial
landscape, unchanged open portrait, and closed after repeated rotation/folding.
No XCTest rerun, Gemini activation, saved data or physical-device/performance
acceptance. Evidence: /private/tmp/miloom-duo-toolbar-swap-20261026.VSPOsp/.

This pass edits DashboardView.swift, ExecutiveBriefingViews.swift and these notes,
preserving all earlier pending work. No original iPhone source edits by this
task. Canonical source changed independently with the recorded quiet-refresh
task. Project/package hashes and global Xcode 26.4 remain unchanged. Local,
uncommitted/unpushed; no merge, deployment, archive, upload or real-phone install.

## 2026-10-26: shared Duo toolbar on entity pages

Financial, Services and Vault now reuse the dashboard's native Duo side toolbar:
Gemini above Plus, Admin at the bottom. Search remains aligned with Admin; the
entity-switching menu stays beside Search. Expanded portrait retains horizontal
controls. The Duo read-only presentation uses a disabled Plus instead of an eye;
all creation checks remain intact. The explicit sample-preview fixture now sets
its synthetic portfolio owner identity, so owner add controls display correctly
without authenticating or changing normal app permissions.

Shared full-window hinge/orientation state reaches navigation destinations even
when their detail column is narrow. Observe it from a non-interactive background,
not directly on NavigationSplitView: attaching it to the container interfered
with dashboard column layout. Avoid a navigation-depth gate for entity toolbar
creation because compact split navigation can empty the bound path while keeping
the entity destination visible. A Duo All Entities request explicitly reconciles
the path, preferred detail column and stored sidebar visibility after folding.
No fold-dependent recreation of the navigation stack was introduced.

Final Xcode 26.4 and 27.1 normal Debug simulator builds and the explicit 27.1
preview build succeeded; whitespace check passed. Synthetic UI during this pass
checked Financial/Services/Vault controls, financial Add menu, Services form
opening/cancellation without saving, Admin/back, partial landscape and portrait.
Final preview checks confirmed all three entity tabs in closed mode, repeated
rotations/folds and a full-width landscape dashboard return with receipt left,
cards/header/Search right and no sidebar. Gemini was not activated. No XCTest
rerun, authenticated permission-matrix test, real-phone or performance acceptance.
Evidence/logs: /private/tmp/miloom-duo-entity-toolbar-20261026.vPZhjT/.

This pass changes CompanyDetailView.swift, DashboardView.swift, RootView.swift
and these notes only, preserving earlier pending work. Original iPhone source
was not edited by this task. Project/package hashes and global Xcode 26.4 remain
unchanged. Local/uncommitted/unpushed; checkpoint 228a9cd0 retained. No merge,
deployment, archive, Apple upload, backend mutation or physical-phone install.

## 2026-10-27: entity switcher above Admin in the Duo side toolbar

On Financial, Services and Vault, the 9-dot entity menu moves from beside Search
into the lower native toolbar group, directly above Admin. Search fills the freed
width and keeps its existing Admin-center alignment. When there is no vertical
toolbar (expanded portrait or legacy iPhone), the existing horizontal entity
menu remains. Shared MiloomEntitySwitcher preserves entity selection/All Entities
actions and styling, and now has the accessibility label Switch entity.

Admin has the same lower entity switcher above a selected, non-interactive
current-page Admin icon. Its existing custom Back/content stay; the navigation
bar is enabled only while the Duo side toolbar is in use. No unrelated Gemini
or Add action was added to Admin. The dashboard passes an empty entity slot and
keeps its previous toolbar arrangement. Existing permission checks are unchanged.

Final normal Debug simulator builds succeeded on Xcode 26.4 and 27.1; explicit
27.1 sample preview and whitespace check passed. Synthetic UI verified all three
closed entity tabs, expanded Search, open/partial landscape placement, Admin
entry from both an entity and dashboard, Admin-to-Personal switching, Admin All
Entities returning to the full-width dashboard, and restored Admin controls
after repeated rotations/closing. Expanded portrait Admin retains its old
hidden-navigation-bar presentation. No settings toggles, saved form data, Gemini
activation, XCTest rerun or real-device/performance acceptance. Evidence/logs:
/private/tmp/miloom-duo-entity-switcher-20261027.e60LtT/.

This pass edits CompanyDetailView.swift, DashboardView.swift, AdminSettingsView.swift
and these notes only, retaining all earlier pending work. Original iPhone source
and installed build were not edited/updated by this task; canonical source diff
fingerprint remained a6c853dd45aeeb2b145f25deb930a49307b67a4c402c0c87a487a7fac07c1d02.
Project/package hashes and global Xcode 26.4 unchanged. Local/uncommitted/unpushed;
checkpoint 228a9cd0 retained. No merge, deployment, archive, upload or phone install.

## 2026-10-27: owner-requested Duo polish checkpoint

Checkpoint scope is the nine pending native source/test/layout-note files since
228a9cd0: full-height landscape briefing/right-pane chrome, native side toolbars
and Search alignment, entity-sheet sizing/pinned Add Accounts, labeled preview
ownership, shared pose/navigation handling, and entity switching above Admin.
All remain confined to this separate Duo checkout. Existing verification above
is retained: latest Xcode 26.4/27.1 normal builds and 27.1 preview succeeded;
earlier focused briefing tests and later synthetic UI checks are dated evidence,
not newly rerun tests. Commit-only pass reviewed the diff and whitespace; no
source behavior, signing, dependencies or build settings changed in this pass.
No push, merge, deployment, upload or installed iPhone update is requested.

## 2026-10-27: Gemini beside Search; separate sharing and reports

Duo dashboard and Financial/Services/Vault place Gemini immediately right of
Search, with matching 44-point controls and the same closed alignment offset.
Entity side toolbars replace Gemini with Share above Plus; the header receipt
menu contains only Financial Report and Subscription Report. Share reuses the
five existing scope options, permission checks and sheet. Expanded portrait has
no side toolbar, so Share remains reachable beside the header receipt. Admin's
only change is the shared modifier argument rename to primaryAction. Legacy
iPhone presentation and original checkout are unchanged by this task.

Normal Debug simulator builds passed with Xcode 26.4 and 27.1; the 27.1 sample
preview and whitespace check passed. Synthetic UI verified all three closed
entity sections, expanded landscape/portrait controls, dashboard closed/open/
partial landscape and portrait placement, Search opening, five Share choices,
and both existing report sheets opening/dismissing. No invitation, access change,
Gemini activation, saved data, XCTest rerun or physical performance acceptance.
Evidence: /private/tmp/miloom-duo-share-reports-20261027.kWsWu5/.

Remaining navigation issue observed during QA: All Entities from an expanded
portrait entity can retain the sidebar; rotating then showed missing dashboard
Search until a close/reopen restored the full-width layout and controls. Cause
and whether it predates this change were not isolated; no navigation fix is
claimed. Screenshot: dashboard-return-portrait-sidebar-issue.png. This pass is
local/uncommitted/unpushed after checkpoint 3b4d069f; no deployment or phone
install. Project/package hashes and the global Xcode 26.4 selection are retained.

## 2026-10-27: remove the left navigation sidebar throughout Duo

RootView now mounts DashboardView's single navigation stack directly when the
existing window observer identifies a Duo. The split sidebar and its reveal
button/gesture are absent on Duo dashboard, entity sections and Admin. The
existing 9-dot menu, section tabs and right-side toolbar remain. This choice uses
device identity rather than pose or width, so folds/rotations keep the same stack
mounted. The legacy split surface is retained for non-Duo devices and older
SDKs; the original iPhone checkout and installed app were not changed.

Normal Debug simulator builds passed on Xcode 26.4 and 27.1, along with the
explicit 27.1 sample preview and whitespace check. Synthetic UI verified all
three entity sections, switching to Personal through the 9-dot menu, Admin and
its All Entities action, full-width open/partial landscape pages, open portrait,
closed dashboard/entity and reopening. The previously observed portrait All
Entities return now kept full width and Search after rotation. Search opened and
remained presented through two rotations and closing, then dismissed normally.
No saved data, settings changes, Gemini activation, XCTest rerun, authenticated
flow or physical-device/performance acceptance. Evidence and three build logs:
/private/tmp/miloom-duo-no-sidebar-20261027.rXCavD/.

Only RootView.swift and these notes changed after fec41d2d. Project/package hashes,
global Xcode 26.4 and canonical non-coordination source fingerprint stayed the
same. Local/uncommitted/unpushed; no merge, deployment, upload, archive, backend
mutation or real-phone install.

## 2026-10-27: dashboard Share above Plus; rightmost card Edit

Duo dashboard adds the existing glass Share control above Plus. Its menu first
chooses an eligible entity, then one of the same five EntitySharingScope options
as the entity pages, and opens the existing ShareEntitySheet. Eligibility reuses
resourceAllowsSharing; no grant/role/backend logic changed. Duo Plus directly
opens New Entity instead of retaining a duplicate long-press Share menu. Expanded
portrait keeps Share in the header when the side toolbar is absent. Duo entity
cards omit the Share callback, leaving Edit at the far right automatically;
CompanyCardView itself and non-Duo callbacks/presentation remain unchanged.

Removed the obsolete sidebar-toggle removal on Duo only: it made the new native
Share label invisible while leaving its menu tappable. Legacy split navigation
still removes its redundant dashboard sidebar toggle. Earlier pending sidebar
removal in RootView is preserved unchanged.

Final Xcode 26.4/27.1 normal Debug simulator builds and the explicit 27.1 sample
preview passed; whitespace check passed. Synthetic UI verified visible Share
above Plus, no Share on either card, rightmost Edit, all five sharing choices,
Entire Entity opening Northstar Studio's existing sheet, scoped documents sheet
during the pass, Edit opening Northstar Studio, Plus opening New Entity, and
closed/open/partial landscape plus open/partial portrait placement. Forms were
canceled; no invitations, grants, saved data or Gemini activation. No XCTest
rerun, authenticated permission-matrix or physical-device/performance acceptance.
Evidence/logs: /private/tmp/miloom-duo-dashboard-share-20261027.X9GSek/.

This pass changes DashboardView.swift and these notes only; earlier pending
RootView work is retained. Canonical non-coordination fingerprint, project/package
hashes, global Xcode 26.4 and installed iPhone build remain unchanged by this task.
Local/uncommitted/unpushed; no merge, deployment, archive, upload or phone install.

## 2026-10-27: selected-entity Transactions in partial landscape

Partially open landscape now embeds the existing Cash-Flow Insights and
Transactions content full height on the left of the selected entity. Entity
header, Financial/Services/Vault content, Search and Gemini occupy the right.
Other poses retain their existing page and modal Transactions entry. The passive
hinge observer records discrete partial-open status; no continuous angle updates.
The pane mounts on first use and stays mounted across folds, rotations and tabs
so its analysis and month/filter state can survive pose changes.

Reuses PortfolioTransactionCenterView and its existing detached analysis,
stale-result guard, source data and sync/pull-to-refresh behavior. No new
Generate/Refresh button, fetch, polling, AI request or backend path. Embedded
analysis resolves account ownership before restricting records to the entity;
cash flow, duplicate/subscription detection, review counts and account filters
use that scope. The company selector is omitted only when embedded. The normal
sheet's nil scope and original presentation remain. Sample-preview-only fixture
transactions deliberately differ between Personal and Northstar Studio.

Verification: nine focused Xcode 26.4 tests passed, including inferred account
ownership, selected-entity cash flow, exclusion of other-entity duplicate alerts
and unchanged default portfolio scope. Final normal Debug simulator builds on
Xcode 26.4/27.1 and explicit 27.1 sample preview passed. Synthetic UI checked
partial landscape on all three tabs, Studio +$1,920 vs Personal -$25 after entity
switching, month selection retained after folding, original fully open modal,
closed layout and partial portrait without the inline pane. Final whitespace
check passed. Evidence/logs:
/private/tmp/miloom-duo-inline-transactions-20261027.IFmm0D/.

Scrolling acceptance remains limited: automated drag/wheel input failed on both
the new pane and original modal in the partially open simulator, while the
original modal scrolled when fully open. A temporary preview diagnostic confirmed
correct viewport/content bounds and was removed. No claim of verified independent
dragging, scroll-offset retention, physical-device performance, authenticated
flow or measured frame rate. No data writes, sync button activation or phone
install during this pass.

Changed CompanyDetailView.swift, PortfolioTransactionCenterView.swift,
RootView.swift, PremiumEngineTests.swift and these notes after 46158b3d. Project
and package hashes, global Xcode 26.4 and canonical non-coordination source
fingerprint remained unchanged. Separate Duo branch codex/duo-evaluation only;
local/uncommitted/unpushed; no merge, deployment, archive or upload.

## 2026-10-27: clear glass cash-flow pane

Duo inline pane removes its Transactions/entity heading and opaque gray outer
background. Cash-Flow Insights uses native glassEffect(.clear) instead of the
black sheet-card backing. Its net cash-flow summary retains its data/spacing but
removes the gray fill and gold box outline. Positive amounts use mint in this
pane so they stay readable over green. Month picker, metrics and action rows
retain existing behavior. ZifrSheetCard gains usesClearGlass, default false;
only the embedded entity cash-flow card opts in. Original modal/default card
styling, data-loading/sync logic and other poses remain unchanged.

Final normal Debug simulator builds passed on Xcode 26.4/27.1, and explicit 27.1
sample preview passed. Whitespace check passed. Synthetic UI verified clear glass,
removed headings/gray boxes, Studio +$1,920 and Personal -$25, month picker and
September no-activity state, month retention through fully open/back to partial,
and the original modal with its dark card/gray summary intact. Returned preview
to Personal/October partial landscape. No XCTest rerun for this visual-only
change, authenticated flow, physical-device or performance acceptance; previous
partial-open simulator scrolling limitation remains. No data writes or sync
activation. Evidence/logs: /private/tmp/miloom-duo-cashflow-glass-20261027.hDN1lp/.

Changed ZifrSheetCard.swift, PortfolioTransactionCenterView.swift and these notes
on codex/duo-evaluation after 580d9a22; local/uncommitted/unpushed. Original iPhone
source/installed build, project/package hashes and global Xcode 26.4 retained.
Canonical non-coordination fingerprint unchanged. No merge, deployment, upload,
archive, backend changes or real-phone install.

## 2026-10-27: match cash-flow glass to Search

Follow-up replaces the pane's untinted clear glass with the entity Search bar's
exact glass settings: .clear.tint(zifrTabBarFill.opacity(0.28)).interactive(),
same 1.5-point gold gradient outline and black 0.4-opacity shadow (radius 6,
x 0/y 3). Pane keeps its rounded rectangular shape. Only usesClearGlass callers
receive the shadow; only embedded cash flow opts in and enables the outline.
Existing uncommitted header/gray-box removal is preserved. Default iPhone sheet
styling and Search itself are unchanged.

Xcode 26.4 normal Debug simulator build and Xcode 27.1 explicit sample preview
build passed; whitespace check passed. Visually compared pane and Search together
in partial landscape with Studio's sample data; tint/edge/shadow now match.
Evidence: /private/tmp/miloom-duo-cashflow-searchglass-20261027.WI9N0w/.
No new XCTest, normal-27.1 build, authenticated flow, scrolling or physical-device
performance acceptance in this follow-up. Project/package hashes, global Xcode
26.4 and canonical non-coordination fingerprint unchanged. Same two Swift files
and notes remain local/uncommitted/unpushed on codex/duo-evaluation. No deployment,
backend mutation, data write or real-phone install.

## 2026-10-27: date glass and cash-flow colors

Duo embedded month picker opts into Search's clear glass tint/interaction/shadow
without adding the gold outline. Its default path remains untinted as before.
Embedded net cash-flow amounts are white for either sign, Money In uses money
green #85BB65 and Money Out uses system red. Spending by Category and Tax
Opportunities use darker green #0D4635, including no-activity/empty tax actions.
TaxOpportunitiesButton accepts an optional backgroundColor defaulting to the
original zifrBG; only embedded cash flow overrides it. Loading/data/actions and
legacy iPhone styling stay unchanged. Earlier pending clear-glass edits retained.

Xcode 26.4 normal Debug simulator build and Xcode 27.1 explicit sample preview
build passed; whitespace passed. Synthetic UI checked positive Studio and negative
Personal cash flow, requested amount/button colors, outline-free tinted picker
and month menu opening/selection. Preview left at Personal/October partial
landscape. Evidence: /private/tmp/miloom-duo-cashflow-colors-20261027.Wz2VTX/.
No fresh XCTest, normal-27.1 build, authenticated flow, scrolling or physical-device
performance acceptance. Previous simulator scrolling gap remains. No sync/data
writes. Project/package hashes, global Xcode 26.4 and canonical non-coordination
fingerprint unchanged. New edits in PortfolioTransactionCenterView.swift and
TaxOpportunitiesView.swift plus notes; earlier ZifrSheetCard.swift pending work
preserved. Local/uncommitted/unpushed on codex/duo-evaluation; no merge/deployment,
backend change or real-phone install.

## 2026-10-27: gold net cash flow and white metrics

Duo embedded net cash-flow digits now use zifrGold (#C1AA78), matching the
Cash-Flow Insights header for every sign. Money In and Money Out digits are both
white. Supersedes the immediately preceding green/red/white amount choices;
all other pending visual work retained. Original iPhone amount colors unchanged.
Xcode 27.1 sample preview build and whitespace check passed; visually verified
header/net gold and white income/outflow in partial landscape. Evidence:
/private/tmp/miloom-duo-cashflow-gold-20261027.2tnW1f/.
No new XCTest, Xcode 26.4/normal-27.1 build, authenticated or performance acceptance
in this three-line follow-up. Previous scrolling gap retained. Only
PortfolioTransactionCenterView.swift and notes edited this pass. Canonical source
fingerprint/global Xcode unchanged; local/uncommitted/unpushed, no phone install,
backend/data mutation or deployment.

## 2026-10-27: expanded landscape report workspace

Fully open landscape now uses the same selected-entity cash-flow pane/geometry as
partially open landscape (Duo + expanded + landscape). Entity report menu routes
Financial Report and Subscription Report into this left area, replacing cash
flow while leaving right-side entity tabs/content/Search usable. Back to Cash
Flow restores the existing mounted transaction view and its analysis/filter state.
Report selection is local view state; no new requests, generators, sync logic or
data changes. Other poses/non-Duo devices retain the existing modal route.

FinancialReceiptView and SubscriptionReceiptView gain isEmbedded default false.
Embedded variants reuse the original receipt/scroll content with clear backing;
Financial omits nested navigation/Close toolbar, Subscription omits sheet-only
presentation and limits light appearance to its own subtree. Default modal
navigation, dark backing and sheet settings are retained. CompanyDetailView's
private pane names/identifier now reflect general report content. No dashboard,
permissions, report calculations, project/signing/package or backend changes.

Verification: normal Debug simulator builds on Xcode 26.4/27.1 and explicit 27.1
sample preview passed. Three existing tests passed (subscription receipt compact/
accessible rendering, selected-entity inferred cash-flow scope, default portfolio/
other-entity duplicate isolation). Whitespace passed. Synthetic UI checked fully
open cash flow, both reports inline with right tabs/Search present, changing the
right tab while a report stayed visible, subscription disclosure, report retention
through partial opening, Back to Cash Flow, closed Financial Report retaining
its original overlay/Close, and expanded portrait without an inline pane. Preview
returned to fully open landscape cash flow. Evidence/logs:
/private/tmp/miloom-duo-report-workspace-20261027.fH2uyb/.

Manual scrolling/performance acceptance remains: drag and wheel input did not
move the embedded subscription report in the fully open simulator. No independent
scrolling, physical-device frame rate or authenticated-flow acceptance claimed;
previous partial-open input limitation also remains. No data writes/sync activation.
Three Swift files plus these notes changed after 6d78816c on codex/duo-evaluation;
local/uncommitted/unpushed. Original iPhone source/installed build, project/package
hashes, global Xcode 26.4 and canonical non-coordination fingerprint unchanged.
No merge, deployment, archive, upload, backend mutation or real-phone install.

## 2026-10-27: stacked portrait workspace

Open and partially open Duo portrait now stack the entity workspace above a
separate Cash Flow / Transactions / Reports section. Default placement is about
60/40 after the fixed bottom toolbar/divider; a provided horizontal reserved fold
anchors the initial divider. Drag the gold grip to resize, double tap it to reset,
or use Expand/Compact/Restore. Resizing clamps bounds and preserves at least
180 points for the entity header/tabs when space allows. The adjustable handle
announces its percentage. A short 16-point/opacity reveal and button resize
animation honor Reduce Motion. Search and existing bottom controls remain fixed
below both panes. Landscape uses its existing left/right geometry; closed/non-Duo
retain their original page/footer and modal routes.

One PortfolioTransactionCenterView remains mounted. Portrait Cash Flow shows
only existing insights; Transactions shows the existing list/search/account/flow/
posting filters plus its month picker. Selected month filters this dedicated
transaction list only and survives section changes; legacy/landscape lists retain
original behavior. Reports has two existing receipt choices; selecting from the
entity header activates Reports below automatically. Report selection survives
fold/rotation; landscape keeps Back to Cash Flow. No additional data load,
generator, sync, polling or duplicate analysis instance added. No backend,
permissions, project/signing/package, dashboard or report calculation changes.

Final normal Debug simulator builds on Xcode 26.4/27.1 and explicit 27.1 sample
preview passed. Seven focused tests passed: three new portrait/resize/fold/closed/
landscape geometry checks, new transaction-month check, two existing selected/
legacy scope checks and subscription rendering. Whitespace passed. Synthetic UI
verified three section buttons, dedicated transaction rows and September filtering,
month retention on Cash Flow return, report chooser, both inline receipts,
header-menu routing, expanded header/tab visibility, drag resize (74% to 59%),
compact (18%)/restore (40%), both portrait poses, closed controls/original All
Transactions entry, and landscape report/right toolbar retention. Preview left
in open portrait, Studio/October Cash Flow/default split. Evidence/logs:
/private/tmp/miloom-duo-portrait-workspace-20261027.YRRh63/.

Remaining acceptance: automated report-content dragging still did not scroll in
portrait (divider dragging did work). Independent scrolling, physical-device
performance/frame rate, runtime Reduce Motion and authenticated flows remain
unverified; earlier scrolling gap retained. No sync activation or saved data.
Changed CompanyDetailView.swift, PortfolioTransactionCenterView.swift, two test
files and these notes after bebcff2c on codex/duo-evaluation; local/uncommitted/
unpushed. Original iPhone source/installed build, project/package hashes, global
Xcode 26.4 and canonical non-coordination fingerprint unchanged. No merge,
deployment, archive, upload, backend mutation or real-phone install.

## 2026-10-28: portrait side toolbar matching landscape

At owner request, the shared DuoSideToolbar adds an app-level trailing rail for
open/partial portrait. It reuses each page's existing Share/Plus near the top and
entity switcher/Admin near the bottom (dashboard/Admin retain their existing
page-specific items). A 52-point lane with padding/spacing reserves content width;
the rail does not overlay the portrait panes. Existing usesSideToolbar bindings
remove duplicate header Share and bottom Admin/entity/Plus controls, leaving
Search/Gemini at the bottom. The measured Admin anchor preserves footer alignment.
Native toolbar creation/placements are still used only for closed and expanded
landscape; no forced system portrait-bar placement. Admin preserves its original
portrait custom Back/header rather than introducing an empty native navigation
bar. Earlier uncommitted stacked portrait/transaction/report work retained.

Final normal Debug simulator builds on Xcode 26.4/27.1 and explicit 27.1 sample
preview passed; whitespace passed. Synthetic UI verified open/partial portrait,
all entity tabs with correct Add actions, one Share menu with all five existing
scopes, entity switching, Admin rail/header, dashboard rail, New Entity opening
and dismissal without saving, and native closed dashboard/entity plus landscape
placement. Search/Gemini remain visible at the bottom. Preview left in partial
portrait Personal/Cash Flow. Evidence/logs:
/private/tmp/miloom-duo-portrait-toolbar-20261028.Seyl6B/.

No new XCTest for this layout-only follow-up; previous seven portrait tests are
historical, not rerun. No invitations, settings changes, saved data, Gemini
activation, backend mutation or real-phone install. Existing report-scrolling,
authenticated-flow and physical-device/performance gaps remain unaccepted.
Today's edits: DashboardView.swift shared modifier, AdminSettingsView.swift
portrait nav visibility, CompanyDetailView.swift comment and these notes.
Earlier dirty files preserved. Local/uncommitted/unpushed on codex/duo-evaluation;
no merge, deployment, upload or archive. Project/package hashes and global Xcode
26.4 retained. No canonical product files written; its non-coordination diff
fingerprint changed during this pass from 222b8c8e7d720af61656d78a9498c0e9f9bba2b8d657006c7749cc35027157c0
to 623f2dae655e1c4db8d66f250cd9d093134d4f5e479f18355c6b8f6a61efecd3;
that separate work was preserved, not investigated or reverted.

## 2026-10-28 — Duo portrait holographic reports at the fold

- Implemented only in `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, on top of the pending portrait workspace/toolbar work after `bebcff2c`. Open/partially open portrait now has Financial Report, Subscriptions Report and Transactions tabs immediately above the physical division; content starts below it. Reserved division bounds take priority, with the window midpoint converted to local coordinates for fully open fallback. This supersedes the movable 60/40 divider and expand/compact controls in portrait. Existing top entity content, side rail and bottom Search/Gemini remain.
- Added portrait-only transparent report presentations with gold totals, cyan/coral sector charts and selectable legends. Subscription type selection filters charges; Monthly/Annual equivalents and a currency menu reuse SubscriptionReceiptSummary without mixing currencies or supplemental charge cycles/sources. Account/service disclosures retain existing details. Financial totals retain the original financial receipt policy. Transactions uses the retained entity-scoped analysis and includes cash flow, existing filters, rows and actions. No polling, network generation, timer/particle loop or dependency added; short selection/section animations honor Reduce Motion. Existing closed and landscape presentation paths stay at their default styles.
- New `DuoHolographicReports.swift` is explicitly in the Zifr target; project changes are four source-membership lines only. Other source edits this pass: CompanyDetailView.swift, FinancialReceiptView.swift, SubscriptionReceiptView.swift, PortfolioTransactionCenterView.swift, RootView.swift (optional synthetic `-duoReportFixtures` argument exclusively inside MILOOM_LAYOUT_PREVIEW), and ExecutiveBriefingTests.swift. All seven previously dirty files were preserved. No canonical product edits; its non-coordination diff fingerprint remained `d4882cf4d06a4125742d5d1fe79697588765339164e84e8353bce666b299e218`. Package pins unchanged; global command-line Xcode remains 26.4.
- Verification: 44 selected XCTest cases passed (37 ExecutiveBriefingTests and 7 ledger/entity-scope/cash-flow regressions), including new fixed-fold bounds and signed/invalid sector-selection tests. An initial Xcode 26.4 type-check timeout in the new aggregation expression was fixed by simplifying it. Final normal Xcode 26.4 and 27.1 simulator builds and sample-only preview build all succeeded; project plist and whitespace checks passed. Tests preceded final spacing/empty-label polish; final builds include that polish. Synthetic UI inspected open/partial portrait, chart/legend selection, USD/EUR separation, monthly USD124 versus annual USD1488, Bills filtering, account-detail expansion, Transactions cash-flow values/records, unchanged landscape cash flow/paper receipt and closed page. Optional fixture data was removed from the running preview by relaunching without the argument; no real data saved, sharing sent, Gemini activated or real phone installed.
- Limits: simulator touch scrolling was inconsistent (financial detail content visibly advanced after expansion, but repeated Transactions drag/wheel attempts did not move its viewport). Full manual touch/scrolling, large-data performance, VoiceOver/Dynamic Type, authenticated actions and physical-device animation acceptance remain unverified; build and chart taps do not establish a completed real-data flow. Preview remains running; user interacted with it during final checks, so their final navigation state was left alone. Logs, xcresult and screenshots: `/private/tmp/miloom-duo-holographic-20261028.SLtGI9/`; self-contained comparison `board.html`/`board.png` uses synthetic data. Local/uncommitted/unpushed; no merge, archive, upload, deployment or release.

## 2026-10-28 — Duo portrait report slider below the hinge

- Implemented in `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, retaining all pending Duo work. This follow-up supersedes the previous above-hinge report tab placement: open/partial portrait now reserves the upper pane to the fold, places the 56-point report selector 8 points below the division, then starts report content 8 points below the selector. Reuses ControlCenterTabSelector's existing glass sliding lens, typography, icons, tap/drag behavior and haptics with optional labels/icons and standalone background. Main selector defaults remain unchanged; the portrait report instance respects Reduce Motion and wraps long labels.
- Upper portrait header top padding reduced from 8 to 0; empty navigation chrome hidden only in this layout, and optional EntityHomeView compact spacing moves the upper content 16 points closer to its main selector while retaining the mask and selector positions. Other layouts use the original spacing. Today's source/test changes: CompanyDetailView.swift, ControlCenterTabSelector.swift, EntityHomeView.swift, ExecutiveBriefingTests.swift. All earlier dirty files preserved. No canonical product files edited; non-coordination diff fingerprint remained `d4882cf4d06a4125742d5d1fe79697588765339164e84e8353bce666b299e218`. Project/package settings and global Xcode 26.4 default unchanged.
- Verification: three focused geometry/isolation tests passed with zero failures (below-fold placement, reserved-fold/tiny-window bounds, closed/landscape preservation). Final normal Xcode 26.4 and 27.1 simulator builds and Duo sample preview build succeeded; whitespace passed. Tests preceded the final content-spacing-only addition; final builds include it. Sample UI verified open/partial portrait placement, report tab taps, horizontal slider drag from Transactions to Subscriptions, independent main/report selection, empty subscriptions and Transactions cash flow. Final upper Vault layout fits all six category buttons above the hinge. Closed and landscape retained existing layouts/native side controls after rotation/folding. Preview left in partial portrait, Northstar Studio/Vault with Financial Report selected. Evidence: `/private/tmp/miloom-duo-tabs-below-fold-20261028.U2N9Lj/`.
- Remaining manual scrolling, physical-device motion/performance, large-data, Dynamic Type/VoiceOver and authenticated-flow acceptance gaps from the prior handoff remain open; no new claim of those passes. No saved real data, sharing, Gemini activation, real-phone install, commit, push, merge, archive, upload, deployment or release. Changes remain local and uncommitted.


## 2026-10-28 — Duo portrait full-height pages and report sheets

- Implemented at owner request in `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`. Supersedes the portrait lower report pane and selector: open/partial portrait now uses the full page height. Financial, Services and Vault each have transaction and receipt buttons in the header. Transactions opens the selected entity's existing cash flow and transaction content; Reports opens Financial/Subscriptions selection with the initial choice appropriate to the page. Sheets use native clear Liquid Glass with the existing MILOOM tint and a dark green (#0D4635) content card matching Spending by Category. Landscape retains its inline panel; closed/iPhone routes retain existing presentation.
- Current-task source/test edits are CompanyDetailView.swift, DuoHolographicReports.swift and ExecutiveBriefingTests.swift; prior pending Duo work preserved. Initial report selection on the first Services presentation was corrected using the sheet item's report value and local picker state. No new fetching, polling or dependencies. No canonical product writes: the canonical non-coordination diff fingerprint changed concurrently from `a6c853dd45aeeb2b145f25deb930a49307b67a4c402c0c87a487a7fac07c1d02` to `3d95f9293c46bb041fd9bca094a59b8c32792a71ccd6af93ecda50f23def1689`; those changes were preserved. Global Xcode default remains `/Applications/Xcode.app/Contents/Developer` (26.4); project/package settings untouched by this task.
- Verification: five focused geometry/entity-scope tests passed, zero failures. Final normal Xcode 26.4 and 27.1 simulator builds and sample preview build succeeded; whitespace check passed. Tests preceded final glass and initial-report-state refinements; final builds include both. Simulator checks covered full-height open/partial portrait, both header icons on all three pages, both report choices, correct first Services report, transaction cash flow, and portrait-sheet dismissal on rotation with the existing landscape pane restored. Closed Services retained its existing layout. Final preview is partial portrait, Northstar Studio/Vault, Transactions sheet open. Evidence: `/private/tmp/miloom-duo-portrait-sheets-20261028.B8hKsW/`; final screenshots include `partial-transactions-final.png`, `services-report-verified.png`, `open-portrait-full-page.png` and `closed-regression.png`.
- Remaining acceptance: simulator transaction vertical drag still did not visibly advance the viewport; manual touch scrolling, physical-device smoothness, large-data performance, VoiceOver/Dynamic Type and authenticated actions remain unverified. No real-data mutation, sharing/Gemini activation, real-phone installation, commit, push, merge, archive, upload, deployment or release. Changes remain local and uncommitted; only the dedicated Duo sample simulator was installed/launched.


## 2026-10-28 — Duo portrait undimmed clear-glass sheets

- In the separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, corrected the grey/opaque report and transaction sheet appearance. Apple's full-height system sheets become opaque (WWDC25 session 323); these expanded-portrait presentations now use a floating sheet in the page's rendering hierarchy with native untinted `.glassEffect(.clear)`, no dimming scrim, and the retained #0D4635 content card. Added explicit close/outside-tap/header-drag dismissal, Reduce Motion handling, modal accessibility traits and initial title focus. Background controls are blocked while it is open. Rotation/folding dismisses it. Landscape and closed presentation routes remain intact.
- Current-task product edits only: CompanyDetailView.swift and DuoHolographicReports.swift. Prior dirty work preserved; no project/package or canonical product edits. Canonical non-coordination fingerprint changed concurrently from `a6186fc2346c97825effae64cf48b266b9bbbe5ab0109f1fd11307a8663fdc8c` to `4b92303f25930654dba16076919a3d3d5b38a2620ee09f79d2136ecc20e0bcd4`; concurrent work was preserved. Global default is still Xcode 26.4; explicit Xcode 27.1 used for Duo.
- Verification: normal simulator builds passed with Xcode 26.4 and 27.1, and the synthetic Duo preview build passed; whitespace passed. UI verified visible underlying content through glass, undimmed outside area, Transactions and Reports, both report choices, close button, outside tap, header swipe-down, full/partial portrait, rotation dismissal/restored landscape cash-flow pane, and existing closed Financial header. No new tests added or rerun for this presentation-only correction. Evidence: `/private/tmp/miloom-duo-clear-sheet-20261028.33Odc4/`, including build logs, before copies/current-task diffs, `transactions-clear-final.png`, `reports-clear.png`, and `open-portrait-reports.png`. Dedicated sample preview left partial portrait/Financial with Transactions open.
- Existing simulator transaction vertical-scroll acceptance remains unresolved: drag showed its scroll indicator but no visible viewport advance. Physical-device smoothness, large-data, VoiceOver/Dynamic Type and authenticated-flow acceptance remain open. No real-data mutation, sharing/Gemini activation, real-phone install, commit, push, merge, archive, deployment or release. Local/uncommitted only.


## 2026-10-28 — Populated Duo sample preview

- Added owner-requested fictional content in the separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`: 3 banks, 4 cards (3 associated with banks and 1 standalone), 4 services with 8 subservices, and 6 documents across Northstar Studio and Personal. Banks include checking/savings balances; services reference sample payment cards. Documents span Legal, Taxes, Receipts, Estate, Identity and Other, with visibly fictional PDF pages generated in the simulator temporary directory for local preview.
- Changed only the existing `RootView.swift` simulator-only `DEBUG && targetEnvironment(simulator) && MILOOM_LAYOUT_PREVIEW` block this task. Default sample content now appears without a launch flag; the older optional report-fixture argument appends its QA examples. Normal app entry point/source outside that block unchanged, no fixture persistence/upload/auth loader added. Existing pending Duo work preserved. Canonical non-coordination fingerprint stayed `43dd6b50f3768e5e8d09bbae2c1c657cc7dbcc36195493a936f57b717f37eeac`; no canonical product changes. Global Xcode 26.4 default unchanged.
- Verification: Xcode 27.1 synthetic preview and normal Xcode 26.4 simulator builds succeeded; whitespace and guarded-source isolation checks passed. Installed/launched only the dedicated Duo evaluation simulator. Visually checked the Financial banks/card counts and standalone card, Services with expanded Office Essentials subservices, Vault's four Studio documents, and opened/closed the local Operating Agreement PDF. Sample preview remains on Northstar Studio/Vault. Evidence: `/private/tmp/miloom-duo-filled-preview-20261028.qUcpRW/` (build logs, before/diff, financial.png, services.png, vault.png, sample-pdf.png).
- No new tests for reversible preview data; no real-data writes, real banking connection, sharing, purchase, physical-phone install, commit, push, merge or deployment. Earlier manual scrolling/performance/accessibility/authenticated-flow acceptance gaps remain open. Local/uncommitted only.


## 2026-10-28 — Duo portrait filing workspace and two-column dashboard

- Implemented owner-approved follow-up in `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, only for expanded Duo portrait (open/partial). Financial, Services and Vault now occupy a narrower full-height right column. The column reuses the observed landscape entity-pane width, clamped to fit beside the tab rail; a cold portrait launch uses a viewport-based fitted estimate until the first landscape measurement. Landscape width is retained in scene state through rotation. Left clear-glass Financial/Subscriptions/Transactions filing tabs select on-demand files that slide from left to right over the main column, with no dimming scrim. Retains clear glass surround, dark green content, header shortcuts, close/outside dismissal, and adds left-swipe header dismissal. Filing tabs remain accessible while a file is open; Reduce Motion is respected.
- Expanded portrait dashboard uses two equal-width entity cards per row across the available dashboard pane, retaining the existing briefing below. Compact card avatar/title sizing is opt-in only for that grid; long entity names wrap. Empty/tutorial fallback stays on existing UI. Closed/iPhone and landscape rendering use existing paths. Current-task files: CompanyDetailView.swift, DuoHolographicReports.swift, DashboardView.swift, CompanyCardView.swift, RootView.swift (scene sizing state/observer), ExecutiveBriefingTests.swift. All prior dirty work and sample fixtures preserved. Canonical product diff fingerprint stayed `43dd6b50f3768e5e8d09bbae2c1c657cc7dbcc36195493a936f57b717f37eeac`; project/packages and global Xcode 26.4 default unchanged.
- Verification: final five focused tests passed, zero failures, with Xcode 26.4 (portrait reference-width/right alignment, bounded small-window math, legacy closed/landscape frames, selected-entity transaction/cash-flow scope). Final normal Xcode 27.1 and synthetic preview builds succeeded; whitespace passed. Simulator UI checked full/partial portrait, all three filing choices and direct switching with selected accessibility traits, Financial/Services/Vault main pages, left-swipe close, rotation dismissal/restored landscape panel, retained measured width on return, two-card dashboard row with readable full names, and closed single-column dashboard. Preview left partial portrait on dashboard. Evidence: `/private/tmp/miloom-duo-portrait-files-20261028.zyArFE/`, including before/diff files, tests26-final.log, normal27-build.log, preview-final.log, portrait-files-final.png, transactions-file-final.png, dashboard-grid-final.png and regression screenshots.
- No new data-fetch engine or timers. Existing vertical-scroll/manual performance, physical-device, large-data, Dynamic Type/VoiceOver and authenticated-flow acceptance gaps remain open; no claim of those passes. No real-data mutation, physical-phone install, sharing/Gemini activation, commit, push, merge or deployment. Local/uncommitted only; dedicated Duo synthetic simulator installation only.


## 2026-10-28 — Duo portrait attached binder dividers

- Implemented owner-requested refinement in `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`. Expanded Duo portrait only: narrow vertical clear-glass binder dividers now rest flush against the left screen edge. Tapping or pulling a divider moves it to the right with a full-width report attached behind it. A shared progress value and persistent divider identity drive both positions, keeping their trailing edges aligned throughout the motion; the report covers the other dividers and the side toolbar. No dimming scrim. Tap the attached divider again or drag it left to close; VoiceOver escape remains available. Animation completions are generation-guarded and cancelled on pose changes; Reduce Motion respected.
- Removed the report's outer title/header, grabber and X button; the title is now inside its dark-green content card, surrounded by native clear Liquid Glass. Main portrait column sizing, dashboard two-card grid, sample fixtures, landscape and closed/iPhone routes retained. Current-task source/tests only: CompanyDetailView.swift, DuoHolographicReports.swift, ExecutiveBriefingTests.swift. Prior dirty work preserved. Canonical non-coordination fingerprint remained `43dd6b50f3768e5e8d09bbae2c1c657cc7dbcc36195493a936f57b717f37eeac`; no project/package/global-toolchain change.
- Verification: seven focused tests passed, zero failures, with Xcode 26.4: full-width attachment at intermediate slide fractions, clamped progress and divider bounds, portrait page sizing/edge placement, closed/landscape preservation and selected-entity transaction scope. Xcode 27.1 normal simulator and sample preview builds succeeded; whitespace passed. Simulator UI verified flush-left divider styling, Financial tap-open, attached-tab drag-close, Subscriptions drag-open and tap-close, full-width Transactions, no X/outer title, in-card titles, full/partial portrait, rotation dismissing the drawer/restoring the existing landscape cash-flow pane, and closed mode without binder controls. Dedicated synthetic preview left partial portrait with Financial Report open. Evidence: `/private/tmp/miloom-duo-binder-20261028.myw6nV/` (before/diffs, tests26.log, normal27-build.log, preview-build.log, dividers-resting.png, financial-open.png, partial-transactions.png, binder-final.png).
- Existing report vertical-scrolling, physical-device motion/performance, large-data, Dynamic Type/VoiceOver and authenticated-flow acceptance gaps remain open; no claim of those passes. No real-data mutation, real-phone installation, sharing/Gemini activation, commit, push, merge or deployment. Local/uncommitted, installed only on the dedicated Duo evaluation simulator.


## 2026-10-28 — Centered Duo portrait content and 80-percent drawer

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, centered the existing landscape-sized entity column within its available content area for open/partial Duo portrait only. Reports now slide from the left to 80% of the display content width. Divider tabs remain stationary at the left edge and are covered by the open drawer; restored a 44-point X close control at the card's top right. Titles remain in the green card. Both glass sheet and card have square leading corners and rounded trailing corners. Retains no-scrim native clear glass, existing data/actions, and Reduce Motion handling. Dashboard grid and closed/landscape/iPhone rendering paths untouched.
- Current-task edits only CompanyDetailView.swift, DuoHolographicReports.swift and ExecutiveBriefingTests.swift; prior pending work preserved. Verification: five focused Xcode 26.4 tests passed (centering, drawer width/stationary dividers, bounds and legacy layout isolation); Xcode 27.1 sample preview build succeeded; whitespace passed. UI verified centered content, square-left 80% drawer, title/X placement, X closing and dividers returning, and open/partial portrait. Preview left in partial portrait with Transactions open. Evidence `/private/tmp/miloom-duo-drawer80-20261028/` contains before/diffs, build/test logs and centered.png, drawer.png, partial-final.png.
- Earlier vertical-scroll/performance, physical-device, large-data, accessibility and authenticated-flow acceptance gaps remain open. No canonical product edits, real-data writes, real-phone install, commit, push, merge or deployment. Only dedicated synthetic Duo simulator installed. Changes remain local/uncommitted.


## 2026-10-28 — Duo portrait 90-percent drawer and inset card

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, shifted the expanded-portrait main column 44 points right of its previous available-area center, clamped to fit. Increased the left-origin drawer to 90% width; dividers remain stationary. Inner dark-green card now has 20-point horizontal/bottom spacing and all rounded corners. Title stays inside card; X moved to a glass-only row above it. Added a transparent outside-tap dismissal target; no dimming backdrop. Scope remains open/partial Duo portrait, retaining square outer leading glass corners and all other layouts/dashboard behavior.
- Changed only CompanyDetailView.swift, DuoHolographicReports.swift and ExecutiveBriefingTests.swift this task; earlier pending work preserved. Five focused Xcode 26.4 tests passed, zero failures (90% width, stationary tab/bounds, right-of-center placement and legacy layout geometry). Xcode 27.1 sample preview build succeeded; whitespace passed. Native preview checked card spacing/corners, X on glass, outside-tap closing and X closing, main-content placement, partial and fully open portrait. Preview left fully open portrait, Financial Report open. Evidence `/private/tmp/miloom-duo-drawer90-20261028/`: before/diffs, preview.log, tests26.log, drawer.png, main-content.png, full-open.png.
- Earlier scrolling/performance, physical-device, large-data, accessibility and authenticated-flow acceptance gaps remain open. No real-data mutation, canonical product edits, real-phone install, commit, push, merge or deployment. Installed only on the dedicated synthetic Duo simulator; local/uncommitted.


## 2026-10-28 — Duo portrait wider content and glass pull handle

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, increased expanded-portrait entity-column target width by 20%, bounded by available width, retaining its right-of-center placement. Removed the portrait-only -16-point content offset so picker-to-card spacing uses the same default as landscape. Replaced X with a small vertical handle midway down the right glass margin; it supports a leftward drag with the sheet following the gesture, tap closure, and an accessible close label/escape. Preserved the 48-point top glass margin and applied 48 points to right/bottom; left card inset remains 20 points and all inner corners rounded. Drawer remains 90% width with no dimming backdrop and outside-tap closure. Scope only open/partial Duo portrait; other rendering paths and dashboard retained.
- Current-task edits only CompanyDetailView.swift, DuoHolographicReports.swift and ExecutiveBriefingTests.swift; existing dirty work preserved. Five focused Xcode 26.4 tests passed, zero failures (widened placement, 90% drawer/stationary tabs, bounds and legacy layout isolation); Xcode 27.1 preview build succeeded; whitespace passed. Simulator verified wider content, landscape-default gap, matching glass margins, no X, visible handle, successful drag-to-close and retained outside-tap closing in partial portrait. Preview left partial portrait on Northstar Studio/Financial main page. Evidence `/private/tmp/miloom-duo-handle-20261028/`: before/diffs, preview.log, tests26.log, main.png and handle.png.
- Earlier vertical-scroll, physical-device smoothness, large-data, accessibility and authenticated-flow acceptance gaps remain open. No real-data mutation, canonical product edits, real-phone install, commit, push, merge or deployment; dedicated synthetic Duo simulator only. Local/uncommitted.


## 2026-10-28 — Duo portrait resisted rightward report pull

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, added rightward overscroll from the report's glass handle. The inner card shifts right and outer glass extends while the leading edge stays anchored, exposing more left glass. Resistance scales movement to 35% of the pull, capped at 48 points and the available final 10% of the display. Gentle release springs back; a pull over 64 points or a deliberate right flick closes the sheet. Existing leftward, tap and outside-tap dismissal retained; Reduce Motion respected. Applies only to existing expanded Duo portrait report component.
- Current-task files: DuoHolographicReports.swift and ExecutiveBriefingTests.swift, after committed base 811dbe33. Fixed a tap/drag conflict found in native QA by using mutually exclusive drag/tap recognition. Five focused Xcode 26.4 tests passed (resistance/bounds, gentle/deliberate thresholds and retained layout isolation); these preceded the final gesture-recognition-only fix. Final Xcode 27.1 sample preview build passed; whitespace passed. Native final UI confirmed small right pull leaves the report open and stronger right pull closes it. Preview left portrait with Financial Report open. Evidence `/private/tmp/miloom-duo-pull-20261028/`: before/diffs, tests26.log, preview-final.log and final.png.
- Existing physical-device smoothness, vertical-scroll, large-data, accessibility and authenticated-flow acceptance limits remain open; no claim of those passes. No canonical product edits, real-data mutation, real-phone installation, commit, push, merge or deployment. Dedicated synthetic Duo simulator only; changes local/uncommitted.


## 2026-10-28 — Duo portrait dashboard briefing file

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, changed expanded Duo portrait dashboard to the control-panel sizing/placement helper. Entity cards now use that same column width and position, one card per row, superseding the earlier two-column portrait grid. Existing full-width dashboard search/footer and header retained. Moved the lower inline briefing into a flush-left Executive Briefing divider opening the shared 90% clear-glass drawer/card and pull handle. Header receipt button also opens this drawer in portrait. Existing briefing data/content, profile/month controls and Pro gates retained; no report-engine changes. Navigation away, rotation and folding dismiss the portrait drawer. Landscape and closed/non-Duo rendering retain existing routes.
- Current-task product edits only DashboardView.swift and DuoHolographicReports.swift; prior uncommitted pull-gesture/test work preserved. Xcode 27.1 sample preview and regular Xcode 26.4 simulator builds passed; whitespace passed. No new/repeated unit tests for this UI reuse. Native checks: matching card column width, single-card rows, unchanged search width, left tab tap/drag opening, header-button opening, existing briefing display, handle/outside dismissal, open and partial portrait, rotation returning to the existing landscape briefing and closed layout without a briefing divider. Preview restored partial portrait on dashboard. Evidence `/private/tmp/miloom-duo-dashboard-file-20261028/`: before/diffs, preview.log, normal26.log, dashboard.png and briefing.png.
- Existing large-data, physical-device smoothness, vertical-scrolling, accessibility and authenticated-flow acceptance gaps remain open. No canonical product edits, production-data mutation, real-phone installation, commit, push, merge or deployment. Dedicated synthetic Duo simulator only; changes local/uncommitted.


## 2026-10-28 — Duo portrait dashboard refinements

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, removed expanded-portrait dashboard's top briefing button and bell background while retaining its hit area/unread badge. Search plus Gemini section now matches the entity-card column width and position. Lowered the left briefing divider to start slightly below the first card; aligned dashboard portrait side-toolbar controls to the Wi-Fi indicator center. Executive Briefing receipt now sits directly on clear glass, without the green wrapper or duplicate outer title; other report cards retain their backgrounds/titles. Scope is open/partial Duo portrait dashboard; closed, landscape and current iPhone product checkout unchanged.
- Product files this task: DashboardView.swift and DuoHolographicReports.swift; earlier pending work preserved. Final Xcode 27.1 sample-preview and regular Xcode 26.4 simulator builds succeeded; whitespace check passed. Initial builds exposed an availability guard missing around the portrait window-center reader, fixed before both final builds. Native preview verified partial/open portrait positioning, removed header button/background, matching footer/card section, toolbar alignment, receipt directly over translucent glass and handle closure. No new unit tests for these UI refinements. Evidence `/private/tmp/miloom-duo-dashboard-refine-20261028/`: before/diffs, preview-final.log, normal26-final.log, dashboard.png, dashboard-open.png, briefing.png. Preview left fully open portrait dashboard.
- Existing physical-device performance, large-data, vertical-scroll, accessibility and authenticated-flow acceptance gaps remain open. Dedicated synthetic Duo simulator only; no real-phone install, production-data mutation, canonical product edits, commit, push, merge or deployment. Changes local/uncommitted.


## 2026-10-28 — Shared Duo portrait toolbar alignment

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, promoted the dashboard's verified 22-point portrait toolbar trailing inset to the shared DuoSideToolbar, removing the per-dashboard override. Entity Financial/Services/Vault pages and Admin now use the same Wi-Fi center alignment. The branch applies only to expanded Duo portrait (open/partial); native closed/landscape toolbars are unchanged. Current-task product edit only DashboardView.swift; earlier dirty work preserved.
- Final Xcode 27.1 sample preview build succeeded, whitespace check passed. Installed/launched only on dedicated synthetic Duo simulator; visually verified entity toolbar alignment in open and partially open portrait. Shared component covers Services/Vault/Admin; those pages were not separately inspected this turn. Evidence `/private/tmp/miloom-duo-toolbar-align-20261028/`: before source, preview-final.log, open.png, partial.png. No unit tests for this spacing-only change.
- Local/uncommitted; no push, merge, deployment, real-data mutation, current-iPhone product edit or installation. Existing broader acceptance gaps remain open.


## 2026-10-28 — Duo portrait divider labels and gold icons

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, restyled MiloomDuoFilingTab: corresponding SF Symbol in existing gold, white REPORT text for report/briefing files, white TRANSACTIONS for transactions. Entire icon/text row retains vertical rotation, clear-glass divider shape, gestures and full descriptive accessibility names. Applies only to existing expanded Duo portrait dividers; other layouts and current iPhone product checkout unchanged. Product edit only DuoHolographicReports.swift.
- Xcode 27.1 sample preview build succeeded; whitespace passed. Installed only on dedicated fictional-data Duo simulator; visually checked financial/subscription/transaction dividers in partial portrait. Evidence `/private/tmp/miloom-duo-tab-labels-20261028/`: before source, preview.log, tabs.png. No unit tests for this visual-only change; broader accessibility/performance/authenticated-flow acceptance remains open. Local/uncommitted; no push, merge, deployment or real-phone installation.


## 2026-10-28 — Correct Duo dividers to stacked letters

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, replaced rotated labels with upright letters stacked vertically beneath the gold icon. REPORT remains white; TRANSACTIONS stacks similarly with font size fitted to the existing divider height. Financial and subscription report icons now directly reuse EntityHomeTab.financial.icon and .subscriptions.icon so they match the header picker. Full descriptive accessibility names and drawer gestures preserved. Open/partial Duo portrait only; other layouts/current iPhone build untouched. Product edits DuoHolographicReports.swift and CompanyDetailView.swift.
- Xcode 27.1 sample preview build and whitespace checks passed. Dedicated synthetic Duo simulator visually confirmed upright stacked labels and matching gold bank/services icons; screenshot `/private/tmp/miloom-duo-tab-labels-20261028/stacked.png`, build `stacked-build.log`. No new unit tests for this visual-only correction. Local/uncommitted; no push, merge, deployment, real-phone installation or data mutation. Existing broader acceptance gaps remain.


## 2026-10-28 — Duo portrait three-icon report bar

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, replaced entity-page left-edge Financial/Subscriptions/Transactions dividers with a horizontal clear-glass capsule containing the same three gold icons below the main Financial/Services/Vault picker. Buttons open the existing left-origin report drawers; close handle/outside dismissal retained. Added an optional report-controls slot to EntityHomeView with matching content clearance, supplied only for open/partial Duo portrait. Dashboard's single briefing divider retained (request concerned the three report tabs). Closed/landscape/current iPhone product paths unchanged; earlier pending divider edits preserved.
- Current-task product files CompanyDetailView.swift and EntityHomeView.swift. Xcode 27.1 sample preview build and whitespace passed. Dedicated synthetic simulator visually verified icon-bar placement and absent three left tabs; tapped all three icons and confirmed Financial Report, Subscriptions Report and Transactions/cash flow content, with successful handle closure. Evidence `/private/tmp/miloom-duo-report-iconbar-20261028/preview.log` and `iconbar.png`. No unit tests for UI-only rearrangement; existing broad acceptance gaps remain. Local/uncommitted; no push, merge, deployment, real-data mutation or current-iPhone install.


## 2026-10-28 — Duo portrait report bar moved left vertically

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, moved the report icon bar from below the main picker to the left edge with three gold icons stacked in one vertical clear-glass capsule (8-point leading, 16-point top inset). Report drawers and labels/actions retained. Removed the no-longer-needed EntityHomeView report-controls slot and extra content clearance, restoring its original picker/card spacing. Scope open/partial Duo portrait only; dashboard briefing divider, closed/landscape/current iPhone product paths unchanged. Current-task edits CompanyDetailView.swift and EntityHomeView.swift; earlier pending changes preserved.
- Xcode 27.1 sample preview build succeeded; whitespace passed. Dedicated synthetic simulator visually verified left vertical bar and restored card spacing, and confirmed Financial Report opens from the moved control. Other two button actions were verified before this placement-only change. Evidence `/private/tmp/miloom-duo-vertical-iconbar-20261028/preview.log` and `iconbar.png`. No new unit tests for visual rearrangement. Existing broader acceptance gaps remain. Local/uncommitted; no push, merge, deployment, data mutation or current-iPhone install.


## 2026-10-28 — Lower portrait report rail and match dashboard style

- In separate Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, moved entity report rail top to the measured header bottom (existing header geometry), replacing its fixed 16-point inset. Leading inset now 22 points, matching the portrait right toolbar trailing inset. Extracted shared MiloomDuoReportIconBar clear-glass capsule; dashboard Executive Briefing now uses this style with one gold receipt icon, 22-point leading inset and header-bottom placement, retaining its briefing drawer and drag-open behavior. Scope open/partial Duo portrait only. Current-task product files CompanyDetailView.swift and DuoHolographicReports.swift; earlier pending work preserved.
- Xcode 27.1 sample preview build succeeded; whitespace passed. Dedicated synthetic simulator visually verified lower entity rail at header bottom, margins and dashboard matching capsule; tapped dashboard icon and confirmed Executive Briefing receipt opens. Evidence `/private/tmp/miloom-duo-iconbar-spacing-20261028/preview.log`, `entity.png`, `dashboard.png`. No new unit tests for this layout/style change. Existing broader acceptance gaps remain. Local/uncommitted; no push, merge, deployment, real-data mutation or current-iPhone product edit/install.


## 2026-10-28 — Duo portrait dashboard inbox rail and logo alignment

- In isolated Duo checkout `/Users/yager/.codex/worktrees/duo-evaluation/cifr---entrepreneur's-company-manager`, branch `codex/duo-evaluation`, moved dashboard inbox bell below Executive Briefing inside the left clear-glass capsule. Reused the same inbox button/action/unread badge and descriptive accessibility value; portrait rail bell is gold with a 44-point target. Header bell retained outside expanded Duo portrait. MILOOM logo now uses the same placement helper as entity cards for horizontal centering in expanded portrait; other layouts retain the original center. Added optional additional-controls slot to briefing rail. Current-task product files DashboardView.swift and DuoHolographicReports.swift; earlier pending changes preserved.
- Xcode 27.1 sample preview build and whitespace checks passed. Dedicated synthetic simulator visually verified bell below briefing and logo centered over card column; tapped moved bell and confirmed INBOX/0 UNREAD empty state. Evidence `/private/tmp/miloom-duo-dashboard-bell-20261028/preview.log` and `dashboard.png`. No unit tests for this UI rearrangement. Existing broader acceptance gaps remain. Local/uncommitted; no push, merge, deployment, real-data mutation or current-iPhone product edit/install.
