import SwiftUI

struct ActivityLogsView: View {
    @Bindable var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var isSelecting: Bool = false
    @State private var selectedLogIDs: Set<UUID> = []
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#171717").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("MESSAGES")
                        .zifrLabel()
                    
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
                                .foregroundStyle(Color(hex: "#4f46e5"))
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
                            
                            if appState.activityLogs.contains(where: { !$0.isRead }) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    Task {
                                        try? await DataRepository.shared.markAllActivityLogsRead()
                                        await DataRepository.shared.fetchAllData(appState: appState)
                                    }
                                } label: {
                                    Label("Mark All as Read", systemImage: "envelope.open")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
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
                            .foregroundStyle(Color.white.opacity(0.3))
                        Text("No messages yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
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
                                                .foregroundStyle(selectedLogIDs.contains(log.id) ? Color(hex: "#4f46e5") : Color.white.opacity(0.3))
                                        }
                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                    
                                    MessageRowView(log: log, vm: vm)
                                        .modifier(ZifrMessageSwipeModifier(
                                            onUnread: {
                                                Task {
                                                    try? await DataRepository.shared.markActivityLogUnread(log.id)
                                                    await DataRepository.shared.fetchAllData(appState: appState)
                                                }
                                            },
                                            onDelete: {
                                                Task {
                                                    try? await DataRepository.shared.deleteActivityLog(log.id)
                                                    await DataRepository.shared.fetchAllData(appState: appState)
                                                }
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
    }
}

struct MessageRowView: View {
    let log: ActivityLog
    let vm: AppViewModel
    @Environment(AppState.self) private var appState
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#4f46e5").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconForAction(log.actionType))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#4f46e5"))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(titleForAction(log.actionType))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(timeAgo(log.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                
                Text(log.message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                
                if !log.isRead {
                    HStack {
                        Spacer()
                        Button {
                            Task {
                                try? await DataRepository.shared.markActivityLogRead(log.id)
                                await DataRepository.shared.fetchAllData(appState: appState)
                            }
                        } label: {
                            Text("Mark as read")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#4f46e5"))
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .masonryGlass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(log.isRead ? Color.clear : Color(hex: "#4f46e5").opacity(0.5), lineWidth: 1)
        )
    }
    
    private func iconForAction(_ type: String) -> String {
        switch type {
        case "shared": return "person.2.fill"
        case "left_resource": return "person.fill.xmark"
        case "updated_company", "updated_subscription", "updated_card", "updated_institution", "updated_loan", "updated_document": return "pencil"
        case "new_device": return "iphone.badge.play"
        default: return "bell.fill"
        }
    }
    
    private func titleForAction(_ type: String) -> String {
        switch type {
        case "shared": return "New Share"
        case "left_resource": return "User Left"
        case "updated_company", "updated_subscription", "updated_card", "updated_institution", "updated_loan", "updated_document": return "Resource Updated"
        case "new_device": return "New Login"
        default: return "Activity"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
