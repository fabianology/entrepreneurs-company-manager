import SwiftUI

// MARK: - ZifrField (CiFr-style text input — bg-[#111111] border white/10 rounded-2xl)
struct ZifrField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 11, weight: .bold)) // also made label slightly smaller and bolder for compact look
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .textInputAutocapitalization(keyboardType == .URL || keyboardType == .emailAddress ? .never : .sentences)
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
