import Foundation

// MARK: - Gemini REST API Service (via Edge Function Proxy)
actor GeminiService {
    static let shared = GeminiService()

    // MARK: - Generic Generate (via Supabase Edge Function)
    private func generate(model: String = "gemini-2.0-flash", prompt: String) async throws -> String {
        guard let session = try? await SupabaseService.shared.client.auth.session else {
            throw NSError(domain: "GeminiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let proxyURL = URL(string: "\(SupabaseService.shared.urlString)/functions/v1/gemini-rest-proxy")!
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
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
        let cleanData = data.trimmingCharacters(in: .whitespacesAndNewlines)
        let dataString = cleanData.isEmpty ? "[NO DATA. The user has not added any companies, subscriptions, or accounts yet.]" : cleanData
        let prompt = """
        You are a smart portfolio manager assistant for an entrepreneur.
        Here is the minified data of all companies and subscriptions: \(dataString)
        User Question: "\(question)"
        Instructions:
        1. Answer briefly and directly (max 2 sentences).
        2. If the user asks about costs, sum them up across relevant companies.
        3. If the data is empty or indicates no data, explicitly inform the user that they haven't added any data yet and encourage them to add some.
        4. Be helpful and professional.
        """
        do {
            return try await generate(model: "gemini-flash-latest", prompt: prompt)
        } catch {
            return "Could not process that query right now."
        }
    }

    func askPortfolioQuestionREST(contents: [[String: Any]], systemInstruction: String, tools: [Tool]?) async throws -> [String: Any] {
        // Fetch current session for auth token
        guard let session = try? await SupabaseService.shared.client.auth.session else {
            throw NSError(domain: "GeminiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Construct target proxy URL
        var request = URLRequest(url: URL(string: "\(SupabaseService.shared.urlString)/functions/v1/gemini-live-proxy")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        var body: [String: Any] = [
            "model": "gemini-2.5-flash",
            "contents": contents
        ]
        
        body["systemInstruction"] = [
            "parts": [["text": systemInstruction]]
        ]
        
        if let tools = tools, !tools.isEmpty {
            let encoder = JSONEncoder()
            if let toolsData = try? encoder.encode(tools),
               let toolsJson = try? JSONSerialization.jsonObject(with: toolsData) as? [[String: Any]] {
                body["tools"] = toolsJson
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        } else {
            throw NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
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
