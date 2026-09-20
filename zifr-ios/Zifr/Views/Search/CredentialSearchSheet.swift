import SwiftUI
import UniformTypeIdentifiers
import Observation

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

    static func resolveLogin(recordID: String, appState: AppState, userID: UUID) throws -> String {
        guard appState.portfolioUserID == userID, appState.hasLoadedPortfolio,
              let record = appState.searchIndex(for: userID).records.first(where: { $0.id == recordID }) else { throw AccessError.changed }
        let value: String?
        switch record.kind {
        case .subscription: value = appState.subscriptions.first { $0.id == record.modelID }?.loginId
        case .card: value = appState.cards.first { $0.id == record.modelID }?.login
        case .institution, .account:
            let bank = appState.institutions.first { $0.id == record.modelID }
            value = bank?.username ?? bank?.email
        default: value = nil
        }
        guard let value, !value.isEmpty else { throw AccessError.changed }
        return value
    }
}

/// Copy and reveal are independent actions. Only the eye changes visibility.
@MainActor @Observable
final class SearchCredentialBoxState {
    enum Field { case login, password }
    var revealed: String?
    var copied: Field?
    var copySerial = 0
    var error: String?

    func copy(_ field: Field, recordID: String, appState: AppState, userID: UUID) {
        do {
            let value = try field == .password
                ? SearchCredentialAccess.resolve(recordID: recordID, appState: appState, userID: userID)
                : SearchCredentialAccess.resolveLogin(recordID: recordID, appState: appState, userID: userID)
            SearchCredentialAccess.copy(value)
            copied = field; copySerial += 1; error = nil
        } catch { clear(); self.error = error.localizedDescription }
    }
    func togglePassword(recordID: String, appState: AppState, userID: UUID) {
        if revealed != nil { revealed = nil; error = nil; return }
        do {
            revealed = try SearchCredentialAccess.resolve(recordID: recordID, appState: appState, userID: userID)
            error = nil
        } catch { clear(); self.error = error.localizedDescription }
    }
    func clear() { revealed = nil; copied = nil; error = nil }
}

/// Tappable credential fields shared by every search card and the saved-login sheet.
struct SearchCredentialBoxes: View {
    let record: SearchRecord
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var state = SearchCredentialBoxState()

    private var visiblePassword: String? { scenePhase == .active && auth.isAuthenticated ? state.revealed : nil }
    var body: some View {
        if !record.login.isEmpty || record.credential != .none {
            VStack(alignment: .leading, spacing: 6) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                layout { loginBox; passwordBox }
                if let error = state.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: state.copied)
            .task(id: state.copySerial) {
                guard state.copied != nil else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                state.copied = nil
            }
            .onChange(of: scenePhase) { _, phase in if phase != .active { state.clear() } }
            .onChange(of: appState.searchRevision) { _, _ in state.clear() }
            .onChange(of: auth.currentUser?.id) { _, _ in state.clear() }
            .onChange(of: auth.isAuthenticated) { _, value in if !value { state.clear() } }
            .onChange(of: record.id) { _, _ in state.clear() }
            .onDisappear { state.clear() }
        }
    }
    private var loginBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("LOGIN ID", copied: state.copied == .login)
            Button { copy(.login) } label: {
                Text(record.login.isEmpty ? "Not saved" : record.login)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.75).allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain).disabled(record.login.isEmpty)
            .background(boxBackground(copied: state.copied == .login))
            .accessibilityLabel("Copy login")
            .accessibilityValue(record.login)
            .accessibilityHint("Copies the saved login")
            .accessibilityIdentifier("search-copy-login-" + record.id)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var passwordBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("PASSWORD", copied: state.copied == .password)
            HStack(spacing: 0) {
                Button { copy(.password) } label: {
                    Text(visiblePassword ?? (record.credential == .none ? "Not saved" : "••••••••"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        .privacySensitive()
                        .padding(.vertical, 14).padding(.leading, 14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(record.credential != .available)
                .accessibilityLabel("Copy password")
                .accessibilityValue(visiblePassword == nil ? "Hidden" : "Visible")
                .accessibilityHint("Copies the password without changing visibility")
                .accessibilityIdentifier("search-copy-password-" + record.id)
                Button {
                    guard auth.isAuthenticated, let userID = auth.currentUser?.id else { state.clear(); return }
                    state.togglePassword(recordID: record.id, appState: appState, userID: userID)
                } label: {
                    Image(systemName: visiblePassword == nil ? "eye" : "eye.slash")
                        .font(.body).foregroundStyle(Color(white: 0.62))
                        .frame(width: 44, height: 52).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(record.credential != .available)
                .accessibilityLabel(visiblePassword == nil ? "Reveal password" : "Hide password")
                .accessibilityIdentifier("search-toggle-password-" + record.id)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(boxBackground(copied: state.copied == .password))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func fieldLabel(_ text: String, copied: Bool) -> some View {
        HStack(spacing: 4) {
            if copied { Image(systemName: "checkmark.circle.fill") }
            Text(copied ? "COPIED" : text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(copied ? Color.zifrGold : Color.secondary)
        .padding(.horizontal, 10)
    }
    private func boxBackground(copied: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14).fill(copied ? Color.zifrGold.opacity(0.2) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.zifrGold.opacity(copied ? 0.8 : 0), lineWidth: 1))
    }
    private func copy(_ field: SearchCredentialBoxState.Field) {
        guard auth.isAuthenticated, let userID = auth.currentUser?.id else { state.clear(); return }
        state.copy(field, recordID: record.id, appState: appState, userID: userID)
        if state.error == nil {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: field == .login ? "Login copied" : "Password copied")
        }
    }
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
                            Text(record.company + " · " + record.detail).font(.footnote).foregroundStyle(.secondary)
                            SearchCredentialBoxes(record: record)
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
