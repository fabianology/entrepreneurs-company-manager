import Foundation
import Supabase

class PlaidService {
    static let shared = PlaidService()
    private var client: SupabaseClient { SupabaseService.shared.client }
    
    func createLinkToken(companyId: UUID, institutionId: UUID? = nil) async throws -> String {
        struct Request: Encodable { 
            let company_id: UUID 
            let institution_id: UUID?
        }
        struct Response: Decodable { let link_token: String }
        
        let payload = try JSONEncoder().encode(Request(company_id: companyId, institution_id: institutionId))
        let session = try await client.auth.session
        let options = FunctionInvokeOptions(
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessToken)"
            ],
            body: payload
        )
        do {
            let response: Response = try await client.functions
                .invoke("create-link-token", options: options)
            return response.link_token
        } catch let FunctionsError.httpError(code, data) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw NSError(domain: "PlaidService", code: code, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw FunctionsError.httpError(code: code, data: data)
        }
    }
    
    func exchangePublicToken(
        publicToken: String,
        institutionName: String,
        institutionId: String,
        companyId: UUID
    ) async throws -> ExchangeResponse {
        struct Request: Encodable {
            let public_token: String
            let institution_name: String
            let institution_id: String
            let company_id: UUID
        }
        
        let payload = try JSONEncoder().encode(Request(
            public_token: publicToken,
            institution_name: institutionName,
            institution_id: institutionId,
            company_id: companyId
        ))
        let session = try await client.auth.session
        let options = FunctionInvokeOptions(
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessToken)"
            ],
            body: payload
        )
        do {
            return try await client.functions
                .invoke("exchange-public-token", options: options)
        } catch let FunctionsError.httpError(code, data) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw NSError(domain: "PlaidService", code: code, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            throw FunctionsError.httpError(code: code, data: data)
        }
    }
    
    struct ExchangeResponse: Decodable {
        let success: Bool
        let item_id: String
        let accounts: [PlaidAccount]
    }
    
    struct PlaidAccount: Decodable {
        let account_id: String
        let name: String
        let type: String
        let subtype: String?
        let balances: PlaidBalances
    }
    
    struct PlaidBalances: Decodable {
        let current: Double?
        let available: Double?
    }
}
