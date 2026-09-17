import Foundation
import PDFKit
import Vision
import ImageIO
import UIKit
import SwiftUI

/// Session-only extraction. Neither source files nor OCR are written to a new persistent index.
/// Indexing is bounded and reports skipped documents instead of pretending coverage is complete.
@MainActor
final class SearchDocumentIndexer {
    static let shared = SearchDocumentIndexer()
    private var generation = UUID()
    private var activeKey: String?
    private var completed: [UUID: String] = [:]

    func index(appState: AppState, userID: UUID) async {
        guard appState.hasLoadedPortfolio, appState.portfolioUserID == userID else { return }
        let key = appState.searchDocumentRevision
        guard activeKey != key else { return }
        activeKey = key
        let run = UUID(); generation = run
        let visibleIDs = Set(appState.searchIndex(for: userID).records.filter { $0.kind == .document }.map(\.modelID))
        let documents = appState.documents.filter { visibleIDs.contains($0.id) }
        let versions = Dictionary(documents.map { ($0.id, $0.url ?? "") }, uniquingKeysWith: { a, _ in a })
        appState.searchDocumentPages.removeAll { versions[$0.documentID] != $0.sourceURL || !visibleIDs.contains($0.documentID) }
        completed = completed.filter { versions[$0.key] == $0.value }
        var indexed = 0, unavailable = 0, limited = 0
        for document in documents {
            guard !Task.isCancelled, generation == run, appState.portfolioUserID == userID else { break }
            if completed[document.id] == document.url, appState.searchDocumentPages.contains(where: { $0.documentID == document.id && $0.sourceURL == document.url }) { indexed += 1; continue }
            appState.searchDocumentStatus = "Indexing document \(indexed + unavailable + limited + 1) of \(documents.count) on this device…"
            do {
                let data = try await Self.load(document)
                let extraction = Task.detached(priority: .utility) { try Self.extract(data, documentID: document.id, sourceURL: document.url) }
                let result = try await withTaskCancellationHandler(operation: { try await extraction.value }, onCancel: { extraction.cancel() })
                guard !Task.isCancelled, generation == run, appState.portfolioUserID == userID,
                      appState.documents.contains(where: { $0.id == document.id && $0.url == document.url && ($0.visibility != "owner_private" || $0.userId == userID) }) else { break }
                appState.searchDocumentPages.removeAll { $0.documentID == document.id }
                guard appState.searchIndex(for: userID).records.contains(where: { $0.kind == .document && $0.modelID == document.id }) else { continue }
                let redactor = appState.searchRedactor()
                appState.searchDocumentPages.append(contentsOf: result.pages.map { page in
                    var page = page; page.text = redactor.clean(page.text); return page
                })
                if result.limited { limited += 1 }
                else if result.pages.isEmpty { unavailable += 1 }
                else { indexed += 1; completed[document.id] = document.url }
            } catch { unavailable += 1 }
        }
        guard generation == run, appState.portfolioUserID == userID else { return }
        activeKey = nil
        appState.searchDocumentStatus = "Document text: \(indexed) complete, \(limited) partial, \(unavailable) unavailable. PDF and image OCR stay on device."
    }

    nonisolated static func load(_ document: CompanyDocument) async throws -> Data {
        guard let path = document.url, !path.isEmpty else { throw URLError(.fileDoesNotExist) }
        let url: URL
        if let local = URL(string: path), local.isFileURL { url = local }
        else { url = try await DataRepository.shared.getSignedUrl(for: path) }
        let maximumBytes = 25 * 1024 * 1024
        if url.isFileURL {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= maximumBytes else { throw URLError(.dataLengthExceedsMaximum) }
            return try Data(contentsOf: url)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), response.expectedContentLength <= maximumBytes else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            if data.count >= maximumBytes { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return data
    }

    nonisolated static func extract(_ data: Data, documentID: UUID, sourceURL: String?) throws -> (pages: [SearchDocumentPage], limited: Bool) {
        var result: [SearchDocumentPage] = []
        var truncated = false
        if let pdf = PDFDocument(data: data) {
            guard !pdf.isLocked else { throw URLError(.cannotDecodeContentData) }
            for pageIndex in 0..<min(pdf.pageCount, 100) {
                try Task.checkCancellation()
                guard let page = pdf.page(at: pageIndex) else { continue }
                var text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if text.count < 20, let image = page.thumbnail(of: CGSize(width: 1440, height: 1920), for: .mediaBox).cgImage {
                    text = try recognize(image)
                }
                if text.count > 40_000 { truncated = true }
                if !text.isEmpty { result.append(.init(documentID: documentID, page: pageIndex + 1, text: String(text.prefix(40_000)), sourceURL: sourceURL)) }
            }
            return (result, truncated || pdf.pageCount > 100)
        }
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
           ] as CFDictionary) {
            let text = try recognize(image)
            if !text.isEmpty { result.append(.init(documentID: documentID, page: 1, text: String(text.prefix(40_000)), sourceURL: sourceURL)) }
            return (result, text.count > 40_000)
        }
        throw URLError(.cannotDecodeContentData)
    }

    nonisolated private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

struct SearchDocumentViewer: View {
    let document: CompanyDocument
    let page: Int
    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?
    @State private var failed = false
    var body: some View {
        NavigationStack {
            Group {
                if let data { SearchDocumentContent(data: data, page: page) }
                else if failed { ContentUnavailableView("Document unavailable", systemImage: "doc", description: Text("The file could not be opened. Check your connection and try again.")) }
                else { ProgressView("Opening page \(page)…") }
            }
            .navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                do { let result = try await SearchDocumentIndexer.load(document); try Task.checkCancellation(); data = result }
                catch { if !Task.isCancelled { failed = true } }
            }
        }.privacySensitive()
    }
}

private struct SearchDocumentContent: UIViewRepresentable {
    let data: Data
    let page: Int
    func makeUIView(context: Context) -> UIView {
        if let document = PDFDocument(data: data) {
            let view = PDFView(); view.autoScales = true; view.document = document
            if let destination = document.page(at: max(0, min(page - 1, document.pageCount - 1))) { view.go(to: destination) }
            return view
        }
        let view = UIImageView(image: UIImage(data: data)); view.contentMode = .scaleAspectFit
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
