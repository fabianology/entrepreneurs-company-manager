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
            
            if !log.isRead {
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

struct NotificationInboxView: View {
    enum Presentation {
        case sheet, duoDrawer
    }

    @Bindable var vm: AppViewModel
    var presentation: Presentation = .sheet
    let onOpenRoute: (NotificationRoute) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var section: InboxSection = .alerts
    @State private var errorMessage: String?
    @State private var incomingInvitations: [IncomingResourceInvitation] = []
    @State private var invitationInProgress: UUID?
    @State private var decliningInvitation: IncomingResourceInvitation?
    @AccessibilityFocusState private var headingFocused: Bool

    private var unreadCount: Int {
        switch section {
        case .alerts: appState.unreadNotificationCount
        case .invitations: incomingInvitations.count
        case .activity: appState.activityLogs.filter { !$0.isRead }.count
        }
    }

    var body: some View {
        Group {
            switch presentation {
            case .sheet:
                reportInbox
                    .frame(maxWidth: 580, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
                    .presentationDragIndicator(.visible)
                    .presentationBackground {
                        DuoGlassReportStyle.tile
                            .opacity(0.86)
                            .background(.regularMaterial)
                    }
            case .duoDrawer:
                reportInbox
            }
        }
        .onAppear { headingFocused = true }
        .task {
            try? await DataRepository.shared.refreshNotifications(appState: appState)
            await refreshInvitations()
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

    private var reportInbox: some View {
        refreshableList {
            DuoGlassReportBody {
                HStack(alignment: .top, spacing: 8) {
                    DuoGlassReportHeading(title: "Inbox", subtitle: inboxCountLabel)
                        .accessibilityFocused($headingFocused)
                    Spacer(minLength: 0)
                    inboxActions
                        .accessibilityLabel("Inbox actions")
                    if presentation == .sheet {
                        closeButton
                    }
                }

                InboxSectionPicker(selection: $section)

                if let empty {
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
                    inboxRows
                }
            }
        }
    }

    @ViewBuilder
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            let icon = Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)

            if #available(iOS 26, *) {
                icon.glassEffect(.regular.interactive(), in: .circle)
            } else {
                icon.background(.thinMaterial, in: Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Inbox")
    }

    private var empty: (icon: String, message: String)? {
        switch section {
        case .alerts:
            appState.notifications.isEmpty ? ("bell.slash", "No alerts yet") : nil
        case .invitations:
            incomingInvitations.isEmpty ? ("person.crop.circle.badge.checkmark", "No pending invitations") : nil
        case .activity:
            appState.activityLogs.isEmpty ? ("clock.arrow.circlepath", "No activity yet") : nil
        }
    }

    @ViewBuilder
    private func refreshableList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch section {
        case .alerts:
            content().refreshable {
                try? await DataRepository.shared.refreshNotifications(appState: appState)
            }
        case .invitations:
            content().refreshable { await refreshInvitations() }
        case .activity:
            content()
        }
    }

    private var inboxActions: some View {
        Menu {
            if section != .invitations {
                Button {
                    Task { await markAllRead() }
                } label: {
                    Label("Mark All as Read", systemImage: "envelope.open")
                }
                .disabled(unreadCount == 0)
            }

            if section != .activity {
                Button {
                    Task {
                        if section == .alerts {
                            do {
                                try await DataRepository.shared.refreshNotifications(appState: appState)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } else {
                            await refreshInvitations()
                        }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.zifrGold)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private var inboxCountLabel: String {
        if section == .invitations {
            return "\(unreadCount) pending"
        }
        return "\(unreadCount) unread"
    }

    private var inboxRows: some View {
        LazyVStack(spacing: 0) {
            switch section {
            case .alerts:
                ForEach(appState.notifications) { notification in
                    notificationRow(notification)
                    reportDivider(beforeNext: notification.id != appState.notifications.last?.id)
                }
            case .invitations:
                ForEach(incomingInvitations) { invitation in
                    invitationRow(invitation)
                    reportDivider(beforeNext: invitation.id != incomingInvitations.last?.id)
                }
            case .activity:
                ForEach(appState.activityLogs) { log in
                    MessageRowView(log: log, vm: vm, usesReportRowStyle: true)
                        .contextMenu {
                            Button {
                                Task { await toggleActivityRead(log) }
                            } label: {
                                Label(log.isRead ? "Mark Unread" : "Mark Read",
                                      systemImage: log.isRead ? "envelope.badge" : "envelope.open")
                            }
                        }
                    reportDivider(beforeNext: log.id != appState.activityLogs.last?.id)
                }
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

    private func invitationRow(_ invitation: IncomingResourceInvitation) -> some View {
        let row = VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                rowIcon("person.2.badge.gearshape", tint: .zifrGold)

                VStack(alignment: .leading, spacing: 5) {
                    Text(invitation.resourceTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(invitation.companyTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.52))
                    Text("Invited by \(invitation.inviterEmail) as \(invitation.role)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
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

    private func notificationRow(_ notification: AppNotification) -> some View {
        Button {
            Task { await open(notification) }
        } label: {
            let row = HStack(alignment: .top, spacing: 14) {
                rowIcon(notificationIcon(notification), tint: notificationTint(notification))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(notification.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        if !notification.isRead {
                            Circle().fill(Color.zifrGold).frame(width: 6, height: 6)
                        }
                        Spacer(minLength: 4)
                        Text(relativeDate(notification.createdAt))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }

                    Text(notification.body)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(notification.isRead ? 0.55 : 0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if notification.route != nil {
                        Label("Open", systemImage: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.zifrGold)
                    }
                }
            }
            rowChrome(row)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { await setNotification(notification, read: !notification.isRead) }
            } label: {
                Label(notification.isRead ? "Mark Unread" : "Mark Read",
                      systemImage: notification.isRead ? "envelope.badge" : "envelope.open")
            }
        }
    }

    @MainActor
    private func open(_ notification: AppNotification) async {
        if !notification.isRead {
            await setNotification(notification, read: true)
        }
        guard let route = notification.route else { return }
        onOpenRoute(route)
        if presentation == .sheet { dismiss() }
    }

    @MainActor
    private func setNotification(_ notification: AppNotification, read: Bool) async {
        guard let index = appState.notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        let original = appState.notifications[index].isRead
        appState.notifications[index].isRead = read
        do {
            try await DataRepository.shared.markNotificationRead(notification.id, isRead: read)
        } catch {
            appState.notifications[index].isRead = original
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleActivityRead(_ log: ActivityLog) async {
        guard let index = appState.activityLogs.firstIndex(where: { $0.id == log.id }) else { return }
        let original = appState.activityLogs[index].isRead
        appState.activityLogs[index].isRead.toggle()
        do {
            if original {
                try await DataRepository.shared.markActivityLogUnread(log.id)
            } else {
                try await DataRepository.shared.markActivityLogRead(log.id)
            }
        } catch {
            appState.activityLogs[index].isRead = original
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func markAllRead() async {
        do {
            switch section {
            case .alerts:
                let originals = appState.notifications
                for index in appState.notifications.indices { appState.notifications[index].isRead = true }
                do {
                    try await DataRepository.shared.markAllNotificationsRead()
                } catch {
                    appState.notifications = originals
                    throw error
                }
            case .invitations:
                return
            case .activity:
                let originals = appState.activityLogs
                for index in appState.activityLogs.indices { appState.activityLogs[index].isRead = true }
                do {
                    try await DataRepository.shared.markAllActivityLogsRead()
                } catch {
                    appState.activityLogs = originals
                    throw error
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshInvitations() async {
        do {
            incomingInvitations = try await DataRepository.shared.fetchIncomingInvitations()
        } catch {
            errorMessage = "Invitations couldn’t be loaded. Please try again."
        }
    }

    @MainActor
    private func accept(_ invitation: IncomingResourceInvitation) async {
        invitationInProgress = invitation.id
        defer { invitationInProgress = nil }
        do {
            _ = try await DataRepository.shared.acceptInvitation(id: invitation.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await refreshInvitations()
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
            await refreshInvitations()
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
        switch notification.resourceType?.lowercased() {
        case "institution", "transaction": return Color(hex: "#1A9CA6")
        case "subscription": return Color(hex: "#4A8FD8")
        default: return Color.zifrGold
        }
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
