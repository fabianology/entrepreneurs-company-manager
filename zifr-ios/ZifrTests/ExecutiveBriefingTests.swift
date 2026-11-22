import XCTest
import SwiftUI
@testable import Zifr

final class ExecutiveBriefingTests: XCTestCase {
    #if compiler(>=6.4)
    func testDuoSideSwipeFollowsTheOpenPortraitAndCompactGutters() {
        let portraitPage = CGRect(x: 116, y: 0, width: 482, height: 850)
        let compactPage = CGRect(x: 0, y: 0, width: 392, height: 678)

        XCTAssertTrue(DuoSideSwipe.Layout.portrait.acceptsStart(x: 100, page: portraitPage, leftPanel: nil))
        XCTAssertFalse(DuoSideSwipe.Layout.portrait.acceptsStart(x: 117, page: portraitPage, leftPanel: nil))
        XCTAssertTrue(DuoSideSwipe.Layout.portrait.acceptsStart(x: 630, page: portraitPage, leftPanel: nil))
        XCTAssertTrue(DuoSideSwipe.Layout.compact.acceptsStart(x: 12, page: compactPage, leftPanel: nil))
        XCTAssertFalse(DuoSideSwipe.Layout.compact.acceptsStart(x: 22, page: compactPage, leftPanel: nil))
        let mirroredPage = CGRect(x: 74, y: 0, width: 392, height: 678)
        XCTAssertTrue(DuoSideSwipe.Layout.leftSplitPane.acceptsStart(x: 455, page: mirroredPage, leftPanel: nil))
        XCTAssertFalse(DuoSideSwipe.Layout.leftSplitPane.acceptsStart(x: 443, page: mirroredPage, leftPanel: nil))
    }

    func testDuoSideSwipeRespectsTheLandscapePaneAndDivider() {
        let page = CGRect(x: 450, y: 0, width: 410, height: 650)
        let panel = CGRect(x: 0, y: 0, width: 430, height: 650)
        let layout = DuoSideSwipe.Layout.split

        XCTAssertTrue(layout.acceptsStart(x: 12, page: page, leftPanel: panel))
        XCTAssertFalse(layout.acceptsStart(x: 25, page: page, leftPanel: panel))
        XCTAssertFalse(layout.acceptsStart(x: 440, page: page, leftPanel: panel))
        XCTAssertFalse(layout.acceptsStart(x: 12, page: page, leftPanel: nil))
        XCTAssertTrue(layout.acceptsStart(x: 902, page: page, leftPanel: panel))
    }

    func testDuoSideSwipeMovesOneTabAndStopsAtEitherEnd() {
        XCTAssertEqual(DuoSideSwipe.tab(from: 0, count: 3, distance: -180, velocity: -900), 1)
        XCTAssertEqual(DuoSideSwipe.tab(from: 1, count: 3, distance: -60, velocity: -100), 2)
        XCTAssertEqual(DuoSideSwipe.tab(from: 2, count: 3, distance: 60, velocity: 100), 1)
        XCTAssertNil(DuoSideSwipe.tab(from: 0, count: 3, distance: 60, velocity: 100))
        XCTAssertNil(DuoSideSwipe.tab(from: 2, count: 3, distance: -60, velocity: -100))
    }

    func testDuoSideSwipeDistinguishesFlicksFromSmallOrReversedDrags() {
        XCTAssertEqual(DuoSideSwipe.tab(from: 1, count: 3, distance: 15, velocity: 400), 0)
        XCTAssertEqual(DuoSideSwipe.tab(from: 1, count: 3, distance: -15, velocity: -400), 2)
        XCTAssertNil(DuoSideSwipe.tab(from: 1, count: 3, distance: 15, velocity: 150))
        XCTAssertNil(DuoSideSwipe.tab(from: 1, count: 3, distance: 15, velocity: -400))
        XCTAssertNil(DuoSideSwipe.tab(from: 1, count: 3, distance: 5, velocity: 600))
    }
    #endif

