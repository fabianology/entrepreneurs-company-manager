import SwiftUI

/// The company card displayed on the Dashboard — mirrors CiFr mobile app layout exactly.
struct CompanyCardView: View {
    let company: Company
    let institutionsCount: Int
    let subscriptionsCount: Int
    let docsCount: Int
    let onEdit: () -> Void
    var onShare: (() -> Void)? = nil
    var shareRole: String? = nil
    var isSharedWithMe: Bool = false
    var isSharedByMe: Bool = false
    var sharedBy: String? = nil

    // Tap callbacks
    let onTapSubscriptions: (() -> Void)?
    let onTapInstitutions: (() -> Void)?
    let onTapDocuments: (() -> Void)?
    let onTapMain: (() -> Void)?

    init(
        company: Company, 
        institutionsCount: Int, 
        subscriptionsCount: Int, 
        docsCount: Int, 
        onEdit: @escaping () -> Void, 
        onShare: (() -> Void)? = nil,
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
        self.onShare = onShare
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
        company.brandColor
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
                
                HStack(spacing: 2) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onEdit()
                        }

                    if let onShare = onShare {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 36, height: 44)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onShare()
                            }
                    }
                }
            }
            .frame(minHeight: 58)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.black.opacity(0.70)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSince1970
                    let hash = abs(company.id.uuidString.hashValue)
                    let duration = 6.5 + Double(hash % 15) / 10.0
                    let initialAngle = Double(hash % 360)
                    let currentAngle = initialAngle + (now.truncatingRemainder(dividingBy: duration) / duration) * 360.0

                    ZStack {
                        // Solid base stroke in a deeper/darker shade of the brand color
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(brandColor.opacity(0.28), lineWidth: 1)
                        
                        // Premium specular angular light sweep in lighter brand color tones
                        AngularGradient(
                            colors: [
                                brandColor.opacity(0.95),
                                brandColor.opacity(0.55),
                                brandColor.opacity(0.20),
                                brandColor.opacity(0.55),
                                brandColor.opacity(0.95)
                            ],
                            center: .center,
                            angle: .degrees(currentAngle)
                        )
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white, lineWidth: 1.25)
                        )
                        .shadow(color: brandColor.opacity(0.30), radius: 5, x: 0, y: 0)
                    }
                    .allowsHitTesting(false)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)

            // ── Status Row ───────────────────────────────────────────────
            HStack {
                Spacer()
                
                statusItem(icon: "square.3.layers.3d", title: "Services", count: subscriptionsCount, color: Color(hex: "#2070BD"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapSubscriptions?()
                    }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 20)
                
                Spacer()
                
                statusItem(icon: "dollarsign.bank.building", title: "Financial", count: institutionsCount, color: Color(hex: "#1A7077"))
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
