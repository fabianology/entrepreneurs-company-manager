import SwiftUI

// MARK: - ZifrField (CiFr-style text input — bg-[#111111] border white/10 rounded-2xl)
struct ZifrField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .textCase(.uppercase)
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(textContentType)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                }
            }
            .textInputAutocapitalization(keyboardType == .URL || keyboardType == .emailAddress ? .never : .sentences)
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
}

struct CopyableField: View {
    let label: String
    let value: String
    var isPassword: Bool = false
    var accentColor: Color = Color.zifrGold

    @State private var copied = false
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .zifrLabel()
                    .foregroundStyle(copied ? accentColor : Color.white.opacity(0.35))
                    .animation(.easeInOut(duration: 0.2), value: copied)

                if isPassword {
                    Button {
                        revealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: revealed ? "eye.slash" : "eye")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                }
            }

            Button {
                guard !value.isEmpty else { return }
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copied = false }
                }
            } label: {
                HStack {
                    Text(displayValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(value.isEmpty ? Color.white.opacity(0.2) : .white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
            }
        }
    }

    private var displayValue: String {
        if value.isEmpty { return "—" }
        if isPassword && !revealed { return "••••••••" }
        return value
    }
}

struct StatusDot: View {
    let isGreen: Bool
    var label: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isGreen ? Color.zifrGreen : Color.red)
                .frame(width: 6, height: 6)
                .shadow(color: isGreen ? Color.zifrGreen : Color.red, radius: 3)

            if let label {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(isGreen ? Color.zifrGreen : Color.red)
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.35))
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

struct FaviconImage: View {
    let website: String
    var size: CGFloat = 32

    var body: some View {
        AsyncImage(url: faviconURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .frame(width: size, height: size)
            default:
                Image(systemName: "globe")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
    }

    private var faviconURL: URL? {
        var host = website
        if !host.hasPrefix("http") { host = "https://\(host)" }
        guard let url = URL(string: host), let h = url.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(h)&sz=128")
    }
}

// MARK: - Safe Double Field (fixes HIG decimal truncation & forced 0)
struct DoubleField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var text: String = ""
    
    private let explicitZero: Double = 0.000000001

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .onAppear { syncFromValue() }
            .onChange(of: text) { newValue in
                processTextChange(newValue)
            }
            .onChange(of: value) { _ in
                syncFromValue()
            }
    }

    private func processTextChange(_ newValue: String) {
        let clean = newValue.replacingOccurrences(of: ",", with: ".")
        if let d = Double(clean) {
            let actualValue = (d == 0 && !clean.isEmpty) ? explicitZero : d
            if value != actualValue { value = actualValue }
        } else if newValue.isEmpty {
            if value != 0 { value = 0 }
        }
    }

    private func syncFromValue() {
        if value == 0 {
            // True unset 0
            if !text.isEmpty { text = "" }
            return
        }
        
        if value == explicitZero {
            // Already showing some form of 0?
            if let currentVal = Double(text.replacingOccurrences(of: ",", with: ".")), currentVal == 0 {
                return
            }
            text = "0"
            return
        }
        
        if let currentTextDouble = Double(text.replacingOccurrences(of: ",", with: ".")), currentTextDouble == value {
            return // avoid wiping user's formatting like decimal trail
        }
        
        let isInt = floor(value) == value
        text = isInt ? String(format: "%.0f", value) : String(value)
    }
}
import SwiftUI

struct LiquidGlassButtonContainer<MenuContent: View>: View {
    let title: String
    let onAdd: () -> Void
    @ViewBuilder let shareMenuContent: () -> MenuContent
    
    @State private var dragOffset: CGSize = .zero
    @State private var isPressing = false
    
    var body: some View {
        ZStack {
            // Liquid Glass Background
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.5, color: Color(hex: "#223d5a")))
                context.addFilter(.blur(radius: 8))
                
                context.drawLayer { ctx in
                    if let blobs = context.resolveSymbol(id: "blobs") {
                        ctx.draw(blobs, at: CGPoint(x: size.width / 2, y: size.height / 2))
                    }
                }
            } symbols: {
                HStack(spacing: 12) {
                    ZStack {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: isPressing ? 160 : 145, height: isPressing ? 46 : 36)
                            .offset(dragOffset)
                    }
                    .frame(width: 145, height: 36) // Fixed footprint to prevent shifting
                    
                    Circle()
                        .fill(Color.black)
                        .frame(width: 36, height: 36)
                }
                .tag("blobs")
            }
            .padding(-20)
            
            // Interactive UI Overlays
            HStack(spacing: 12) {
                // Main Expandable Button
                ZStack {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Text(title)
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1)
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                    }
                    .frame(width: isPressing ? 160 : 145, height: isPressing ? 46 : 36)
                    .offset(dragOffset)
                }
                .frame(width: 145, height: 36) // Fixed footprint
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                                isPressing = true
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                isPressing = false
                                dragOffset = .zero
                            }
                            if abs(value.translation.width) < 10 && abs(value.translation.height) < 10 {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onAdd()
                            }
                        }
                )
                
                // Share Menu
                Menu {
                    shareMenuContent()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#A2A2A2"))
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
            }
        }
        .frame(width: 145 + 12 + 36, height: 46)
    }
}


