import SwiftUI

struct OwnerBriefingCard: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authVM
    @Environment(AccessController.self) private var accessController

    var onOpenResource: (PortfolioObligation) -> Void

    @State private var showingBriefing = false
    @State private var showingUpgrade = false

    private var visibleObligations: [PortfolioObligation] {
        Array(appState.openObligations.prefix(3))
    }

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
                HStack(spacing: 10) {
                    Image(systemName: "checklist.checked")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OWNER BRIEFING")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.4)
                            .foregroundStyle(.white)
                        Text(accessController.isPro ? "What needs attention across your portfolio" : "Your connected portfolio preview")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    if !accessController.isPro {
                        Text("PRO")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.zifrGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.zifrGold.opacity(0.12))
                            .clipShape(Capsule())
                    } else if appState.unreadBriefingCount > 0 {
                        Text("\(appState.unreadBriefingCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 26, minHeight: 26)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.35))
                }

                if accessController.isPro {
                    if visibleObligations.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Nothing urgent. Your portfolio is up to date.")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    } else {
                        VStack(spacing: 9) {
                            ForEach(visibleObligations) { obligation in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(color(for: obligation.severity))
                                        .frame(width: 7, height: 7)
                                    Text(obligation.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.78))
                                        .lineLimit(1)
                                    Spacer()
                                    if let due = obligation.dueAt {
                                        Text(due, style: .relative)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("Miloom found \(appState.confirmedConnectionCount + appState.suggestedConnectionCount) connections and \(appState.openObligations.count) upcoming items. Upgrade to see your complete portfolio briefing.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#182333").opacity(0.96), Color(hex: "#11161E").opacity(0.96)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.zifrGold.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingBriefing) {
            OwnerBriefingView(onOpenResource: onOpenResource)
        }
        .sheet(isPresented: $showingUpgrade) {
            PremiumUpgradeView(gate: accessController.pendingGate)
        }
    }

    private func color(for severity: ObligationSeverity) -> Color {
        switch severity {
        case .urgent: return .red
        case .attention: return .orange
        case .info: return Color.zifrGold
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

    var onOpenResource: (PortfolioObligation) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.zifrBG.ignoresSafeArea()
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingPreferences = true } label: { Image(systemName: "bell.badge") }
                        .foregroundStyle(Color.zifrGold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.zifrGold)
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
        .onDisappear { undoTask?.cancel() }
    }

    @ViewBuilder
    private func briefingContent(now: Date) -> some View {
        let visible = selectedTab == .current ? appState.openObligations : appState.deferredObligations
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
            let reminders = reminders(in: appState.openObligations, category: category)
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
            let bucketReminders = appState.deferredObligations.filter {
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

    private func reminders(
        in obligations: [PortfolioObligation],
        category: BriefingResourceCategory
    ) -> [PortfolioObligation] {
        obligations.filter { BriefingResourceCategory.category(for: $0.sourceType) == category }
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
                    .foregroundStyle(Color.zifrGold)
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
                .foregroundStyle(Color.zifrGold.opacity(0.75))
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

private struct BriefingPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var weekday = 1
    @State private var time = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    @State private var weeklyEnabled = true
    @State private var criticalEnabled = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let weekdays = [
        (1, "Monday"), (2, "Tuesday"), (3, "Wednesday"), (4, "Thursday"),
        (5, "Friday"), (6, "Saturday"), (7, "Sunday")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Weekly briefing") {
                    Toggle("Private weekly push", isOn: $weeklyEnabled)
                    Picker("Day", selection: $weekday) {
                        ForEach(weekdays, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }
                Section("Important changes") {
                    Toggle("Immediate high-severity alerts", isOn: $criticalEnabled)
                    Text("Lock-screen notifications only show the number of items. Names, balances, credentials, and documents stay inside Miloom.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
            }
            .navigationTitle("Briefing Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let preferences = appState.userPreferences else { return }
        weekday = preferences.briefingWeekday ?? 1
        weeklyEnabled = preferences.weeklyBriefingEnabled ?? true
        criticalEnabled = preferences.criticalAlertsEnabled ?? false
        if let value = preferences.briefingTime {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            time = formatter.date(from: value) ?? time
        }
    }

    private func save() async {
        isSaving = true
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let value = String(format: "%02d:%02d:00", components.hour ?? 8, components.minute ?? 0)
        do {
            try await DataRepository.shared.saveBriefingPreferences(
                weekday: weekday, time: value, timezone: TimeZone.current.identifier,
                weeklyEnabled: weeklyEnabled, criticalEnabled: criticalEnabled
            )
            await MainActor.run { dismiss() }
        } catch {
            errorMessage = "Could not save your briefing schedule."
        }
        isSaving = false
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
            .background(Color.zifrBG)
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") { Task { await save() } }
                        .disabled(target == nil || isSaving)
                }
            }
        }
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
            .background(Color.zifrBG)
            .navigationTitle("Choose Free Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Continue") {
                        Task { await save() }
                    }
                    .disabled(companyId == nil || (activeItems.count > 1 && plaidItemId == nil) || isSaving)
                }
            }
        }
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
