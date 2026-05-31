import Foundation
import Supabase
import UIKit

class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    let urlString: String
    
    private init() {
        self.urlString = "https://xxqdytdbpiqjilhutvhz.supabase.co"
        let supabaseURL = URL(string: urlString)!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cWR5dGRicGlxamlsaHV0dmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTYwMDMsImV4cCI6MjA5MzE5MjAwM30.LzjILfwR6mW4EcwG2e_f9Q9NNgc4mlpPV8qy537jYYw"
        
        #if os(iOS)
        let deviceModel = UIDevice.current.model
        let osVersion = UIDevice.current.systemVersion
        let userAgent = "Miloom iOS App (\(deviceModel); iOS \(osVersion))"
        #else
        let userAgent = "Miloom App (Mac)"
        #endif
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL, 
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["User-Agent": userAgent]
                )
            )
        )
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
