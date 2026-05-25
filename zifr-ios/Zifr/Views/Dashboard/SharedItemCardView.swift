import SwiftUI

struct SharedItemCardView: View {
    let title: String
    let type: String
    let role: String
    let senderEmail: String
    let createdAt: Date
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#3b82f6").opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconFor(type))
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "#3b82f6"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Text(type)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                    
                    Circle().frame(width: 3, height: 3).foregroundStyle(Color.white.opacity(0.3))
                    
                    Text("Shared by \(senderEmail)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.2))
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    private func iconFor(_ type: String) -> String {
        switch type {
        case "Subscription": return "repeat.circle"
        case "Card": return "creditcard"
        case "Institution": return "building.columns"
        case "Loan": return "banknote"
        case "Document": return "doc.text"
        default: return "tray"
        }
    }
}
