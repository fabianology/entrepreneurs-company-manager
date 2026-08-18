import SwiftUI
import SafariServices
import PhotosUI
import PDFKit

struct DocumentListView: View {
    let company: Company
    let documents: [CompanyDocument]
    @Bindable var vm: AppViewModel
    var hideActionBar: Bool = false
    @Environment(AppState.self) private var appState
    @Environment(OnboardingStateManager.self) private var onboardingState

    @State private var editingDoc: CompanyDocument? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var documentToDelete: CompanyDocument? = nil
    @State private var openURL: IdentifiableURL? = nil
    @State private var selectedType: String = "All"
    @State private var isScanning = false
    @State private var isProcessingScan = false
    @State private var showShareSheet = false
    @State private var shareResourceId: UUID = UUID()
    @State private var shareResourceType: String = "all_documents"
    @State private var shareResourceTitle: String = "All Documents"
    @AppStorage("aiConsentStatus") private var aiConsentStatus: String = "unset"
    @State private var showAIConsentAlert = false

    var grouped: [String: [CompanyDocument]] {
        Dictionary(grouping: documents, by: { CompanyDocument.normalizeType($0.type) })
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Scrollable Document Rows List (Background layer scrolling behind header)
            ScrollView {
                VStack(spacing: 0) {
                    // Offset for top action bar + anchored category tabs header
                    Spacer().frame(height: hideActionBar ? 312 : 276)

                    Group {
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
                                                    openDocument(doc)
                                                } onShare: {
                                                    shareResourceId = doc.id
                                                    shareResourceType = "document"
                                                    shareResourceTitle = doc.name.isEmpty ? "Document" : doc.name
                                                    showShareSheet = true
                                                } onDelete: {
                                                    documentToDelete = doc
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
                                                openDocument(doc)
                                            } onShare: {
                                                shareResourceId = doc.id
                                                shareResourceType = "document"
                                                shareResourceTitle = doc.name.isEmpty ? "Document" : doc.name
                                                showShareSheet = true
                                            } onDelete: {
                                                documentToDelete = doc
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
            }
            .scrollIndicators(.hidden)

            // Fixed Header with Tabs (anchored, does not move when scrolling)
            VStack(spacing: 0) {
                Spacer().frame(height: hideActionBar ? 98 : 62)

                VStack(spacing: 12) {
                    // All Documents Box (Full Width)
                    let isAllSelected = selectedType == "All"
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedType = "All"
                    } label: {
                        HStack {
                            Text("ALL DOCUMENTS")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(isAllSelected ? Color(hex: "#918457") : .white)
                            Spacer()
                            if documents.count > 0 {
                                Text("\(documents.count)")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(isAllSelected ? Color(hex: "#918457") : .white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isAllSelected ? Color(hex: "#918457").opacity(0.15) : Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isAllSelected ? Color.black.opacity(0.40) : Color.black.opacity(0.70))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "#918457"),
                                            Color(hex: "#918457").opacity(0.3)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
                    }

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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            
            if !hideActionBar {
                documentActionBar
                    .zIndex(100)
            }
        }.overlay(alignment: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if aiConsentStatus == "unset" {
                    showAIConsentAlert = true
                } else {
                    isScanning = true
                }
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
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true, companyStructure: company.structure)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: false, companyStructure: company.structure)
        }
        .sheet(item: $openURL) { wrapper in
            DocumentViewerView(url: wrapper.url)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareEntitySheet(resourceId: shareResourceId, resourceType: shareResourceType, resourceTitle: shareResourceTitle)
        }
        .fullScreenCover(isPresented: $isScanning) {
            DocumentScannerView(
                onCancel: {
                    isScanning = false
                },
                onComplete: { images in
                    isScanning = false
                    processScan(images)
                },
                onError: { error in
                    isScanning = false
                    print("Document scan error: \(error.localizedDescription)")
                }
            )
            .ignoresSafeArea()
        }
        .alert("AI Document Processing", isPresented: $showAIConsentAlert) {
            Button("Yes (Use AI)") {
                aiConsentStatus = "yes"
                isScanning = true
            }
            Button("No (Manual Only)") {
                aiConsentStatus = "no"
                isScanning = true
            }
        } message: {
            Text("Would you like to use Google Gemini AI to automatically extract text and categorize this document?\n\nClicking 'Yes' will securely process the document with AI. Clicking 'No' keeps the document entirely private on your device, and you can categorize it manually.")
        }
        .alert(
            "Delete Document?",
            isPresented: Binding(
                get: { documentToDelete != nil },
                set: { if !$0 { documentToDelete = nil } }
            ),
            presenting: documentToDelete
        ) { doc in
            Button("Delete Document", role: .destructive) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    vm.deleteDoc(doc, appState: appState)
                }
                documentToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                documentToDelete = nil
            }
        } message: { doc in
            Text("“\(doc.name.isEmpty ? "This document" : doc.name)” and all associated files will be completely and permanently removed from the server. This action cannot be undone.")
        }
    }
    
    private var documentActionBar: some View {
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
                                    Label(doc.name.isEmpty ? "Unnamed Document" : doc.name, systemImage: "doc")
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
        .premiumDarkBar(cornerRadius: 12)
        .padding(.horizontal, 20)
        .padding(.top, 6)
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
        .spotlightTarget(isActive: onboardingState.isSpotlightingNotes)
    }

    private func openDocument(_ doc: CompanyDocument) {
        guard let docUrl = doc.url, !docUrl.isEmpty else { return }
        if docUrl.hasPrefix("file://") || docUrl.hasPrefix("/") {
            let cleanPath = docUrl.hasPrefix("file://") ? docUrl : "file://\(docUrl)"
            if let u = URL(string: cleanPath) {
                openURL = IdentifiableURL(url: u)
            }
        } else if let u = URL(string: docUrl.hasPrefix("http") ? docUrl : "https://\(docUrl)") {
            openURL = IdentifiableURL(url: u)
        }
    }

    private func processScan(_ images: [UIImage]) {
        isProcessingScan = true
        
        Task {
            do {
                // 1 & 2. OCR and AI Categorization (if consented)
                var categorization: [String: String]? = nil
                let filename: String
                
                if aiConsentStatus != "no" {
                    let extractedText = try await DocumentProcessor.shared.extractText(from: images)
                    categorization = await GeminiService.shared.categorizeDocument(text: extractedText, isPersonal: company.structure == "Personal")
                    filename = categorization?["name"] ?? UUID().uuidString
                } else {
                    filename = "Scanned_\(Int(Date().timeIntervalSince1970))"
                }
                
                // 3. Generate PDF
                let pdfURL = DocumentProcessor.shared.generatePDF(from: images, filename: filename)
                
                // 4. Create Document
                await MainActor.run {
                    var doc = vm.addDocument(appState: appState, userId: company.userId, companyId: company.id)
                    
                    if let cat = categorization {
                        doc.name = cat["name"] ?? "Scanned Document"
                        doc.type = CompanyDocument.normalizeType(cat["category"] ?? "Other")
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
    var onShare: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    enum RevealedState { case none, leftActions, rightAction }

    @State private var dragOffset: CGFloat = 0
    @State private var revealedState: RevealedState = .none

    private let leftRevealWidth: CGFloat = 70
    private let rightRevealWidth: CGFloat = -70

    var body: some View {
        ZStack {
            // Share Action Button revealed on sliding right (left side)
            if (dragOffset > 0 || revealedState == .leftActions) && onShare != nil {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                            revealedState = .none
                        }
                        onShare?()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.70))
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(hex: "#918457").opacity(0.95),
                                                        Color(hex: "#918457").opacity(0.35)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color(hex: "#918457").opacity(0.30), radius: 6, x: 0, y: 2)

                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                            }
                            .frame(width: 44, height: 44)

                            Text("Share")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .opacity(min(1.0, Double(max(0, dragOffset) / 40.0)))

                    Spacer()
                }
            }

            // Delete Action Button revealed on sliding left (right side)
            if (dragOffset < 0 || revealedState == .rightAction) && onDelete != nil {
                HStack {
                    Spacer()

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                            revealedState = .none
                        }
                        onDelete?()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.70))
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.red.opacity(0.95),
                                                        Color.red.opacity(0.35)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color.red.opacity(0.30), radius: 6, x: 0, y: 2)

                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.red.opacity(0.9))
                            }
                            .frame(width: 44, height: 44)

                            Text("Delete")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .opacity(min(1.0, Double(abs(min(0, dragOffset)) / 40.0)))
                }
            }

            // Document row content
            HStack(spacing: 14) {
                Image(systemName: doc.typeIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.name.isEmpty ? "Document" : doc.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    if !(doc.uploadDate ?? "").isEmpty {
                        Text("Added \(doc.uploadDate ?? "")")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    if !(doc.notes ?? "").isEmpty {
                        Text(doc.notes ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if !(doc.url ?? "").isEmpty {
                    Button(action: onOpen) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(hex: "#918457"))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1C1C1E"))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#918457"),
                                Color(hex: "#918457").opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .onTapGesture {
                if revealedState != .none {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dragOffset = 0
                        revealedState = .none
                    }
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let translation = value.translation.width
                        if revealedState == .none {
                            if translation > 0 && onShare != nil {
                                dragOffset = min(leftRevealWidth + 15, translation)
                            } else if translation < 0 && onDelete != nil {
                                if translation > rightRevealWidth {
                                    dragOffset = translation
                                } else {
                                    dragOffset = rightRevealWidth + (translation - rightRevealWidth) * 0.75
                                }
                            }
                        } else if revealedState == .leftActions {
                            dragOffset = max(0, min(leftRevealWidth + 15, leftRevealWidth + translation))
                        } else if revealedState == .rightAction {
                            if translation > 0 {
                                dragOffset = min(0, rightRevealWidth + translation)
                            } else {
                                dragOffset = rightRevealWidth + translation * 0.75
                            }
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - value.translation.width

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if revealedState == .none {
                                if translation < -140 || (translation < -80 && velocity < -150) {
                                    // Deep swipe-through: trigger delete confirmation popup directly
                                    dragOffset = 0
                                    revealedState = .none
                                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                    onDelete?()
                                } else if translation < -30 && onDelete != nil {
                                    dragOffset = rightRevealWidth
                                    revealedState = .rightAction
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } else if translation > 30 && onShare != nil {
                                    dragOffset = leftRevealWidth
                                    revealedState = .leftActions
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } else {
                                    dragOffset = 0
                                    revealedState = .none
                                }
                            } else if revealedState == .leftActions {
                                if translation < -20 {
                                    dragOffset = 0
                                    revealedState = .none
                                } else {
                                    dragOffset = leftRevealWidth
                                    revealedState = .leftActions
                                }
                            } else if revealedState == .rightAction {
                                if translation < -60 || velocity < -120 {
                                    // Swiped further left from revealed state -> trigger delete popup
                                    dragOffset = 0
                                    revealedState = .none
                                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                                    onDelete?()
                                } else if translation > 20 {
                                    dragOffset = 0
                                    revealedState = .none
                                } else {
                                    dragOffset = rightRevealWidth
                                    revealedState = .rightAction
                                }
                            }
                        }
                    }
            )
        }
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
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    
    @State private var inputMode: Int = 0 // 0 = File, 1 = Link
    
    private var uploadDateBinding: Binding<Date> {
        Binding {
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            if let str = doc.uploadDate, !str.isEmpty, let d = df.date(from: str) { return d }
            return Date()
        } set: { newDate in
            let df = DateFormatter()
            df.dateFormat = "MMM d, yyyy"
            doc.uploadDate = df.string(from: newDate)
        }
    }
    
    private var isViewer: Bool {
        let share = appState.resourceShares.first(where: { $0.resourceId == doc.id || $0.resourceId == doc.companyId })
        return share?.role == "Viewer"
    }
    
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
            ZStack {
                Color(hex: "#171717").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        SharedItemOverrideBanner(resourceId: doc.id, defaultCompanyId: doc.companyId)
                        
                        Group {
                            // 1. Document Info Card
                            ZifrSheetCard(title: "Document Info", icon: "doc.text.fill") {
                                VStack(spacing: 14) {
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
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Upload Date").zifrLabel()
                                        HStack {
                                            DatePicker("Upload Date", selection: uploadDateBinding, displayedComponents: .date)
                                                .labelsHidden()
                                                .colorScheme(.dark)
                                                .tint(.zifrBlue)
                                            Spacer()
                                        }
                                        .cifrField()
                                    }
                                }
                            }
                            
                            // 2. File & Storage Card
                            ZifrSheetCard(title: "File & Storage", icon: "folder.fill") {
                                VStack(spacing: 14) {
                                    Picker("Source", selection: $inputMode) {
                                        Text("Local File").tag(0)
                                        Text("External Link").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    
                                    if inputMode == 0 {
                                        VStack(spacing: 12) {
                                            if let url = doc.url, !url.isEmpty, !url.hasPrefix("http") {
                                                HStack {
                                                    Image(systemName: "doc.circle.fill")
                                                        .font(.system(size: 22))
                                                        .foregroundStyle(Color(hex: "#C1AA78"))
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Local File / Scan")
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundStyle(.white)
                                                        Text(url)
                                                            .font(.system(size: 10))
                                                            .foregroundStyle(Color.white.opacity(0.5))
                                                            .lineLimit(1)
                                                    }
                                                    Spacer()
                                                    
                                                    Button(role: .destructive) {
                                                        doc.url = nil
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundStyle(.red)
                                                            .font(.system(size: 16))
                                                    }
                                                }
                                                .padding(12)
                                                .background(Color.white.opacity(0.05))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                            
                                            HStack(spacing: 12) {
                                                Button {
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    showFileImporter = true
                                                } label: {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "folder.badge.plus")
                                                        Text("Choose File")
                                                        Spacer()
                                                    }
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.vertical, 12)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                }
                                                .buttonStyle(.plain)
                                                
                                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "photo.badge.plus")
                                                        Text("Choose Photo")
                                                        Spacer()
                                                    }
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.vertical, 12)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                }
                                            }
                                            
                                            if isUploading {
                                                HStack(spacing: 8) {
                                                    ProgressView()
                                                        .tint(.zifrBlue)
                                                    Text("Uploading document...")
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(Color.white.opacity(0.6))
                                                }
                                                .padding(.top, 4)
                                            }
                                            
                                            if let err = uploadError {
                                                Text(err)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundStyle(.red)
                                                    .padding(.top, 4)
                                            }
                                        }
                                    } else {
                                        ZifrField(label: "URL / Link", placeholder: "https://drive.google.com/...", text: Binding(get: { doc.url ?? "" }, set: { doc.url = $0 }), keyboardType: .URL)
                                    }
                                }
                            }
                            
                            // 3. Notes Card
                            ZifrSheetCard(title: "Notes", icon: "note.text") {
                                TextEditor(text: Binding(get: { doc.notes ?? "" }, set: { doc.notes = $0 }))
                                    .font(.system(size: 13)).foregroundStyle(.white)
                                    .scrollContentBackground(.hidden).frame(minHeight: 80)
                                    .padding(12).background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // MARK: – Actions
                            if !isNew {
                                ZifrSheetCard(title: "ACTIONS", icon: "slider.horizontal.3") {
                                    VStack(spacing: 12) {
                                        // Share Document
                                        Button {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            showShareSheet = true
                                        } label: {
                                            VStack(spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "person.crop.circle.badge.plus")
                                                    Text("Share Document")
                                                }
                                                .font(.system(size: 13, weight: .semibold))
                                                Text("Generate a share link for collaborators")
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                        }
                                        .buttonStyle(MiloomSecondaryButtonStyle())
                                    }
                                }

                                // ── Unencapsulated Bottom Delete Button ─────
                                Button(role: .destructive) {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showDelete = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "trash")
                                        Text("Delete \(doc.name.isEmpty ? "Document" : doc.name)")
                                        Spacer()
                                    }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .confirmationDialog(
                                    "Delete \"\(doc.name.isEmpty ? "this document" : doc.name)\"?",
                                    isPresented: $showDelete,
                                    titleVisibility: .visible
                                ) {
                                    Button("Delete Document", role: .destructive) {
                                        vm.deleteDoc(doc, appState: appState)
                                        dismiss()
                                    }
                                    Button("Cancel", role: .cancel) {}
                                } message: {
                                    Text("This will permanently delete this document and all associated files from the server. This action cannot be undone.")
                                }
                            }
                        }
                        .disabled(isViewer)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isNew ? "New Document" : "Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                snapshot = currentSnapshot
                
                if (doc.uploadDate ?? "").isEmpty {
                    let df = DateFormatter()
                    df.dateFormat = "MMM d, yyyy"
                    doc.uploadDate = df.string(from: Date())
                }
                if let url = doc.url, url.hasPrefix("http") {
                    inputMode = 1
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item = item else { return }
                isUploading = true
                uploadError = nil
                
                Task {
                    do {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            let maxSize = 25 * 1024 * 1024 // 25 MB
                            guard data.count <= maxSize else {
                                throw NSError(domain: "App", code: -3, userInfo: [NSLocalizedDescriptionKey: "File is too large (\(data.count / 1_048_576) MB). Maximum size is 25 MB."])
                            }
                            let fileName = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                            let uploadUrl = try await DataRepository.shared.uploadDocumentFile(fileData: data, fileName: fileName, contentType: "image/jpeg")
                            
                            await MainActor.run {
                                doc.url = uploadUrl.absoluteString
                                if doc.name.isEmpty || doc.name == "New Document" {
                                    doc.name = "Photo - \(doc.type)"
                                }
                                isUploading = false
                            }
                        } else {
                            throw NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load photo data."])
                        }
                    } catch {
                        await MainActor.run {
                            uploadError = "Upload failed: \(error.localizedDescription)"
                            isUploading = false
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    isUploading = true
                    uploadError = nil
                    
                    Task {
                        do {
                            guard url.startAccessingSecurityScopedResource() else {
                                throw NSError(domain: "App", code: -2, userInfo: [NSLocalizedDescriptionKey: "Permission denied for this file."])
                            }
                            defer { url.stopAccessingSecurityScopedResource() }
                            
                            let data = try Data(contentsOf: url)
                            let maxSize = 25 * 1024 * 1024 // 25 MB
                            guard data.count <= maxSize else {
                                throw NSError(domain: "App", code: -3, userInfo: [NSLocalizedDescriptionKey: "File is too large (\(data.count / 1_048_576) MB). Maximum size is 25 MB."])
                            }
                            let fileName = url.lastPathComponent
                            
                            let uti = url.pathExtension.lowercased()
                            let contentType: String
                            switch uti {
                            case "pdf": contentType = "application/pdf"
                            case "png": contentType = "image/png"
                            case "jpg", "jpeg": contentType = "image/jpeg"
                            case "heic": contentType = "image/heic"
                            case "gif": contentType = "image/gif"
                            case "txt": contentType = "text/plain"
                            case "doc": contentType = "application/msword"
                            case "docx": contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                            case "xls": contentType = "application/vnd.ms-excel"
                            case "xlsx": contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                            case "csv": contentType = "text/csv"
                            default: contentType = "application/octet-stream"
                            }
                            
                            let uploadUrl = try await DataRepository.shared.uploadDocumentFile(fileData: data, fileName: fileName, contentType: contentType)
                            
                            await MainActor.run {
                                doc.url = uploadUrl.absoluteString
                                if doc.name.isEmpty || doc.name == "New Document" {
                                    doc.name = url.deletingPathExtension().lastPathComponent
                                }
                                isUploading = false
                            }
                        } catch {
                            await MainActor.run {
                                uploadError = "Upload failed: \(error.localizedDescription)"
                                isUploading = false
                            }
                        }
                    }
                case .failure(let error):
                    uploadError = "Failed to select file: \(error.localizedDescription)"
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(isNew ? "New Document" : "Edit Document")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: "#C1AA78"))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        if isNew {
                            // Only delete if it was already saved (e.g. scan flow saves before opening sheet)
                            if appState.documents.contains(where: { $0.id == doc.id }) {
                                vm.deleteDoc(doc, appState: appState)
                            }
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
                    if !isViewer {
                        Button("Save") { vm.saveDoc(doc, appState: appState); dismiss() }
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(isDirty ? Color.green : .white)
                    }
                }
            }
            .interactiveDismissDisabled(isNew)
            .sheet(isPresented: $showShareSheet) {
                ShareEntitySheet(resourceId: doc.id, resourceType: "document", resourceTitle: doc.name.isEmpty ? "Document" : doc.name)
            }
        }
    }
}

// MARK: - Document Viewer
struct DocumentViewerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var isLocalFile: Bool {
        url.isFileURL
    }
    
    var isPDF: Bool {
        url.pathExtension.lowercased() == "pdf"
    }
    
    var body: some View {
        if isLocalFile {
            NavigationStack {
                ZStack {
                    Color(hex: "#171717").ignoresSafeArea()
                    
                    Group {
                        if isPDF {
                            PDFKitView(url: url)
                        } else if let uiImage = UIImage(contentsOfFile: url.path) {
                            ScrollView([.horizontal, .vertical]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text("Unsupported offline file format")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                    }
                }
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            dismiss()
                        }
                        .foregroundStyle(Color.white.opacity(0.6))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.zifrBlue)
                        }
                    }
                }
            }
        } else {
            SafariView(url: url)
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.09, alpha: 1.0)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
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
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 13)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.black.opacity(0.40) : Color.black.opacity(0.70))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#918457"),
                                Color(hex: "#918457").opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        }
    }
}
