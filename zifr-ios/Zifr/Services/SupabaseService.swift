import Foundation
import OSLog
import Supabase
import UIKit

enum AppDiagnostics {
    private static let logger = Logger(subsystem: "com.miloom.app", category: "reliability")

    static func event(_ area: String, _ operation: String, status: String) {
        logger.info("area=\(area, privacy: .public) operation=\(operation, privacy: .public) status=\(status, privacy: .public)")
    }

    static func failure(_ area: String, _ operation: String, error: Error? = nil) {
        let nsError = error as NSError?
        let domain = nsError?.domain ?? "none"
        let code = nsError?.code ?? 0
        logger.error("area=\(area, privacy: .public) operation=\(operation, privacy: .public) status=failure domain=\(domain, privacy: .public) code=\(code, privacy: .public)")
    }

    static func serviceFailure(_ area: String, _ operation: String, statusCode: Int, reason: String) {
        logger.error("area=\(area, privacy: .public) operation=\(operation, privacy: .public) status=remote_failure http_status=\(statusCode, privacy: .public) reason=\(reason, privacy: .public)")
    }

    static func duration(_ area: String, _ operation: String, seconds: TimeInterval) {
        let milliseconds = Int((seconds * 1_000).rounded())
        logger.info("area=\(area, privacy: .public) operation=\(operation, privacy: .public) status=complete duration_ms=\(milliseconds, privacy: .public)")
    }
}


class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    let urlString: String
    let appURLScheme: String
    
    private init() {
        var urlString = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        var supabaseKey = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""

        // A disposable staging app must never silently connect to production.
        if Bundle.main.bundleIdentifier == "com.vibing.miloom.staging" {
            guard urlString == "https://bvtuyzhyospqxvpzcrmv.supabase.co",
                  !supabaseKey.isEmpty,
                  !supabaseKey.contains("$(") else {
                preconditionFailure("The staging app requires explicit staging Supabase configuration")
            }
        }
        
        // Fallback if Secrets.local.xcconfig is missing from Xcode build configuration
        if urlString.isEmpty || urlString.contains("$(") {
            urlString = "https://xxqdytdbpiqjilhutvhz.supabase.co"
        }
        if supabaseKey.isEmpty || supabaseKey.contains("$(") {
            supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cWR5dGRicGlxamlsaHV0dmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTYwMDMsImV4cCI6MjA5MzE5MjAwM30.LzjILfwR6mW4EcwG2e_f9Q9NNgc4mlpPV8qy537jYYw"
        }
        
        self.urlString = urlString
        let appURLScheme = Self.registeredMiloomURLScheme() ?? "miloom"
        self.appURLScheme = appURLScheme
        let supabaseURL = URL(string: urlString) ?? URL(string: "https://xxqdytdbpiqjilhutvhz.supabase.co")!
        
        #if os(iOS)
        let deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        let userAgent = "Miloom iOS App (\(deviceModel); iOS \(osVersion))"
        #else
        let userAgent = "Miloom App (Mac)"
        #endif

        // Supabase uses URLSession.shared by default, whose request timeout is long
        // enough to leave authentication controls looking frozen on a weak or
        // interrupted mobile connection. Keep a bounded session for all Supabase
        // traffic so requests fail back to the UI and can be retried.
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 15
        sessionConfiguration.timeoutIntervalForResource = 60
        sessionConfiguration.waitsForConnectivity = false
        #if DEBUG && targetEnvironment(simulator)
        if StagingSaveFailureProtocol.isEnabled(
            url: supabaseURL, bundleID: Bundle.main.bundleIdentifier,
            arguments: ProcessInfo.processInfo.arguments
        ) {
            sessionConfiguration.protocolClasses = [StagingSaveFailureProtocol.self]
                + (sessionConfiguration.protocolClasses ?? [])
        }
        #endif
        let networkSession = URLSession(configuration: sessionConfiguration)
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL, 
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: URL(string: "\(appURLScheme)://auth-callback"),
                    // Emitting the cached value first prevents an auth-state
                    // subscriber from synchronously waiting on token refresh.
                    emitLocalSessionAsInitialSession: true
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["User-Agent": userAgent],
                    session: networkSession
                )
            )
        )
    }

    func appURL(path: String) -> URL? {
        URL(string: "\(appURLScheme)://\(path)")
    }

    private static func registeredMiloomURLScheme() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }
        return urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
            .first { $0.lowercased().hasPrefix("miloom") }
    }
    
    func deleteUserAccount() async throws {
        // Fetch current session for auth token
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "SupabaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        var request = URLRequest(url: URL(string: "\(urlString)/functions/v1/delete-user-account")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
/// Explicitly opted-in, staging-only native acceptance aid. It fails selected
/// save requests at URLSession, before transmission. Auth, reads and all other
/// hosts pass through untouched. This is absent from device and Release builds.
final class StagingSaveFailureProtocol: URLProtocol {
    static func isEnabled(url: URL, bundleID: String?, arguments: [String]) -> Bool {
        url.absoluteString == "https://bvtuyzhyospqxvpzcrmv.supabase.co"
            && bundleID == "com.vibing.miloom.staging"
            && arguments.contains("--miloom-staging-save-faults")
    }

    static func errorCode(for request: URLRequest, instruction: String) -> URLError.Code? {
        guard request.url?.scheme == "https",
              request.url?.host == "bvtuyzhyospqxvpzcrmv.supabase.co" else { return nil }
        let parts = instruction.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2 else { return nil }
        let path = request.url?.path ?? "", method = request.httpMethod ?? ""
        switch parts[1] {
        case "document-prepare":
            guard method == "POST", path == "/functions/v1/prepare-document-upload" else { return nil }
        case "document-upload":
            guard method == "PUT",
                  path.range(of: "^/storage/v1/object/upload/sign/CompanyDocuments/[0-9a-fA-F-]{36}/[0-9a-fA-F-]{36}\\.[a-z0-9]{1,12}$", options: .regularExpression) != nil else { return nil }
        case "document-finalize":
            guard method == "POST", path == "/rest/v1/rpc/miloom_finalize_document_upload" else { return nil }
        default:
            guard ["POST", "PATCH"].contains(method),
                  ["institutions", "financial_cards", "subscriptions", "company_documents", "rpc/miloom_save_loan"].contains(String(parts[1])),
                  path == "/rest/v1/\(parts[1])" else { return nil }
        }
        switch parts[0] {
        case "offline": return .notConnectedToInternet
        case "interrupted": return .networkConnectionLost
        case "timeout": return .timedOut
        default: return nil
        }
    }

    static func isAllowedInstructionPath(_ path: String) -> Bool {
        // Foundation canonicalizes /private/tmp to /tmp on macOS/simulator.
        let file = URL(fileURLWithPath: path).standardizedFileURL
        let directory = URL(fileURLWithPath: "/private/tmp", isDirectory: true).resolvingSymlinksInPath()
        return file.deletingLastPathComponent().resolvingSymlinksInPath() == directory
            && file.lastPathComponent.hasPrefix("miloom-staging-save-fault-")
    }

    private static func currentError(for request: URLRequest) -> URLError.Code? {
        guard let path = ProcessInfo.processInfo.environment["MILOOM_STAGING_SAVE_FAULT_FILE"],
              isAllowedInstructionPath(path),
              let instruction = try? String(contentsOfFile: path, encoding: .utf8),
              instruction.utf8.count < 128 else { return nil }
        return errorCode(for: request, instruction: instruction)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        currentError(for: request) != nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(Self.currentError(for: request) ?? .cancelled))
    }
    override func stopLoading() {}
}
#endif
