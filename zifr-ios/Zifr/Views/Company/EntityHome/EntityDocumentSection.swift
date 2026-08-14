import SwiftUI

struct EntityDocumentSection: View {
    let company: Company
    let documents: [CompanyDocument]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    @Environment(OnboardingStateManager.self) private var onboardingState
    
    @Binding var expandedCategories: Set<String>
    @Binding var newDoc: CompanyDocument?
    @Binding var editingDoc: CompanyDocument?

    @Binding var selectedCategory: String?

    private let docsColor = Color(hex: "#918457")

    private var docCategories: [String] {
        CompanyDocument.types(for: company.structure)
    }
    
    private var coveredCategories: Set<String> {
        Set(documents.map { CompanyDocument.normalizeType($0.type) })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .documents
            } label: {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(docsColor)
                            .padding(.trailing, 8)
                        
                        Text("DOCUMENTS")
                            .font(.system(size: 13, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("\(documents.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" docs").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                            
                            Text("\(coveredCategories.count)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white) +
                            Text(" categories").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.leading, 4)
                    }
                    
                    let completionRatio = docCategories.isEmpty ? 0.0 : Double(coveredCategories.count) / Double(docCategories.count)
                    let completionPct = Int(completionRatio * 100)
                    
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.1))
                                Capsule()
                                    .fill(LinearGradient(colors: [docsColor, docsColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(completionRatio))
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(completionPct)% Vault Completion")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color.black.opacity(0.70))
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)


        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .spotlightTarget(isActive: onboardingState.isSpotlightingCommandCenterDocuments)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func categoryPopup(category: String) -> some View {
        let docsInCategory = documents.filter { CompanyDocument.normalizeType($0.type) == category }
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        selectedCategory = nil
                    }
                }
            
            VStack(spacing: 0) {
                categoryPopupHeader(category: category, count: docsInCategory.count)
                
                Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                
                categoryPopupList(docs: docsInCategory)
                
                Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                
                categoryPopupActions()
            }
            .background(Color(hex: "#1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(10)
    }
    
    @ViewBuilder
    private func categoryPopupHeader(category: String, count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(docsColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: CompanyDocument.icon(for: category))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(docsColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                let suffix = count == 1 ? "" : "s"
                Text("\(count) document\(suffix)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private func categoryPopupList(docs: [CompanyDocument]) -> some View {
        if docs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.25))
                Text("No documents yet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(docs) { doc in
                        categoryDocRow(doc: doc, isLast: doc.id == docs.last?.id)
                    }
                }
            }
            .frame(maxHeight: 250)
        }
    }
    
    @ViewBuilder
    private func categoryDocRow(doc: CompanyDocument, isLast: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedCategory = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                editingDoc = doc
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(docsColor.opacity(0.8))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.name.isEmpty ? "Untitled" : doc.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !(doc.notes ?? "").isEmpty {
                        Text(doc.notes ?? "")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        
        if !isLast {
            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
        }
    }
    
    @ViewBuilder
    private func categoryPopupActions() -> some View {
        HStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedCategory = nil
                newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Document")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(docsColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            
            Divider().background(Color.white.opacity(0.06)).frame(height: 20)
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    selectedCategory = nil
                }
            } label: {
                Text("Close")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
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
