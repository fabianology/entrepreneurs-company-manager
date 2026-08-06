import SwiftUI

struct SharedItemOverrideBanner: View {
    let resourceId: UUID
    let defaultCompanyId: UUID
    @Environment(AppState.self) private var appState
    
    private var isSharedWithMe: Bool {
        appState.resourceShares.contains { $0.resourceId == resourceId || $0.resourceId == defaultCompanyId }
    }
    
    private var shareSender: String? {
        appState.resourceShares.first { $0.resourceId == resourceId || $0.resourceId == defaultCompanyId }?.senderEmail
    }
    
    var body: some View {
        if isSharedWithMe {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                    Text("Shared by \(shareSender ?? "Unknown")")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#818cf8"))
                
                Text("You can link this item to one of your own companies to view it seamlessly on your dashboard.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                
                Menu {
                    Button("Keep in Shared Inbox") {
                        appState.localCompanyOverrides.removeValue(forKey: resourceId.uuidString)
                    }
                    Divider()
                    ForEach(appState.companies) { comp in
                        Button(comp.name) {
                            appState.localCompanyOverrides[resourceId.uuidString] = comp.id
                        }
                    }
                } label: {
                    HStack {
                        let currentOverride = appState.localCompanyOverrides[resourceId.uuidString]
                        let selectedName = appState.companies.first(where: { $0.id == currentOverride })?.name ?? "Keep in Shared Inbox"
                        
                        Text(selectedName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
            .background(Color(hex: "#4f46e5").opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }
}
