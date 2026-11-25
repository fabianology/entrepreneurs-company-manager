import SwiftUI

/// Entity identity and section shortcuts on the Dashboard.
struct CompanyCardView: View {
    let company: Company
    let institutionsCount: Int?
    let subscriptionsCount: Int?
    let docsCount: Int?
    let onEdit: () -> Void
    var canEdit: Bool = true
    var onShare: (() -> Void)? = nil
    var shareRole: String? = nil
    var isSharedWithMe: Bool = false
    var isSharedByMe: Bool = false
    var sharedBy: String? = nil
    var usesCompactLayout = false

    // Tap callbacks
    let onTapSubscriptions: (() -> Void)?
    let onTapInstitutions: (() -> Void)?
    let onTapDocuments: (() -> Void)?
    let onTapMain: (() -> Void)?

    init(
        company: Company, 
        institutionsCount: Int?,
        subscriptionsCount: Int?,
        docsCount: Int?,
        onEdit: @escaping () -> Void, 
        canEdit: Bool = true,
        onShare: (() -> Void)? = nil,
        shareRole: String? = nil, 
        isSharedWithMe: Bool = false, 
        isSharedByMe: Bool = false, 
        sharedBy: String? = nil,
        onTapSubscriptions: (() -> Void)? = nil,
        onTapInstitutions: (() -> Void)? = nil,
        onTapDocuments: (() -> Void)? = nil,
        onTapMain: (() -> Void)? = nil,
        usesCompactLayout: Bool = false
    ) {
        self.company = company
        self.institutionsCount = institutionsCount
        self.subscriptionsCount = subscriptionsCount
        self.docsCount = docsCount
        self.onEdit = onEdit
        self.canEdit = canEdit
        self.onShare = onShare
        self.shareRole = shareRole
        self.isSharedWithMe = isSharedWithMe
        self.isSharedByMe = isSharedByMe
        self.sharedBy = sharedBy
        self.onTapSubscriptions = onTapSubscriptions
        self.onTapInstitutions = onTapInstitutions
        self.onTapDocuments = onTapDocuments
        self.onTapMain = onTapMain
        self.usesCompactLayout = usesCompactLayout
    }

    private var resolvedBrandColor: Color {
        company.brandColor
    }

    var body: some View {
        if usesCompactLayout {
            compactCard
        } else {
            standardCard
        }
    }

    private var standardCard: some View {
        VStack(spacing: 0) {
            // ── Top Row (Brand Canvas Header) ───────────────────────────
            HStack(alignment: .center, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // Logo
                    CompanyAvatar(company: company, size: 48)
                        .padding(.trailing, 14)

                    // Name + Structure
                    VStack(alignment: .leading, spacing: 4) {
                        Text(companyName)
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
                
                managementButtons
            }
            .frame(minHeight: 58)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(companyHeaderFill, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 18)

            // ── Status Row ───────────────────────────────────────────────
            HStack {
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
                
                statusItem(icon: "square.3.layers.3d", title: "Services", count: subscriptionsCount, color: Color(hex: "#1A7077"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapSubscriptions?()
                    }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 20)
                
                Spacer()
                
                statusItem(icon: "doc.text", title: "Documents", count: docsCount, color: Color(hex: "#1A7077"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTapDocuments?()
                    }
                
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .background(cardBackdrop(cornerRadius: 24))
        .shadow(color: resolvedBrandColor.opacity(0.08), radius: 20, x: 0, y: 10)
        .background(
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapMain?()
                }
        )
    }

    private var companyName: String {
        company.name.isEmpty ? "New Business" : company.name
    }

    private var companyHeaderFill: Color { .black.opacity(0.70) }

    private func cardBackdrop(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let gold = Color(hex: "#918457")
        return shape
            .fill(Color.zifrBG)
            .overlay { shape.fill(Color.zifrTabBarFill.opacity(0.70)) }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [gold, gold.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            }
            .allowsHitTesting(false)
    }

    private var compactCard: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Button {
                    onTapMain?()
                } label: {
                    HStack(spacing: 10) {
                        CompanyAvatar(company: company, size: 38)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(companyName)
                                .font(.headline)
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text(company.structure)
                                    .foregroundStyle(.secondary)
                                if isSharedWithMe {
                                    Text(shareRole ?? "Viewer")
                                        .foregroundStyle(Color.zifrGold)
                                } else if isSharedByMe {
                                    Text("Owner")
                                        .foregroundStyle(Color.zifrGold)
                                }
                            }
                            .font(.caption)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(onTapMain == nil)
                managementButtons
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(companyHeaderFill, in: RoundedRectangle(cornerRadius: 12))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { compactShortcuts }
                VStack(spacing: 0) { compactShortcuts }
            }
        }
        .padding(7)
        .foregroundStyle(.white)
        .background(cardBackdrop(cornerRadius: 16))
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var compactShortcuts: some View {
        compactShortcut(.financial, count: institutionsCount, action: onTapInstitutions)
        compactShortcut(.subscriptions, count: subscriptionsCount, action: onTapSubscriptions)
        compactShortcut(.documents, count: docsCount, action: onTapDocuments)
    }

    private func compactShortcut(_ tab: EntityHomeTab, count: Int?, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .foregroundStyle(Color.zifrGold)
                Text(tab.rawValue)
                    .fontWeight(.medium)
                Text(count.map(String.init) ?? "–")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
        .accessibilityLabel(Text("\(companyName), \(tab.rawValue)"))
        .accessibilityValue(count.map(String.init) ?? "Count unavailable")
    }

    private var managementButtons: some View {
        HStack(spacing: 2) {
            if canEdit {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit company")
            }

            if let onShare = onShare {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share company")
            }
        }
    }

    private func statusItem(icon: String, title: String, count: Int?, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
                
                Text(count.map(String.init) ?? "–")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}
