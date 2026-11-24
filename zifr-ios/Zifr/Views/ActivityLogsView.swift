import SwiftUI

struct ActivityLogsView: View {
    @Bindable var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var isSelecting: Bool = false
    @State private var selectedLogIDs: Set<UUID> = []
    @State private var feedback: MessageFeedback? = nil

    private var unreadCount: Int {
        appState.activityLogs.filter { !$0.isRead }.count
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.zifrCard.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.70))
                            )
                            .background(.regularMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.vaultOutline, lineWidth: 1.5)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 3) {
                        Text("MESSAGES")
                            .font(.system(size: 10, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Color.white.opacity(0.65))

                        Text(unreadCount == 1 ? "1 UNREAD" : "\(unreadCount) UNREAD")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color(hex: "#C1AA78"))
                    }
                    
                    Spacer()
                    
                    if isSelecting {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation {
                                isSelecting = false
                                selectedLogIDs.removeAll()
                            }
                        } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: "#C1AA78"))
                        }
                        .frame(width: 44, height: 44)
                    } else if !appState.activityLogs.isEmpty {
                        Menu {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation {
                                    isSelecting = true
                                }
                            } label: {
                                Label("Select Messages", systemImage: "checkmark.circle")
                            }
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                Task {
                                    try? await DataRepository.shared.markAllActivityLogsRead()
                                    await DataRepository.shared.fetchAllData(appState: appState)
                                }
                            } label: {
                                Label("Mark All as Read", systemImage: "envelope.open")
                            }
                            .disabled(unreadCount == 0)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.70))
                                )
                                .background(.regularMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.vaultOutline, lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                if appState.activityLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color(hex: "#C1AA78").opacity(0.75))
                        Text("No messages yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.activityLogs) { log in
                                HStack(spacing: 12) {
                                    if isSelecting {
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            if selectedLogIDs.contains(log.id) {
                                                selectedLogIDs.remove(log.id)
                                            } else {
                                                selectedLogIDs.insert(log.id)
                                            }
                                        } label: {
                                            Image(systemName: selectedLogIDs.contains(log.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 24))
                                                .foregroundStyle(selectedLogIDs.contains(log.id) ? Color(hex: "#C1AA78") : Color.white.opacity(0.3))
                                        }
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                    
                                    MessageRowView(log: log, vm: vm)
                                        .modifier(ZifrMessageSwipeModifier(
                                            onReadToggle: {
                                                Task {
                                                    if log.isRead {
                                                        try? await DataRepository.shared.markActivityLogUnread(log.id)
                                                    } else {
                                                        try? await DataRepository.shared.markActivityLogRead(log.id)
                                                    }
                                                    await DataRepository.shared.fetchAllData(appState: appState)
                                                }
                                            },
                                            onDelete: {
                                                deleteMessage(log)
                                            },
                                            isRead: log.isRead
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
                
                if isSelecting && !selectedLogIDs.isEmpty {
                    VStack {
                        Divider().background(Color.white.opacity(0.1))
                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            let ids = Array(selectedLogIDs)
                            Task {
                                try? await DataRepository.shared.deleteActivityLogs(ids: ids)
                                await MainActor.run {
                                    selectedLogIDs.removeAll()
                                    isSelecting = false
                                }
                                await DataRepository.shared.fetchAllData(appState: appState)
                            }
                        } label: {
                            Text("Delete Selected (\(selectedLogIDs.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(hex: "#171717").ignoresSafeArea(edges: .bottom))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let feedback {
                HStack(spacing: 10) {
                    Image(systemName: feedback.systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(feedback.tint)

                    Text(feedback.message)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.70))
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.vaultOutline, lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.bottom, isSelecting && !selectedLogIDs.isEmpty ? 92 : 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func deleteMessage(_ log: ActivityLog) {
        guard let originalIndex = appState.activityLogs.firstIndex(where: { $0.id == log.id }) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            appState.activityLogs.remove(at: originalIndex)
        }
        showFeedback("Deleting message…", systemImage: "trash", tint: Color(hex: "#C1AA78"))

        Task {
            do {
                try await DataRepository.shared.deleteActivityLog(log.id)
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showFeedback("Message deleted", systemImage: "checkmark.circle.fill", tint: Color(hex: "#C1AA78"))
                }
            } catch {
                await MainActor.run {
                    let restoredIndex = min(originalIndex, appState.activityLogs.count)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        appState.activityLogs.insert(log, at: restoredIndex)
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    showFeedback("Couldn’t delete message", systemImage: "exclamationmark.triangle.fill", tint: .red)
                }
            }
        }
    }

    private func showFeedback(_ message: String, systemImage: String, tint: Color) {
        let newFeedback = MessageFeedback(message: message, systemImage: systemImage, tint: tint)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            feedback = newFeedback
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard feedback?.id == newFeedback.id else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                feedback = nil
            }
        }
    }
}

private struct MessageFeedback: Identifiable {
    let id = UUID()
    let message: String
    let systemImage: String
    let tint: Color
}

struct MessageRowView: View {
    let log: ActivityLog
    let vm: AppViewModel
    var usesReportRowStyle = false
    var showsMarkReadButton = true
    @Environment(AppState.self) private var appState

    @ViewBuilder
    var body: some View {
        if usesReportRowStyle {
            row.padding(.vertical, 12)
        } else {
            row
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black.opacity(0.70))
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#918457"),
                                    Color(hex: "#918457").opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
        }
    }

    private var row: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(titleForAction(log.actionType))
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "#C1AA78"))
                    .textCase(.uppercase)

                if !log.isRead {
                    Circle()
                        .fill(Color(hex: "#C1AA78"))
                        .frame(width: 6, height: 6)
                }

                Spacer()
                Text(timeAgo(log.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Text(log.message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(log.isRead ? 0.58 : 0.82))
                .fixedSize(horizontal: false, vertical: true)
            
            if showsMarkReadButton && !log.isRead {
                HStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            try? await DataRepository.shared.markActivityLogRead(log.id)
                            await DataRepository.shared.fetchAllData(appState: appState)
                        }
                    } label: {
                        Label("MARK READ", systemImage: "envelope.open")
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(Color(hex: "#C1AA78"))
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(Color(hex: "#C1AA78").opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#C1AA78").opacity(0.32), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func titleForAction(_ type: String) -> String {
        switch type {
        case "shared": return "New Share"
        case "left_resource": return "User Left"
        case "updated_company", "updated_subscription", "updated_card", "updated_institution", "updated_loan", "updated_document": return "Resource Updated"
        case "new_device": return "New Login"
        case "security_alert": return "Security Alert"
        default: return "Activity"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private let inboxRowIconTint = Color(hex: "#A8D5B8")

private struct InboxRowActions: ViewModifier {
    let isRead: Bool
    let markRead: () -> Void
    let markUnread: () -> Void
    let delete: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(ZifrMessageSwipeModifier(
                onReadToggle: markRead, onDelete: delete, isRead: isRead, markReadOnly: true
            ))
            .contextMenu {
                Button(action: isRead ? markUnread : markRead) {
                    Label(isRead ? "Mark Unread" : "Mark as Read",
                          systemImage: isRead ? "envelope.badge" : "envelope.open")
                }
                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

private enum InboxSection: String, CaseIterable {
    case alerts = "Alerts"
    case invitations = "Invites"
    case activity = "Activity"
}

private struct InboxSectionPicker: UIViewRepresentable {
    @Binding var selection: InboxSection

    final class PickerContainer: UIView {
        let control = UISegmentedControl(items: InboxSection.allCases.map(\.rawValue))

        override init(frame: CGRect) {
            super.init(frame: frame)

            // The app's segmented-control appearance also applies to UIKit views hosted by SwiftUI.
            let appearance = UISegmentedControl.appearance(whenContainedInInstancesOf: [PickerContainer.self])
            appearance.selectedSegmentTintColor = nil
            appearance.backgroundColor = nil
            appearance.setTitleTextAttributes(nil, for: .normal)
            appearance.setTitleTextAttributes(nil, for: .selected)

            control.accessibilityLabel = "Inbox section"
            control.translatesAutoresizingMaskIntoConstraints = false
            addSubview(control)
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(equalTo: leadingAnchor),
                control.trailingAnchor.constraint(equalTo: trailingAnchor),
                control.topAnchor.constraint(equalTo: topAnchor),
                control.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        required init?(coder: NSCoder) { nil }
    }

    final class Coordinator: NSObject {
        var selection: Binding<InboxSection>

        init(selection: Binding<InboxSection>) {
            self.selection = selection
        }

        @objc func selectSection(_ control: UISegmentedControl) {
            let sections = InboxSection.allCases
            guard sections.indices.contains(control.selectedSegmentIndex) else { return }
            selection.wrappedValue = sections[control.selectedSegmentIndex]
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> PickerContainer {
        let container = PickerContainer(frame: .zero)
        container.control.addTarget(
            context.coordinator, action: #selector(Coordinator.selectSection(_:)), for: .valueChanged
        )
        return container
    }

    func updateUIView(_ view: PickerContainer, context: Context) {
        context.coordinator.selection = $selection
        let index = InboxSection.allCases.firstIndex(of: selection) ?? 0
        if view.control.selectedSegmentIndex != index {
            view.control.selectedSegmentIndex = index
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PickerContainer, context: Context) -> CGSize? {
        let intrinsicSize = uiView.control.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsicSize.width, height: max(44, intrinsicSize.height))
    }
}

private struct InboxOlderMessagesButton: View {
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 10) {
                Text("Older messages")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                DisclosureStateChevron(isExpanded: isExpanded)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

private struct InboxAlertDetails: View {
    let notification: AppNotification
    let receivedTime: String
    var dueOn: String?
    var actionLabel: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        let payment = InboxScheduledPayment(notification, timeZone: timeZone, dueOn: dueOn)
        let subject = HStack(spacing: 6) {
            Text(payment?.name ?? notification.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            if !notification.isRead {
                Circle().fill(Color.zifrGold).frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        let subtitle = Group {
            if let payment {
                Text("\(payment.kind) · \(payment.date, format: .dateTime.month(.abbreviated).day().year())")
            } else {
                Text(notification.body)
            }
        }
        .font(.footnote)
        .foregroundStyle(Color.white.opacity(notification.isRead ? 0.64 : 0.78))
        let timing = Group {
            if let payment {
                TimelineView(.everyMinute) { clock in
                    countdown(payment.daysUntil(from: clock.date, calendar: localCalendar))
                }
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color.zifrGold)
                .fixedSize(horizontal: true, vertical: false)
            } else if !receivedTime.isEmpty {
                Text(receivedTime)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .fixedSize(horizontal: true, vertical: false)
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                subject
                subtitle
                timing
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    subject
                    Spacer(minLength: 0)
                    timing
                }
                subtitle
            }
            if let actionLabel {
                Text(actionLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.zifrGold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? "" : "Unread")
    }

    private var localCalendar: Calendar {
        var value = calendar
        value.timeZone = timeZone
        return value
    }

    private func countdown(_ days: Int) -> Text {
        switch days {
        case 0: Text("Today")
        case 1: Text("Tomorrow")
        case -1: Text("Yesterday")
        case 2...: Text("In \(days) days")
        default: Text("\(-days) days ago")
        }
    }
}

private struct InboxSubscriptionPaymentDrawer: View {
    let notification: AppNotification
    let payment: InboxScheduledPayment
    let openRoute: (NotificationRoute) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.calendar) private var calendar
    @State private var lastCharge: SearchRecord?

    static let fill = Color(hex: "#20463E")

    private var subscription: Subscription? {
        guard appState.portfolioUserID == notification.userId,
              let id = notification.resourceId else { return nil }
        return appState.subscriptions.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let subscription {
                let context = funding(for: subscription)
                let currency = ExecutiveBriefingSnapshot.currency(subscription.currency)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        expectedCharge(context, currency: currency)
                        Spacer(minLength: 4)
                        coverageLabel(context, currency: currency).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        expectedCharge(context, currency: currency)
                        coverageLabel(context, currency: currency)
                    }
                }

                if let group = context.group, group.fundingRoute != nil {
                    fact("Payment account", context.paymentRoute ?? [group.sourceDetail, group.sourceName]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    if let card = context.paymentRoute {
                        let account = [group.sourceDetail, group.sourceName].filter { !$0.isEmpty }.joined(separator: " · ")
                        if account != card { fact("Funding account", account) }
                    }
                    if let available = group.availableAmount, context.hasReliableBalance {
                        fact(group.availableLabel, available.formatted(.currency(code: currency)))
                    }
                } else {
                    fact("Payment account", "Unverified")
                    if let charge = lastCharge {
                        let account = charge.accountName
                        if !account.isEmpty, account != "Unassigned account" {
                            let bank = charge.safeDetails["institution"] ?? ""
                            fact("Last charged to", [bank, account].filter { !$0.isEmpty }.joined(separator: " · "))
                        }
                    }
                }

                if !context.matchesAlertSchedule, let renewal = subscription.nextRenewalAt {
                    fact("Next renewal", renewal.formatted(.dateTime.month(.abbreviated).day().year()))
                }
                fact("Auto-pay", autoPay(for: subscription.renew))
                if let charge = lastCharge, let amount = charge.amount, let day = charge.date {
                    fact("Last charge", "\(amount.formatted(.currency(code: charge.currency))) · \(day.formatted(.dateTime.month(.abbreviated).day()))")
                }

                if let reason = context.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                if let group = context.group, group.charges.count > 1, context.reason == nil {
                    Text("Includes \(group.charges.count) saved charges through \(payment.date.formatted(.dateTime.month(.abbreviated).day())).")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                if let syncedAt = context.group?.balanceSyncedAt {
                    Text("Balance synced \(syncedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if context.matchesAlertSchedule, let route = context.group?.fundingRoute,
                   context.reason != nil || context.group?.status == .atRisk {
                    action("Review payment account", route: route)
                } else {
                    action("Open subscription", route: .subscriptionInServices(subscription.id))
                }
            } else {
                Text(appState.isLoading ? "Loading subscription details…" : "Subscription details are unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: appState.searchRevision) { await loadLastCharge() }
    }

    private func expectedCharge(_ context: InboxSubscriptionFunding, currency: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.matchesAlertSchedule ? "Expected charge" : "Saved charge")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            Text(context.amount.map { $0.formatted(.currency(code: currency)) } ?? "Unavailable")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private func coverageLabel(_ context: InboxSubscriptionFunding, currency: String) -> some View {
        let label: String
        let icon: String
        let color: Color
        let conditionalDate = context.matchesAlertSchedule
            ? ""
            : " if charged \(payment.date.formatted(.dateTime.month(.abbreviated).day()))"
        switch context.estimate {
        case .unknown:
            label = "Coverage unknown"
            icon = "questionmark.circle"
            color = .white.opacity(0.78)
        case .likelyShort(let shortfall):
            label = "Likely \(shortfall.formatted(.currency(code: currency))) short\(conditionalDate)"
            icon = "exclamationmark.circle"
            color = Color(hex: "#F0BC91")
        case .tight:
            label = "Tight\(conditionalDate)"
            icon = "exclamationmark.circle"
            color = Color(hex: "#F0BC91")
        case .likelyCovered:
            label = "Likely covered\(conditionalDate)"
            icon = "checkmark.circle"
            color = .white.opacity(0.92)
        }
        return Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider().overlay(.white.opacity(0.12))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label).foregroundStyle(.white.opacity(0.75)).fixedSize()
                    Spacer(minLength: 6)
                    Text(value).multilineTextAlignment(.trailing).fixedSize()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).foregroundStyle(.white.opacity(0.75))
                    Text(value)
                }
            }
            .font(.footnote)
            .monospacedDigit()
            .accessibilityElement(children: .combine)
        }
    }

    private func action(_ label: String, route: NotificationRoute) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(.white.opacity(0.12))
            Button { openRoute(route) } label: {
                HStack(spacing: 8) {
                    Text(label).font(.footnote.weight(.semibold))
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.zifrGold)
        }
    }

    private func autoPay(for setting: String) -> String {
        switch setting.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "auto", "automatic", "on", "yes": "On · Saved setting"
        case "manual", "off", "no": "Off · Saved setting"
        default: "Unknown"
        }
    }

    private func funding(for subscription: Subscription) -> InboxSubscriptionFunding {
        let companyID = appState.localCompanyOverrides[subscription.id.uuidString] ?? subscription.companyId
        let sameCompanyBanks = appState.institutions(for: companyID)
        let sameCompanyCards = appState.cards(for: companyID)
        let companySubscriptions = appState.subscriptions(for: companyID)
        let bankIDs = Set(sameCompanyBanks.map(\.id))
        let cardIDs = Set(sameCompanyCards.map(\.id))
        let subscriptionIDs = Set(companySubscriptions.map(\.id))
        let plaidID = subscription.plaidAccountId.flatMap { $0.isEmpty ? nil : $0 }
        let savedID = subscription.paymentMethodId

        // The payment picker supports explicitly selecting an account from another
        // visible entity. Name-only matching stays within the subscription's entity.
        let linkedCards = appState.cards.filter { card in
            (card.id == savedID || (plaidID != nil && card.plaidAccountId == plaidID))
        }
        let linkedCardIDs = Set(linkedCards.map(\.id))
        let linkedBanks = appState.institutions.filter { bank in
            bank.id == savedID || bank.accounts.contains { account in
                (plaidID != nil && (account.plaidAccountId == plaidID || account.id == plaidID))
                    || account.linkedCardId.flatMap(UUID.init(uuidString:)).map(linkedCardIDs.contains) == true
            }
        }
        let linkedMethodIDs = Set(linkedBanks.map(\.id)).union(linkedCardIDs)
        let relatedSubscriptions = appState.subscriptions.filter { other in
            !subscriptionIDs.contains(other.id) && (
                other.paymentMethodId.map(linkedMethodIDs.contains) == true
                    || (plaidID != nil && other.plaidAccountId == plaidID)
            )
        }

        let fundingBanks = sameCompanyBanks + linkedBanks.filter { !bankIDs.contains($0.id) }
        let fundingCards = sameCompanyCards + linkedCards.filter { !cardIDs.contains($0.id) }
        let availableMethodIDs = Set(fundingBanks.map(\.id)).union(fundingCards.map(\.id))
        let projectedSubscriptions = (companySubscriptions + relatedSubscriptions).filter { other in
            // An old Plaid hint should not pull a charge with an explicit
            // payment source outside this projection into the balance estimate.
            other.paymentMethodId.map(availableMethodIDs.contains) ?? true
        }

        return UpcomingCoverageEngine.inboxFunding(
            subscription: subscription, payment: payment, subscriptions: projectedSubscriptions,
            institutions: fundingBanks, cards: fundingCards, plaidItems: appState.plaidItems, calendar: calendar
        )
    }

    @MainActor
    private func loadLastCharge() async {
        lastCharge = nil
        guard let subscription, !appState.transactions.isEmpty else { return }
        let userID = notification.userId
        guard let index = try? await appState.searchIndexInBackground(for: userID, calendar: calendar) else { return }
        let id = subscription.id
        let cutoff = Date()
        let result = await Task.detached(priority: .utility) {
            index.latestPostedInboxCharge(subscriptionID: id, before: cutoff)
        }.value
        guard !Task.isCancelled, appState.portfolioUserID == userID else { return }
        lastCharge = result
    }
}

struct NotificationInboxView: View {
    enum Presentation {
        case sheet, duoDrawer
    }

    @Bindable var vm: AppViewModel
    var presentation: Presentation = .sheet
    let onOpenRoute: (NotificationRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.timeZone) private var timeZone
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedSubscriptionAlertID: UUID?
    @State private var expandedHistory: Set<InboxSection> = []
    @State private var currentDate = Date()
    @State private var inboxRefreshID = UUID()
    @State private var inboxContext: InboxContext?
    @State private var inboxActivity: [ActivityLog]?
    @State private var localOutcomes: [InboxInvitationOutcome] = []
    @State private var section: InboxSection = .alerts
    @State private var updatingRows: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var incomingInvitations: [IncomingResourceInvitation] = []
    @State private var invitationInProgress: UUID?
    @State private var decliningInvitation: IncomingResourceInvitation?
    @AccessibilityFocusState private var headingFocused: Bool

    private var alertCalendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        let configured = inboxContext?.timeZone ?? appState.userPreferences?.timezone
        value.timeZone = configured.flatMap(TimeZone.init(identifier:)) ?? timeZone
        return value
    }

    private var liveBankIssues: [Institution] {
        let broken = Set(appState.plaidItems.filter(\.requiresReconnect).compactMap(\.institutionId))
        return appState.institutions.filter { $0.isDisconnected || broken.contains($0.id) }
    }

    private var alertMetadata: [UUID: InboxAlertMetadata] {
        Dictionary((inboxContext?.alerts ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var activityRecords: [ActivityLog] { inboxActivity ?? appState.activityLogs }

    private var timeline: InboxTimeline {
        let agedInvites = incomingInvitations.filter { $0.expiresAt <= currentDate }.map {
            InboxInvitationOutcome(invitation: $0, outcome: .expired, at: $0.expiresAt)
        }
        let outcomes = (inboxContext?.inviteHistory ?? []) + localOutcomes + agedInvites
        let history = Dictionary(outcomes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return InboxTimeline(
            notifications: appState.notifications, invitations: incomingInvitations, history: Array(history.values),
            activity: activityRecords, banks: liveBankIssues, metadata: alertMetadata,
            age: InboxAgePolicy(now: currentDate, calendar: alertCalendar)
        )
    }

    private func unreadCount(for timeline: InboxTimeline) -> Int {
        switch section {
        case .alerts: timeline.alertUnreadCount
        case .invitations: timeline.pendingInvites.count
        case .activity: timeline.recentActivity.filter { !$0.isRead }.count
        }
    }

    @ViewBuilder
    private func inboxSections(_ timeline: InboxTimeline) -> some View {
        switch section {
        case .alerts:
            if !timeline.reconnect.isEmpty || !timeline.attention.isEmpty {
                inboxSectionHeading("Needs attention")
                ForEach(timeline.reconnect) { bank in
                    bankIssueRow(bank)
                }
                alertRows(timeline.attention)
            }
            if !timeline.upcoming.isEmpty {
                inboxSectionHeading("Upcoming")
                alertRows(timeline.upcoming)
            }
            if !timeline.recentAlerts.isEmpty {
                if !timeline.upcoming.isEmpty || !timeline.reconnect.isEmpty || !timeline.attention.isEmpty {
                    inboxSectionHeading("Recent")
                }
                alertRows(timeline.recentAlerts)
            }
            olderMessages(timeline.olderAlerts, rows: alertRows)
        case .invitations:
            ForEach(timeline.pendingInvites) { invitation in
                invitationRow(invitation)
            }
            if !timeline.recentInvites.isEmpty {
                inboxSectionHeading("Recent outcomes")
                invitationOutcomes(timeline.recentInvites)
            }
            olderMessages(timeline.olderInvites, rows: invitationOutcomes)
        case .activity:
            activityRows(timeline.recentActivity)
            olderMessages(timeline.olderActivity, rows: activityRows)
        }
    }

    private func emptySection(_ timeline: InboxTimeline) -> (icon: String, message: String)? {
        switch section {
        case .alerts:
            let empty = timeline.reconnect.isEmpty && timeline.attention.isEmpty && timeline.upcoming.isEmpty
                && timeline.recentAlerts.isEmpty && timeline.olderAlerts.isEmpty
            return empty ? ("bell.slash", "No alerts yet") : nil
        case .invitations:
            let empty = timeline.pendingInvites.isEmpty && timeline.recentInvites.isEmpty && timeline.olderInvites.isEmpty
            return empty ? ("person.crop.circle.badge.checkmark", "No pending invitations") : nil
        case .activity:
            return timeline.recentActivity.isEmpty && timeline.olderActivity.isEmpty
                ? ("clock.arrow.circlepath", "No activity yet") : nil
        }
    }

    private func inboxSectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.66))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func olderMessages<Row, Rows: View>(
        _ groups: [InboxHistoryGroup<Row>], @ViewBuilder rows: @escaping ([Row]) -> Rows
    ) -> some View {
        if !groups.isEmpty {
            let tab = section
            InboxOlderMessagesButton(isExpanded: Binding(
                get: { expandedHistory.contains(tab) },
                set: { expanded in
                    if expanded { expandedHistory.insert(tab) }
                    else { expandedHistory.remove(tab) }
                }
            ))
            .padding(.top, 8)
            if expandedHistory.contains(tab) {
                ForEach(groups) { group in
                    inboxSectionHeading(group.topic.rawValue)
                    rows(group.rows)
                }
            }
        }
    }

    private func invitationOutcomes(_ outcomes: [InboxInvitationOutcome]) -> some View {
        ForEach(outcomes) { outcome in
            VStack(alignment: .leading, spacing: 4) {
                Text(outcome.subject)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                let details = [outcome.outcome.topic.rawValue, outcome.role, outcome.inviterEmail]
                    .compactMap { $0 }.filter { !$0.isEmpty }
                Text(details.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.68))
                Text(outcome.occurredAt, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private func bankIssueRow(_ bank: Institution) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "building.columns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(inboxRowIconTint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(bank.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text("Bank connection needs attention")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.68))
                if bank.userId == appState.portfolioUserID,
                   appState.plaidItems.contains(where: { $0.institutionId == bank.id && $0.representsLinkedInstitution }) {
                    PlaidLinkButton(companyId: bank.companyId, institutionId: bank.id,
                                    buttonText: "Reconnect", isReconnect: true) { _, _, _ in
                        Task { await refreshBankAfterReconnect(bank.id) }
                    }
                    .frame(maxWidth: 180)
                } else {
                    Button("Review connection") { openInboxRoute(.institution(bank.id)) }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.zifrGold)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    @MainActor
    private func refreshBankAfterReconnect(_ id: UUID) async {
        do {
            try await PlaidService.shared.syncLatestAvailableData(institutionId: id)
            await DataRepository.shared.fetchAllData(appState: appState)
        } catch {
            errorMessage = "The bank connection updated, but its latest balance couldn’t be loaded. Try refreshing."
            await DataRepository.shared.fetchAllData(appState: appState)
        }
    }

    private func actionLabel(for notification: AppNotification) -> String? {
        guard notification.route != nil else { return nil }
        switch InboxTopic.alert(notification, metadata: alertMetadata[notification.id]) {
        case .briefings: return "Open briefing"
        case .balances:
            if notification.notificationType == "transaction_review" { return "Review transactions" }
            return notification.resourceType == "transaction" ? "Review transaction" : "Review account"
        case .connections: return "Review connection"
        case .security: return "Review details"
        default: return nil
        }
    }


    var body: some View {
        let timeline = self.timeline
        let unreadCount = unreadCount(for: timeline)
        Group {
            switch presentation {
            case .sheet:
                reportInbox(timeline, unreadCount: unreadCount)
                    .frame(maxWidth: 580, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
                    .presentationDragIndicator(.visible)
                    .accessibilityAction(.escape) { dismiss() }
                    .presentationBackground {
                        DuoGlassReportStyle.tile
                            .opacity(0.86)
                            .background(.regularMaterial)
                    }
            case .duoDrawer:
                reportInbox(timeline, unreadCount: unreadCount)
            }
        }
        .onAppear { headingFocused = true }
        .environment(\.timeZone, alertCalendar.timeZone)
        .task(id: appState.portfolioUserID) {
            inboxContext = nil
            inboxActivity = nil
            incomingInvitations = []
            localOutcomes = []
            expandedHistory = []
            await refreshInbox()
        }
        .task(id: alertCalendar.timeZone) { await watchInboxCalendar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                currentDate = Date()
                Task { await refreshInbox() }
            }
        }
        .confirmationDialog(
            "Decline Invitation?",
            isPresented: Binding(
                get: { decliningInvitation != nil },
                set: { if !$0 { decliningInvitation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Decline Invitation", role: .destructive) {
                guard let invitation = decliningInvitation else { return }
                Task { await decline(invitation) }
            }
            Button("Cancel", role: .cancel) { decliningInvitation = nil }
        } message: {
            Text("The invitation will be removed. The owner can invite you again later.")
        }
        .alert("Inbox Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "The inbox could not be updated.")
        }
    }

    private func reportInbox(_ timeline: InboxTimeline, unreadCount: Int) -> some View {
        Group {
            DuoGlassReportBody {
                HStack(alignment: .top, spacing: 8) {
                    DuoGlassReportHeading(title: "Inbox", subtitle: inboxCountLabel(unreadCount))
                        .accessibilityFocused($headingFocused)
                    Spacer(minLength: 0)
                    inboxActions(unreadCount)
                        .accessibilityLabel("Inbox actions")
                }

                InboxSectionPicker(selection: $section)

                if let empty = emptySection(timeline) {
                    VStack(spacing: 10) {
                        Image(systemName: empty.icon)
                            .font(.title2.weight(.light))
                            .foregroundStyle(Color.zifrGold)
                            .accessibilityHidden(true)
                        Text(empty.message)
                            .font(.subheadline)
                            .foregroundStyle(DuoGlassReportStyle.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 0) { inboxSections(timeline) }
                }
            }
        }
        .refreshable { await refreshInbox() }
    }

    private func inboxActions(_ unreadCount: Int) -> some View {
        Menu {
            if section != .invitations {
                Button {
                    Task { await markAllRead() }
                } label: {
                    Label("Mark All as Read", systemImage: "envelope.open")
                }
                .disabled(unreadCount == 0)
            }

            Button {
                Task { await refreshInbox(reportError: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            if presentation == .sheet {
                Divider()
                Button("Close Inbox") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.zifrGold)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private func inboxCountLabel(_ unreadCount: Int) -> String {
        if section == .invitations {
            return "\(unreadCount) pending"
        }
        return "\(unreadCount) unread"
    }

    private func alertRows(_ notifications: [AppNotification]) -> some View {
        ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
            notificationRow(notification)
            let nextIndex = index + 1
            if nextIndex < notifications.count {
                let nextID = notifications[nextIndex].id
                reportDivider(beforeNext: expandedSubscriptionAlertID != notification.id && expandedSubscriptionAlertID != nextID)
            }
        }
    }

    @ViewBuilder
    private func reportDivider(beforeNext: Bool) -> some View {
        if beforeNext {
            Rectangle().fill(DuoGlassReportStyle.border).frame(height: 1)
                .accessibilityHidden(true)
        }
    }

    private func rowChrome<Content: View>(_ content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func rowIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 26)
            .padding(.top, 2)
            .accessibilityHidden(true)
    }

    private func activityRows(_ logs: [ActivityLog]) -> some View {
        ForEach(logs) { log in
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(log.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    if !log.isRead {
                        Circle().fill(Color.zifrGold).frame(width: 5, height: 5).accessibilityHidden(true)
                    }
                }
                HStack(spacing: 8) {
                    if !log.actorEmail.isEmpty {
                        Text(log.actorEmail)
                    }
                    Text(log.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.64))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityValue(log.isRead ? "" : "Unread")
            .modifier(InboxRowActions(
                isRead: log.isRead,
                markRead: { Task { await setActivityRead(log, read: true) } },
                markUnread: { Task { await setActivityRead(log, read: false) } },
                delete: { Task { await deleteActivity(log) } }
            ))
        }
    }

    private func invitationRow(_ invitation: IncomingResourceInvitation) -> some View {
        let row = VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                rowIcon("person.2.badge.gearshape", tint: inboxRowIconTint)

                VStack(alignment: .leading, spacing: 5) {
                    Text(invitation.resourceTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(invitation.companyTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.52))
                    Text("Invited by \(invitation.inviterEmail)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Expires \(invitation.expiresAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))")
                        .font(.caption)
                        .foregroundStyle(Color.zifrGold)
                }

                Spacer(minLength: 0)

                Text(invitation.role.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.zifrGold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.zifrGold.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                Button("Decline", role: .destructive) {
                    decliningInvitation = invitation
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(invitationInProgress != nil)

                Button {
                    Task { await accept(invitation) }
                } label: {
                    if invitationInProgress == invitation.id {
                        ProgressView().tint(.black)
                    } else {
                        Text("Accept").fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.zifrGold)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(invitationInProgress != nil)
            }
        }
        return rowChrome(row)
    }

    private func subscriptionAlertRow(_ notification: AppNotification, payment: InboxScheduledPayment) -> some View {
        let expanded = expandedSubscriptionAlertID == notification.id
        let radius: CGFloat = 14
        let fill = InboxSubscriptionPaymentDrawer.fill
        let shape = RoundedRectangle(cornerRadius: radius)
        let toggle = {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                expandedSubscriptionAlertID = expanded ? nil : notification.id
            }
            if !expanded, !notification.isRead {
                Task { await setNotification(notification, read: true) }
            }
        }

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: notificationIcon(notification))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(notificationTint(notification))
                    .frame(width: 18)
                    .accessibilityHidden(true)
                InboxAlertDetails(notification: notification, receivedTime: "", dueOn: alertMetadata[notification.id]?.dueOn)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 15)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .onTapGesture(perform: toggle)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "Collapses payment details" : "Expands payment details")
            .accessibilityAction { toggle() }
            .modifier(InboxRowActions(
                isRead: notification.isRead,
                markRead: { Task { await setNotification(notification, read: true) } },
                markUnread: { Task { await setNotification(notification, read: false) } },
                delete: { Task { await deleteNotification(notification) } }
            ))

            if expanded {
                InboxSubscriptionPaymentDrawer(notification: notification, payment: payment) { route in
                    onOpenRoute(route)
                    if presentation == .sheet { dismiss() }
                }
                .padding(.leading, 40)
                .padding(.trailing, 13)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .background(fill, in: .rect(bottomLeadingRadius: radius, bottomTrailingRadius: radius))
            }
        }
        .overlay {
            if expanded {
                shape.strokeBorder(fill, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func notificationRow(_ notification: AppNotification) -> some View {
        if notification.resourceType == "subscription",
           let payment = InboxScheduledPayment(notification, timeZone: alertCalendar.timeZone, dueOn: alertMetadata[notification.id]?.dueOn) {
            subscriptionAlertRow(notification, payment: payment)
        } else {
            standardNotificationRow(notification)
        }
    }

    private func standardNotificationRow(_ notification: AppNotification) -> some View {
        let label = HStack(alignment: .top, spacing: 14) {
            rowIcon(notificationIcon(notification), tint: notificationTint(notification))

            InboxAlertDetails(notification: notification, receivedTime: relativeDate(notification.createdAt),
                              dueOn: alertMetadata[notification.id]?.dueOn, actionLabel: actionLabel(for: notification))
        }
        let row = rowChrome(label)

        let activate: () -> Void = { Task { await open(notification) } }
        let tappableRow = row
            .onTapGesture(perform: activate)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { activate() }

        return tappableRow.modifier(InboxRowActions(
            isRead: notification.isRead,
            markRead: { Task { await setNotification(notification, read: true) } },
            markUnread: { Task { await setNotification(notification, read: false) } },
            delete: { Task { await deleteNotification(notification) } }
        ))
    }

    @MainActor
    private func open(_ notification: AppNotification) async {
        if !notification.isRead {
            await setNotification(notification, read: true)
        }
        guard let route = notification.route else { return }
        openInboxRoute(route)
    }

    private func openInboxRoute(_ route: NotificationRoute) {
        onOpenRoute(route)
        if presentation == .sheet { dismiss() }
    }

    @MainActor
    private func refreshInbox(reportError: Bool = false) async {
        currentDate = Date()
        guard let userID = appState.portfolioUserID else { return }
        let refreshID = UUID()
        inboxRefreshID = refreshID
        async let notifications = try? DataRepository.shared.fetchNotifications()
        async let invites = try? DataRepository.shared.fetchIncomingInvitations()
        async let context = try? DataRepository.shared.fetchInboxContext()
        async let activity = try? DataRepository.shared.fetchInboxActivity()
        let (newNotifications, newInvites, newContext, newActivity) = await (notifications, invites, context, activity)
        guard !Task.isCancelled, appState.portfolioUserID == userID, inboxRefreshID == refreshID else { return }

        if let newNotifications { appState.notifications = newNotifications }
        if let newInvites { incomingInvitations = newInvites }
        if let newContext { inboxContext = newContext }
        if let newActivity { inboxActivity = newActivity }
        let refreshFailed = switch section {
        case .alerts: newNotifications == nil
        case .invitations: newInvites == nil
        case .activity: newActivity == nil && inboxContext != nil
        }
        if reportError && refreshFailed { errorMessage = "This Inbox tab couldn’t be refreshed." }
    }

    @MainActor
    private func watchInboxCalendar() async {
        while !Task.isCancelled {
            let now = Date()
            let calendar = alertCalendar
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }
            do {
                try await Task.sleep(for: .seconds(max(1, nextDay.timeIntervalSince(now))))
            } catch {
                return
            }
            await refreshInbox()
        }
    }

    @MainActor
    private func setNotification(_ notification: AppNotification, read: Bool) async {
        guard appState.notifications.contains(where: { $0.id == notification.id && $0.isRead != read }) else { return }
        await updateInbox(id: notification.id) {
            try await DataRepository.shared.markNotificationRead(notification.id, isRead: read)
            if let index = appState.notifications.firstIndex(where: { $0.id == notification.id }) {
                appState.notifications[index].isRead = read
            }
        }
    }

    @MainActor
    private func setActivityRead(_ log: ActivityLog, read: Bool) async {
        guard activityRecords.contains(where: { $0.id == log.id && $0.isRead != read }) else { return }
        await updateInbox(id: log.id) {
            if read {
                try await DataRepository.shared.markActivityLogRead(log.id)
            } else {
                try await DataRepository.shared.markActivityLogUnread(log.id)
            }
            if let index = appState.activityLogs.firstIndex(where: { $0.id == log.id }) {
                appState.activityLogs[index].isRead = read
            }
            if let index = inboxActivity?.firstIndex(where: { $0.id == log.id }) {
                inboxActivity?[index].isRead = read
            }
        }
    }

    @MainActor
    private func deleteNotification(_ notification: AppNotification) async {
        await updateInbox(id: notification.id) {
            try await DataRepository.shared.deleteNotification(notification.id)
            withAnimation { appState.notifications.removeAll { $0.id == notification.id } }
        }
    }

    @MainActor
    private func deleteActivity(_ log: ActivityLog) async {
        await updateInbox(id: log.id) {
            try await DataRepository.shared.dismissInboxActivity(log.id)
            withAnimation {
                if let index = appState.activityLogs.firstIndex(where: { $0.id == log.id }) {
                    appState.activityLogs[index].inboxDismissedAt = Date()
                }
                inboxActivity?.removeAll { $0.id == log.id }
            }
        }
    }

    @MainActor
    private func markAllRead() async {
        await updateInbox {
            switch section {
            case .alerts:
                let ids = Set(appState.notifications.map(\.id))
                try await DataRepository.shared.markAllNotificationsRead()
                for index in appState.notifications.indices where ids.contains(appState.notifications[index].id) {
                    appState.notifications[index].isRead = true
                }
            case .invitations:
                return
            case .activity:
                let ids = Set(appState.activityLogs.map(\.id))
                try await DataRepository.shared.markAllActivityLogsRead()
                for index in appState.activityLogs.indices where ids.contains(appState.activityLogs[index].id) {
                    appState.activityLogs[index].isRead = true
                }
                inboxActivity = inboxActivity?.map { log in
                    var updated = log
                    updated.isRead = true
                    return updated
                }
            }
        }
    }

    @MainActor
    private func updateInbox(id: UUID? = nil, _ update: @MainActor () async throws -> Void) async {
        if let id, !updatingRows.insert(id).inserted { return }
        defer { if let id { updatingRows.remove(id) } }
        do {
            try await update()
            inboxRefreshID = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func accept(_ invitation: IncomingResourceInvitation) async {
        invitationInProgress = invitation.id
        defer { invitationInProgress = nil }
        do {
            _ = try await DataRepository.shared.acceptInvitation(id: invitation.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            incomingInvitations.removeAll { $0.id == invitation.id }
            localOutcomes.removeAll { $0.id == invitation.id }
            localOutcomes.append(InboxInvitationOutcome(invitation: invitation, outcome: .accepted, at: Date()))
            await refreshInbox()
            await DataRepository.shared.fetchAllData(appState: appState)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = "The invitation couldn’t be accepted. It may have expired or been cancelled."
        }
    }

    @MainActor
    private func decline(_ invitation: IncomingResourceInvitation) async {
        invitationInProgress = invitation.id
        decliningInvitation = nil
        defer { invitationInProgress = nil }
        do {
            try await DataRepository.shared.declineInvitation(id: invitation.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            incomingInvitations.removeAll { $0.id == invitation.id }
            localOutcomes.removeAll { $0.id == invitation.id }
            localOutcomes.append(InboxInvitationOutcome(invitation: invitation, outcome: .declined, at: Date()))
            await refreshInbox()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = "The invitation couldn’t be declined. Please try again."
        }
    }

    private func notificationIcon(_ notification: AppNotification) -> String {
        if notification.notificationType == "owner_briefing" { return "list.bullet.clipboard" }
        switch notification.resourceType?.lowercased() {
        case "transaction": return "creditcard.and.123"
        case "institution": return "building.columns"
        case "subscription": return "arrow.triangle.2.circlepath"
        case "loan": return "dollarsign.circle"
        case "card": return "creditcard"
        case "document": return "doc.text"
        default: return "bell.fill"
        }
    }

    private func notificationTint(_ notification: AppNotification) -> Color {
        notification.notificationType == "owner_briefing" ? .zifrGold : inboxRowIconTint
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct InvitationAcceptanceSheet: View {
    let token: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var invitation: IncomingResourceInvitation?
    @State private var isLoading = true
    @State private var isResponding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading invitation…")
                        .tint(Color.zifrGold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let invitation {
                    ScrollView {
                        VStack(spacing: 20) {
                            ZifrSheetCard(title: "SHARED WITH YOU", icon: "person.2.badge.gearshape") {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.zifrGold.opacity(0.13))
                                            Image(systemName: resourceIcon(invitation.resourceType))
                                                .font(.system(size: 21, weight: .bold))
                                                .foregroundStyle(Color.zifrGold)
                                        }
                                        .frame(width: 52, height: 52)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(invitation.resourceTitle)
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(invitation.companyTitle)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Color.white.opacity(0.52))
                                        }
                                        Spacer(minLength: 0)
                                    }

                                    Divider().overlay(Color.white.opacity(0.08))

                                    invitationDetail("INVITED BY", value: invitation.inviterEmail)
                                    invitationDetail("ACCESS", value: invitation.role)
                                    invitationDetail("EXPIRES", value: relativeExpiration(invitation.expiresAt))
                                }
                            }

                            ZifrSheetCard(title: "BEFORE YOU ACCEPT", icon: "lock.shield") {
                                Text("Accepting adds this shared resource to your Miloom account. The owner can change or revoke your access later. Vault secrets require a separate encrypted grant in a later phase.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.62))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 12) {
                                Button("Decline", role: .destructive) {
                                    Task { await respond(accept: false) }
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .frame(maxWidth: .infinity, minHeight: 44)

                                Button {
                                    Task { await respond(accept: true) }
                                } label: {
                                    if isResponding {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text("Accept").fontWeight(.semibold)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.zifrGold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .disabled(isResponding)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    ContentUnavailableView(
                        "Invitation Unavailable",
                        systemImage: "envelope.badge.shield.half.filled",
                        description: Text(errorMessage ?? "This invitation may have expired, been cancelled, or belong to another account.")
                    )
                }
            }
            .background(Color(hex: "#1C1C1E").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#1C1C1E"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Invitation")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.zifrGold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task { await loadInvitation() }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    @ViewBuilder
    private func invitationDetail(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.trailing)
        }
    }

    @MainActor
    private func loadInvitation() async {
        isLoading = true
        defer { isLoading = false }
        do {
            invitation = try await DataRepository.shared.previewInvitation(token: token)
        } catch {
            invitation = nil
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func respond(accept: Bool) async {
        isResponding = true
        defer { isResponding = false }
        do {
            if accept {
                _ = try await DataRepository.shared.acceptInvitation(token: token)
                await DataRepository.shared.fetchAllData(appState: appState)
            } else {
                try await DataRepository.shared.declineInvitation(token: token)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            invitation = nil
            errorMessage = "This invitation is no longer available."
        }
    }

    private func relativeExpiration(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func resourceIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "company": return "building.2.crop.circle"
        case "all_subscriptions", "subscription": return "repeat.circle"
        case "all_documents", "document": return "doc.text"
        case "all_financials", "all_institutions", "institution", "card", "loan": return "dollarsign.circle"
        default: return "person.2"
        }
    }
}
