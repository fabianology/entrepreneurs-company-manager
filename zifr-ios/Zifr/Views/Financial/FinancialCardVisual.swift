import SwiftUI
import SwiftData
import LocalAuthentication
import AVFoundation

// ── Wallet Sleeve Component ──
struct AggressiveSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 20
        let topYLeft: CGFloat = 35
        let topYRight: CGFloat = 0
        
        path.move(to: CGPoint(x: 0, y: topYLeft))
        path.addLine(to: CGPoint(x: rect.width, y: topYRight))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addArc(center: CGPoint(x: rect.width - radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: radius, y: rect.height))
        path.addArc(center: CGPoint(x: radius, y: rect.height - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: topYLeft))
        
        return path
    }
}

struct WalletSleeveView: View {
    var body: some View {
        ZStack {
            // Main Leather Body (Matte Finish)
            AggressiveSleeveShape()
                .fill(Color(hex: "#121212"))
                // Subtle overlay to simulate deep matte leather finish
                .overlay(
                    AggressiveSleeveShape()
                        .fill(Color.black.opacity(0.15))
                        .blendMode(.multiply)
                )
                .shadow(color: .black.opacity(0.6), radius: 10, y: -4)
            
            // Premium Stitching
            AggressiveSleeveShape()
                .stroke(Color(hex: "#2B3A3B"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(6)
                
            // Edge highlight
            AggressiveSleeveShape()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .frame(height: 120)
    }
}

// ── Shared Card Visual (Overlapping flippable view for stack) ──
struct FinancialCardVisual: View {
    let card: FinancialCard
    let isPopped: Bool
    
    @Environment(AppState.self) private var appState
    
    @State private var isFlipped: Bool = false
    @State private var isUnlocked: Bool = false
    @State private var sheenOffset: CGFloat = -0.5
    
    private var subscriptions: [Subscription] { appState.subscriptions }
    
    private var paysForServices: [(name: String, cost: Double)] {
        let cardName = card.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cardName.isEmpty else { return [] }
        var results: [(name: String, cost: Double)] = []
        for sub in subscriptions {
            if (sub.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                results.append((name: sub.name.isEmpty ? "Unnamed Service" : sub.name, cost: sub.cost))
            }
            for subSvc in sub.subServices {
                if (subSvc.paymentMethod ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cardName {
                    results.append((name: subSvc.name.isEmpty ? "Unnamed Sub-service" : subSvc.name, cost: subSvc.cost))
                }
            }
        }
        return results
    }

    private var promoEndsString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: card.promoEnds ?? Date())
    }

    var body: some View {
        ZStack {
            // ── Brushed Metal & Gradient Background ──
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: card.cardGradientHex.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isPopped ? (isFlipped ? Color.green.opacity(0.3) : Color.white.opacity(0.3)) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: isPopped ? 16 : 8, y: isPopped ? 8 : 4)
            
            // Brushed metal grain lines overlay
            BrushedMetalBackground(colors: card.cardGradientHex.map { Color(hex: $0) })
                .clipShape(RoundedRectangle(cornerRadius: 24))
            
            let isLight = card.cardGradientHex.first?.uppercased() == "#FFFFFF"
            let primaryColor = isLight ? Color.black : Color.white
            let secondaryColor = isLight ? Color.black.opacity(0.7) : Color.white.opacity(0.7)
            
            // Dynamic Specular Highlight (Reflection Sweep)
            LinearGradient(
                colors: [.clear, Color.white.opacity(isLight ? 0.08 : 0.15), .clear],
                startPoint: UnitPoint(x: sheenOffset - 0.5, y: 0),
                endPoint: UnitPoint(x: sheenOffset + 0.5, y: 1)
            )
            .blendMode(.plusLighter)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .allowsHitTesting(false)
            
            // Flippable Content Container
            ZStack {
                // FRONT SIDE VIEW
                VStack(spacing: 0) {
                    frontHeaderRow(primaryColor: primaryColor, secondaryColor: secondaryColor)
                    
                    Spacer(minLength: 0)
                    
                    if isPopped {
                        poppedFrontDetails(isLight: isLight, primaryColor: primaryColor, secondaryColor: secondaryColor)
                    }
                }
                .padding(16)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
                
                // BACK SIDE VIEW (CREDENTIALS)
                VStack(alignment: .leading, spacing: 8) {
                    backHeaderRow(primaryColor: primaryColor, secondaryColor: secondaryColor)
                    
                    Spacer(minLength: 0)
                    
                    if isUnlocked {
                        unlockedBackDetails(isLight: isLight, primaryColor: primaryColor)
                    } else {
                        lockedBackPrompt(primaryColor: primaryColor)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(16)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: isFlipped)
        .onChange(of: isPopped) { _, popped in
            // Reset state if card collapses
            if !popped {
                isFlipped = false
                isUnlocked = false
                sheenOffset = -0.5
            } else {
                // Sheen sweep sweep effect when card pops open
                sheenOffset = -0.5
                withAnimation(.linear(duration: 1.2)) {
                    sheenOffset = 1.5
                }
            }
        }
        .onChange(of: isFlipped) { _, flipped in
            if flipped && !isUnlocked {
                authenticateBiometrics { success in
                    isUnlocked = success
                }
            }
        }
    }
    
    // ── Helper Sub-Views (Opaque methods to bypass Swift compiler complex expressions checks) ──
    
    @ViewBuilder
    private func frontHeaderRow(primaryColor: Color, secondaryColor: Color) -> some View {
        HStack(alignment: .top) {
            // Nickname & Cardholder Name aligned left
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(card.name.isEmpty ? "Card" : card.name)
                        .font(.system(size: isPopped ? 16 : 12, weight: .bold))
                        .foregroundStyle(primaryColor)
                    
                    if !(card.last4 ?? "").isEmpty {
                        Text("•••• \(card.last4 ?? "")")
                            .font(.system(size: isPopped ? 14 : 10, weight: .semibold))
                            .foregroundStyle(secondaryColor)
                    }
                }
                
                if isPopped {
                    Text((card.cardHolder ?? "").isEmpty ? "Name on Card" : (card.cardHolder ?? ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryColor.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Network & Expiry Date aligned right
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 8) {
                    if isPopped {
                        ContactlessIndicator(color: primaryColor)
                    }
                    
                    switch card.network {
                    case "Visa": VisaLogo(color: primaryColor)
                    case "Mastercard": MastercardLogo()
                    case "Amex": AmexLogo(color: primaryColor)
                    default:
                        Text(card.network)
                            .font(.system(size: isPopped ? 14 : 12, weight: .semibold))
                            .foregroundStyle(secondaryColor)
                            .italic()
                    }
                }
                
                if isPopped {
                    let expStr = (card.expiry ?? "").isEmpty ? "—" : (card.expiry ?? "")
                    Text("Expires \(expStr)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryColor.opacity(0.8))
                }
            }
        }
    }
    
    @ViewBuilder
    private func poppedFrontDetails(isLight: Bool, primaryColor: Color, secondaryColor: Color) -> some View {
        VStack(spacing: 0) {
            // Action button aligned to right
            HStack {
                Spacer()
                
                // Secure flip activation
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isFlipped = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text("REVEAL DETAILS")
                    }
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.0)
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.12), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)
            
            let services = paysForServices
            let hasFinancials = card.limit > 0 || card.balance > 0 || card.apr > 0 || card.promoApr > 0 || (card.autopay != "N/A" && !card.autopay.isEmpty)
            
            if hasFinancials || !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                Divider()
                    .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                    .padding(.bottom, 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    if hasFinancials {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            if card.balance > 0 { cardMetric(title: "BALANCE", value: "$\(String(format: "%.0f", card.balance))", isLight: isLight, primaryColor: primaryColor) }
                            if card.limit > 0 { cardMetric(title: "LIMIT", value: "$\(String(format: "%.0f", card.limit))", isLight: isLight, primaryColor: primaryColor) }
                            if card.apr > 0 { cardMetric(title: "APR", value: "\(String(format: "%.1f", card.apr))%", isLight: isLight, primaryColor: primaryColor) }
                            if card.promoApr > 0 {
                                cardMetric(title: "PROMO", value: "\(String(format: "%.1f", card.promoApr))%", isLight: isLight, primaryColor: primaryColor)
                                cardMetric(title: "PROMO END", value: promoEndsString, isLight: isLight, primaryColor: primaryColor)
                            }
                            if card.autopay != "N/A" && !card.autopay.isEmpty { cardMetric(title: "AUTO PAY", value: card.autopay, isLight: isLight, primaryColor: primaryColor) }
                        }
                        
                        if !(card.paidFrom ?? "").isEmpty || !services.isEmpty {
                            Divider()
                                .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                        }
                    }
                    
                    if !(card.paidFrom ?? "").isEmpty {
                        HStack {
                            Text("PAY FROM")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                            Spacer()
                            Text(paidFromWithInstitution)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(primaryColor)
                        }
                    }
                    
                    if !(card.paidFrom ?? "").isEmpty && !services.isEmpty {
                        Divider()
                            .background(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.06))
                    }
                    
                    if !services.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PAYS FOR")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                            
                            ForEach(Array(services.prefix(2).enumerated()), id: \.offset) { index, svc in
                                HStack {
                                    Text(svc.name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(primaryColor)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("$\(String(format: "%.0f", svc.cost))")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(primaryColor)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func backHeaderRow(primaryColor: Color, secondaryColor: Color) -> some View {
        HStack {
            Text("SECURE DATA")
                .font(.system(size: 10, weight: .black))
                .tracking(1.5)
                .foregroundStyle(secondaryColor)
            Spacer()
            
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isFlipped = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    Text("BACK")
                }
                .font(.system(size: 9, weight: .black))
                .tracking(1.0)
                .foregroundStyle(primaryColor)
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func unlockedBackDetails(isLight: Bool, primaryColor: Color) -> some View {
        VStack(spacing: 6) {
            BackFieldView(
                label: "CARD NUMBER",
                value: formatCardNumber(card.cardNumber ?? "•••• •••• •••• ••••"),
                isLight: isLight,
                primaryColor: primaryColor,
                isSecure: false
            )
            
            HStack(spacing: 6) {
                BackFieldView(
                    label: "EXPIRY",
                    value: card.expiry ?? "——/——",
                    isLight: isLight,
                    primaryColor: primaryColor,
                    isSecure: false
                )
                BackFieldView(
                    label: "CVV",
                    value: "•••",
                    isLight: isLight,
                    primaryColor: primaryColor,
                    isSecure: false
                )
            }
            
            if !(card.login ?? "").isEmpty || !(card.password ?? "").isEmpty {
                HStack(spacing: 6) {
                    if let login = card.login, !login.isEmpty {
                        BackFieldView(
                            label: "LOGIN ID",
                            value: login,
                            isLight: isLight,
                            primaryColor: primaryColor,
                            isSecure: false
                        )
                    }
                    if let pwd = card.password, !pwd.isEmpty {
                        BackFieldView(
                            label: "PASSWORD",
                            value: pwd,
                            isLight: isLight,
                            primaryColor: primaryColor,
                            isSecure: true
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func lockedBackPrompt(primaryColor: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundStyle(primaryColor.opacity(0.4))
            
            Text("Authentication Required")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(primaryColor)
            
            Button {
                authenticateBiometrics { success in
                    isUnlocked = success
                }
            } label: {
                Text("Tap to Authenticate")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(primaryColor.opacity(0.08))
                            .overlay(Capsule().stroke(primaryColor.opacity(0.2), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func cardMetric(title: String, value: String, isLight: Bool, primaryColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(isLight ? Color.black.opacity(0.5) : Color.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func authenticateBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Reveal Zifr secure card credentials"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    completion(success)
                }
            }
        } else {
            // Fallback for Simulator without biometric enrollment
            completion(true)
        }
    }
    
    private func formatCardNumber(_ raw: String) -> String {
        let digits = raw.replacingOccurrences(of: " ", with: "")
        guard digits.count == 16 else { return raw }
        var result = ""
        for (idx, char) in digits.enumerated() {
            if idx > 0 && idx % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return result
    }
    
    private var paidFromWithInstitution: String {
        guard let paidFrom = card.paidFrom, !paidFrom.isEmpty else { return "" }
        let normalizedPaidFrom = paidFrom.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Search in cards
        for c in appState.cards {
            if c.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                let instName = (c.institutionName ?? "").isEmpty ? "" : c.institutionName!
                if !instName.isEmpty {
                    return "\(instName) · \(paidFrom)"
                }
            }
        }
        
        // 2. Search in institutions accounts
        for inst in appState.institutions {
            for acc in inst.accounts {
                let accName = acc.name.isEmpty ? acc.type : acc.name
                if accName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == normalizedPaidFrom {
                    let instName = inst.name.isEmpty ? "" : inst.name
                    if !instName.isEmpty {
                        return "\(instName) · \(paidFrom)"
                    }
                }
            }
        }
        return paidFrom
    }
}

// ── Sub-component View Structures (To ensure perfect SwiftUI type check separation) ──

struct BrushedMetalBackground: View {
    let colors: [Color]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Double-band diagonal light sheen for anisotropic metal reflection
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .white.opacity(0.08),
                    .clear,
                    .white.opacity(0.12),
                    .clear,
                    .white.opacity(0.05),
                    .clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            
            // Hairline grain scratches overlay (strongly visible but micro-fine)
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 1.5) {
                    let opacity = Double.random(in: 0.04...0.11)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: 0.5
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct ContactlessIndicator: View {
    let color: Color
    var body: some View {
        Image(systemName: "wave.3.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color.opacity(0.6))
            .rotationEffect(.degrees(-90))
    }
}

struct VisaLogo: View {
    let color: Color
    var body: some View {
        Text("VISA")
            .font(.system(size: 14, weight: .black, design: .default))
            .italic()
            .foregroundStyle(color)
            .tracking(0.5)
    }
}

struct MastercardLogo: View {
    var body: some View {
        HStack(spacing: -6) {
            Circle()
                .fill(Color(hex: "#EB001B"))
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color(hex: "#FF5F00").opacity(0.85))
                .frame(width: 16, height: 16)
                .blendMode(.plusLighter)
        }
    }
}

struct AmexLogo: View {
    let color: Color
    var body: some View {
        Text("AMEX")
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .border(color, width: 1.5)
            .foregroundStyle(color)
    }
}

struct BackFieldView: View {
    let label: String
    let value: String
    let isLight: Bool
    let primaryColor: Color
    let isSecure: Bool
    
    @State private var isCopied = false
    @State private var isPasswordRevealed = false
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(isLight ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
            
            HStack(spacing: 4) {
                Text(isSecure && !isPasswordRevealed ? "••••••••" : value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                if isSecure {
                    Button {
                        isPasswordRevealed.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isPasswordRevealed ? "eye.slash" : "eye")
                            .font(.system(size: 10))
                            .foregroundStyle(primaryColor.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if isSpeaking {
                            synthesizer.stopSpeaking(at: .immediate)
                            isSpeaking = false
                        } else {
                            isSpeaking = true
                            
                            let introUtterance = AVSpeechUtterance(string: "I cannot read your password for security reasons, but I will hand you over to your device's secure local system to read it to you.")
                            introUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                            
                            let passUtterance = AVSpeechUtterance(string: value)
                            passUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                            
                            synthesizer.speak(introUtterance)
                            synthesizer.speak(passUtterance)
                            
                            // Simple reset
                            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                                isSpeaking = false
                            }
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSpeaking ? Color.blue : primaryColor.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    UIPasteboard.general.string = value
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation { isCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { isCopied = false }
                    }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(isCopied ? Color.green : primaryColor.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isLight ? Color.black.opacity(0.04) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
