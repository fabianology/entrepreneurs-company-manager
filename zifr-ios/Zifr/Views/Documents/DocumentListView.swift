import SwiftUI
import SafariServices

struct DocumentListView: View {
    let company: Company
    let documents: [CompanyDocument]
    @Bindable var vm: AppViewModel
    @Environment(AppState.self) private var appState

    @State private var editingDoc: CompanyDocument? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var openURL: IdentifiableURL? = nil
    @State private var selectedType: String = "All"
    @State private var isScanning = false
    @State private var isProcessingScan = false
    @State private var showShareSheet = false
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_documents"
    @State private var shareResourceTitle: String = "All Documents"

    var grouped: [String: [CompanyDocument]] {
        Dictionary(grouping: documents, by: \.type)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // ── Action Bar ──
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                        Text("Documents")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                    }
                    .padding(.leading, 16)

                    Spacer()

                    Menu {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            shareResourceId = company.id
                            shareResourceType = "all_documents"
                            shareResourceTitle = "All Documents"
                            showShareSheet = true
                        } label: {
                            Label("All Documents", systemImage: "folder.badge.person.crop")
                        }
                        
                        if !documents.isEmpty {
                            ForEach(Array(grouped.keys.sorted()), id: \.self) { category in
                                Section(category) {
                                    ForEach(grouped[category] ?? []) { doc in
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            shareResourceId = doc.id
                                            shareResourceType = "document"
                                            shareResourceTitle = doc.name.isEmpty ? "Document" : doc.name
                                            showShareSheet = true
                                        } label: {
                                            Label(doc.name.isEmpty ? "Unnamed Document" : doc.name, systemImage: "person.crop.circle.badge.plus")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(hex: "#A2A2A2"))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 20)

                    Button {
                        newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                    } label: {
                        HStack(spacing: 6) {
                            Text("ADD DOCUMENT").font(.system(size: 13, weight: .bold)).tracking(1).foregroundStyle(.white)
                            Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.white.opacity(0.5))
                        }
                        .frame(width: 164, height: 44)
                        .contentShape(Rectangle())
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#1C1C1E").opacity(0.70))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 6)

                VStack(spacing: 12) {
                    // Category Dashboard Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(CompanyDocument.types(for: company.structure), id: \.self) { type in
                            let count = grouped[type]?.count ?? 0
                            CategoryGridCard(
                                title: type,
                                icon: CompanyDocument.icon(for: type),
                                count: count,
                                isSelected: selectedType == type
                            ) {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if selectedType == type {
                                    selectedType = "All"
                                } else {
                                    selectedType = type
                                }
                            }
                        }
                    }

                    // All Documents Box
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedType = "All"
                    } label: {
                        HStack {
                            Text("ALL DOCUMENTS")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(selectedType == "All" ? Color(hex: "#918457") : .white)
                            Spacer()
                            if documents.count > 0 {
                                Text("\(documents.count)")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(selectedType == "All" ? Color(hex: "#918457") : .white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedType == "All" ? Color(hex: "#918457").opacity(0.15) : Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .background(Color.clear)
                        .liquidGlass(cornerRadius: 12)
                    }
                }
                .padding(.horizontal, 20)

                if documents.isEmpty {
                    emptyState.padding(.horizontal, 20)
                } else {
                    if selectedType == "All" {
                        VStack(spacing: 10) {
                            ForEach(CompanyDocument.types(for: company.structure), id: \.self) { type in
                                if let docs = grouped[type], !docs.isEmpty {
                                    ForEach(docs) { doc in
                                        DocumentRow(doc: doc) {
                                            editingDoc = doc
                                        } onOpen: {
                                            if let u = URL(string: (doc.url ?? "").hasPrefix("http") ? (doc.url ?? "") : "https://\((doc.url ?? ""))") {
                                                openURL = IdentifiableURL(url: u)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    } else {
                        // Show only selected category
                        let docs = grouped[selectedType] ?? []
                        if docs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "folder")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                Text("No Documents")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(docs) { doc in
                                    DocumentRow(doc: doc) {
                                        editingDoc = doc
                                    } onOpen: {
                                        if let u = URL(string: (doc.url ?? "").hasPrefix("http") ? (doc.url ?? "") : "https://\((doc.url ?? ""))") {
                                            openURL = IdentifiableURL(url: u)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isScanning = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#A2A2A2"))
                    Text("SCAN")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 20)
                .frame(height: 36)
                .background(Color(hex: "#223E5A"))
                .clipShape(Capsule())
                .shadow(color: Color.zifrBlue.opacity(0.5), radius: 12, x: 0, y: 0)
            }
            .padding(.bottom, 20)
        }
        .overlay {
            if isProcessingScan {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.zifrBlue)
                            .shimmer()
                        Text("AI is extracting data...")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shimmer()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScannerView {
                isScanning = false
            } onComplete: { images in
                isScanning = false
                processScan(images)
            } onError: { error in
                isScanning = false
                print("Scanner error: \(error)")
            }
            .ignoresSafeArea()
        }
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true, companyStructure: company.structure)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: company.structure)
        }
        .sheet(item: $openURL) { wrapper in
            SafariView(url: wrapper.url)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
        }
    }

    @State private var dummyDoc = CompanyDocument(
        userId: UUID(),
        companyId: UUID(),
        name: "Articles of Incorporation",
        type: "Formation & Governance",
        url: "drive.google.com/...",
        uploadDate: "Oct 12, 2025",
        notes: "Filed in Delaware"
    )

    private var emptyState: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            newDoc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
        }) {
            ZStack {
                // Dummy document row
                VStack(spacing: 0) {
                    DocumentRow(doc: dummyDoc, onEdit: {}, onOpen: {})
                }
                .allowsHitTesting(false)
                .blur(radius: 3)
                
                // Glass overlay
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                    Text("ADD YOUR FIRST DOCUMENT")
                        .font(.system(size: 11, weight: .black))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding(.top, 40)
    }

    private func processScan(_ images: [UIImage]) {
        isProcessingScan = true
        
        Task {
            do {
                // 1. OCR Extract Text
                let extractedText = try await DocumentProcessor.shared.extractText(from: images)
                
                // 2. AI Categorization
                let categorization = await GeminiService.shared.categorizeDocument(text: extractedText, isPersonal: company.structure == "Personal")
                
                // 3. Generate PDF
                let filename = categorization?["name"] ?? UUID().uuidString
                let pdfURL = DocumentProcessor.shared.generatePDF(from: images, filename: filename)
                
                // 4. Create Document
                await MainActor.run {
                    var doc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                    
                    if let cat = categorization {
                        doc.name = cat["name"] ?? "Scanned Document"
                        doc.type = cat["category"] ?? "Other"
                        doc.uploadDate = cat["date"] ?? ""
                        doc.notes = cat["notes"] ?? ""
                    }
                    
                    if let url = pdfURL {
                        doc.url = url.absoluteString
                    }
                    vm.saveDoc(doc, appState: appState)
                    
                    isProcessingScan = false
                    
                    // Delay slightly to let the UI settle before opening sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editingDoc = doc
                    }
                }
                
            } catch {
                print("Failed to process scan: \(error)")
                await MainActor.run {
                    isProcessingScan = false
                }
            }
        }
    }
}

struct DocumentRow: View {
    let doc: CompanyDocument
    let onEdit: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.zifrBlue.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: doc.typeIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.zifrBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.name.isEmpty ? "Document" : doc.name)
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                if !(doc.uploadDate ?? "").isEmpty {
                    Text("Added \(doc.uploadDate ?? "")").zifrLabel()
                }
                if !(doc.notes ?? "").isEmpty {
                    Text(doc.notes ?? "")
                        .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if !(doc.url ?? "").isEmpty {
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.zifrBlue)
                    }
                }
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

struct EditDocumentSheet: View {
    @State var doc: CompanyDocument
    @Bindable var vm: AppViewModel
    let isNew: Bool
    let companyStructure: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var showShareSheet = false
    
    struct Snapshot: Equatable {
        var name, type, url, uploadDate, notes: String
    }
    
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: doc.name, type: doc.type, url: doc.url ?? "", uploadDate: doc.uploadDate ?? "", notes: doc.notes ?? "")
    }

