import SwiftUI
import UniformTypeIdentifiers

/// Resolve credentials from the current authorized session when the user reveals or copies.
/// Search records and assistant responses contain only opaque record IDs.
@MainActor
enum SearchCredentialAccess {
    enum AccessError: LocalizedError {
        case unavailable, locked, changed
        var errorDescription: String? {
            switch self {
            case .unavailable: return "No saved password is available for this item."
            case .locked: return "This password is locked on this device. Open the item to replace it."
            case .changed: return "This item or your access changed. Search again."
            }
        }
    }

    static func resolve(recordID: String, appState: AppState, userID: UUID) throws -> String {
        guard appState.portfolioUserID == userID, appState.hasLoadedPortfolio,
              let record = appState.searchIndex(for: userID).records.first(where: { $0.id == recordID }) else { throw AccessError.changed }
        let value: String?
        switch record.kind {
        case .subscription: value = appState.subscriptions.first { $0.id == record.modelID }?.password
        case .card: value = appState.cards.first { $0.id == record.modelID }?.password
        case .institution, .account: value = appState.institutions.first { $0.id == record.modelID }?.password
        default: value = nil
        }
        guard let value, !value.isEmpty else { throw AccessError.unavailable }
        guard !SecurityService.isLockedValue(value) else { throw AccessError.locked }
        return value
    }

    static func copy(_ password: String) {
        UIPasteboard.general.setItems([[UTType.plainText.identifier: password]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
    }
}

/// Shared direct reveal/copy controls. Passwords exist only in local view state, never search evidence.
struct SearchPasswordControls: View {
    let recordID: String
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var revealed: String?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let revealed, scenePhase == .active, auth.isAuthenticated {
                Text(revealed).font(.system(.body, design: .monospaced)).privacySensitive()
            }
            Group {
                if dynamicTypeSize.isAccessibilitySize { VStack(alignment: .leading, spacing: 8) { revealButton; copyButton } }
                else { HStack(spacing: 8) { revealButton; copyButton } }
            }.font(.caption.weight(.semibold)).buttonStyle(.plain)
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { clear() } }
        .onChange(of: appState.searchRevision) { _, _ in clear() }
        .onChange(of: auth.isAuthenticated) { _, value in if !value { clear() } }
        .onDisappear { clear() }
    }
    private var revealButton: some View {
        Button {
            if revealed != nil { revealed = nil; message = nil }
            else { access(copy: false) }
        } label: {
            actionLabel(revealed == nil ? "Show password" : "Hide password", icon: revealed == nil ? "eye" : "eye.slash")
        }
        .accessibilityLabel(revealed == nil ? "Reveal password" : "Hide password")
    }
    private var copyButton: some View {
        Button { access(copy: true) } label: {
            actionLabel("Copy password", icon: "doc.on.doc")
        }
    }
    private func actionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.zifrGold)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color.zifrGold.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    private func access(copy: Bool) {
        guard let userID = auth.currentUser?.id, auth.isAuthenticated else { clear(); return }
        do {
            let value = try SearchCredentialAccess.resolve(recordID: recordID, appState: appState, userID: userID)
            if copy { SearchCredentialAccess.copy(value); message = "Copied" }
            else { revealed = value; message = nil }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch { revealed = nil; message = error.localizedDescription }
    }
    private func clear() { revealed = nil; message = nil }
}

struct CredentialSearchSheet: View {
    let recordIDs: [String]
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private var candidates: [SearchRecord] {
        guard let userID = auth.currentUser?.id, auth.isAuthenticated else { return [] }
        let ids = Set(recordIDs)
        // A bank and its nested accounts share one credential; show it only once.
        var seen = Set<String>()
        return appState.searchIndex(for: userID).records.filter {
            ids.contains($0.id) && seen.insert("\($0.kind == .account ? "institution" : $0.kind.rawValue):\($0.modelID)").inserted
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(candidates.count > 1 ? "Choose the account you mean" : "Saved password").font(.title3.bold())
                    if candidates.isEmpty { Text("This item is no longer available. Search again.") }
                    ForEach(candidates) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(record.title).font(.headline)
                            Text(record.company + " · " + record.detail).font(.caption).foregroundStyle(.secondary)
                            if !record.login.isEmpty {
                                HStack {
                                    Text(record.login).font(.subheadline).textSelection(.enabled)
                                    Spacer()
                                    Button("Copy login") { SearchCredentialAccess.copy(record.login) }.font(.caption.bold())
                                }
                            }
                            if record.credential == .available { SearchPasswordControls(recordID: record.id) }
                            else {
                                Text(record.credential == .locked ? "Password locked on this device. Open the item to replace it." : "No saved password.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }.padding(16).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(20)
            }
            .background(Color(hex: "#1C1C1E")).navigationTitle("Saved login").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .privacySensitive()
        .onChange(of: auth.isAuthenticated) { _, value in if !value { dismiss() } }
    }
}

/// Edit forms preserve the original one-tap eye control.
struct SecretVisibilityToggle: View {
    @Binding var isVisible: Bool
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Button {
            isVisible.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.white.opacity(0.4)).padding()
        }
        .accessibilityLabel(isVisible ? "Hide password" : "Reveal password")
        .onChange(of: scenePhase) { _, phase in if phase != .active { isVisible = false } }
        .onDisappear { isVisible = false }
    }
}
