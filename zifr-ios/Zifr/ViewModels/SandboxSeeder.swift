import Foundation

struct SandboxSeeder {
    static let sandboxCompanyId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let sandboxAmexId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let sandboxChaseId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let sandboxCard1Id = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let sandboxCard2Id = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    
    static func isSandbox(companyId: UUID) -> Bool {
        return companyId == sandboxCompanyId
    }
    
    static func seed(appState: AppState, userId: UUID, force: Bool = false) {
        if force {
            UserDefaults.standard.set(false, forKey: "sandboxPurged")
        } else {
            // Do not seed if the user has explicitly purged the sandbox
            guard !UserDefaults.standard.bool(forKey: "sandboxPurged") else { return }
            
            // Only seed if no real companies exist and sandbox is not already seeded
            guard appState.companies.isEmpty || (appState.companies.count == 1 && appState.companies.first?.id == sandboxCompanyId) else { return }
        }
        
        guard !appState.companies.contains(where: { $0.id == sandboxCompanyId }) else { return }
        
        let demoCompany = Company(
            id: sandboxCompanyId,
            userId: userId,
            name: "Spatula & Co. Bakery",
            structure: "LLC",
            companyDescription: "A mock bakery business used for exploring Miloom features.",
            colorHex: "#f59e0b", // Warm Orange
            website: "www.spatulabakery.com"
        )
        
        // Mock Accounts/Institutions
        let amexAcc = InstitutionAccount(
            id: sandboxCard1Id.uuidString,
            name: "Business Platinum",
            type: "Credit Card",
            last4: "1007",
            balance: 1420.50,
            cardHolder: "Demo Baker",
            expiry: "12/28",
            network: "Amex",
            limit: 25000,
            autopay: "Yes"
        )
        let amex = Institution(
            id: sandboxAmexId,
            userId: userId,
            companyId: sandboxCompanyId,
            name: "American Express",
            loginUrl: "www.americanexpress.com",
            username: "spatula_amex",
            accounts: [amexAcc]
        )
        
        let chaseChecking = InstitutionAccount(
            id: UUID().uuidString,
            name: "Business Checking",
            type: "Checking",
            last4: "8821",
            balance: 12450.80,
            cardHolder: "Spatula & Co."
        )
        let chaseSavings = InstitutionAccount(
            id: UUID().uuidString,
            name: "Business Savings",
            type: "Savings",
            last4: "9902",
            balance: 45000.00,
            cardHolder: "Spatula & Co."
        )
        let chase = Institution(
            id: sandboxChaseId,
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Chase",
            loginUrl: "www.chase.com",
            username: "spatula_chase",
            accounts: [chaseChecking, chaseSavings]
        )
        
        // Mock Financial Cards (linked to the institutions)
        let card1 = FinancialCard(
            id: sandboxCard1Id,
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Business Platinum",
            institutionName: "American Express",
            cardHolder: "Demo Baker",
            last4: "1007",
            expiry: "12/28",
            network: "Amex",
            type: "Credit",
            limit: 25000,
            balance: 1420.50,
            notes: "Used for bakery ingredients and operational expenses."
        )
        
        let card2 = FinancialCard(
            id: sandboxCard2Id,
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Chase Debit",
            institutionName: "Chase",
            cardHolder: "Demo Baker",
            last4: "8821",
            expiry: "06/29",
            network: "Visa",
            type: "Debit",
            limit: 0,
            balance: 12450.80,
            notes: "Linked to checking account for daily store operation expenses."
        )
        
        // Mock Subscriptions
        let sub1 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Netflix (Breakroom)",
            cost: 15.49,
            billingCycle: "Monthly",
            paymentMethod: "Business Platinum",
            paymentMethodId: sandboxCard1Id,
            nextRenewal: "Jun 28, 2026",
            website: "netflix.com",
            notes: "Breakroom entertainment for staff."
        )
        let sub2 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Adobe Creative Cloud",
            cost: 54.99,
            billingCycle: "Monthly",
            paymentMethod: "Chase Debit",
            paymentMethodId: sandboxCard2Id,
            nextRenewal: "Jun 15, 2026",
            website: "adobe.com",
            notes: "Used for menus, flyer designs, and social media posts."
        )
        let sub3 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Google Workspace",
            cost: 18.00,
            billingCycle: "Monthly",
            paymentMethod: "Chase Debit",
            paymentMethodId: sandboxCard2Id,
            nextRenewal: "Jun 10, 2026",
            website: "google.com",
            notes: "Custom email domain & team collaboration tools."
        )
        
        // Mock Documents
        let doc1 = CompanyDocument(
            id: UUID(),
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Articles of Organization (LLC)",
            type: "Formation & Governance",
            uploadDate: "May 12, 2026",
            notes: "Certified LLC formation document filed with State Department."
        )
        let doc2 = CompanyDocument(
            id: UUID(),
            userId: userId,
            companyId: sandboxCompanyId,
            name: "Bakery Commercial Lease Agreement",
            type: "Contracts & HR",
            uploadDate: "May 14, 2026",
            notes: "Lease agreement for main street store location."
        )
        
        // Append all to appState
        appState.companies.append(demoCompany)
        appState.institutions.append(contentsOf: [amex, chase])
        appState.cards.append(contentsOf: [card1, card2])
        appState.subscriptions.append(contentsOf: [sub1, sub2, sub3])
        appState.documents.append(contentsOf: [doc1, doc2])
    }
    
    static func purge(appState: AppState) {
        UserDefaults.standard.set(true, forKey: "sandboxPurged")
        appState.companies.removeAll { $0.id == sandboxCompanyId }
        appState.institutions.removeAll { $0.companyId == sandboxCompanyId }
        appState.cards.removeAll { $0.companyId == sandboxCompanyId }
        appState.subscriptions.removeAll { $0.companyId == sandboxCompanyId }
        appState.documents.removeAll { $0.companyId == sandboxCompanyId }
    }
}
