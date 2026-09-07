import SwiftUI
import UniformTypeIdentifiers

struct BusinessExpenseReviewSheet: View {
    var initialReview: BusinessExpenseReview? = nil
    var transaction: ResolvedTransaction? = nil
    @Environment(AppState.self) private var state
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var model = TaxOpportunitiesViewModel()
    @State private var reviewId: UUID?
    @State private var editingReview: BusinessExpenseReview?
    @State private var companyId: UUID?
    @State private var percent = "100"
    @State private var purpose = ""
    @State private var category = ""
    @State private var exception = ""
    @State private var context = ""
    @State private var notes = ""
    @State private var treatment = "undetermined"
    @State private var professional = "not_requested"
    @State private var acknowledge = false
    @State private var showImporter = false
    @State private var showScanner = false
    @State private var receiptData: Data?
    @State private var receiptName = "receipt.pdf"
    @State private var receiptType = "application/pdf"
    @State private var documentURL: URL?
    @State private var mutationId = UUID()
    private var review: BusinessExpenseReview? { state.businessExpenseReviews.first { $0.id == reviewId || ($0.transactionId != nil && $0.transactionId == transaction?.id) } ?? initialReview }
    private var companies: [Company] { state.companies.filter { $0.userId == auth.currentUser?.id && OwnerBriefingScope.business.includes($0) } }
    private var basisPoints: Int? {
        guard let decimal = Decimal(string: percent, locale: Locale(identifier: "en_US_POSIX")), decimal > 0, decimal <= 100 else { return nil }
        let scaled = decimal * 100
        let result = NSDecimalNumber(decimal: scaled).intValue
        return Decimal(result) == scaled ? result : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Actual payment") {
                    Text(review?.source.merchant ?? transaction.map { TransactionIntelligence.displayName(for: $0) } ?? "Transaction").font(.headline)
                    if let source = review?.source {
                        LabeledContent("Purchase", value: BusinessExpensePolicy.money(source.amount, currency: source.currency))
                        LabeledContent("Account", value: source.accountName)
                        LabeledContent("Institution", value: source.institutionName)
                        LabeledContent("Date", value: source.date)
                    } else if let transaction {
                        LabeledContent("Purchase", value: BusinessExpensePolicy.money(transaction.transaction.amount.map { Decimal($0) }, currency: transaction.transaction.currency))
                        LabeledContent("Account", value: transaction.accountName)
                        LabeledContent("Institution", value: transaction.institutionName)
                    }
                    Text("Business review does not move or duplicate this purchase.").font(.caption).foregroundStyle(.secondary)
                }
                if let review {
                    Section(review.statusLabel) {
                        ForEach(review.suggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Potential \(companies.first { $0.id == suggestion.companyId }?.name ?? "business") expense").fontWeight(.semibold)
                                Text(suggestion.explanation).font(.footnote)
                                Text(suggestion.confidence == "high" ? "High business relevance" : "Worth reviewing").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if review.sourceState == "disconnected" { Text("Payment account disconnected. This retained record describes the reviewed purchase.").font(.footnote) }
                        if review.sourceState == "changed" && review.transactionId != nil { Toggle("I reviewed the changed source transaction", isOn: $acknowledge) }
                        if review.sourceState == "removed" || review.sourceState == "conflict" { Text("The financial source needs attention before a standard export. Your previous review is preserved.").foregroundStyle(.orange) }
                        if review.changedSinceExport { Text("Changed since export").foregroundStyle(.orange) }
                    }
                }
                Section("Business use") {
                    Picker("Entity", selection: $companyId) {
                        Text("Choose Entity").tag(nil as UUID?)
                        ForEach(companies) { Text($0.name).tag(Optional($0.id)) }
                    }
                    HStack {
                        Button("Yes, business") { percent = "100" }
                        Spacer()
                        Button("Partly") { percent = "50" }
                    }.buttonStyle(.borderless)
                    TextField("Business-use percentage", text: $percent).keyboardType(.decimalPad)
                    Text("Enter 100 for wholly business use, or a smaller percentage for mixed personal/business use.").font(.caption).foregroundStyle(.secondary)
                    TextField("Business purpose", text: $purpose, axis: .vertical).lineLimit(2...5)
                    Picker("Expense category", selection: $category) {
                        Text("Choose category").tag("")
                        ForEach(BusinessExpensePolicy.categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Client, project, event, or travel purpose (optional)", text: $context, axis: .vertical)
                    Button(review?.decision == "confirmed" ? "Save business review" : "Confirm for Business") { save(decision: "confirmed") }
                        .disabled(companyId == nil || basisPoints == nil || model.isBusy)
                }
                Section("Receipt / documentation") {
                    if review?.allocation != nil {
                        ForEach(review?.documents ?? []) { document in
                            HStack {
                                Button { Task {
                                    do { documentURL = try await DataRepository.shared.getSignedUrl(for: document.path) }
                                    catch { model.error = error.localizedDescription }
                                } } label: { Label(document.name, systemImage: "lock.doc") }
                                Spacer()
                                Button(role: .destructive) { unlink(document) } label: { Image(systemName: "link.badge.plus").rotationEffect(.degrees(45)) }.accessibilityLabel("Unlink receipt")
                            }.buttonStyle(.borderless)
                        }
                        Button("Upload receipt") { showImporter = true }
                        Button("Scan receipt") { showScanner = true }
                    } else { Text("Confirm the Entity first, then attach a receipt.").font(.footnote).foregroundStyle(.secondary) }
                    if receiptData != nil {
                        Text("\(receiptName) — not uploaded yet").font(.footnote).foregroundStyle(.orange)
                        Button("Retry receipt upload") { uploadReceipt() }.disabled(model.isBusy)
                    }
                    TextField("If no receipt is available, explain why", text: $exception, axis: .vertical).lineLimit(2...4)
                    if let allocation = review?.allocation,
                       let entity = state.companies.first(where: { $0.id == allocation.companyId }) {
                        Text("Saved in \(entity.name) → Vault → Receipts. The original payment source stays linked.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Receipts are private to you. An exception is disclosed in the accountant export.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Bookkeeping review") {
                    Picker("Proposed treatment", selection: $treatment) { ForEach(BusinessExpensePolicy.treatments, id: \.0) { Text($0.1).tag($0.0) } }
                    Picker("Tax professional", selection: $professional) {
                        Text("Not requested").tag("not_requested")
                        Text("Review requested").tag("requested")
                        Text("Reviewed externally — recorded by me").tag("owner_recorded_review")
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                    Text("Miloom does not select accounting or tax treatment for you.").font(.caption).foregroundStyle(.secondary)
                }
                if let review, review.decision == "confirmed" {
                    Section("Documentation checklist") {
                        if review.missing.isEmpty {
                            Label(exception.isEmpty ? "Ready for Tax Professional" : "Ready — receipt exception noted", systemImage: "checkmark.circle")
                        } else { ForEach(review.missing, id: \.self) { Label($0, systemImage: "circle").foregroundStyle(.orange) } }
                    }
                }
                Section {
                    Button("No, personal") { save(decision: "personal") }.disabled(model.isBusy)
                    Button("Dismiss suggestion") { save(decision: "dismissed") }.disabled(model.isBusy)
                    if let review, review.decision != "unreviewed" { Button("Reopen for review") { save(decision: "unreviewed") }.disabled(model.isBusy) }
                }
                if model.isBusy { ProgressView("Saving…") }
                if let error = model.error { Text(error).foregroundStyle(.orange) }
                Section { Text(BusinessExpensePolicy.disclosure).font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Business Review").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(model.isBusy) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(decision: "confirmed") }.disabled(companyId == nil || basisPoints == nil || model.isBusy) }
            }
            .task {
                reviewId = initialReview?.id
                await model.refresh(state)
                let current = review
                editingReview = current
                reviewId = current?.id
                if let a = current?.allocation {
                    companyId = a.companyId; percent = NSDecimalNumber(decimal: Decimal(a.businessBasisPoints) / 100).stringValue
                    purpose = a.purpose; category = a.category; exception = a.receiptException; context = a.context; notes = a.notes; treatment = a.treatment; professional = a.professionalStatus
                } else if current?.suggestions.count == 1 { companyId = current?.suggestions.first?.companyId }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let allowed = url.startAccessingSecurityScopedResource(); defer { if allowed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                    receiptData = try Data(contentsOf: url); receiptName = url.lastPathComponent
                    receiptType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/pdf"
                    uploadReceipt()
                } catch { model.error = error.localizedDescription }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView(onCancel: { showScanner = false }, onComplete: { images in
                    showScanner = false
                    if let url = DocumentProcessor.shared.generatePDF(from: images, filename: "expense-receipt") {
                        do { receiptData = try Data(contentsOf: url); receiptName = "receipt.pdf"; receiptType = "application/pdf"; try? FileManager.default.removeItem(at: url); uploadReceipt() }
                        catch { model.error = error.localizedDescription }
                    } else { model.error = "Could not create the receipt PDF. Please try again." }
                }, onError: { error in showScanner = false; model.error = error.localizedDescription })
            }
            .sheet(isPresented: Binding(get: { documentURL != nil }, set: { if !$0 { documentURL = nil } })) {
                if let documentURL { SafariView(url: documentURL) }
            }
        }.preferredColorScheme(.dark)
    }
    private func advanceEditingRevision() {
        let expected = (editingReview?.revision ?? 1) + 1
        editingReview = review
        editingReview?.revision = expected
    }
    private func save(decision: String) {
        let allocation = companyId.flatMap { id in basisPoints.map { BusinessExpenseAllocation(companyId: id, businessBasisPoints: $0, purpose: purpose, category: category, receiptException: exception, context: context, notes: notes, treatment: treatment, professionalStatus: professional) } }
        Task {
            if await model.perform(state, operation: {
                reviewId = try await DataRepository.shared.saveBusinessExpense(transactionId: transaction?.id, review: editingReview, decision: decision, allocation: decision == "confirmed" ? allocation : nil, acknowledge: acknowledge, mutationId: mutationId)
            }) { advanceEditingRevision(); mutationId = UUID(); acknowledge = false }
        }
    }
    private func uploadReceipt() {
        guard let review = editingReview ?? review, let receiptData else { return }
        Task {
            if await model.perform(state, operation: { try await DataRepository.shared.attachBusinessExpenseReceipt(review: review, data: receiptData, name: receiptName, contentType: receiptType) }) { advanceEditingRevision(); self.receiptData = nil }
        }
    }
    private func unlink(_ document: BusinessExpenseDocument) {
        guard let review = editingReview ?? review else { return }
        Task { if await model.perform(state, operation: { try await DataRepository.shared.unlinkBusinessExpenseReceipt(review: review, documentId: document.id) }) { advanceEditingRevision() } }
    }
}
