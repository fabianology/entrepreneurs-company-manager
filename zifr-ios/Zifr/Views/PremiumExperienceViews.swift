import SwiftUI

enum DashboardDisplayMode: String, CaseIterable, Identifiable {
    case portfolio = "Portfolio"
    case briefing = "Briefing"

    var id: String { rawValue }
}

struct DashboardModePicker: View {
    let selection: DashboardDisplayMode
    let onSelect: (DashboardDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DashboardDisplayMode.allCases) { mode in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(mode)
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(selection == mode ? Color.white : Color.white.opacity(0.42))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if selection == mode {
                        pickerGlass(
                            RoundedRectangle(cornerRadius: 13, style: .continuous),
                            opacity: 0.44
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color(hex: "#918457").opacity(0.72), lineWidth: 1)
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selection)
            }
        }
        .padding(4)
        .background {
            pickerGlass(Capsule(), opacity: 0.25)
        }
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dashboard view")
    }

    @ViewBuilder
    private func pickerGlass<S: Shape>(_ shape: S, opacity: Double) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .clear.tint(Color.zifrTabBarFill.opacity(opacity)).interactive(),
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.zifrTabBarFill.opacity(opacity)))
        }
    }
}

struct OwnerBriefingCard: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    var onOpenResource: (PortfolioObligation) -> Void

    @State private var showingBriefing = false
    @State private var showingUpgrade = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if accessController.request(.ownerBriefing, source: "dashboard_briefing", appState: appState, userId: authVM.currentUser?.id) {
                showingBriefing = true
            } else {
                showingUpgrade = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Owner Briefing")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(briefingSubtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }

                    Spacer(minLength: 8)

                    if !accessController.isPro {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.zifrGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.zifrGold.opacity(0.12), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.42))
                }

                if !visibleCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(visibleCategories) { category in
                                categorySummary(
                                    category,
                                    count: reminderCount(in: category)
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 74)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background {
                ownerBriefingGlass(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Owner Briefing")
        .accessibilityValue(accessController.isPro && appState.unreadBriefingCount > 0
            ? "\(appState.unreadBriefingCount) reminders need attention"
            : accessController.isPro ? "No reminders need attention" : "Pro feature")
        .sheet(isPresented: $showingBriefing) {
            OwnerBriefingView(onOpenResource: onOpenResource)
        }
        .sheet(isPresented: $showingUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }

    private var visibleCategories: [BriefingResourceCategory] {
        BriefingResourceCategory.allCases.filter { reminderCount(in: $0) > 0 }
    }

    private var briefingSubtitle: String {
        guard accessController.isPro else { return "Unlock your portfolio reminders" }
        let count = appState.openObligations.count
        if count == 0 { return "No reminders need attention" }
        return "\(count) reminder\(count == 1 ? "" : "s") need attention"
    }

    private func reminderCount(in category: BriefingResourceCategory) -> Int {
        appState.openObligations.reduce(into: 0) { count, obligation in
            if BriefingResourceCategory.category(for: obligation) == category {
                count += 1
            }
        }
    }

    private func categorySummary(
        _ category: BriefingResourceCategory,
        count: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text(category.title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(width: 108, height: 56, alignment: .leading)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.7)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.title), \(count) reminder\(count == 1 ? "" : "s")")
    }

    @ViewBuilder
    private func ownerBriefingGlass<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .clear
                        .tint(Color.zifrTabBarFill.opacity(0.28))
                        .interactive(),
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.zifrTabBarFill.opacity(0.35)))
        }
    }
}

