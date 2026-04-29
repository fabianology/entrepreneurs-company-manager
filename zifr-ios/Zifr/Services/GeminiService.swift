import Foundation

// MARK: - Gemini REST API Service
actor GeminiService {
    static let shared = GeminiService()

    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String ?? ""
    }

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // MARK: - Generic Generate
    private func generate(model: String = "gemini-flash-latest", prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.8]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let errorMessage = json?["error"] as? [String: Any], let message = errorMessage["message"] as? String {
            return "API Error: \(message)"
        }
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        return parts?.first?["text"] as? String ?? ""
    }

    // MARK: - Email Purpose
    func generateEmailPurpose(for subscriptionName: String) async -> String {
        let prompt = "Provide a very short (max 12 words), professional explanation of what the primary account email for \"\(subscriptionName)\" is typically used for in a company. Focus on things like 'Primary Admin', 'Billing notifications', 'Team invites', 'SSO ownership'. Example for GitHub: \"Receives all pull request notifications, team invites, and security alerts.\" Return ONLY the purpose text, no quotes or prefix."
        do {
            return try await generate(prompt: prompt)
        } catch {
            return ""
        }
    }

    // MARK: - Portfolio Insights
    func askPortfolioQuestion(data: String, question: String) async -> String {
        let prompt = """
        You are a smart portfolio manager assistant for an entrepreneur.
        Here is the minified data of all companies and subscriptions: \(data)
        User Question: "\(question)"
        Instructions:
        1. Answer briefly and directly (max 2 sentences).
        2. If the user asks about costs, sum them up across relevant companies.
        3. Be helpful and professional.
        """
        do {
            return try await generate(model: "gemini-flash-latest", prompt: prompt)
        } catch {
            return "Could not process that query right now."
        }
    }

    // MARK: - Document Scanning AI
    func categorizeDocument(text: String, isPersonal: Bool = false) async -> [String: String]? {
        let validCategories = isPersonal 
            ? "\"Medical\", \"Identity & Vital Docs\", \"Legal\", \"Taxes\", \"Property & Estate\", or \"Other\""
            : "\"Formation & Governance\", \"Tax & IRS\", \"Legal & IP\", \"Contracts & HR\", \"Compliance & Insurance\", \"Identity & Vital Records\", \"Property & Assets\", \"Estate & Medical\", or \"Other\""
            
        let prompt = """
        You are an expert financial and legal assistant for an entrepreneur. 
        I am giving you the raw OCR text of a scanned document. 
        Your job is to analyze it and return a strict JSON dictionary with EXACTLY these four keys:
        - "name": A concise, clear title for the document (e.g. "Vendor Name - Document Type - Year" or similar appropriate title).
        - "category": MUST be one of these exact strings: \(validCategories).
        - "date": The effective date, signature date, or upload date of the document in 'MMM dd, yyyy' format (e.g. 'Oct 12, 2025'). If none found, leave empty string.
        - "notes": A very short 1-sentence summary of what this document is.

        Return ONLY the JSON. No markdown formatting, no backticks, no explanations. Just a raw {"name":"...", "category":"...", "date":"...", "notes":"..."}.

        Raw OCR Text:
        \(text)
        """
        
        do {
            let result = try await generate(model: "gemini-flash-latest", prompt: prompt)
            let cleanedJSON = result.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let data = cleanedJSON.data(using: .utf8) {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                return dict
            }
            return nil
        } catch {
            print("Gemini Categorization Error: \(error)")
            return nil
        }
    }
}
