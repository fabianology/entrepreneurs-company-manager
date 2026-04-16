import SwiftUI

// MARK: - ZifrField (CiFr-style text input — bg-[#111111] border white/10 rounded-2xl)
struct ZifrField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
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
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#111111"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
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
