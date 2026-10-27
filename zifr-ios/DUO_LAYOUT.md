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
