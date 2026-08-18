import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let zifrGreen  = Color(hex: "#1f7055")
    static let zifrGold   = Color(hex: "#EBC351")
    static let zifrBlue   = Color(hex: "#0091FF")
    static let zifrBG     = Color(hex: "#445C5E")
    static let zifrCard   = Color(hex: "#171717")
    static let zifrBorder = Color.white.opacity(0.08)

    // MARK: - Hex Init
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Status Colors
extension String {
    var statusColor: Color {
        switch self {
        case "Active": return .zifrGreen
        case "Paused", "Frozen", "Default": return .red
        case "Pending", "Cancelled": return .orange
        case "Paid Off", "Expired": return .gray
        default: return .white.opacity(0.4)
        }
    }

    var networkColor: Color {
        switch self {
        case "Visa": return Color(hex: "#1A1F71")
        case "Mastercard": return Color(hex: "#EB001B")
        case "Amex": return Color(hex: "#007BC1")
        case "Discover": return Color(hex: "#FF6600")
        default: return .gray
        }
    }
}

// MARK: - Gradients
extension ShapeStyle where Self == LinearGradient {
    static var miloomPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#4f609a"), Color(hex: "#f2ac5b")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var miloomSecondary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#15566a"), Color(hex: "#00544e")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var vaultOutline: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#918457"),
                Color(hex: "#918457").opacity(0.3)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
