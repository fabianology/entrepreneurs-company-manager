import SwiftUI
import VisionKit
import Vision
import PDFKit

struct DocumentScannerView: UIViewControllerRepresentable {
    var onCancel: () -> Void
    var onComplete: ([UIImage]) -> Void
    var onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }
            parent.onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onError(error)
        }
    }
}

class DocumentProcessor {
    static let shared = DocumentProcessor()
    
    // MARK: - OCR Text Extraction
    func extractText(from images: [UIImage]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var extractedText = ""
                
                for image in images {
                    guard let cgImage = image.cgImage else { continue }
                    
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    let request = VNRecognizeTextRequest { request, error in
                        if let error = error {
                            print("OCR Error: \(error)")
                            return
                        }
                        
                        guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                        
                        let pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                        extractedText += pageText + "\n"
                    }
                    
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    
                    do {
                        try requestHandler.perform([request])
                    } catch {
                        print("Failed to perform OCR: \(error)")
                    }
                }
                
                continuation.resume(returning: extractedText)
            }
        }
    }
    
    // MARK: - Generate PDF
    func generatePDF(from images: [UIImage], filename: String = UUID().uuidString) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "CiFr App",
            kCGPDFContextAuthor: "Entrepreneur"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        let pdfURL = documentDirectory.appendingPathComponent("\(filename).pdf")
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792), format: format) // 8.5 x 11 inches at 72 DPI
        
        do {
            try renderer.writePDF(to: pdfURL) { context in
                for image in images {
                    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
                    context.beginPage(withBounds: pageBounds, pageInfo: [:])
                    
                    // Aspect fit image into page bounds
                    let imageSize = image.size
                    let scale = min(pageBounds.width / imageSize.width, pageBounds.height / imageSize.height)
                    let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    
                    let imageRect = CGRect(
                        x: (pageBounds.width - scaledSize.width) / 2.0,
                        y: (pageBounds.height - scaledSize.height) / 2.0,
                        width: scaledSize.width,
                        height: scaledSize.height
                    )
                    
                    image.draw(in: imageRect)
                }
            }
            return pdfURL
        } catch {
            print("Failed to generate PDF: \(error)")
            return nil
        }
    }
}
