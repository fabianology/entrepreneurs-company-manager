import SwiftUI
import AVFoundation
import Vision

struct CardScanResult {
    var cardNumber: String?
    var expiry: String?
    var cardHolder: String?
    var network: String?
}

struct CardScannerView: View {
    let onScan: (CardScanResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isFlashOn = false
    @State private var triggerSnap = false
    @State private var statusText = "Align card inside frame"
    @State private var isCardDetected = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraScannerRepresentable(
                isFlashOn: isFlashOn,
                triggerSnap: $triggerSnap,
                onStatusUpdate: { text, detected in
                    statusText = text
                    isCardDetected = detected
                },
                onDetected: { result in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onScan(result)
                    dismiss()
                }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        isFlashOn.toggle()
                    } label: {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isFlashOn ? .yellow : .white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: isCardDetected
                                    ? [Color(hex: "#1FE400"), Color(hex: "#34d399")]
                                    : [Color.white.opacity(0.8), Color.white.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isCardDetected ? 3 : 2
                        )
                        .frame(width: 320, height: 202)
                        .shadow(color: isCardDetected ? Color(hex: "#1FE400").opacity(0.5) : Color.black.opacity(0.3), radius: isCardDetected ? 16 : 8, x: 0, y: 0)

                    if isCardDetected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color(hex: "#1FE400"))
                            .shadow(radius: 4)
                    }
                }

                Spacer()

                VStack(spacing: 18) {
                    Text(statusText)
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(isCardDetected ? Color(hex: "#1FE400") : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isCardDetected ? Color(hex: "#1FE400").opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1))

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        triggerSnap = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(isCardDetected ? Color(hex: "#1FE400") : Color.white)
                                .frame(width: 58, height: 58)
                        }
                    }
                }
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - UIKit Representable
struct CameraScannerRepresentable: UIViewControllerRepresentable {
    var isFlashOn: Bool
    @Binding var triggerSnap: Bool
    let onStatusUpdate: (String, Bool) -> Void
    let onDetected: (CardScanResult) -> Void

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let vc = CameraScannerViewController()
        vc.onStatusUpdate = onStatusUpdate
        vc.onDetected = onDetected
        return vc
    }

    func updateUIViewController(_ vc: CameraScannerViewController, context: Context) {
        vc.setFlash(on: isFlashOn)
        if triggerSnap {
            vc.snapCurrentFrame()
            DispatchQueue.main.async { triggerSnap = false }
        }
    }
}

// MARK: - Camera Controller
class CameraScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onStatusUpdate: ((String, Bool) -> Void)?
    var onDetected: ((CardScanResult) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isProcessing = false
    private var manualSnapRequested = false
    private var videoConnection: AVCaptureConnection?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "card_scanner"))
        if session.canAddOutput(output) { session.addOutput(output) }

        // Lock the video connection to portrait so Vision bounding boxes
        // align with natural left-to-right, top-to-bottom reading order.
        if let conn = output.connection(with: .video) {
            conn.videoOrientation = .portrait
            videoConnection = conn
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        if let pl = previewLayer { view.layer.addSublayer(pl) }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func setFlash(on: Bool) {
        guard let d = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              d.hasTorch else { return }
        try? d.lockForConfiguration()
        d.torchMode = on ? .on : .off
        d.unlockForConfiguration()
    }

    func snapCurrentFrame() { manualSnapRequested = true }

    // MARK: - Frame Processing
    func captureOutput(_ output: AVCaptureOutput, didOutput buf: CMSampleBuffer, from conn: AVCaptureConnection) {
        let isManual = manualSnapRequested
        guard !isProcessing, let px = CMSampleBufferGetImageBuffer(buf) else { return }
        isProcessing = true

        let req = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self = self,
                  let obs = request.results as? [VNRecognizedTextObservation] else {
                self?.isProcessing = false
                return
            }

            let result = CardNumberParser.parse(observations: obs)

            DispatchQueue.main.async {
                if isManual || self.manualSnapRequested {
                    self.manualSnapRequested = false
                    self.session.stopRunning()
                    self.onDetected?(result ?? CardScanResult())
                    return
                }

                if let r = result, r.cardNumber != nil {
                    self.onStatusUpdate?("Card Detected!", true)
                    self.session.stopRunning()
                    self.onDetected?(r)
                } else {
                    self.onStatusUpdate?("Align card inside frame", false)
                    self.isProcessing = false
                }
            }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = false

        // No explicit orientation needed because we locked videoOrientation = .portrait
        let handler = VNImageRequestHandler(cvPixelBuffer: px, options: [:])
        try? handler.perform([req])
    }
}

// MARK: - Card Number Parser (Stateless)
enum CardNumberParser {

    /// Parse card data from Vision OCR observations.
    /// Returns nil if no valid card number was found.
    static func parse(observations: [VNRecognizedTextObservation]) -> CardScanResult? {

        // ── Step 1: Extract raw text items with bounding boxes ──
        let items: [(text: String, box: CGRect)] = observations.compactMap { obs in
            guard let str = obs.topCandidates(1).first?.string else { return nil }
            return (text: str, box: obs.boundingBox)
        }

        let allTexts = items.map { $0.text }

        // ── Step 2: Try to find a full card number ──
        let cardNumber = findCardNumber(items: items)

        guard let number = cardNumber else { return nil }

        let network = detectNetwork(number)

        // ── Step 3: Find expiry ──
        let expiry = findExpiry(texts: allTexts)

        // ── Step 4: Find cardholder name ──
        let holder = findCardHolder(texts: allTexts)

        return CardScanResult(
            cardNumber: number,
            expiry: expiry,
            cardHolder: holder,
            network: network
        )
    }

