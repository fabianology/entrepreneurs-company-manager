import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    let urlString: String
    
    private init() {
        self.urlString = "https://xxqdytdbpiqjilhutvhz.supabase.co"
        let supabaseURL = URL(string: urlString)!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4cWR5dGRicGlxamlsaHV0dmh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc2MTYwMDMsImV4cCI6MjA5MzE5MjAwM30.LzjILfwR6mW4EcwG2e_f9Q9NNgc4mlpPV8qy537jYYw"
        
        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }
}
