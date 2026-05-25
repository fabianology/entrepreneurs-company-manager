import SwiftUI

struct EntityDocumentSection: View {
    let company: Company
    let documents: [CompanyDocument]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState
    
    @Binding var expandedCategories: Set<String>
    @Binding var newDoc: CompanyDocument?
    @Binding var editingDoc: CompanyDocument?

    private let docsColor = Color(hex: "#23414B")

    private var docCategories: [String] {
        ["Incorporation", "Taxes", "Bank Statements", "Contracts", "IP", "Payroll", "Insurance", "Misc"]
    }
    
    private var coveredCategories: Set<String> {
        Set(documents.map { $0.type })
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.activeTab = .documents
            } label: {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(docsColor)
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
                .padding(.bottom, 16)
                .background(Color.white.opacity(0.03))
                .overlay(
                    Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            // Categories Accordion
            VStack(spacing: 8) {
                ForEach(docCategories.filter { coveredCategories.contains($0) }, id: \.self) { category in
                    let docsInCategory = documents.filter { $0.type == category }
                    let isExpanded = expandedCategories.contains(category)
                    
                    ExpandableDashboardCard(
                        isExpanded: isExpanded,
                        onToggle: {
                            if isExpanded { expandedCategories.remove(category) }
                            else { expandedCategories.insert(category) }
                        },
                        collapsedHeader: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(docsColor)
                                Text(category)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(docsInCategory.count) Docs")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .rotationEffect(.degrees(isExpanded ? 0 : 180))
                                    .padding(.leading, 8)
                            }
                        },
                        innerRows: {
                            ForEach(docsInCategory) { doc in
                                DashboardInnerRow(
                                    icon: "doc.text.fill",
                                    label: doc.name,
                                    value: ""
                                )
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingDoc = doc
                                }
                            }
                        },
                        actionButtons: {
                            DashboardActionButton(icon: "list.bullet.rectangle", title: "View Details") {
                                vm.activeTab = .documents
                            }
                            Divider().background(Color.white.opacity(0.06))
                            DashboardActionButton(icon: "plus", title: "Add Document") {
                                newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Button {
                // Future: show document report
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Generate Report")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PremiumButtonStyle())
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1C1C1E").opacity(0.70))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