private struct HealthCategoryCard: View {
    let summary: OwnerHealthCategorySummary
    let compact: Bool
    let onDataDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 10) {
            HStack(spacing: 8) {
                Image(systemName: summary.category.icon)
                    .font(.system(size: compact ? 12 : 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20)
                Text(summary.category.title)
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 3)
                if compact {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                } else {
                    HealthStatusBadge(status: summary.status)
                }
            }

            if compact {
                HStack(alignment: .center, spacing: 10) {
                    Text(summary.summary)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 9) {
                        ForEach(summary.metrics.prefix(3)) { metric in
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(metric.value)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.62)
                                Text(metric.label.uppercased())
                                    .font(.system(size: 6, weight: .black))
                                    .foregroundStyle(Color.white.opacity(0.28))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                    }
                }
            } else {
                Text(summary.summary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .lineLimit(3)

                HStack(alignment: .top, spacing: 14) {
                    ForEach(summary.metrics.prefix(3)) { metric in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.value)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(metric.label.uppercased())
                                .font(.system(size: 7, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(Color.white.opacity(0.3))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !compact, !summary.affectedEntityNames.isEmpty {
                Text(summary.affectedEntityNames.joined(separator: " • "))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor.opacity(0.88))
                    .lineLimit(2)
            }

            HStack(spacing: 5) {
                Text(summary.recurringSuggestions.isEmpty
                    ? summary.dataState.title
                    : "\(summary.recurringSuggestions.count) statement suggestion\(summary.recurringSuggestions.count == 1 ? "" : "s")")
                    .font(.system(size: compact ? 7 : 8, weight: .bold))
                    .foregroundStyle(summary.recurringSuggestions.isEmpty ? dataStateColor : Color.zifrGold)
                    .lineLimit(1)
                if onDataDetails != nil {
                    Spacer(minLength: 4)
                    Text("Review")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(Color.zifrGold)
                }
            }
        }
        .padding(.horizontal, compact ? 11 : 14)
        .padding(.vertical, compact ? 7 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: compact ? 62 : 0, alignment: .top)
        .background(
            Color.zifrTabBarFill.opacity(summary.requiresAttention ? 0.78 : 0.52),
            in: RoundedRectangle(cornerRadius: compact ? 16 : 19, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 16 : 19, style: .continuous)
                .stroke(statusColor.opacity(summary.requiresAttention ? 0.48 : 0.17), lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: compact ? 16 : 19, style: .continuous))
        .onTapGesture { onDataDetails?() }
        .accessibilityElement(children: .combine)
        .accessibilityHint(onDataDetails == nil ? "" : "Shows information that could be added or ignored")
    }

    private var statusColor: Color {
        switch summary.status {
        case .critical: return .red
        case .needsAttention: return .orange
        case .healthy: return .green
        case .notApplicable: return Color.white.opacity(0.3)
        }
    }

    private var dataStateColor: Color {
        switch summary.dataState {
        case .complete: return Color.green.opacity(0.64)
        case .moreDataUseful: return Color.zifrGold.opacity(0.75)
        case .noData: return Color.white.opacity(0.28)
        }
    }
}

struct MissingDataDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: OwnerHealthCategorySummary
    let onOpen: (OwnerHealthDataIssue) -> Void
    let onIgnore: (OwnerHealthDataIssue) -> Void
    let onRestore: (OwnerHealthDataIssue) -> Void

    @State private var ignoredInSheet: Set<String> = []
    @State private var lastIgnored: OwnerHealthDataIssue?

    private var visibleIssues: [OwnerHealthDataIssue] {
        summary.dataIssues.filter { !ignoredInSheet.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#141414").ignoresSafeArea()

                if visibleIssues.isEmpty {
                    ContentUnavailableView(
                        "Suggestions Cleared",
                        systemImage: "checkmark.circle.fill",
                        description: Text("There are no remaining data suggestions in this category.")
                    )
                    .foregroundStyle(.white)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            Text("Adding these details can improve the briefing. They are optional and do not affect health on their own.")
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.58))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 4)

                            ForEach(visibleIssues) { issue in
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.miloomGold.opacity(0.14))
                                            Image(systemName: summary.category.icon)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundStyle(Color.miloomGold)
                                        }
                                        .frame(width: 44, height: 44)
                                        .accessibilityHidden(true)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(issue.resourceName)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(issue.entityName)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color.white.opacity(0.48))
                                        }

                                        Spacer(minLength: 0)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("USEFUL INFORMATION")
                                            .font(.caption2.bold())
                                            .tracking(1.1)
                                            .foregroundStyle(Color.white.opacity(0.42))
                                        ForEach(issue.missingFields, id: \.self) { field in
                                            HStack(alignment: .firstTextBaseline, spacing: 9) {
                                                Circle()
                                                    .fill(Color.miloomGold)
                                                    .frame(width: 5, height: 5)
                                                Text(field)
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.white.opacity(0.74))
                                            }
                                        }
                                    }

                                    HStack(spacing: 10) {
                                        Button {
                                            onOpen(issue)
                                        } label: {
                                            Text("Add information")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color(hex: "#171914"))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 46)
                                                .background(Color.miloomGold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                _ = ignoredInSheet.insert(issue.id)
                                            }
                                            lastIgnored = issue
                                            onIgnore(issue)
                                        } label: {
                                            Text("Ignore")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.white.opacity(0.72))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 46)
                                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle(summary.category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#141414"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(summary.category.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.miloomGold)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let lastIgnored {
                HStack(spacing: 10) {
                    Text("Suggestion ignored")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Undo") {
                        ignoredInSheet.remove(lastIgnored.id)
                        onRestore(lastIgnored)
                        self.lastIgnored = nil
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.zifrGold)
                }
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#141414"))
        .preferredColorScheme(.dark)
    }
}

enum OwnerHealthDataIssueStore {
    private static let key = "ownerHealthIgnoredDataIssues"

    static func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func save(_ values: Set<String>) {
        UserDefaults.standard.set(Array(values).sorted(), forKey: key)
    }
}

struct RecurringSuggestionReview: Identifiable {
    let id = UUID()
    let suggestions: [DetectedSubscription]
}

private struct HealthStatusBadge: View {
    let status: OwnerHealthStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(status.title.uppercased())
                .font(.system(size: 8, weight: .black))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .critical: return .red
        case .needsAttention: return .orange
        case .healthy: return .green
        case .notApplicable: return Color.white.opacity(0.35)
        }
    }
}