// MARK: - Pro Context Menu (Zero-Click Access)
struct ProContextMenuModifier: ViewModifier {
    let password: String?
    let loginId: String?
    let last4: String?
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                if let pwd = password, !pwd.isEmpty {
                    Button {
                        UIPasteboard.general.string = pwd
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label("Copy Password", systemImage: "key.fill")
                    }
                }
                if let login = loginId, !login.isEmpty {
                    Button {
                        UIPasteboard.general.string = login
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label("Copy Login ID", systemImage: "person.crop.circle")
                    }
                }
                if let l4 = last4, !l4.isEmpty {
                    Button {
                        UIPasteboard.general.string = l4
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label("Copy Last 4", systemImage: "creditcard.fill")
                    }
                }
                
                if (loginId != nil && !loginId!.isEmpty) || (password != nil && !password!.isEmpty) {
                    let shareText = [
                        (loginId != nil && !loginId!.isEmpty) ? "Login: \(loginId!)" : nil,
                        (password != nil && !password!.isEmpty) ? "Password: \(password!)" : nil
                    ].compactMap { $0 }.joined(separator: "\n")
                    
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }
}

extension View {
    func proContextMenu(password: String? = nil, loginId: String? = nil, last4: String? = nil) -> some View {
        self.modifier(ProContextMenuModifier(password: password, loginId: loginId, last4: last4))
    }
}

// MARK: - Tier 2 Autofill Smart Components

struct SubscriptionAutofillBar: View {
    let typedName: String
    let currentCompanyId: UUID
    let onAutofill: (Subscription) -> Void
    @Environment(AppState.self) private var appState
    
    private var allSubscriptions: [Subscription] { appState.subscriptions }
    private var allCompanies: [Company] { appState.companies }
    
    var body: some View {
        if let match = findMatch() {
            let companyName = allCompanies.first(where: { $0.id == match.companyId })?.name ?? "Another Entity"
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onAutofill(match)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.zifrGold)
                    Text("Autofill from \(companyName)")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.zifrGold.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zifrGold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
    
    private func findMatch() -> Subscription? {
        let normalized = typedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty && normalized.count > 2 else { return nil }
        return allSubscriptions.first { 
            $0.companyId != currentCompanyId && 
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized 
        }
    }
}

struct InstitutionAutofillBar: View {
    let typedName: String
    let currentCompanyId: UUID
    let onAutofill: (Institution) -> Void
    @Environment(AppState.self) private var appState
    
    private var allInstitutions: [Institution] { appState.institutions }
    private var allCompanies: [Company] { appState.companies }
    
    var body: some View {
        if let match = findMatch() {
            let companyName = allCompanies.first(where: { $0.id == match.companyId })?.name ?? "Another Entity"
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onAutofill(match)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.zifrGold)
                    Text("Autofill from \(companyName)")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.zifrGold.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.zifrGold.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
    
    private func findMatch() -> Institution? {
        let normalized = typedName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty && normalized.count > 2 else { return nil }
        return allInstitutions.first { 
            $0.companyId != currentCompanyId && 
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalized 
        }
    }
}

struct ZifrAutocompleteField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var suggestions: [String] = []
    
    @FocusState private var isFocused: Bool
    
