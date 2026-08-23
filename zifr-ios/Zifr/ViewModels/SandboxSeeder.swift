import Foundation

struct DummyDataSeeder {
    static let dummyCompanyId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let dummyAmexId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let dummyChaseId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let dummyCard1Id = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let dummyCard2Id = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let dummyLoanId = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!

    static func isDummy(companyId: UUID) -> Bool {
        return companyId == dummyCompanyId
    }

    static func seed(appState: AppState, userId: UUID, force: Bool = false) {
        if force {
            UserDefaults.standard.set(false, forKey: "dummyPurged")
        } else {
            guard !UserDefaults.standard.bool(forKey: "dummyPurged") else { return }
            guard appState.companies.isEmpty || (appState.companies.count == 1 && appState.companies.first?.id == dummyCompanyId) else { return }
        }

        guard !appState.companies.contains(where: { $0.id == dummyCompanyId }) else { return }

        let dummyCompany = Company(
            id: dummyCompanyId,
            userId: userId,
            name: "ARK (dummy)",
            structure: "LLC",
            companyDescription: "ARK Investment & Innovation LLC.",
            colorHex: "#f59e0b",
            website: "ark.com"
        )

        // Mock Accounts/Institutions
        let amexAcc = InstitutionAccount(
            id: dummyCard1Id.uuidString,
            name: "Business Platinum",
            type: "Credit Card",
            last4: "1007",
            balance: 1420.50,
            cardHolder: "ARK Holdings",
            expiry: "12/28",
            network: "Amex",
            limit: 50000,
            autopay: "Yes"
        )
        let amex = Institution(
            id: dummyAmexId,
            userId: userId,
            companyId: dummyCompanyId,
            name: "American Express",
            loginUrl: "www.americanexpress.com",
            username: "ark_amex",
            accounts: [amexAcc]
        )

        let chaseChecking = InstitutionAccount(
            id: UUID().uuidString,
            name: "Business Checking",
            type: "Checking",
            last4: "8821",
            balance: 48750.80,
            cardHolder: "ARK (dummy)"
        )
        let chaseSavings = InstitutionAccount(
            id: UUID().uuidString,
            name: "Treasury Reserve",
            type: "Savings",
            last4: "9902",
            balance: 125000.00,
            cardHolder: "ARK (dummy)"
        )
        let chase = Institution(
            id: dummyChaseId,
            userId: userId,
            companyId: dummyCompanyId,
            name: "Chase",
            loginUrl: "www.chase.com",
            username: "ark_chase",
            accounts: [chaseChecking, chaseSavings]
        )

        // Mock Financial Cards
        let card1 = FinancialCard(
            id: dummyCard1Id,
            userId: userId,
            companyId: dummyCompanyId,
            name: "Business Platinum",
            institutionName: "American Express",
            cardHolder: "ARK Holdings",
            last4: "1007",
            expiry: "12/28",
            network: "Amex",
            type: "Credit",
            limit: 50000,
            balance: 1420.50,
            notes: "Corporate operations & SaaS subscriptions."
        )

        let card2 = FinancialCard(
            id: dummyCard2Id,
            userId: userId,
            companyId: dummyCompanyId,
            name: "Chase Business Debit",
            institutionName: "Chase",
            cardHolder: "ARK (dummy)",
            last4: "8821",
            expiry: "06/29",
            network: "Visa",
            type: "Debit",
            limit: 0,
            balance: 48750.80,
            notes: "Linked to checking account for payroll and operational expenses."
        )

        // Mock Loan
        let loan = Loan(
            id: dummyLoanId,
            userId: userId,
            companyId: dummyCompanyId,
            role: "Bank Loan",
            lender: "Chase",
            name: "Commercial Term Loan",
            principalAmount: 150000,
            remainingBalance: 84500,
            interestType: "Percentage",
            interestRate: 6.25,
            term: "72 months",
            termYears: 6,
            termMonths: 0,
            scheduleFrequency: "Monthly",
            monthlyPayment: 2150,
            startDate: Date().addingTimeInterval(-86400 * 365 * 2),
            maturityDate: Date().addingTimeInterval(86400 * 365 * 4),
            status: "Active",
            notes: "Expansion equipment financing."
        )

        // Mock Subscriptions
        let sub1 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Bloomberg Terminal",
            cost: 2200.00,
            billingCycle: "Monthly",
            paymentMethod: "Business Platinum",
            paymentMethodId: dummyCard1Id,
            nextRenewal: "Jun 28, 2026",
            website: "bloomberg.com",
            notes: "Market intelligence & analytics feeds."
        )
        let sub2 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "AWS Cloud Infrastructure",
            cost: 450.00,
            billingCycle: "Monthly",
            paymentMethod: "Business Platinum",
            paymentMethodId: dummyCard1Id,
            nextRenewal: "Jun 15, 2026",
            website: "aws.amazon.com",
            notes: "Production server hosting & cloud storage."
        )
        let sub3 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Google Workspace",
            cost: 72.00,
            billingCycle: "Monthly",
            paymentMethod: "Chase Business Debit",
            paymentMethodId: dummyCard2Id,
            nextRenewal: "Jun 10, 2026",
            website: "google.com",
            notes: "Custom email domain & team collaboration suite."
        )
        let sub4 = Subscription(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Adobe Creative Cloud",
            cost: 89.99,
            billingCycle: "Monthly",
            paymentMethod: "Chase Business Debit",
            paymentMethodId: dummyCard2Id,
            nextRenewal: "Jun 01, 2026",
            website: "adobe.com",
            notes: "Brand design, presentations, and investor reporting."
        )

        // Mock Documents
        let doc1 = CompanyDocument(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Articles of Organization (LLC)",
            type: "Formation & Governance",
            uploadDate: "May 12, 2026",
            notes: "Certified LLC formation document filed with State Department."
        )
        let doc2 = CompanyDocument(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Operating Agreement",
            type: "Formation & Governance",
            uploadDate: "May 15, 2026",
            notes: "Executed multi-member LLC operating agreement."
        )
        let doc3 = CompanyDocument(
            id: UUID(),
            userId: userId,
            companyId: dummyCompanyId,
            name: "Commercial Office Lease",
            type: "Contracts & HR",
            uploadDate: "May 20, 2026",
            notes: "Master lease agreement for headquarters location."
        )

        // Append all to appState
        appState.companies.append(dummyCompany)
        appState.institutions.append(contentsOf: [amex, chase])
        appState.cards.append(contentsOf: [card1, card2])
        appState.loans.append(loan)
        appState.subscriptions.append(contentsOf: [sub1, sub2, sub3, sub4])
        appState.documents.append(contentsOf: [doc1, doc2, doc3])
    }

    static func purge(appState: AppState) {
        UserDefaults.standard.set(true, forKey: "dummyPurged")
        appState.companies.removeAll { $0.id == dummyCompanyId }
        appState.institutions.removeAll { $0.companyId == dummyCompanyId }
        appState.cards.removeAll { $0.companyId == dummyCompanyId }
        appState.loans.removeAll { $0.companyId == dummyCompanyId }
        appState.subscriptions.removeAll { $0.companyId == dummyCompanyId }
        appState.documents.removeAll { $0.companyId == dummyCompanyId }
    }
}

typealias SandboxSeeder = DummyDataSeeder