    // MARK: Card Number

    private static func findCardNumber(items: [(text: String, box: CGRect)]) -> String? {

        // ── Strategy A: A single observation already has the full number ──
        // Vision often reads "4111 2222 3333 4444" as one text block.
        // Strip spaces/hyphens and check.
        for item in items {
            let digits = item.text.filter { $0.isNumber }
            if digits.count >= 13 && digits.count <= 19 && luhn(digits) {
                return digits
            }
            // Also try the text with spaces/hyphens removed but keeping char positions
            // in case Vision inserted odd chars
            let cleaned = item.text.replacingOccurrences(of: " ", with: "")
                                   .replacingOccurrences(of: "-", with: "")
                                   .replacingOccurrences(of: ".", with: "")
            let cleanDigits = cleaned.filter { $0.isNumber }
            if cleanDigits.count >= 13 && cleanDigits.count <= 19
               && cleanDigits.count == cleaned.count  // entire cleaned string is digits
               && luhn(cleanDigits) {
                return cleanDigits
            }
        }

        // ── Strategy B: Find 4-digit groups on the same horizontal line ──
        // Credit cards show the number as 4 groups of 4 digits (or 4-6-5 for Amex).
        // Find all observations that look like a 4, 5, or 6-digit group.
        struct DigitGroup {
            let digits: String
            let midX: CGFloat
            let midY: CGFloat
        }

        var groups: [DigitGroup] = []
        for item in items {
            let digits = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                  .filter { $0.isNumber }
            // Accept 4, 5, or 6 digit groups (covers Visa 4x4 and Amex 4-6-5)
            if digits.count >= 4 && digits.count <= 6 {
                // Make sure the original text is predominantly digits
                let nonDigits = item.text.filter { !$0.isNumber && !$0.isWhitespace && $0 != "-" }
                if nonDigits.count <= 1 {
                    groups.append(DigitGroup(
                        digits: digits,
                        midX: item.box.midX,
                        midY: item.box.midY
                    ))
                }
            }
        }

        // Group by horizontal line (midY within 5% tolerance)
        var lines: [[DigitGroup]] = []
        for g in groups {
            if let idx = lines.firstIndex(where: { line in
                guard let first = line.first else { return false }
                return abs(first.midY - g.midY) < 0.05
            }) {
                lines[idx].append(g)
            } else {
                lines.append([g])
            }
        }

        // For each line with 3-4 groups, sort left-to-right and try Luhn
        for line in lines {
            guard line.count >= 3 && line.count <= 5 else { continue }
            let sorted = line.sorted { $0.midX < $1.midX }
            let combined = sorted.map { $0.digits }.joined()
            if combined.count >= 13 && combined.count <= 19 && luhn(combined) {
                return combined
            }
        }

        // ── Strategy C: Concatenate all texts, scan for digit runs ──
        // Sort items top-to-bottom, left-to-right first
        let sorted = items.sorted { a, b in
            let dy = abs(a.box.midY - b.box.midY)
            if dy < 0.04 { return a.box.minX < b.box.minX }
            return a.box.midY > b.box.midY
        }
        let fullText = sorted.map { $0.text }.joined(separator: " ")

        // Find all runs of 13-19 digits (with optional spaces/hyphens between them)
        let pattern = "\\d(?:[\\s-]*\\d){12,18}"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
           let range = Range(match.range, in: fullText) {
            let digits = String(fullText[range]).filter { $0.isNumber }
            if digits.count >= 13 && digits.count <= 19 && luhn(digits) {
                return digits
            }
        }

        return nil
    }

    // MARK: Expiry

    private static func findExpiry(texts: [String]) -> String? {
        let joined = texts.joined(separator: " ")
        let pattern = "\\b(0[1-9]|1[0-2])\\/(\\d{2}|\\d{4})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: joined, range: NSRange(joined.startIndex..., in: joined)),
              let range = Range(match.range, in: joined) else { return nil }
        return String(joined[range])
    }

    // MARK: Cardholder Name

    private static func findCardHolder(texts: [String]) -> String? {
        let skip: Set<String> = [
            "VISA", "MASTERCARD", "AMEX", "DISCOVER", "DEBIT", "CREDIT",
            "BANK", "VALID", "THRU", "EXPIRES", "MEMBER", "SINCE",
            "PLATINUM", "GOLD", "SIGNATURE", "REWARDS", "BUSINESS",
            "GOOD", "FROM", "INTERAC", "FLASH", "PAYWAVE", "PAYPASS"
        ]
        for str in texts {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard words.count >= 2 && words.count <= 4 else { continue }
            let allLetters = words.allSatisfy { w in
                w.allSatisfy { $0.isLetter || $0 == "." || $0 == "-" || $0 == "'" }
            }
            guard allLetters else { continue }
            let hasSkip = words.contains { skip.contains($0.uppercased()) }
            guard !hasSkip else { continue }
            if trimmed.count >= 4 && trimmed.count <= 30 {
                return trimmed.uppercased()
            }
        }
        return nil
    }

    // MARK: Network Detection

    private static func detectNetwork(_ digits: String) -> String {
        let prefix2 = String(digits.prefix(2))
        if digits.hasPrefix("4") { return "Visa" }
        if let p2 = Int(prefix2), p2 >= 51 && p2 <= 55 { return "Mastercard" }
        if prefix2 == "34" || prefix2 == "37" { return "Amex" }
        if digits.hasPrefix("6011") || digits.hasPrefix("65") { return "Discover" }
        return "Visa"
    }

    // MARK: Luhn

    static func luhn(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 && digits.count <= 19 else { return false }
        var sum = 0
        for (i, d) in digits.reversed().enumerated() {
            if i % 2 == 1 {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }
}