    func testDuoTabSliderGentleFlickMovesOneTabInEitherDirection() {
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 0, tabCount: 3, tabWidth: 135, translation: 18, predictedEndTranslation: 65
        ), 1)
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 2, tabCount: 3, tabWidth: 135, translation: -18, predictedEndTranslation: -65
        ), 1)
    }

    func testDuoTabSliderVeryShortFlickCannotSkipTheMiddleTab() {
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 0, tabCount: 3, tabWidth: 135, translation: 16, predictedEndTranslation: 400
        ), 1)
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 2, tabCount: 3, tabWidth: 135, translation: -16, predictedEndTranslation: -400
        ), 1)
    }

    func testDuoTabSliderHardFlickCarriesAcrossTwoTabsInEitherDirection() {
        for tabWidth: CGFloat in [72, 135, 190] {
            let translation = tabWidth * 0.33
            let projected = tabWidth * 1.8
            XCTAssertEqual(DuoTabSliderMotion.targetIndex(
                from: 0, tabCount: 3, tabWidth: tabWidth, translation: translation,
                predictedEndTranslation: projected
            ), 2)
            XCTAssertEqual(DuoTabSliderMotion.targetIndex(
                from: 2, tabCount: 3, tabWidth: tabWidth, translation: -translation,
                predictedEndTranslation: -projected
            ), 0)
        }
    }

    func testDuoTabSliderSettlesWhereLongDragEnded() {
        for projection: CGFloat in [120, 220, 300] {
            XCTAssertEqual(DuoTabSliderMotion.targetIndex(
                from: 0, tabCount: 3, tabWidth: 135, translation: 220, predictedEndTranslation: projection
            ), 2)
            XCTAssertEqual(DuoTabSliderMotion.targetIndex(
                from: 2, tabCount: 3, tabWidth: 135, translation: -220, predictedEndTranslation: -projection
            ), 0)
        }
    }

    func testDuoTabSliderSnapsSlowDragsToTheNearestSlotAndStopsAtEdges() {
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 1, tabCount: 3, tabWidth: 135, translation: 20, predictedEndTranslation: 20
        ), 1)
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 1, tabCount: 3, tabWidth: 135, translation: 80, predictedEndTranslation: 80
        ), 2)
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 0, tabCount: 3, tabWidth: 135, translation: -200, predictedEndTranslation: -500
        ), 0)
        XCTAssertEqual(DuoTabSliderMotion.targetIndex(
            from: 2, tabCount: 3, tabWidth: 135, translation: 200, predictedEndTranslation: 500
        ), 2)
    }

    func testDuoMirrorsControlsOnlyInTheLeftSplitPane() {
        let display = CGRect(x: 0, y: 0, width: 951, height: 669)
        let left = CGRect(x: 0, y: 0, width: 468, height: 669)
        let right = CGRect(x: 483, y: 0, width: 468, height: 669)

        XCTAssertTrue(MiloomDuoLayoutState.occupiesLeftSplitPane(window: left, display: display))
        XCTAssertFalse(MiloomDuoLayoutState.occupiesLeftSplitPane(window: right, display: display))
        XCTAssertFalse(MiloomDuoLayoutState.occupiesLeftSplitPane(window: display, display: display))
        XCTAssertFalse(MiloomDuoLayoutState.occupiesLeftSplitPane(
            window: CGRect(x: 0, y: 10, width: 468, height: 640), display: display
        ))

        let layout = MiloomDuoLayoutState()
        layout.isInLeftSplitPane = true
        XCTAssertFalse(layout.usesLeftSplitToolbar)
        layout.isDuoDevice = true
        XCTAssertFalse(layout.usesLeftSplitToolbar)
        layout.isExpanded = true
        XCTAssertTrue(layout.placesSplitControlsOnLeadingEdge(in: .leftToRight))
        XCTAssertFalse(layout.placesSplitControlsOnLeadingEdge(in: .rightToLeft))
    }

    func testDuoExpandedLayoutsRequireRoomInTheAppWindow() {
        let layout = MiloomDuoLayoutState()
        layout.isDuoDevice = true
        layout.isExpanded = true

        layout.windowSize = CGSize(width: 475, height: 669)
        XCTAssertTrue(layout.usesCompactLayout)
        XCTAssertFalse(layout.usesExpandedPortrait)
        XCTAssertFalse(layout.usesExpandedLandscape)

        layout.windowSize = CGSize(width: 475, height: 320)
        XCTAssertTrue(layout.usesCompactLayout)
        XCTAssertFalse(layout.usesExpandedPortrait)
        XCTAssertFalse(layout.usesExpandedLandscape)

        layout.windowSize = CGSize(width: 669, height: 951)
        XCTAssertFalse(layout.usesCompactLayout)
        XCTAssertTrue(layout.usesExpandedPortrait)
        XCTAssertFalse(layout.usesExpandedLandscape)

        layout.windowSize = CGSize(width: 951, height: 669)
        XCTAssertFalse(layout.usesCompactLayout)
        XCTAssertFalse(layout.usesExpandedPortrait)
        XCTAssertTrue(layout.usesExpandedLandscape)

        layout.windowSize = CGSize(width: 475, height: 669)
        layout.isExpanded = false
        XCTAssertTrue(layout.usesCompactLayout)
        XCTAssertFalse(layout.usesExpandedLandscape)

        layout.isExpanded = true
        layout.isDuoDevice = false
        XCTAssertFalse(layout.usesCompactLayout)
        XCTAssertFalse(layout.usesExpandedLandscape)
    }

    func testDuoEntityPortraitUsesItsAvailableWidthAndKeepsContentRightOfCenter() {
        let size = CGSize(width: 700, height: 1000)
        let frames = DuoEntityPanelFrames.resolve(size: size, expanded: true, portrait: true)
        XCTAssertEqual(frames.page.width, size.width - 124, accuracy: 0.001)
        XCTAssertEqual(frames.page.minX, min(size.width - frames.page.width, (size.width - frames.page.width) / 2 + 44))
        XCTAssertEqual(frames.page.height, size.height)
        XCTAssertLessThan(frames.sections.maxX, frames.page.minX)
        XCTAssertGreaterThanOrEqual(frames.sections.width, 44)
        XCTAssertEqual(frames.sections.minX, 0)
        XCTAssertEqual(frames.panel, .zero)
        XCTAssertEqual(frames.divider, .zero)
    }

    func testDuoPortraitContentWidthIsIndependentOfHeightAndLandscapeDivision() {
        let size = CGSize(width: 587, height: 951)
        let frames = DuoEntityPanelFrames.resolve(size: size, expanded: true, portrait: true)
        let resized = DuoEntityPanelFrames.resolve(size: CGSize(width: size.width, height: 620),
            expanded: true, portrait: true, division: CGRect(x: 520, y: 0, width: 24, height: 620))

        XCTAssertEqual(frames.page.width, 463)
        XCTAssertEqual(resized.page.width, frames.page.width)
        XCTAssertEqual(resized.page.minX, frames.page.minX)
    }

    func testDuoEntityPortraitFilingFramesStayInBoundsForSmallWindows() {
        for size in [CGSize.zero, CGSize(width: 80, height: 30), CGSize(width: 320, height: 200), CGSize(width: 700, height: 1000)] {
            let frames = DuoEntityPanelFrames.resolve(size: size, expanded: true, portrait: true,
                division: CGRect(x: 0, y: size.height / 2, width: size.width, height: 40))
            XCTAssertGreaterThanOrEqual(frames.page.minX, 0)
            XCTAssertGreaterThanOrEqual(frames.page.width, 0)
            XCTAssertEqual(frames.page.minX, min(size.width - frames.page.width, (size.width - frames.page.width) / 2 + 44))
            XCTAssertEqual(frames.page.height, size.height)
            XCTAssertLessThanOrEqual(frames.sections.maxX, frames.page.minX)
            XCTAssertLessThanOrEqual(frames.sections.maxY, size.height)
            XCTAssertEqual(frames.panel, .zero)
        }
    }

    func testDuoBinderDrawerUsesNinetyPercentWidthAndLeavesDividersAtLeftEdge() {
        let size = CGSize(width: 700, height: 1000)
        for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
            let frames = DuoBinderDrawerFrames.resolve(size: size, progress: progress, tabIndex: 1)
            XCTAssertEqual(frames.sheet.width, 630)
            XCTAssertEqual(frames.tab.minX, 0)
            XCTAssertEqual(frames.sheet.minX, (progress - 1) * 630, accuracy: 0.001)
        }
        let open = DuoBinderDrawerFrames.resolve(size: size, progress: 1, tabIndex: 1)
        XCTAssertEqual(open.sheet.minX, 0)
        XCTAssertEqual(open.sheet.maxX, 630)
        let closed = DuoBinderDrawerFrames.resolve(size: size, progress: 0, tabIndex: 1)
        XCTAssertEqual(closed.sheet.maxX, 0)
    }

    func testDuoBinderDrawerClampsProgressAndFitsAllDividerTabs() {
        for size in [CGSize.zero, CGSize(width: 30, height: 20), CGSize(width: 700, height: 1000)] {
            for progress: CGFloat in [-1, 0, 1, 2, .nan] {
                for index in 0..<3 {
                    let frames = DuoBinderDrawerFrames.resolve(size: size, progress: progress, tabIndex: index)
                    XCTAssertGreaterThanOrEqual(frames.tab.minX, 0)
                    XCTAssertLessThanOrEqual(frames.tab.maxX, size.width)
                    XCTAssertGreaterThanOrEqual(frames.tab.minY, 0)
                    XCTAssertLessThanOrEqual(frames.tab.maxY, size.height)
                    XCTAssertTrue(frames.sheet.minX.isFinite)
                }
            }
        }
    }

    func testDuoReportPullResistsAndBoundsRightwardStretch() {
        XCTAssertEqual(DuoReportPull.stretch(translation: 40, sheetWidth: 630), 14, accuracy: 0.001)
        XCTAssertEqual(DuoReportPull.stretch(translation: 400, sheetWidth: 630), 48)
        XCTAssertEqual(DuoReportPull.stretch(translation: 400, sheetWidth: 90), 10)
        XCTAssertEqual(DuoReportPull.stretch(translation: -40, sheetWidth: 630), 0)
        XCTAssertEqual(DuoReportPull.stretch(translation: .nan, sheetWidth: 630), 0)
    }

    func testDuoReportPullDistinguishesGentleReleaseFromDeliberateClose() {
        XCTAssertFalse(DuoReportPull.shouldClose(translation: 24, predicted: 500))
        XCTAssertFalse(DuoReportPull.shouldClose(translation: 40, predicted: 45))
        XCTAssertTrue(DuoReportPull.shouldClose(translation: 65, predicted: 65))
        XCTAssertTrue(DuoReportPull.shouldClose(translation: 32, predicted: 200))
        XCTAssertTrue(DuoReportPull.shouldClose(translation: -45, predicted: -45))
        XCTAssertFalse(DuoReportPull.shouldClose(translation: .nan, predicted: 100))
    }

    func testHolographicSectorSelectionDoesNotTurnCreditsOrInvalidValuesIntoDebt() {
        let slices: [DuoReportSlice] = [
            .init(id: "credit", title: "Credit balance", value: -20, color: .white),
            .init(id: "invalid", title: "Invalid", value: .nan, color: .white),
            .init(id: "cards", title: "Cards", value: 200, color: .white),
            .init(id: "loans", title: "Loans", value: 300, color: .white)
        ]
        XCTAssertEqual(DuoReportSeries.selectedID(at: 0, in: slices), "cards")
        XCTAssertEqual(DuoReportSeries.selectedID(at: 199.9, in: slices), "cards")
        XCTAssertEqual(DuoReportSeries.selectedID(at: 200, in: slices), "loans")
        XCTAssertNil(DuoReportSeries.selectedID(at: 500, in: slices))
        XCTAssertNil(DuoReportSeries.selectedID(at: .nan, in: slices))
        XCTAssertNil(DuoReportSeries.selectedID(at: -1, in: slices))
        XCTAssertNil(DuoReportSeries.selectedID(at: nil, in: slices))
    }

    func testDuoEntityClosedAndLandscapePlacementRemainUnchanged() {
        let size = CGSize(width: 1000, height: 700)
        for portrait in [true, false] {
            let closed = DuoEntityPanelFrames.resolve(size: size, expanded: false, portrait: portrait)
            XCTAssertEqual(closed.page, CGRect(origin: .zero, size: size))
            XCTAssertEqual(closed.panel, .zero)
            XCTAssertEqual(closed.divider, .zero)
        }
        let division = CGRect(x: 480, y: 0, width: 40, height: 700)
        let original = DuoDashboardPanelFrames.resolve(size: size, expanded: true, division: division)
        let current = DuoEntityPanelFrames.resolve(size: size, expanded: true, portrait: false, division: division)
        XCTAssertEqual(current.page, original.cards)
        XCTAssertEqual(current.panel, original.receipt)
        XCTAssertEqual(current.divider, .zero)
    }

    private let owner = UUID()
    private var now: Date { ISO8601DateFormatter().date(from: "2027-08-30T12:00:00Z")! }


    func testDuoLandscapePlacesReceiptLeftAndCardsRight() {
        let frames = DuoDashboardPanelFrames.resolve(size: CGSize(width: 1000, height: 700), expanded: true)
        XCTAssertEqual(frames.receipt.minX, 0)
        XCTAssertEqual(frames.cards.maxX, 1000)
        XCTAssertLessThan(frames.receipt.maxX, frames.cards.minX)
        XCTAssertEqual(frames.cards.height, 700)
        XCTAssertEqual(frames.receipt.height, 700)
    }

    func testDuoPortraitPlacesCardsAboveReceiptAndAvoidsDivision() {
        let frames = DuoDashboardPanelFrames.resolve(
            size: CGSize(width: 700, height: 1000), expanded: true,
            division: CGRect(x: 0, y: 480, width: 700, height: 40)
        )
        XCTAssertEqual(frames.cards.minY, 0)
        XCTAssertEqual(frames.cards.maxY, 480)
        XCTAssertEqual(frames.receipt.minY, 520)
        XCTAssertEqual(frames.receipt.maxY, 1000)
    }

    func testClosedDashboardKeepsCardsFullSizeWithoutReceipt() {
        let size = CGSize(width: 390, height: 844)
        let frames = DuoDashboardPanelFrames.resolve(size: size, expanded: false)
        XCTAssertEqual(frames.cards, CGRect(origin: .zero, size: size))
        XCTAssertEqual(frames.receipt, .zero)
    }

    func testDuoLandscapeChromeLeavesReceiptFullHeightAndAlignsSearchWithPlus() {
        let frames = DuoDashboardChromeFrames.resolve(
            size: CGSize(width: 1000, height: 700), expanded: true,
            division: CGRect(x: 480, y: 0, width: 40, height: 700),
            headerHeight: 62, footerHeight: 56, footerControlCenterY: 670
        )
        XCTAssertEqual(frames.receipt, CGRect(x: 0, y: 0, width: 480, height: 700))
        XCTAssertEqual(frames.header.minX, 520)
        XCTAssertEqual(frames.footer.minX, 520)
        XCTAssertEqual(frames.footer.maxX, 1000)
        XCTAssertEqual(frames.footer.minY + 22, 670)
        XCTAssertEqual(frames.cards.minY, frames.header.maxY)
        XCTAssertEqual(frames.cards.maxY, frames.footer.minY)
    }

    func testDuoPortraitChromeRemainsPageWideAndRespectsHinge() {
        let frames = DuoDashboardChromeFrames.resolve(
            size: CGSize(width: 700, height: 1000), expanded: true,
            division: CGRect(x: 0, y: 480, width: 700, height: 40),
            headerHeight: 62, footerHeight: 64, footerControlCenterY: 100
        )
        XCTAssertEqual(frames.header.width, 700)
        XCTAssertEqual(frames.footer.minY, 936)
        XCTAssertEqual(frames.cards.minY, 62)
        XCTAssertEqual(frames.cards.maxY, 480)
        XCTAssertEqual(frames.receipt.minY, 520)
        XCTAssertEqual(frames.receipt.maxY, 936)
    }

    func testLandscapeSearchCanFollowPlusIntoBottomSafeArea() {
        let frames = DuoDashboardChromeFrames.resolve(
            size: CGSize(width: 1000, height: 700), expanded: true,
            headerHeight: 62, footerHeight: 56, footerControlCenterY: 685
        )
        XCTAssertEqual(frames.footer.minY + 22, 685)
        XCTAssertEqual(frames.receipt.maxY, 700)
    }

    func testClosedDuoChromeKeepsLegacyFullWidthRegions() {
        let frames = DuoDashboardChromeFrames.resolve(
            size: CGSize(width: 390, height: 844), expanded: false,
            headerHeight: 62, footerHeight: 56, footerControlCenterY: 100
        )
        XCTAssertEqual(frames.header, CGRect(x: 0, y: 0, width: 390, height: 62))
        XCTAssertEqual(frames.cards, CGRect(x: 0, y: 62, width: 390, height: 726))
        XCTAssertEqual(frames.footer, CGRect(x: 0, y: 788, width: 390, height: 56))
        XCTAssertEqual(frames.receipt, .zero)
    }

    @MainActor
    func testDuoWorkerUsesImmutableInputsAndRunsOffUIThread() async throws {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        state.hasLoadedPortfolio = true
        state.portfolioUserID = owner
        state.transactions = (0..<1000).map { _ in transaction(company: company.id, amount: 20) }
        let input = SearchIndexSnapshot(state)
        let legacy = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        let key = duoKey(state: state, scope: .business)
        state.transactions.removeAll()
        let report = try await DuoBriefingBuilder().build(input: input, key: key, now: now)
        XCTAssertFalse(report.builtOnMainThread)
        XCTAssertEqual(report.snapshot.records.count, 1000)
        XCTAssertEqual(report.financials.first?.insight.current.moneyOut, legacy.financials.first?.insight.current.moneyOut)
        XCTAssertTrue(state.transactions.isEmpty)
        XCTAssertEqual(state.companies, [company])
    }

    @MainActor
    func testDuoReportCacheReusesScopeAndMonthWithoutRebuilding() async {
        let state = AppState()
        state.companies = [Company(userId: owner, name: "Business", structure: "LLC")]
        state.hasLoadedPortfolio = true
        state.portfolioUserID = owner
        let input = SearchIndexSnapshot(state)
        let store = DuoBriefingStore()
        let business = duoKey(state: state, scope: .business)
        let personal = duoKey(state: state, scope: .personal)
        await store.prepare(input: input, key: business, now: now)
        await store.prepare(input: input, key: business, now: now)
        XCTAssertEqual(store.completedBuildCount, 1)
        await store.prepare(input: input, key: personal, now: now)
        XCTAssertEqual(store.completedBuildCount, 2)
        await store.prepare(input: input, key: business, now: now)
        XCTAssertEqual(store.completedBuildCount, 2)
        XCTAssertEqual(store.report?.key, business)
    }

    @MainActor
    func testDuoCancelledPreparationDoesNotPublishAndInvalidationClearsReceipt() async {
        let state = AppState()
        state.hasLoadedPortfolio = true
        state.portfolioUserID = owner
        let input = SearchIndexSnapshot(state)
        let key = duoKey(state: state, scope: .personal)
        let store = DuoBriefingStore()
        let cancelled = Task { await store.prepare(input: input, key: key, now: now) }
        cancelled.cancel()
        await cancelled.value
        XCTAssertNil(store.report)
        XCTAssertEqual(store.completedBuildCount, 0)
        await store.prepare(input: input, key: key, now: now)
        XCTAssertNotNil(store.report)
        store.invalidate()
        XCTAssertNil(store.report)
        XCTAssertFalse(store.isRefreshing)
    }

    @MainActor
    func testDuoPrivacyAndAccountKeysCannotKeepPreviousFiguresVisible() {
        let state = AppState()
        state.portfolioUserID = owner
        let key = duoKey(state: state, scope: .business)
        let otherUser = DuoBriefingKey(userID: UUID(), revision: key.revision,
            privacyRevision: key.privacyRevision, scope: key.scope, month: key.month,
            minute: key.minute, ignoredDataIssueIDs: [])
        let changedPermission = DuoBriefingKey(userID: owner, revision: key.revision,
            privacyRevision: key.privacyRevision + 1, scope: key.scope, month: key.month,
            minute: key.minute, ignoredDataIssueIDs: [])
        XCTAssertFalse(otherUser.canKeepVisible(key))
        XCTAssertFalse(changedPermission.canKeepVisible(key))
    }

    @MainActor
    private func duoKey(state: AppState, scope: OwnerBriefingScope) -> DuoBriefingKey {
        DuoBriefingKey(
            userID: state.portfolioUserID, revision: state.searchRevision,
            privacyRevision: state.resourceShares.hashValue, scope: scope,
            month: CashFlowMonth(containing: now), minute: Int(now.timeIntervalSince1970 / 60),
            ignoredDataIssueIDs: []
        )
    }

    func testScopeAndCompanyFilterPreserveInventoryAndConnections() {
        let state = AppState()
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let other = Company(userId: owner, name: "Other", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Household")
        state.companies = [business, other, personal]
        state.hasLoadedPortfolio = true
        state.subscriptions = [business, other, personal].map { Subscription(userId: owner, companyId: $0.id, name: $0.name, cost: 10) }
        state.transactions = [business, other, personal].map { transaction(company: $0.id, amount: 20) }
        state.resourceConnections = [ResourceConnection(ownerUserId: owner,
            sourceType: .subscription, sourceId: state.subscriptions[0].id,
            targetType: .company, targetId: business.id, relationshipType: .dependsOn,
            origin: .manual, confidence: 1, state: .confirmed)]
        let before = state.subscriptions
        let connections = state.resourceConnections
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now).activeSubscriptionCount, 2)
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now).activeSubscriptionCount, 1)
        let scoped = ExecutiveBriefingSnapshot(appState: state, scope: .business, companyID: business.id, now: now)
        XCTAssertEqual(scoped.companies.map(\.id), [business.id])
        XCTAssertEqual(scoped.financials.first?.insight.current.moneyOut, 20)
        XCTAssertEqual(state.subscriptions, before)
        XCTAssertEqual(state.resourceConnections, connections)
        XCTAssertEqual(state.transactions.count, 3)
    }

    func testCashFlowSeparatesRefundsCurrenciesAndExcludedTransactions() throws {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        let income = transaction(company: company.id, amount: -400)
        let expense = transaction(company: company.id, amount: 100)
        let refund = transaction(company: company.id, amount: -25)
        let transfer = transaction(company: company.id, amount: 1000)
        let ignored = transaction(company: company.id, amount: 500)
        var pending = transaction(company: company.id, amount: 200)
        pending.pending = true
        var euro = transaction(company: company.id, amount: 70)
        euro.currency = "EUR"
        var old = transaction(company: company.id, amount: 10)
        old.date = "2027-07-10"
        state.transactions = [income, expense, refund, transfer, ignored, pending, euro, old]
        state.transactionOverrides = [(refund, TransactionFlowOverride.refund), (transfer, .transfer), (ignored, .ignored)].map { record, flow in
            TransactionOverride(userId: owner, transactionId: record.id, flowOverride: flow)
        }
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        let usd = try XCTUnwrap(snapshot.financials.first { $0.currency == "USD" })
        XCTAssertEqual(usd.income, 400)
        XCTAssertEqual(usd.refunds, 25)
        XCTAssertEqual(usd.insight.current.moneyOut, 100)
        XCTAssertEqual(usd.insight.current.net, 325)
        XCTAssertEqual(snapshot.financials.first { $0.currency == "EUR" }?.insight.current.net, -70)
    }

    func testExecutiveSummaryUsesCalendarMonthAndSamePointLastMonth() throws {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]

        var currentMonth = transaction(company: company.id, amount: 40)
        currentMonth.date = "2027-08-01"
        var comparablePreviousMonth = transaction(company: company.id, amount: 20)
        comparablePreviousMonth.date = "2027-07-30"
        var laterPreviousMonth = transaction(company: company.id, amount: 70)
        laterPreviousMonth.date = "2027-07-31"
        state.transactions = [currentMonth, comparablePreviousMonth, laterPreviousMonth]

        let summary = try XCTUnwrap(
            ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now).financials.first
        )
        XCTAssertEqual(summary.insight.current.moneyOut, 40)
        XCTAssertEqual(summary.insight.previous.moneyOut, 20)
        XCTAssertEqual(summary.insight.records.map(\.id), [currentMonth.id])
    }

    func testRecurringCommitmentCountsOnlyActiveServicesAndAddonsOnce() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        var active = Subscription(userId: owner, companyId: company.id, name: "Software", cost: 120, billingCycle: "Yearly", serviceType: .subscription)
        active.subServices = [
            SubService(name: "Active monthly", cost: 5),
            SubService(name: "Active yearly", cost: 24, billingCycle: .yearly),
            SubService(name: "Cancelled", cost: 100, status: .cancelled),
            SubService(name: "Paused", cost: 100, status: .paused),
            SubService(name: "Pending", cost: 100, status: .pending)
        ]
        var cancelled = active
        cancelled.id = UUID(); cancelled.status = "Cancelled"
        state.subscriptions = [active, cancelled,
            Subscription(userId: owner, companyId: company.id, name: "Utility", cost: 20, serviceType: .bill),
            Subscription(userId: owner, companyId: company.id, name: "Euro service", cost: 8, currency: "EUR"),
            Subscription(userId: owner, companyId: company.id, name: "Unknown cycle", cost: 999, billingCycle: "Custom")]
        let result = ExecutiveBriefingSnapshot(appState: state, scope: .business)
        XCTAssertEqual(result.activeSubscriptionCount, 3)
        XCTAssertEqual(result.activeBillCount, 1)
        XCTAssertEqual(result.supplementalCount, 2)
        XCTAssertEqual(result.recurringCosts["USD"], 37)
        XCTAssertEqual(result.recurringCosts["EUR"], 8)
        XCTAssertEqual(result.unknownBillingCount, 1)
    }

    func testLocalAssignmentMovesBothResourceAndItsTransactionsWithoutSaving() {
        let state = AppState()
        let previous = state.localCompanyOverrides
        defer { state.localCompanyOverrides = previous }
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let bank = Institution(userId: owner, companyId: business.id, name: "Bank", accounts: [InstitutionAccount(id: "account")])
        state.companies = [business, personal]
        state.institutions = [bank]
        state.localCompanyOverrides[bank.id.uuidString] = personal.id
        var value = transaction(company: business.id, amount: 35)
        value.accountId = "account"; value.institutionId = bank.id
        state.transactions = [value]
        XCTAssertTrue(ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now).records.isEmpty)
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now).financials.first?.insight.current.moneyOut, 35)
        XCTAssertEqual(state.institutions[0].companyId, business.id)
        XCTAssertEqual(state.transactions[0].companyId, business.id)
    }

    func testUrgentNoticesDeduplicateBrokenBankAndExcludeRoutineAndDeferredItems() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        let bank = Institution(userId: owner, companyId: company.id, name: "Bank", isDisconnected: true)
        state.companies = [company]; state.institutions = [bank]
        state.plaidItems = [PlaidItemSummary(id: UUID(), companyId: company.id, institutionId: bank.id, status: "requires_reauth")]
        let reconnect = obligation(bank: bank, kind: "bank_connection", severity: .urgent)
        let deadline = obligation(bank: bank, kind: "critical_deadline", severity: .urgent)
        let routine = obligation(bank: bank, kind: "routine", severity: .info)
        var deferred = obligation(bank: bank, kind: "deferred", severity: .urgent)
        deferred.state = .deferred
        state.obligations = [reconnect, deadline, deadline, routine, deferred]
        let result = ExecutiveUrgentNotice.notices(in: state)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.filter { $0.obligation == nil }.count, 1)
        XCTAssertEqual(result.compactMap(\.obligation).map(\.id), [deadline.id])
        XCTAssertTrue(result.allSatisfy { $0.entityName == "Business · Business" })
        XCTAssertEqual(state.obligations.count, 5)
    }

    func testCoverageDoesNotTreatUnloadedOrFailedDataAsHealthy() {
        let state = AppState()
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).coverage, "Waiting for portfolio data")
        state.hasLoadedPortfolio = true; state.portfolioLoadIssue = "Unavailable"
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).coverage, "Some portfolio data is unavailable")
        XCTAssertTrue(ExecutiveBriefingSnapshot(appState: state, scope: .business).financials.isEmpty)
    }

    func testBusinessSummaryIsHiddenWhenThereAreNoBusinessProfiles() {
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        XCTAssertEqual(ExecutiveBriefingLayout.visibleScopes(companies: [personal]), [.personal])

        let business = Company(userId: owner, name: "Studio", structure: "LLC")
        XCTAssertEqual(ExecutiveBriefingLayout.visibleScopes(companies: [personal, business]), [.business, .personal])
    }

    func testUrgentNoticesAreAssignedToTheirExecutiveSummary() {
        let state = AppState()
        let business = Company(userId: owner, name: "Studio", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let businessBank = Institution(userId: owner, companyId: business.id, name: "Studio Bank", isDisconnected: true)
        let personalBank = Institution(userId: owner, companyId: personal.id, name: "Personal Bank", isDisconnected: true)
        state.companies = [business, personal]
        state.institutions = [businessBank, personalBank]

        let notices = ExecutiveUrgentNotice.notices(in: state)
        XCTAssertEqual(notices.filter { $0.belongs(to: .business, in: state) }.map(\.title), ["Reconnect Studio Bank"])
        XCTAssertEqual(notices.filter { $0.belongs(to: .personal, in: state) }.map(\.title), ["Reconnect Personal Bank"])
    }

    func testUnassignedUrgentNoticeRemainsVisibleWithoutBusinessProfile() {
        let state = AppState()
        state.companies = [Company(userId: owner, name: "Personal", structure: "Individual")]
        let notice = ExecutiveUrgentNotice(
            id: "unassigned", title: "Review connection", detail: "Action needed",
            entityName: "Unassigned", companyID: nil, sourceType: .collaborator,
            sourceID: UUID(), obligation: nil, dueAt: nil
        )

        XCTAssertTrue(notice.belongs(to: .personal, in: state))
        XCTAssertFalse(notice.belongs(to: .business, in: state))
    }

    func testHealthFilterAndRemindersFollowEffectiveAssignment() {
        let state = AppState()
        let previous = state.localCompanyOverrides
        defer { state.localCompanyOverrides = previous }
        let business = Company(userId: owner, name: "Business", structure: "LLC")
        let personal = Company(userId: owner, name: "Personal", structure: "Individual")
        let bank = Institution(userId: owner, companyId: business.id, name: "Moved bank", isDisconnected: true)
        state.companies = [business, personal]; state.institutions = [bank]
        state.localCompanyOverrides[bank.id.uuidString] = personal.id
        let notice = obligation(bank: bank, kind: "bank_connection", severity: .urgent)
        state.obligations = [notice]
        XCTAssertEqual(ExecutiveBriefingSnapshot.companyID(for: notice, in: state), personal.id)
        let businessHealth = OwnerHealthEngine.snapshot(appState: state, scope: .business, companyID: business.id)
        let personalHealth = OwnerHealthEngine.snapshot(appState: state, scope: .personal, companyID: personal.id)
        XCTAssertEqual(businessHealth.categories.first { $0.category == .institution }?.status, .notApplicable)
        XCTAssertEqual(personalHealth.categories.first { $0.category == .institution }?.status, .critical)
        XCTAssertEqual(ExecutiveUrgentNotice.notices(in: state).first?.entityName, "Personal · Personal")
    }

    func testUnassignedTransactionsAndMissingSyncRemainExplicit() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]; state.hasLoadedPortfolio = true
        var unassigned = transaction(company: company.id, amount: 100)
        unassigned.companyId = nil
        state.transactions = [unassigned]
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        XCTAssertEqual(snapshot.unassignedTransactionCount, 1)
        XCTAssertTrue(snapshot.financials.isEmpty)
        XCTAssertEqual(snapshot.coverage, "No transaction history available")
    }

    func testUnknownBillingDoesNotCreateAFalseZeroAndFreeAddonsAreIncluded() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        state.subscriptions = [Subscription(userId: owner, companyId: company.id, cost: 50, billingCycle: "Custom")]
        let unknown = ExecutiveBriefingSnapshot(appState: state, scope: .business)
        XCTAssertTrue(unknown.recurringCosts.isEmpty)
        XCTAssertEqual(unknown.unknownBillingCount, 1)
        XCTAssertEqual(unknown.activeSubscriptionCount, 1)
        state.subscriptions = [Subscription(userId: owner, companyId: company.id, cost: 500,
            subServices: [SubService(name: "Paid add-on", cost: 5)], pricingModel: "free")]
        XCTAssertEqual(ExecutiveBriefingSnapshot(appState: state, scope: .business).recurringCosts["USD"], 5)
    }

    func testUpcomingCoverageGroupsChargesBySavedBankAccountAndUsesAvailableBalance() throws {
        let institutionID = UUID()
        let account = InstitutionAccount(
            id: "checking", name: "Operating", type: "Checking", last4: "4242",
            balance: 140, availableBalance: 100, currency: "USD"
        )
        let institution = Institution(
            id: institutionID, userId: owner, companyId: UUID(), name: "Community Bank",
            accounts: [account]
        )
        let first = Subscription(
            userId: owner, companyId: institution.companyId, name: "Internet", cost: 60,
            paymentMethod: "Operating", paymentMethodId: institutionID,
            nextRenewalAt: now.addingTimeInterval(5 * 86_400), serviceType: .bill
        )
        let second = Subscription(
            userId: owner, companyId: institution.companyId, name: "Software", cost: 50,
            paymentMethod: "Operating", paymentMethodId: institutionID,
            nextRenewalAt: now.addingTimeInterval(12 * 86_400), serviceType: .subscription
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [first, second], institutions: [institution], cards: [], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(group.charges.map(\.name), ["Internet", "Software"])
        XCTAssertEqual(group.totalDue, 110, accuracy: 0.001)
        XCTAssertEqual(group.availableAmount, 100)
        XCTAssertEqual(group.status, .atRisk)
        XCTAssertEqual(group.difference, -10)
        XCTAssertEqual(group.sourceName, "Operating ••••4242")
    }

    func testUpcomingCoverageMarksDisconnectedStaleAndUnlinkedSourcesUnknown() {
        let companyID = UUID()
        let institution = Institution(
            userId: owner, companyId: companyID, name: "Bank",
            accounts: [InstitutionAccount(id: "linked", plaidAccountId: "plaid-1", name: "Checking", balance: 500)],
            lastSyncedAt: now.addingTimeInterval(-10 * 86_400)
        )
        let stale = Subscription(
            userId: owner, companyId: companyID, name: "Rent", cost: 100,
            paymentMethod: "Checking", paymentMethodId: institution.id,
            nextRenewalAt: now.addingTimeInterval(2 * 86_400), serviceType: .bill,
            plaidAccountId: "plaid-1"
        )
        let unlinked = Subscription(
            userId: owner, companyId: companyID, name: "Membership", cost: 20,
            paymentMethod: "Old card", nextRenewalAt: now.addingTimeInterval(3 * 86_400)
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [stale, unlinked], institutions: [institution], cards: [], plaidItems: [], now: now
        )
        XCTAssertEqual(result.unknownCount, 2)
        XCTAssertTrue(result.groups.allSatisfy { $0.status == .unknown })
        XCTAssertTrue(result.groups.contains { $0.reason == "Connected balance is out of date" })
        XCTAssertTrue(result.groups.contains { $0.reason == "Link its payment account to verify funds" })

        var disconnected = institution
        disconnected.isDisconnected = true
        disconnected.lastSyncedAt = now
        let brokenResult = UpcomingCoverageEngine.project(
            subscriptions: [stale], institutions: [disconnected], cards: [], plaidItems: [], now: now
        )
        XCTAssertEqual(brokenResult.groups.first?.reason, "Bank connection needs attention")
    }

    func testUpcomingCoverageUsesAvailableCreditAndAddonInheritsParentSource() throws {
        let companyID = UUID()
        let card = FinancialCard(
            userId: owner, companyId: companyID, name: "Rewards", last4: "9999",
            type: "Credit", limit: 1_000, balance: 200
        )
        let addon = SubService(
            name: "Extra seat", cost: 25, renewsOn: now.addingTimeInterval(4 * 86_400)
        )
        let service = Subscription(
            userId: owner, companyId: companyID, name: "Workspace", cost: 0,
            paymentMethod: "Rewards", paymentMethodId: card.id,
            subServices: [addon], pricingModel: "free"
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [service], institutions: [], cards: [card], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(group.status, .covered)
        XCTAssertEqual(group.availableAmount, 800)
        XCTAssertEqual(group.totalDue, 25)
        XCTAssertEqual(group.charges.map(\.name), ["Extra seat"])
        XCTAssertEqual(result.unscheduledCount, 1)
    }

    func testUpcomingCoverageUsesLinkedBankAccountForCardAndCountsItsBalanceOnce() throws {
        let companyID = UUID()
        let card = FinancialCard(
            userId: owner, companyId: companyID, name: "Visa", last4: "9225",
            type: "Credit", limit: 10_000, balance: 100
        )
        let account = InstitutionAccount(
            id: "sofi-checking", name: "SoFi Checking", type: "Checking", last4: "5181",
            balance: 225, availableBalance: 200, currency: "USD",
            linkedCardId: card.id.uuidString
        )
        let institution = Institution(
            userId: owner, companyId: companyID, name: "SoFi", accounts: [account]
        )
        let cardPayment = Subscription(
            userId: owner, companyId: companyID, name: "Phone", cost: 150,
            paymentMethod: "Visa", paymentMethodId: card.id,
            nextRenewalAt: now.addingTimeInterval(2 * 86_400), serviceType: .bill
        )
        let directPayment = Subscription(
            userId: owner, companyId: companyID, name: "Internet", cost: 100,
            paymentMethod: "SoFi Checking", paymentMethodId: institution.id,
            nextRenewalAt: now.addingTimeInterval(3 * 86_400), serviceType: .bill
        )

        let result = UpcomingCoverageEngine.project(
            subscriptions: [cardPayment, directPayment], institutions: [institution],
            cards: [card], plaidItems: [], now: now
        )
        let group = try XCTUnwrap(result.groups.first)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(group.sourceName, "SoFi Checking ••••5181")
        XCTAssertEqual(group.paymentRoutes, ["Visa ••••9225"])
        XCTAssertEqual(group.availableAmount, 200)
        XCTAssertEqual(group.totalDue, 250)
        XCTAssertEqual(group.status, .atRisk)
        XCTAssertEqual(group.difference, -50)
    }

    func testCardBankCashExcludesInvestmentsCreditAndClosedAccounts() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        state.institutions = [Institution(userId: owner, companyId: company.id, accounts: [
            InstitutionAccount(id: "checking", type: "Checking", balance: 500, availableBalance: 100),
            InstitutionAccount(id: "savings", type: "Savings", balance: 200),
            InstitutionAccount(id: "investment", type: "Investing", balance: 9000),
            InstitutionAccount(id: "credit", type: "Credit Card", balance: 800),
            InstitutionAccount(id: "closed", type: "Checking", balance: 1000, status: "Closed"),
            InstitutionAccount(id: "euro", type: "Savings", balance: 50, currency: "EUR")
        ])]
        let metrics = ExecutiveCardMetrics(snapshot: ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now), now: now)
        XCTAssertEqual(metrics.bankCash, ["USD": 700, "EUR": 50])
        XCTAssertTrue(ExecutiveCardMetrics(snapshot: ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now), now: now).bankCash.isEmpty)
        XCTAssertEqual(BriefingFormat.cardAmounts(metrics.bankCash, empty: "—"), "2 currencies")
        XCTAssertTrue(BriefingFormat.cardAmounts(["USD": 3100], empty: "—", signed: true).hasPrefix("+"))
        XCTAssertEqual(BriefingFormat.cardAmounts(["Unknown currency": 10], empty: "—"), "Unknown")
    }

    func testCardSevenDaysIncludesTodayAndDaySixButNotDaySeven() {
        let state = AppState()
        let company = Company(userId: owner, name: "Business", structure: "LLC")
        state.companies = [company]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // Window crosses the spring daylight-saving change.
        let anchor = ISO8601DateFormatter().date(from: "2027-03-12T20:00:00Z")!
        let today = calendar.startOfDay(for: anchor)
        state.subscriptions = [0, 6, 7].map { day in
            Subscription(userId: owner, companyId: company.id, name: "Day \(day)", cost: 10,
                nextRenewalAt: calendar.date(byAdding: .day, value: day, to: today))
        }
        state.subscriptions.append(Subscription(userId: owner, companyId: company.id, name: "No date", cost: 20))
        state.subscriptions.append(Subscription(userId: owner, companyId: company.id, name: "Unsupported", cost: 50,
            billingCycle: "Weekly", nextRenewalAt: today))
        var cancelled = state.subscriptions[0]
        cancelled.id = UUID(); cancelled.status = "Cancelled"
        state.subscriptions.append(cancelled)
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: anchor)
        let metrics = ExecutiveCardMetrics(snapshot: snapshot, now: anchor, calendar: calendar)
        XCTAssertEqual(metrics.scheduledCosts, ["USD": 20])
        XCTAssertEqual(metrics.scheduleIncompleteCount, 2)
        XCTAssertEqual(state.subscriptions[0].nextRenewalAt, today)
    }

    func testCardDocumentDatesUseCalendarDaysAndUnknownIsNotHealthy() {
        let state = AppState()
        let company = Company(userId: owner, name: "Household", structure: "Household")
        state.companies = [company]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: now)
        state.documents = [-1, 0, 60, 61].map { offset in
            CompanyDocument(userId: owner, companyId: company.id, name: "Document \(offset)",
                expiresAt: calendar.date(byAdding: .day, value: offset, to: today))
        }
        state.documents.append(CompanyDocument(userId: owner, companyId: company.id, name: "Undated"))
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now)
        let metrics = ExecutiveCardMetrics(snapshot: snapshot, now: now, calendar: calendar)
        XCTAssertEqual(metrics.expiredDocuments.map(\.name), ["Document -1"])
        XCTAssertEqual(metrics.expiringDocuments.map(\.name), ["Document 0", "Document 60"])
        XCTAssertEqual(metrics.datedDocumentCount, 4)
        XCTAssertEqual(metrics.coverageNote(for: snapshot), "Loading tracked records")
        state.hasLoadedPortfolio = true
        state.portfolioLoadIssue = "Unavailable"
        XCTAssertEqual(metrics.coverageNote(for: ExecutiveBriefingSnapshot(appState: state, scope: .personal, now: now)),
            "Some data unavailable · totals incomplete")
    }

    func testCardAttentionPrioritizesDeadlinesOverConnectionsAndDoesNotDuplicateDocuments() {
        let state = AppState()
        let company = Company(userId: owner, name: "Acme", structure: "LLC")
        let personal = Company(userId: owner, name: "Home", structure: "Household")
        state.companies = [company, personal]
        state.institutions = [Institution(userId: owner, companyId: company.id, name: "Bank", isDisconnected: true)]
        let expired = CompanyDocument(userId: owner, companyId: company.id, name: "Insurance", expiresAt: now.addingTimeInterval(-86400))
        state.documents = [expired,
            CompanyDocument(userId: owner, companyId: company.id, name: "License", expiresAt: now.addingTimeInterval(30 * 86400)),
            CompanyDocument(userId: owner, companyId: personal.id, name: "Passport", expiresAt: now.addingTimeInterval(-86400))]
        let notices = ExecutiveUrgentNotice.cardNotices(in: state, scope: .business, now: now)
        XCTAssertEqual(notices.map(\.sourceType), [.document, .document, .institution])
        XCTAssertEqual(notices.first?.entityName, "Acme")
        var urgent = obligation(bank: state.institutions[0], kind: "document_expired", severity: .urgent)
        urgent.sourceType = .document; urgent.sourceId = expired.id; urgent.dueAt = expired.expiresAt
        state.obligations = [urgent]
        XCTAssertEqual(ExecutiveUrgentNotice.cardNotices(in: state, scope: .business, now: now).filter { $0.sourceID == expired.id }.count, 1)
    }

    func testCardFundingWarningRequiresKnownFundsAndSurfacesStaleData() {
        let state = AppState()
        let company = Company(userId: owner, name: "Acme", structure: "LLC")
        let bank = Institution(userId: owner, companyId: company.id, name: "Bank", accounts: [
            InstitutionAccount(id: "checking", plaidAccountId: "connected", name: "Operating", balance: 100, availableBalance: 100)
        ], lastSyncedAt: now)
        state.companies = [company]
        state.institutions = [bank]
        state.hasLoadedPortfolio = true
        state.subscriptions = [Subscription(userId: owner, companyId: company.id, name: "Rent", cost: 150,
            paymentMethod: "Operating", paymentMethodId: bank.id, nextRenewalAt: now.addingTimeInterval(2 * 86400),
            serviceType: .bill, plaidAccountId: "connected")]
        XCTAssertEqual(ExecutiveUrgentNotice.cardNotices(in: state, scope: .business, now: now).first?.title,
            "Scheduled payments may exceed funds")
        state.institutions[0].lastSyncedAt = now.addingTimeInterval(-10 * 86400)
        let snapshot = ExecutiveBriefingSnapshot(appState: state, scope: .business, now: now)
        let metrics = ExecutiveCardMetrics(snapshot: snapshot, now: now)
        XCTAssertTrue(metrics.hasStaleBankData)
        XCTAssertEqual(metrics.coverageNote(for: snapshot), "Bank balances out of date · review updates")
        XCTAssertFalse(ExecutiveUrgentNotice.cardNotices(in: state, scope: .business, now: now)
            .contains { $0.title == "Scheduled payments may exceed funds" })
    }

    private func transaction(company: UUID, amount: Double) -> Zifr.Transaction {
        var value = Zifr.Transaction()
        value.userId = owner; value.companyId = company; value.amount = amount
        value.date = "2027-08-20"; value.name = "Fixture"
        return value
    }

    private func obligation(bank: Institution, kind: String, severity: ObligationSeverity) -> PortfolioObligation {
        PortfolioObligation(id: UUID(), ownerUserId: owner, companyId: bank.companyId,
            sourceType: .institution, sourceId: bank.id, kind: kind, severity: severity,
            title: "Notice", summary: "Action needed", actionType: "open_source", state: .open,
            fingerprint: UUID().uuidString, createdAt: now, updatedAt: now)
    }
}
