import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let institutionsCount: Int
    let subscriptionsCount: Int
    let docsCount: Int
    let onEdit: () -> Void
    var shareRole: String? = nil
    var isSharedWithMe: Bool = false
    var isSharedByMe: Bool = false
    var sharedBy: String? = nil

    // Tap callbacks
    let onTapSubscriptions: (() -> Void)?
    let onTapInstitutions: (() -> Void)?
    let onTapDocuments: (() -> Void)?
    let onTapMain: (() -> Void)?

    @State private var rotation: Double = 0

    init(
        company: Company, 
        institutionsCount: Int, 
        subscriptionsCount: Int, 
        docsCount: Int, 
        onEdit: @escaping () -> Void, 
        shareRole: String? = nil, 
        isSharedWithMe: Bool = false, 
        isSharedByMe: Bool = false, 
        sharedBy: String? = nil,
        onTapSubscriptions: (() -> Void)? = nil,
        onTapInstitutions: (() -> Void)? = nil,
        onTapDocuments: (() -> Void)? = nil,
        onTapMain: (() -> Void)? = nil
    ) {
        self.company = company
        self.institutionsCount = institutionsCount
        self.subscriptionsCount = subscriptionsCount
        self.docsCount = docsCount
        self.onEdit = onEdit
        self.shareRole = shareRole
        self.isSharedWithMe = isSharedWithMe
        self.isSharedByMe = isSharedByMe
        self.sharedBy = sharedBy
        self.onTapSubscriptions = onTapSubscriptions
        self.onTapInstitutions = onTapInstitutions
        self.onTapDocuments = onTapDocuments
        self.onTapMain = onTapMain
    }

    private var resolvedBrandColor: Color {
        let hex = company.colorHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hex == "#000000" || hex == "#000" || hex == "" {
            // Stable integer hash from the UUID string to guarantee consistency across app launches
            let uuidString = company.id.uuidString
            let charSum = uuidString.utf8.reduce(0) { $0 + Int($1) }
            // Vibrant modern color options: Indigo, Emerald, Amber, Scarlet, Teal, Violet, Blue, Pink
            let fallbackColors = ["#6366f1", "#10b981", "#f59e0b", "#ef4444", "#14b8a6", "#8b5cf6", "#3b82f6", "#ec4899"]
            let chosen = fallbackColors[charSum % fallbackColors.count]
            return Color(hex: chosen)
        }
        return Color(hex: company.colorHex)
    }

    var body: some View {
        let brandColor = resolvedBrandColor
        
        VStack(spacing: 0) {
            // ── Top Row (Brand Canvas Header) ───────────────────────────
            HStack(alignment: .center, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // Logo
                    CompanyAvatar(company: company, size: 48)
                        .padding(.trailing, 14)

                    // Name + Structure
                    VStack(alignment: .leading, spacing: 4) {
                        Text(company.name.isEmpty ? "New Business" : company.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text(company.structure)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.4))
                            
                            if isSharedWithMe {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 9))
                                    Text(shareRole ?? "Viewer")
                                        .font(.system(size: 9, weight: .bold))
                                        .textCase(.uppercase)
                                        .tracking(0.3)
                                }
                                .foregroundStyle(Color(hex: "#818cf8"))
                            } else if isSharedByMe {
                                HStack(spacing: 3) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 9))
                                    Text("Owner")
                                        .font(.system(size: 9, weight: .bold))
                                        .textCase(.uppercase)
                                        .tracking(0.3)
                                }
                                .foregroundStyle(Color(hex: "#34d399"))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapMain?()
                }
                
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onEdit()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.black.opacity(0.70)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.clear, lineWidth: 1)
                    .background(
                        AngularGradient(
                            colors: [
                                brandColor.opacity(0.45),
                                brandColor.opacity(0.12),
                                Color.white.opacity(0.05),
                                brandColor.opacity(0.12),
                                brandColor.opacity(0.45)
                            ],
                            center: .center,
                            angle: .degrees(rotation)
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white, lineWidth: 1)
                        )
                    )
                    .allowsHitTesting(false)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)

            // ── Status Row ───────────────────────────────────────────────
            HStack {
                Spacer()
                
                statusItem(icon: "square.3.layers.3d", title: "Subscriptions", count: subscriptionsCount, color: Color(hex: "#2070BD"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapSubscriptions?()
                    }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 20)
                
                Spacer()
                
                statusItem(icon: "building.columns", title: "Banks", count: institutionsCount, color: Color(hex: "#1A7077"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapInstitutions?()
                    }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 20)
                
                Spacer()
                
                statusItem(icon: "doc.text", title: "Documents", count: docsCount, color: Color(hex: "#918457"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapDocuments?()
                    }
                
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#1C1C1E").opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: brandColor.opacity(0.08), radius: 20, x: 0, y: 10)
        .background(
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapMain?()
                }
        )
        .onAppear {
            let hash = abs(company.id.uuidString.hashValue)
            // Stagger duration between 12.0s and 24.0s; offset initial start phase between 0.0s and 4.0s
            let duration = 12.0 + Double(hash % 13)
            let delay = Double(hash % 5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
        }
    }

    private func statusItem(icon: String, title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}
