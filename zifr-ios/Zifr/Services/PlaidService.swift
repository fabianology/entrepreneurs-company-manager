import Foundation
import Supabase

class PlaidService {
    static let shared = PlaidService()
    private var client: SupabaseClient { SupabaseService.shared.client }
    
    func createLinkToken(companyId: UUID, institutionId: UUID? = nil, redirectUri: String? = nil) async throws -> String {
        struct Request: Encodable { 
            let company_id: UUID 
            let institution_id: UUID?
            let redirect_uri: String?
        }
        struct Response: Decodable { let link_token: String }
        
        let payload = try JSONEncoder().encode(Request(company_id: companyId, institution_id: institutionId, redirect_uri: redirectUri))
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
    
    func syncSubscriptions(institutionId: UUID? = nil) async throws {
        let session = try await client.auth.session
        var bodyData = Data()
        if let instId = institutionId {
            struct SyncReq: Encodable { let institution_id: UUID }
            bodyData = try JSONEncoder().encode(SyncReq(institution_id: instId))
        }
        
        let options = FunctionInvokeOptions(
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(session.accessToken)"
            ],
            body: bodyData
        )
        
        struct SyncResponse: Decodable {
            let success: Bool
            let synced: Int
        }
        
        do {
            let response: SyncResponse = try await client.functions.invoke("plaid-nightly-sync", options: options)
            if response.synced == 0 {
                throw NSError(domain: "PlaidService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No active Plaid connection found for this bank. Plaid sync is only available for officially linked accounts."])
            }
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
        let mask: String?
        let balances: PlaidBalances
        let liability_details: PlaidLiabilityDetails?
    }
    
    struct PlaidLiabilityDetails: Decodable {
        // Credit Card
        let aprs: [PlaidAPR]?
        // Shared
        let next_payment_due_date: String?
        let minimum_payment_amount: Double?
        
        // Mortgage
        let next_monthly_payment: Double?
        let interest_rate: PlaidInterestRate?
        
        // Student
        let interest_rate_percentage: Double?
        
        var effectiveAPR: Double? {
            if let aprs = aprs, let first = aprs.first { return first.apr_percentage }
            if let interestRate = interest_rate { return interestRate.percentage }
            if let studentRate = interest_rate_percentage { return studentRate }
            return nil
        }
        
        var effectiveMinimumPayment: Double? {
            return minimum_payment_amount ?? next_monthly_payment
        }
    }
    
    struct PlaidAPR: Decodable {
        let apr_percentage: Double
    }
    
    struct PlaidInterestRate: Decodable {
        let percentage: Double
    }
    
    struct PlaidBalances: Decodable {
        let current: Double?
        let available: Double?
    }
}
