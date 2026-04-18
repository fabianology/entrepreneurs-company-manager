import SwiftUI
import SafariServices

struct DocumentListView: View {
    let company: Company
    let documents: [CompanyDocument]
    @Bindable var vm: AppViewModel
    @Environment(\.modelContext) private var context

    @State private var editingDoc: CompanyDocument? = nil
    @State private var newDoc: CompanyDocument? = nil
    @State private var openURL: IdentifiableURL? = nil

    var grouped: [String: [CompanyDocument]] {
        Dictionary(grouping: documents, by: \.type)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Add button row
                HStack {
                    Spacer()
                    Button { 
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        newDoc = vm.addDocument(context: context, companyId: company.id) 
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                            Text("DOCUMENT")
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(Color(hex: "#A2A2A2"))
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(Color(hex: "#222E2F"))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)

                if documents.isEmpty {
                    emptyState.padding(.horizontal, 20)
                } else {
                    ForEach(CompanyDocument.types, id: \.self) { type in
                        if let docs = grouped[type], !docs.isEmpty {
                            VStack(spacing: 10) {
                                // CiFr-style section header
                                HStack {
                                    Text(type)
                                        .font(.system(size: 12, weight: .bold))
                                        .textCase(.uppercase)
                                        .tracking(3)
                                        .foregroundStyle(Color.white.opacity(0.4))
                                    Spacer()
                                    Text("\(docs.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.25))
                                }
                                .padding(.horizontal, 20)

                                ForEach(docs) { doc in
                                    DocumentRow(doc: doc) {
                                        editingDoc = doc
                                    } onOpen: {
                                        if let u = URL(string: doc.url.hasPrefix("http") ? doc.url : "https://\(doc.url)") {
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
        .sheet(item: $newDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: true)
        }
        .sheet(item: $editingDoc) { doc in
            EditDocumentSheet(doc: doc, vm: vm, isNew: false)
        }
        .sheet(item: $openURL) { wrapper in
            SafariView(url: wrapper.url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 44))
                .foregroundStyle(Color.white.opacity(0.2))
            Text("No Documents")
                .font(.system(size: 16, weight: .black)).foregroundStyle(.white)
            Text("Store formation docs, contracts, and more")
                .font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Button("Add Document") { 
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newDoc = vm.addDocument(context: context, companyId: company.id) 
            }
                .font(.system(size: 13, weight: .black)).foregroundStyle(.black)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(.white).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
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
                if !doc.uploadDate.isEmpty {
                    Text("Added \(doc.uploadDate)").zifrLabel()
                }
                if !doc.notes.isEmpty {
                    Text(doc.notes)
                        .font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                if !doc.url.isEmpty {
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
    @Bindable var doc: CompanyDocument
    @Bindable var vm: AppViewModel
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    
    struct Snapshot: Equatable {
        var name, type, url, uploadDate, notes: String
    }
    
    @State private var snapshot: Snapshot?

    private var currentSnapshot: Snapshot {
        Snapshot(name: doc.name, type: doc.type, url: doc.url, uploadDate: doc.uploadDate, notes: doc.notes)
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
                        Picker("Type", selection: Binding(get: { doc.type }, set: { doc.type = $0 })) {
                            ForEach(CompanyDocument.types, id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                    ZifrField(label: "URL / Link", placeholder: "https://drive.google.com/...", text: Binding(get: { doc.url }, set: { doc.url = $0 })).keyboardType(.URL)
                    ZifrField(label: "Upload Date", placeholder: "April 15, 2026", text: Binding(get: { doc.uploadDate }, set: { doc.uploadDate = $0 }))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes").zifrLabel()
                        TextEditor(text: Binding(get: { doc.notes }, set: { doc.notes = $0 }))
                            .font(.system(size: 13)).foregroundStyle(.white)
                            .scrollContentBackground(.hidden).frame(minHeight: 70)
                            .padding(12).background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if !isNew {
                        if showDelete {
                            HStack(spacing: 20) {
                                Text("Sure?").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
                                Button("Yes") { vm.deleteDoc(doc, context: context); dismiss() }
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
                            vm.deleteDoc(doc, context: context) 
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
                    Button("Save") { vm.saveDoc(doc, context: context); dismiss() }
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(isDirty ? Color.green : .white)
                }
            }
            .interactiveDismissDisabled(isNew)
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