    var filteredSuggestions: [String] {
        let counts = suggestions.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let unique = counts.keys

        if text.isEmpty {
            return unique.sorted {
                if counts[$0] != counts[$1] { return counts[$0]! > counts[$1]! }
                return $0 < $1
            }
        }

        return unique
            .filter { $0.lowercased().contains(text.lowercased()) && $0 != text }
            .sorted {
                if counts[$0] != counts[$1] { return counts[$0]! > counts[$1]! }
                return $0 < $1
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .textCase(.uppercase)
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(keyboardType == .URL || keyboardType == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .focused($isFocused)
            
            if isFocused && !filteredSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredSuggestions.prefix(3)), id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            isFocused = false
                        } label: {
                            HStack {
                                Text(suggestion)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#1a1a1a"))
                        }
                        .buttonStyle(.plain)
                        
                        if suggestion != filteredSuggestions.prefix(3).last {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Premium UI Components

struct CustomSegmentedControl: View {
    let options: [String]
    @Binding var selection: String
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selection = option
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: selection == option ? .semibold : .medium))
                        .foregroundStyle(selection == option ? Color.white : Color.white.opacity(0.65))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.miloomPrimary)
                                    .matchedGeometryEffect(id: "SEGMENT", in: animation)
                            }
                        }
                        .padding(2)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 36)
        .background(Color(hex: "#2C2C2E"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PremiumInputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(keyboardType == .URL || keyboardType == .emailAddress ? .never : .sentences)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
}

struct PremiumDoubleField: View {
    let label: String
    let placeholder: String
    let currency: String
    @Binding var value: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .textCase(.uppercase)
            
            HStack(spacing: 4) {
                Text(currency).foregroundStyle(Color.white.opacity(0.45))
                DoubleField(placeholder: placeholder, value: $value)
            }
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(hex: "#2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
}

struct PremiumToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color(hex: "#30D158") : Color(hex: "#2C2C2E"))
                    .frame(width: 50, height: 30)
                    .shadow(color: configuration.isOn ? Color(hex: "#30D158").opacity(0.3) : .clear, radius: 4)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .animation(.easeInOut(duration: 0.25), value: configuration.isOn)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                configuration.isOn.toggle()
            }
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct MiloomPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : Color.white.opacity(0.3))
            .background {
                if isEnabled {
                    LinearGradient.miloomPrimary
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct MiloomSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : Color.white.opacity(0.3))
            .background {
                if isEnabled {
                    LinearGradient.miloomSecondary
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
struct PremiumRow<Left: View, Right: View>: View {
    let left: Left
    let right: Right
    
    init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left()
        self.right = right()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            left
                .frame(maxWidth: .infinity, alignment: .leading)
            right
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Expandable Dashboard Cards
struct ExpandableDashboardCard<CollapsedHeader: View, InnerRows: View, ActionButtons: View>: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let collapsedHeader: () -> CollapsedHeader
    @ViewBuilder let innerRows: () -> InnerRows
    @ViewBuilder let actionButtons: () -> ActionButtons
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            }) {
                collapsedHeader()
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        innerRows()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    HStack(spacing: 0) {
                        actionButtons()
                    }
                    .frame(height: 44)
                }
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.top, 12)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Grouped Dashboard Cards
struct InstitutionDashboardCard<CollapsedHeader: View, AccountsContent: View>: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let collapsedHeader: () -> CollapsedHeader
    @ViewBuilder let accountsContent: () -> AccountsContent
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            }) {
                collapsedHeader()
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.1))
                    accountsContent()
                }
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
}

struct AccountNestedRow<CollapsedHeader: View, InnerRows: View, ActionButtons: View>: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    var isLast: Bool = false
    @ViewBuilder let collapsedHeader: () -> CollapsedHeader
    @ViewBuilder let innerRows: () -> InnerRows
    @ViewBuilder let actionButtons: () -> ActionButtons
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            }) {
                collapsedHeader()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        innerRows()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    HStack(spacing: 0) {
                        actionButtons()
                    }
                    .frame(height: 44)
                }
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            
            if !isLast {
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
}

struct DashboardActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(hex: "#227b5f"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PremiumButtonStyle())
    }
}

struct DashboardInnerRow: View {
    var icon: String? = nil
    let label: String
    let value: String
    var valueColor: Color = .white
    var trailingView: AnyView? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#227b5f").opacity(0.8))
                    .frame(width: 20)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(valueColor)
            
            if let trailingView = trailingView {
                trailingView
            }
        }
    }
}

// MARK: - Miloom Global List Components

struct MiloomListView<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.clear)
    }
}

// MARK: - Premium Animated Header Background
struct AnimatedHeaderBackground: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Base background color
                Color.black.ignoresSafeArea()

                // Deep Indigo
                Circle()
                    .fill(Color(hex: "#221C4A").opacity(0.9))
                    .frame(width: w * 1.6, height: w * 1.6)
                    .blur(radius: 100)
                    .offset(x: animate ? -w * 0.2 : w * 0.1, y: animate ? -h * 0.35 : -h * 0.45)
                
                // Vibrant Purple
                Circle()
                    .fill(Color(hex: "#46246B").opacity(0.7))
                    .frame(width: w * 1.3, height: w * 1.3)
                    .blur(radius: 90)
                    .offset(x: animate ? w * 0.25 : -w * 0.2, y: animate ? -h * 0.45 : -h * 0.3)
                
                // Teal Splash (Reduced)
                Circle()
                    .fill(Color(hex: "#1E8C8C").opacity(0.35))
                    .frame(width: w * 0.7, height: w * 0.7)
                    .blur(radius: 80)
                    .offset(x: animate ? -w * 0.15 : w * 0.3, y: animate ? -h * 0.3 : -h * 0.4)
                
                // Black bleed from sides
                HStack(spacing: 0) {
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 60)
                    Spacer()
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 60)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct MiloomListCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .masonryGlass(cornerRadius: 24)
    }
}

struct MiloomAccordion<Content: View>: View {
    let title: String
    let count: Int?
    let expanded: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
            
            Button(action: action) {
                HStack {
                    if let count = count {
                        Text("\(title) ")
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(0.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                        + Text("(\(count))")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.2))
                    } else {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .tracking(0.2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "#227b5f"))
                }
                .padding(.horizontal, 24)
                .frame(height: 47)
                .contentShape(Rectangle())
            }
            .buttonStyle(PremiumButtonStyle())
            
            if expanded {
                content
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .clipped()
            }
        }
    }
}

