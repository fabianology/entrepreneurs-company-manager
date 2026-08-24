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
    @Environment(AppState.self) private var appState
    
    var body: some View {
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
