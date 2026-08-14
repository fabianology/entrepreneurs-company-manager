import SwiftUI

struct DocumentCategoryCoverFlow: View {
    let documents: [CompanyDocument]
    let docCategories: [String]
    @Binding var selectedCategory: String?

    private let docsColor = Color(hex: "#918457")

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(docCategories, id: \.self) { category in
                    let docsInCategory = documents.filter { CompanyDocument.normalizeType($0.type) == category }
                    let count = docsInCategory.count
                    let hasDocs = count > 0
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: CompanyDocument.icon(for: category))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(hasDocs ? docsColor : Color.white.opacity(0.25))
                                .frame(width: 24, height: 24)
                            
                            Text(categoryShortName(category))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(hasDocs ? .white : Color.white.opacity(0.35))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(hasDocs ? docsColor : Color.white.opacity(0.2))
                            +
                            Text(" doc\(count == 1 ? "" : "s")")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(hasDocs ? 0.5 : 0.2))
                        }
                        .padding(8)
                        .frame(width: 80, height: 90, alignment: .leading)
                        .background(hasDocs ? Color(hex: "#1C1C1E") : Color(hex: "#1C1C1E").opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(hasDocs ? docsColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 106)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(hex: "#1C1C1E").opacity(0.70))
        .frame(maxWidth: .infinity)
    }

    private func categoryShortName(_ name: String) -> String {
        switch name {
        case "Formation & Governance": return "Formation"
        case "Compliance & Insurance": return "Compliance"
        case "Identity & Vital Records", "Identity & Vital Docs": return "Identity"
        case "Property & Assets", "Property & Estate": return "Property"
        case "Estate & Medical": return "Estate"
        case "Contracts & HR": return "Contracts"
        case "Tax & IRS": return "Tax & IRS"
        case "Legal & IP": return "Legal & IP"
        default: return name
        }
    }
}
