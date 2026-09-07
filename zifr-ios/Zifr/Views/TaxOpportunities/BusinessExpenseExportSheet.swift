import SwiftUI
import Supabase

struct BusinessExpenseExportSheet: View {
    var initialCompanyId: UUID?
    @Environment(AppState.self) private var state
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var model = TaxOpportunitiesViewModel()
    @State private var companyId: UUID?
    @State private var start = BusinessExpensePolicy.defaultStart()
    @State private var end = Date()
    @State private var incomplete = false
    @State private var includeReceipts = false
    @State private var mutationId = UUID()
    @State private var files: [URL] = []
    @State private var showShare = false
    @State private var folder: URL?
    private var records: [BusinessExpenseReview] {
        state.businessExpenseReviews.filter {
            $0.allocation?.companyId == companyId && $0.decision == "confirmed" &&
            $0.source.date >= BusinessExpensePolicy.dateString(start) && $0.source.date <= BusinessExpensePolicy.dateString(end)
        }
    }
    private var blockers: [BusinessExpenseReview] { records.filter { !$0.missing.isEmpty } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Accountant export") {
                    Picker("Entity", selection: $companyId) {
                        Text("Choose Entity").tag(nil as UUID?)
                        ForEach(state.companies.filter { $0.userId == auth.currentUser?.id }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                    DatePicker("Through", selection: $end, in: start...Date(), displayedComponents: .date)
                    Text("\(records.count) confirmed expenses")
                    Toggle("Include selected expenses’ receipts", isOn: $includeReceipts)
                    Text("Shares the receipts attached to these expenses. Payment account names are included; account numbers are excluded.").font(.caption).foregroundStyle(.secondary)
                }
                if !blockers.isEmpty {
                    Section("\(blockers.count) expenses need attention") {
                        ForEach(blockers) { review in
                            VStack(alignment: .leading) { Text(review.source.merchant); Text(review.missing.joined(separator: ", ")).font(.caption).foregroundStyle(.orange) }
                        }
                        Toggle("Export incomplete records for review", isOn: $incomplete)
                    }
                }
                Section {
                    Button(incomplete ? "Generate incomplete review export" : "Generate accountant CSV") { generate() }
                        .disabled(companyId == nil || records.isEmpty || (!incomplete && !blockers.isEmpty) || model.isBusy)
                    if model.isBusy { ProgressView("Preparing export…") }
                    if !files.isEmpty { Button("Share generated files") { showShare = true } }
                    Text("Generating an export does not confirm delivery to an accountant. Later edits are marked Changed since export.").font(.caption).foregroundStyle(.secondary)
                }
                if let error = model.error { Text(error).foregroundStyle(.orange) }
                Section { Text(BusinessExpensePolicy.disclosure).font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Export for Review").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.disabled(model.isBusy) } }
            .onAppear { companyId = initialCompanyId }
            .onChange(of: companyId) { _, _ in mutationId = UUID() }
            .onChange(of: start) { _, _ in mutationId = UUID() }
            .onChange(of: end) { _, _ in mutationId = UUID() }
            .onChange(of: incomplete) { _, _ in mutationId = UUID() }
            .onDisappear { if let folder { try? FileManager.default.removeItem(at: folder) } }
            .sheet(isPresented: $showShare) { ExpenseFileShareSheet(files: files) }
        }.preferredColorScheme(.dark)
    }
    private func generate() {
        guard let companyId else { return }
        Task {
            _ = await model.perform(state, operation: {
                let export = try await DataRepository.shared.prepareBusinessExpenseExport(companyId: companyId, from: start, to: end, incomplete: incomplete, mutationId: mutationId)
                if let folder { try? FileManager.default.removeItem(at: folder) }
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("miloom-expense-export-\(export.id.uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
                folder = directory
                let csvURL = directory.appendingPathComponent(incomplete ? "incomplete-expense-review.csv" : "business-expenses.csv")
                try Data(BusinessExpensePolicy.csv(export).utf8).write(to: csvURL, options: [.atomic, .completeFileProtection])
                var generated = [csvURL]
                if includeReceipts {
                    var seen = Set<UUID>()
                    for document in export.items.flatMap(\.documents) where seen.insert(document.id).inserted {
                        let data = try await SupabaseService.shared.client.storage.from("CompanyDocuments").download(path: document.path)
                        let name = "\(document.id.uuidString)-\(URL(fileURLWithPath: document.name).lastPathComponent)"
                        let url = directory.appendingPathComponent(name)
                        try data.write(to: url, options: [.atomic, .completeFileProtection]); generated.append(url)
                    }
                }
                files = generated; showShare = true; mutationId = UUID()
            })
        }
    }
}
private struct ExpenseFileShareSheet: UIViewControllerRepresentable {
    var files: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: files, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