    private var isDirty: Bool {
        guard let snap = snapshot else { return isNew && !doc.name.trimmingCharacters(in: .whitespaces).isEmpty }
        return snap != currentSnapshot
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ZifrField(label: "Document Name", placeholder: "Articles of Incorporation", text: Binding(get: { doc.name }, set: { doc.name = $0 }))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Document Type").zifrLabel()
                        HStack {
                            Picker("Type", selection: Binding(get: { doc.type }, set: { doc.type = $0 })) {
                                ForEach(CompanyDocument.types(for: companyStructure), id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                            Spacer()
                        }
                        .cifrField()
                    }
                    ZifrField(label: "URL / Link", placeholder: "https://drive.google.com/...", text: Binding(get: { doc.url ?? "" }, set: { doc.url = $0 }), keyboardType: .URL)
                    ZifrField(label: "Upload Date", placeholder: "April 15, 2026", text: Binding(get: { doc.uploadDate ?? "" }, set: { doc.uploadDate = $0 }))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").zifrLabel()
                        TextEditor(text: Binding(get: { doc.notes ?? "" }, set: { doc.notes = $0 }))
                            .font(.system(size: 13)).foregroundStyle(.white)
                            .scrollContentBackground(.hidden).frame(minHeight: 70)
                            .padding(12).background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !isNew {
                        // Share Document
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showShareSheet = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Share Document")
                                Spacer()
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4f46e5"))
                            .padding(.vertical, 14)
                            .background(Color(hex: "#4f46e5").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4f46e5").opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)

                        if showDelete {
                            HStack(spacing: 20) {
                                Text("Sure?").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
                                Button("Yes") { vm.deleteDoc(doc, appState: appState); dismiss() }
                                    .font(.system(size: 12, weight: .black)).foregroundStyle(.red)
                                Button("No") { showDelete = false }
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color.white.opacity(0.4))
                            }
                            .padding(14).glassCard(cornerRadius: 14)
                        } else {
                            Button { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); showDelete = true } label: {
                                Label("Delete Document", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.red.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(20).padding(.bottom, 40)
            }
            .background(Color(hex: "#171717"))
            .navigationTitle(isNew ? "New Document" : "Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                snapshot = currentSnapshot
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        if isNew { 
                            vm.deleteDoc(doc, appState: appState) 
                        } else if let snap = snapshot {
                            doc.name = snap.name
                            doc.type = snap.type
                            doc.url = snap.url
                            doc.uploadDate = snap.uploadDate
                            doc.notes = snap.notes
                        }
                        dismiss() 
                    }
                    .foregroundStyle(Color.white.opacity(0.5))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveDoc(doc, appState: appState); dismiss() }
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(isDirty ? Color.green : .white)
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: doc.id, resourceType: "document", resourceTitle: doc.name.isEmpty ? "Document" : doc.name)
            }
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct CategoryGridCard: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Color(hex: "#918457") : .white)
                    
                    Spacer()
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(isSelected ? Color(hex: "#918457") : .white)
                            .frame(width: 20, height: 20)
                            .background(isSelected ? Color(hex: "#918457").opacity(0.15) : Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? Color(hex: "#918457") : Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(height: 75)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .liquidGlass(cornerRadius: 16)
        }
    }
}