struct OwnerBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedTab: OwnerBriefingTab = .current
    @State private var pushService = PushNotificationService.shared
    @State private var showingPreferences = false
    @State private var collapsedResourceCategories: Set<BriefingResourceCategory> = []
    @State private var collapsedAgeBuckets: Set<DeferredAgeBucket> = []
    @State private var mutatingIDs: Set<UUID> = []
    @State private var pendingDismissal: BriefingDismissalUndo?
    @State private var undoTask: Task<Void, Never>?
    @State private var mutationError: String?

    var scope: OwnerBriefingScope? = nil
    var companyID: UUID? = nil
    var onOpenResource: (PortfolioObligation) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#141414").ignoresSafeArea()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(spacing: 16) {
                        Picker("Briefing view", selection: $selectedTab) {
                            Text(OwnerBriefingPresentation.dateLabel(for: context.date)).tag(OwnerBriefingTab.current)
                            Text("Complete Later").tag(OwnerBriefingTab.completeLater)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)

                        briefingContent(now: context.date)

                        if pushService.authorizationStatus != .authorized {
                            Button {
                                Task { await pushService.enableWeeklyBriefings() }
                            } label: {
                                Label("Enable Private Weekly Briefings", systemImage: "bell.badge")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(MiloomPrimaryButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                        }
                    }
                }
            }
            .navigationTitle("Owner Briefing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#141414"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingPreferences = true } label: { Image(systemName: "bell.badge") }
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .principal) {
                    Text("Owner Briefing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.miloomGold)
                }
            }
            .task { await pushService.refreshAuthorizationStatus() }
            .sheet(isPresented: $showingPreferences) {
                BriefingPreferencesSheet()
            }
        }
        .overlay(alignment: .bottom) {
            if pendingDismissal != nil {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("Reminder dismissed")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 12)
                    Button("Undo") {
                        Task { await undoDismissal() }
                    }
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.zifrGold)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pendingDismissal?.id)
        .alert("Couldn’t Update Reminder", isPresented: Binding(
            get: { mutationError != nil },
            set: { if !$0 { mutationError = nil } }
        )) {
            Button("OK", role: .cancel) { mutationError = nil }
        } message: {
            Text(mutationError ?? "Please try again.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#141414"))
        .preferredColorScheme(.dark)
        .onDisappear { undoTask?.cancel() }
    }

    @ViewBuilder
    private func briefingContent(now: Date) -> some View {
        let visible = selectedTab == .current ? scopedOpenObligations : scopedDeferredObligations
        if visible.isEmpty {
            ContentUnavailableView(
                selectedTab == .current ? "You're Ahead" : "Nothing Deferred",
                systemImage: selectedTab == .current ? "checkmark.seal.fill" : "timer",
                description: Text(selectedTab == .current
                    ? "Nothing needs your attention right now."
                    : "Reminders moved to Complete Later will appear here.")
            )
            .foregroundStyle(.white)
        } else {
            List {
                if selectedTab == .current {
                    currentReminderSections
                } else {
                    completeLaterSections(now: now)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var currentReminderSections: some View {
        ForEach(BriefingResourceCategory.allCases) { category in
            let reminders = reminders(in: scopedOpenObligations, category: category)
            if !reminders.isEmpty {
                BriefingAccordionHeader(
                    title: category.title,
                    icon: category.icon,
                    count: reminders.count,
                    isCollapsed: collapsedResourceCategories.contains(category),
                    onToggle: { toggle(category) }
                )
                if !collapsedResourceCategories.contains(category) {
                    ForEach(reminders) { reminder in
                        reminderRow(reminder, isDeferred: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func completeLaterSections(now: Date) -> some View {
        ForEach(DeferredAgeBucket.allCases) { bucket in
            let bucketReminders = scopedDeferredObligations.filter {
                DeferredAgeBucket.bucket(
                    deferredAt: OwnerBriefingPresentation.effectiveDeferredAt(for: $0),
                    now: now
                ) == bucket
            }
            if !bucketReminders.isEmpty {
                BriefingAccordionHeader(
                    title: bucket.title,
                    icon: "calendar.badge.clock",
                    count: bucketReminders.count,
                    isCollapsed: collapsedAgeBuckets.contains(bucket),
                    onToggle: { toggle(bucket) }
                )
                if !collapsedAgeBuckets.contains(bucket) {
                    ForEach(BriefingResourceCategory.allCases) { category in
                        let reminders = reminders(in: bucketReminders, category: category)
                        if !reminders.isEmpty {
                            BriefingResourceSubheading(category: category, count: reminders.count)
                            ForEach(reminders) { reminder in
                                reminderRow(reminder, isDeferred: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scopedCompanyIDs: Set<UUID> {
        guard let scope else { return [] }
        return Set(appState.companies.filter(scope.includes).map(\.id))
    }

    private var scopedOpenObligations: [PortfolioObligation] {
        appState.openObligations.filter(matchesScope)
    }

    private var scopedDeferredObligations: [PortfolioObligation] {
        appState.deferredObligations.filter(matchesScope)
    }

    private func matchesScope(_ obligation: PortfolioObligation) -> Bool {
        let ownerID = ExecutiveBriefingSnapshot.companyID(for: obligation, in: appState)
        if let companyID, ownerID != companyID { return false }
        guard let scope else { return true }
        guard let companyID = ownerID else { return scope == .business }
        return scopedCompanyIDs.contains(companyID)
    }

    private func reminders(
        in obligations: [PortfolioObligation],
        category: BriefingResourceCategory
    ) -> [PortfolioObligation] {
        obligations.filter { BriefingResourceCategory.category(for: $0) == category }
    }

    private func toggle(_ category: BriefingResourceCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedResourceCategories.contains(category) {
                collapsedResourceCategories.remove(category)
            } else {
                collapsedResourceCategories.insert(category)
            }
        }
    }

    private func toggle(_ bucket: DeferredAgeBucket) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsedAgeBuckets.contains(bucket) {
                collapsedAgeBuckets.remove(bucket)
            } else {
                collapsedAgeBuckets.insert(bucket)
            }
        }
    }

    private func reminderRow(_ obligation: PortfolioObligation, isDeferred: Bool) -> some View {
        BriefingObligationRow(
            obligation: obligation,
            isDeferred: isDeferred,
            isBusy: mutatingIDs.contains(obligation.id),
            onOpen: {
                dismiss()
                onOpenResource(obligation)
            },
            onDismiss: { Task { await dismissObligation(obligation) } },
            onHandle: { Task { await handle(obligation) } },
            onDefer: { Task { await deferObligation(obligation) } }
        )
        .listRowBackground(Color.white.opacity(0.045))
        .listRowSeparatorTint(Color.white.opacity(0.06))
    }

    private func dismissObligation(_ obligation: PortfolioObligation) async {
        guard let original = await mutate(obligation, update: { updated in
            updated = OwnerBriefingPresentation.settingState(updated, to: .dismissed, at: Date())
        }) else { return }

        let undo = BriefingDismissalUndo(original: original)
        pendingDismissal = undo
        undoTask?.cancel()
        undoTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, pendingDismissal?.id == undo.id else { return }
            pendingDismissal = nil
        }
    }

    private func handle(_ obligation: PortfolioObligation) async {
        _ = await mutate(obligation) { updated in
            updated = OwnerBriefingPresentation.settingState(updated, to: .handled, at: Date())
        }
    }

    private func deferObligation(_ obligation: PortfolioObligation) async {
        let deferredAt = Date()
        _ = await mutate(obligation) { updated in
            updated = OwnerBriefingPresentation.deferring(updated, at: deferredAt)
        }
    }

    private func undoDismissal() async {
        guard let pendingDismissal else { return }
        undoTask?.cancel()
        self.pendingDismissal = nil
        let original = pendingDismissal.original
        _ = await mutate(original) { updated in
            updated = OwnerBriefingPresentation.restoringLifecycle(of: updated, from: original, at: Date())
        }
    }

    private func mutate(
        _ obligation: PortfolioObligation,
        update: (inout PortfolioObligation) -> Void
    ) async -> PortfolioObligation? {
        guard !mutatingIDs.contains(obligation.id),
              let index = appState.obligations.firstIndex(where: { $0.id == obligation.id }) else { return nil }

        mutatingIDs.insert(obligation.id)
        defer { mutatingIDs.remove(obligation.id) }

        let original = appState.obligations[index]
        var updated = original
        update(&updated)
        appState.obligations[index] = updated

        do {
            try await DataRepository.shared.updateObligation(updated)
            return original
        } catch {
            if let rollbackIndex = appState.obligations.firstIndex(where: { $0.id == obligation.id }) {
                appState.obligations[rollbackIndex] = original
            }
            mutationError = "Your change could not be saved. The reminder was restored."
            return nil
        }
    }
}

private struct BriefingDismissalUndo: Identifiable {
    let id = UUID()
    let original: PortfolioObligation
}

private struct BriefingAccordionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(count)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .listRowBackground(Color(hex: "#182333").opacity(0.96))
        .listRowSeparator(.hidden)
        .accessibilityLabel("\(title), \(count) reminders")
        .accessibilityHint(isCollapsed ? "Expands this category" : "Collapses this category")
    }
}

private struct BriefingResourceSubheading: View {
    let category: BriefingResourceCategory
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Text(category.title.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.48))
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))
            Spacer()
        }
        .padding(.top, 5)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

struct BriefingPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var pushService = PushNotificationService.shared
    @State private var weekday = 1
    @State private var time = Calendar.current.date(
        bySettingHour: 8,
        minute: 0,
        second: 0,
        of: Date()
    ) ?? Date()
    @State private var weeklyEnabled = true
    @State private var criticalEnabled = false
    @State private var alertRules: [AlertRule] = []
    @State private var largeTransactionThreshold = "1000"
    @State private var balanceChangeThreshold = "500"
    @State private var balanceChangePercent = "25"
    @State private var isLoadingRules = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var testMessage: String?

    private let weekdays = [
        (1, "Monday"), (2, "Tuesday"), (3, "Wednesday"), (4, "Thursday"),
        (5, "Friday"), (6, "Saturday"), (7, "Sunday")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Notification delivery") {
                    LabeledContent("In-app inbox", value: "Available")
                    Text("Inbox alerts stay inside Miloom and remain available even when iPhone push notifications are off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("iPhone push", value: permissionLabel)
                    LabeledContent("This device", value: registrationLabel)
                    if pushService.authorizationStatus == .denied {
                        Button("Open iPhone Settings") { openNotificationSettings() }
                    } else if pushService.authorizationStatus == .notDetermined {
                        Button("Enable Notifications") {
                            Task { await pushService.enableWeeklyBriefings() }
                        }
                    } else if pushService.registrationStatus == .failed || pushService.registrationStatus == .notRegistered {
                        Button("Retry Device Registration") {
                            pushService.retryDeviceRegistration()
                        }
                    }
                    Button {
                        Task { await sendTestNotification() }
                    } label: {
                        Label("Send Private Test Notification", systemImage: "bell.badge")
                    }
                    Text("Test and lock-screen notifications never include merchant names, balances, account details, credentials, or documents.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let testMessage {
                        Text(testMessage)
                            .font(.footnote)
                            .foregroundStyle(testMessage.hasPrefix("Test") ? .green : .red)
                    }
                    if pushService.registrationStatus == .failed {
                        Text("This device could not register for push delivery. Check your connection, then retry. Your in-app inbox is still available.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Weekly briefing") {
                    Toggle("Private weekly push", isOn: $weeklyEnabled)
                        .tint(.zifrBlue)
                    Picker("Day", selection: $weekday) {
                        ForEach(weekdays, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    LabeledContent("Last delivered", value: lastDeliveredLabel)
                    LabeledContent("Next scheduled", value: nextScheduledLabel)
                    Text("For a same-day test, choose a time at least 15 minutes ahead. Briefings are delivered within 15 minutes of the selected time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Immediate alerts") {
                    Toggle("Immediate high-severity alerts", isOn: $criticalEnabled)
                        .tint(.zifrBlue)
                    Text("When enabled, urgent items can send a private push before your weekly briefing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Portfolio alert rules") {
                    ForEach(AlertRuleType.allCases) { ruleType in
                        Toggle(isOn: enabledBinding(for: ruleType)) {
                            Label(ruleTitle(ruleType), systemImage: ruleIcon(ruleType))
                        }
                        .tint(.zifrBlue)

                        if ruleType == .largeTransaction && isEnabled(ruleType) {
                            HStack {
                                Text("Minimum amount")
                                Spacer()
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("1,000", text: $largeTransactionThreshold)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                            }
                        }

                        if ruleType == .balanceChange && isEnabled(ruleType) {
                            HStack {
                                Text("Minimum amount")
                                Spacer()
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("500", text: $balanceChangeThreshold)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 100)
                            }
                            HStack {
                                Text("Minimum percent")
                                Spacer()
                                TextField("25", text: $balanceChangePercent)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 80)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Transaction and balance alerts run after each successful Plaid sync and apply to newly received changes. Saving a rule does not start another sync or share additional financial data with Apple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Automation & Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving || isLoadingRules || alertRules.isEmpty)
                }
            }
            .onAppear { load() }
            .task {
                await pushService.refreshAuthorizationStatus()
                await refreshAlertRules()
            }
        }
    }

    private func load() {
        if let preferences = appState.userPreferences {
            weekday = preferences.briefingWeekday ?? 1
            weeklyEnabled = preferences.weeklyBriefingEnabled ?? true
            criticalEnabled = preferences.criticalAlertsEnabled ?? false
            if let value = preferences.briefingTime {
                let components = value.split(separator: ":").compactMap { Int($0) }
                if components.count >= 2,
                   let sameDayTime = Calendar.current.date(
                       bySettingHour: components[0],
                       minute: components[1],
                       second: 0,
                       of: Date()
                   ) {
                    time = sameDayTime
                }
            }
        }
        applyAlertRules(appState.alertRules)
    }

    private func refreshAlertRules() async {
        isLoadingRules = true
        defer { isLoadingRules = false }
        do {
            let rules = try await DataRepository.shared.fetchAlertRules()
            appState.alertRules = rules
            applyAlertRules(rules)
        } catch {
            AppDiagnostics.failure("briefing", "refresh_alert_rules", error: error)
            errorMessage = "Could not load alert rules. Pull down to retry."
        }
    }

    private func applyAlertRules(_ rules: [AlertRule]) {
        guard !rules.isEmpty else { return }
        alertRules = rules
        largeTransactionThreshold = amountString(rule(.largeTransaction)?.thresholdAmount ?? 1_000)
        balanceChangeThreshold = amountString(rule(.balanceChange)?.thresholdAmount ?? 500)
        balanceChangePercent = amountString(rule(.balanceChange)?.thresholdPercent ?? 25)
    }

    private func save() async {
        errorMessage = nil

        var largeAmount: Double?
        if isEnabled(.largeTransaction) {
            guard let value = positiveNumber(largeTransactionThreshold) else {
                errorMessage = "Enter a positive minimum amount for large transactions."
                return
            }
            largeAmount = value
        }

        var balanceAmount: Double?
        var balancePercent: Double?
        if isEnabled(.balanceChange) {
            guard let amount = positiveNumber(balanceChangeThreshold),
                  let percent = positiveNumber(balanceChangePercent),
                  percent <= 100 else {
                errorMessage = "Enter a positive balance amount and a percent from 1 to 100."
                return
            }
            balanceAmount = amount
            balancePercent = percent
        }

        isSaving = true
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let value = String(format: "%02d:%02d:00", components.hour ?? 8, components.minute ?? 0)
        if let largeAmount {
            updateRule(.largeTransaction) { $0.thresholdAmount = largeAmount }
        }
        if let balanceAmount, let balancePercent {
            updateRule(.balanceChange) {
                $0.thresholdAmount = balanceAmount
                $0.thresholdPercent = balancePercent
            }
        }
        do {
            try await DataRepository.shared.saveBriefingPreferences(
                weekday: weekday, time: value, timezone: TimeZone.current.identifier,
                weeklyEnabled: weeklyEnabled, criticalEnabled: criticalEnabled
            )
            try await DataRepository.shared.saveAlertRules(alertRules)
            appState.alertRules = alertRules
            if var preferences = appState.userPreferences {
                preferences.briefingWeekday = weekday
                preferences.briefingTime = value
                preferences.timezone = TimeZone.current.identifier
                preferences.weeklyBriefingEnabled = weeklyEnabled
                preferences.criticalAlertsEnabled = criticalEnabled
                appState.userPreferences = preferences
            }
            await MainActor.run { dismiss() }
        } catch {
            errorMessage = "Could not save your automation settings. Please try again."
        }
        isSaving = false
    }

    private var permissionLabel: String {
        switch pushService.authorizationStatus {
        case .authorized: return "Allowed"
        case .provisional: return "Quietly allowed"
        case .denied: return "Off"
        case .notDetermined: return "Not set"
        case .ephemeral: return "Temporary"
        @unknown default: return "Unknown"
        }
    }

    private var registrationLabel: String {
        switch pushService.registrationStatus {
        case .registered: return "Ready"
        case .registering: return "Registering…"
        case .notRegistered: return "Needs registration"
        case .unavailableOnSimulator: return "Physical device only"
        case .failed: return "Needs attention"
        }
    }

    private var lastDeliveredLabel: String {
        guard let delivered = appState.notifications
            .filter({ $0.notificationType == "owner_briefing" })
            .compactMap(\.createdAt)
            .max() else { return "Not yet" }
        return delivered.formatted(date: .abbreviated, time: .shortened)
    }

    private var nextScheduledLabel: String {
        guard weeklyEnabled else { return "Off" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let value = String(format: "%02d:%02d:00", components.hour ?? 8, components.minute ?? 0)
        guard let next = AutomationSchedule.nextBriefingDate(
            weekday: weekday,
            time: value,
            timezone: TimeZone.current.identifier
        ) else { return "Unavailable" }
        return next.formatted(date: .abbreviated, time: .shortened)
    }

    private func sendTestNotification() async {
        testMessage = nil
        let scheduled = await pushService.sendPrivateTestNotification()
        testMessage = scheduled ? "Test notification scheduled." : (pushService.lastError ?? "Could not schedule the test notification.")
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func rule(_ type: AlertRuleType) -> AlertRule? {
        alertRules.first { $0.ruleType == type }
    }

    private func isEnabled(_ type: AlertRuleType) -> Bool {
        rule(type)?.enabled ?? false
    }

    private func enabledBinding(for type: AlertRuleType) -> Binding<Bool> {
        Binding(
            get: { isEnabled(type) },
            set: { enabled in updateRule(type) { $0.enabled = enabled } }
        )
    }

    private func updateRule(_ type: AlertRuleType, mutation: (inout AlertRule) -> Void) {
        guard let index = alertRules.firstIndex(where: { $0.ruleType == type }) else { return }
        mutation(&alertRules[index])
    }

    private func positiveNumber(_ value: String) -> Double? {
        let normalized = value.replacingOccurrences(of: ",", with: "")
        guard let number = Double(normalized), number > 0 else { return nil }
        return number
    }

    private func amountString(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private func ruleTitle(_ type: AlertRuleType) -> String {
        switch type {
        case .largeTransaction: return "Large transactions"
        case .possibleDuplicate: return "Possible duplicate charges"
        case .unusualSpending: return "Unusual spending"
        case .balanceChange: return "Large balance changes"
        case .upcomingPayment: return "Upcoming payments"
        case .expiringItem: return "Expiring cards & documents"
        case .disconnectedInstitution: return "Disconnected institutions"
        }
    }

    private func ruleIcon(_ type: AlertRuleType) -> String {
        switch type {
        case .largeTransaction: return "dollarsign.circle"
        case .possibleDuplicate: return "square.on.square"
        case .unusualSpending: return "waveform.path.ecg"
        case .balanceChange: return "chart.line.uptrend.xyaxis"
        case .upcomingPayment: return "calendar.badge.clock"
        case .expiringItem: return "calendar.badge.exclamationmark"
        case .disconnectedInstitution: return "link.badge.plus"
        }
    }
}

private struct BriefingObligationRow: View {
    let obligation: PortfolioObligation
    let isDeferred: Bool
    let isBusy: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void
    let onHandle: () -> Void
    let onDefer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(obligation.title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text(obligation.summary).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.55))
                        if let dueAt = obligation.dueAt {
                            Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(color)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the related resource")

            HStack(spacing: 10) {
                BriefingIconAction(
                    icon: "xmark",
                    label: "Dismiss reminder",
                    tint: .red,
                    action: onDismiss
                )
                BriefingIconAction(
                    icon: "checkmark",
                    label: "Mark as handled",
                    tint: .green,
                    action: onHandle
                )
                BriefingIconAction(
                    icon: "timer",
                    label: isDeferred ? "Restart Complete Later age" : "Complete later",
                    tint: Color.zifrGold,
                    action: onDefer
                )
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.45 : 1)
        }
        .padding(.vertical, 6)
    }

    private var color: Color {
        switch obligation.severity {
        case .urgent: return .red
        case .attention: return .orange
        case .info: return Color.zifrGold
        }
    }

    private var icon: String {
        switch obligation.sourceType {
        case .subscription: return "arrow.triangle.2.circlepath"
        case .institution: return "building.columns.fill"
        case .card: return "creditcard.fill"
        case .loan: return "banknote.fill"
        case .document: return "doc.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
}

private struct BriefingIconAction: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ResourceConnectionsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    let reference: ResourceReference
    var onOpen: ((ResourceReference) -> Void)? = nil

    @State private var showingUpgrade = false
    @State private var showingManualConnection = false

    private var connections: [ResourceConnection] {
        PortfolioConnectionEngine.connections(for: reference, in: appState)
    }

    private var connectedTo: [ResourceConnection] {
        connections.filter { $0.source == reference }
    }

    private var usedBy: [ResourceConnection] {
        connections.filter { $0.target == reference }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("RELATIONSHIPS", systemImage: "link")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                if !accessController.isPro {
                    Text("PRO").font(.system(size: 9, weight: .black)).foregroundStyle(Color.zifrGold)
                } else {
                    Button {
                        showingManualConnection = true
                    } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.zifrGold)
                    }
                    .buttonStyle(.plain)
                }
            }

            if accessController.isPro {
                if connections.isEmpty {
                    Text("No connections yet. Add one or let Miloom suggest relationships as your portfolio grows.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if !connectedTo.isEmpty {
                        relationshipGroup("CONNECTED TO", values: connectedTo)
                    }
                    if !usedBy.isEmpty {
                        relationshipGroup("USED BY", values: usedBy)
                    }
                }
            } else {
                Button {
                    _ = accessController.request(.connectedPortfolio, source: "resource_connections", appState: appState, userId: authVM.currentUser?.id)
                    showingUpgrade = true
                } label: {
                    HStack {
                        Text("See what this is connected to and what depends on it.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Spacer()
                        Image(systemName: "lock.fill").foregroundStyle(Color.zifrGold)
                    }
                    .padding(13)
                    .background(Color.zifrGold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.07)))
        .sheet(isPresented: $showingUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
        .sheet(isPresented: $showingManualConnection) {
            ManualConnectionSheet(source: reference)
        }
    }

    @ViewBuilder
    private func relationshipGroup(_ title: String, values: [ResourceConnection]) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .black))
            .tracking(1)
            .foregroundStyle(Color.white.opacity(0.36))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        ForEach(values) { connection in
            ConnectionRow(
                connection: connection,
                reference: reference,
                onOpen: onOpen,
                onConfirm: { setState(connection, .confirmed) },
                onReject: { setState(connection, .rejected) }
            )
        }
    }

    private func setState(_ connection: ResourceConnection, _ state: ConnectionState) {
        guard let index = appState.resourceConnections.firstIndex(where: { $0.id == connection.id }) else { return }
        var updated = connection
        updated.state = state
        updated.updatedAt = Date()
        appState.resourceConnections[index] = updated
        Task { try? await DataRepository.shared.updateConnection(updated) }
    }
}

private struct ConnectionRow: View {
    @Environment(AppState.self) private var appState
    let connection: ResourceConnection
    let reference: ResourceReference
    let onOpen: ((ResourceReference) -> Void)?
    let onConfirm: () -> Void
    let onReject: () -> Void

    private var other: ResourceReference {
        PortfolioConnectionEngine.otherReference(in: connection, from: reference)
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: resourceIcon(other.kind))
                .foregroundStyle(Color.zifrGold)
                .frame(width: 24)
            Button {
                onOpen?(other)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.relationshipType.label.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.38))
                    Text(PortfolioConnectionEngine.displayName(for: other, appState: appState))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if connection.state == .suggested {
                Button(action: onReject) { Image(systemName: "xmark.circle") }
                    .foregroundStyle(Color.white.opacity(0.42))
                Button(action: onConfirm) { Image(systemName: "checkmark.circle.fill") }
                    .foregroundStyle(.green)
            } else if onOpen != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
    }
}

struct ManualConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM

    let source: ResourceReference
    @State private var relationship: ConnectionRelationship = .dependsOn
    @State private var target: ResourceReference?
    @State private var isSaving = false

    private var candidates: [ResourceReference] {
        var values = appState.companies.map { ResourceReference(kind: .company, resourceId: $0.id) }
        values += appState.subscriptions.map { ResourceReference(kind: .subscription, resourceId: $0.id) }
        values += appState.institutions.map { ResourceReference(kind: .institution, resourceId: $0.id) }
        values += appState.cards.map { ResourceReference(kind: .card, resourceId: $0.id) }
        values += appState.loans.map { ResourceReference(kind: .loan, resourceId: $0.id) }
        values += appState.documents.map { ResourceReference(kind: .document, resourceId: $0.id) }
        return values.filter { $0 != source }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Relationship", selection: $relationship) {
                    ForEach(ConnectionRelationship.allCases, id: \.self) { relation in
                        Text(relation.label).tag(relation)
                    }
                }
                Section("Connect to") {
                    ForEach(candidates) { candidate in
                        Button {
                            target = candidate
                        } label: {
                            HStack {
                                Image(systemName: resourceIcon(candidate.kind))
                                Text(PortfolioConnectionEngine.displayName(for: candidate, appState: appState))
                                Spacer()
                                if target == candidate { Image(systemName: "checkmark").foregroundStyle(Color.zifrGold) }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#141414"))
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#141414"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Connection")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") { Task { await save() } }
                        .disabled(target == nil || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#141414"))
        .preferredColorScheme(.dark)
    }

    private func save() async {
        guard let target, let ownerId = authVM.currentUser?.id else { return }
        isSaving = true
        let connection = ResourceConnection(
            ownerUserId: ownerId,
            sourceType: source.kind, sourceId: source.resourceId,
            targetType: target.kind, targetId: target.resourceId,
            relationshipType: relationship,
            origin: .manual, confidence: 1, state: .confirmed
        )
        do {
            try await DataRepository.shared.insertConnection(connection)
            appState.resourceConnections.append(connection)
            dismiss()
        } catch {
            appState.error = "Failed to add connection."
        }
        isSaving = false
    }
}

private func resourceIcon(_ kind: ResourceKind) -> String {
    switch kind {
    case .company: return "building.2.fill"
    case .subscription: return "arrow.triangle.2.circlepath"
    case .institution: return "building.columns.fill"
    case .card: return "creditcard.fill"
    case .loan: return "banknote.fill"
    case .document: return "doc.fill"
    case .collaborator: return "person.fill"
    }
}

struct DowngradeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AccessController.self) private var accessController

    @State private var companyId: UUID?
    @State private var plaidItemId: UUID?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var activeItems: [PlaidItemSummary] {
        appState.plaidItems.filter { $0.status == "active" }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your data stays safe. Choose the company and live bank connection that remain editable on Free; everything else becomes read-only.")
                }

                Section("Editable company") {
                    Picker("Company", selection: $companyId) {
                        ForEach(appState.companies) { company in
                            Text(company.name).tag(Optional(company.id))
                        }
                    }
                    .pickerStyle(.inline)
                }

                if activeItems.count > 1 {
                    Section("Live institution") {
                        Picker("Institution", selection: $plaidItemId) {
                            ForEach(activeItems) { item in
                                Text(item.institutionName ?? "Connected institution").tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#141414"))
            .navigationTitle("Choose Free Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#141414"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Choose Free Access")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.miloomGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Continue") {
                        Task { await save() }
                    }
                    .disabled(companyId == nil || (activeItems.count > 1 && plaidItemId == nil) || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color(hex: "#141414"))
        .preferredColorScheme(.dark)
        .onAppear {
            companyId = accessController.snapshot.selectedFreeCompanyId ?? appState.companies.first?.id
            plaidItemId = accessController.snapshot.selectedFreePlaidItemId ?? activeItems.first?.id
        }
        .interactiveDismissDisabled()
    }

    private func save() async {
        guard let companyId else { return }
        isSaving = true
        do {
            try await accessController.selectFreeResources(companyId: companyId, plaidItemId: plaidItemId)
            dismiss()
        } catch {
            errorMessage = "Could not save your Free access selection. Please try again."
        }
        isSaving = false
    }
}
