import XCTest
import SwiftUI
import CryptoKit
import Supabase
@testable import Zifr

final class ResourceCredentialRevealGateTests: XCTestCase {
    func testCurrentActiveRevealAccepted() {
        let gate = ResourceCredentialRevealGate()
        XCTAssertEqual(gate.accept(["password": "synthetic"], for: gate.operationID, isActive: true), ["password": "synthetic"])
    }

    func testInactivePresentationRejectsReveal() {
        let gate = ResourceCredentialRevealGate()
        XCTAssertNil(gate.accept(["password": "synthetic"], for: gate.operationID, isActive: false))
    }

    @MainActor
    func testDelayedResponseAfterDismissalCannotPublishPlaintext() async {
        let started = expectation(description: "Authenticated request suspended before response")
        var completion: CheckedContinuation<[String: String], Never>?
        var gate = ResourceCredentialRevealGate()
        let token = gate.operationID
        var displayed: [String: String] = [:]
        let request = Task { @MainActor in
            let response = await withCheckedContinuation { continuation in
                completion = continuation
                started.fulfill()
            }
            if let accepted = gate.accept(response, for: token, isActive: true) { displayed = accepted }
        }
        await fulfillment(of: [started], timeout: 2)
        // Same invalidation used by the native sheet's onDisappear/background.
        gate.invalidate()
        completion?.resume(returning: ["password": "synthetic-delayed"])
        await request.value
        XCTAssertTrue(displayed.isEmpty)
    }

    @MainActor
    func testDelayedOldResponseCannotReplaceNewPresentationReveal() async {
        let started = expectation(description: "Old request suspended")
        var completion: CheckedContinuation<[String: String], Never>?
        var gate = ResourceCredentialRevealGate()
        let oldToken = gate.operationID
        var displayed: [String: String] = [:]
        let request = Task { @MainActor in
            let response = await withCheckedContinuation { continuation in
                completion = continuation
                started.fulfill()
            }
            if let accepted = gate.accept(response, for: oldToken, isActive: true) { displayed = accepted }
        }
        await fulfillment(of: [started], timeout: 2)
        gate.invalidate()
        displayed = gate.accept(["password": "synthetic-new"], for: gate.operationID, isActive: true) ?? [:]
        completion?.resume(returning: ["password": "synthetic-old"])
        await request.value
        XCTAssertEqual(displayed, ["password": "synthetic-new"])
    }
}

final class ActiveSessionsTests: XCTestCase {
    @MainActor
    func testOverviewPaymentFailureRetryKeepsDraftIdentityAndOriginalOwner() async throws {
        for failure: Error in [URLError(.networkConnectionLost), LoanSaveError.accessDenied, LoanSaveError.changed] {
            let state = AppState(), vm = AppViewModel()
            let owner = UUID(), editor = UUID()
            let company = Company(userId: owner, name: "Shared")
            var loan = Loan(userId: owner, companyId: company.id)
            loan.principalAmount = 100
            loan.remainingBalance = 100
            loan.revision = 7
            loan.payments = []
            state.portfolioUserID = editor
            state.companies = [company]
            state.loans = [loan]
            state.resourceShares = [ResourceShare(resourceId: loan.id, resourceType: "loan", userId: editor, role: "Editor")]
            let payment = LoanPayment(userId: owner, loanId: loan.id, amount: 25, source: "Dummy payment")
            do {
                _ = try await vm.saveLoanPaymentConfirmed(payment, for: loan, appState: state) { proposed in
                    XCTAssertEqual(proposed.payments, [payment])
                    XCTAssertEqual(proposed.revision, 7)
                    XCTAssertEqual(state.loans, [loan])
                    throw failure
                }
                XCTFail("Payment failure swallowed")
            } catch {}
            XCTAssertEqual(state.loans, [loan])
            XCTAssertNil(state.error)
            let saved = try await vm.saveLoanPaymentConfirmed(payment, for: loan, appState: state) { proposed in
                XCTAssertEqual(proposed.userId, owner)
                XCTAssertEqual(proposed.payments, [payment])
                XCTAssertEqual(proposed.revision, 7)
                var receipt = proposed
                receipt.revision = 8
                return receipt
            }
            XCTAssertEqual(state.loans, [saved])
            XCTAssertEqual(saved.payments, [payment])
            XCTAssertEqual(saved.revision, 8)
        }
    }

    @MainActor
    func testOverviewPaymentFailsClosedForWrongBindingMissingLedgerDuplicateAndRevocation() async throws {
        let state = AppState(), vm = AppViewModel(), owner = UUID(), editor = UUID()
        let company = Company(userId: owner, name: "Shared")
        var loan = Loan(userId: owner, companyId: company.id)
        loan.payments = []
        loan.revision = 1
        let payment = LoanPayment(userId: owner, loanId: loan.id, amount: 25)
        state.portfolioUserID = editor
        state.companies = [company]
        state.loans = [loan]
        state.resourceShares = [ResourceShare(resourceId: loan.id, resourceType: "loan", userId: editor, role: "Editor")]
        var wrongOwner = payment, wrongLoan = payment, invalidAmount = payment
        wrongOwner.userId = editor
        wrongLoan.loanId = UUID()
        invalidAmount.amount = 0
        var missingLedger = loan, missingRevision = loan, duplicate = loan
        missingLedger.payments = nil
        missingRevision.revision = nil
        duplicate.payments = [payment]
        for (draft, snapshot) in [(wrongOwner, loan), (wrongLoan, loan), (invalidAmount, loan), (payment, missingLedger), (payment, missingRevision), (payment, duplicate)] {
            do {
                _ = try await vm.saveLoanPaymentConfirmed(draft, for: snapshot, appState: state) { _ in XCTFail("Invalid payment submitted"); return loan }
                XCTFail("Invalid draft accepted")
            } catch {}
        }
        state.resourceShares = []
        do {
            _ = try await vm.saveLoanPaymentConfirmed(payment, for: loan, appState: state) { _ in XCTFail("Revoked payment submitted"); return loan }
            XCTFail("Revoked payment accepted")
        } catch { XCTAssertEqual(error as? LoanSaveError, .accessDenied) }
        XCTAssertEqual(state.loans, [loan])
        XCTAssertNil(state.error)
    }

    #if DEBUG && targetEnvironment(simulator)
    func testDocumentFailureHookIsLimitedToThreeUploadStages() {
        let base = URL(string: "https://bvtuyzhyospqxvpzcrmv.supabase.co")!
        let signed = "storage/v1/object/upload/sign/CompanyDocuments/\(UUID().uuidString)/\(UUID().uuidString).png"
        for (stage, path, method) in [
            ("document-prepare", "functions/v1/prepare-document-upload", "POST"),
            ("document-upload", signed, "PUT"),
            ("document-finalize", "rest/v1/rpc/miloom_finalize_document_upload", "POST")
        ] {
            var request = URLRequest(url: base.appendingPathComponent(path))
            request.httpMethod = method
            XCTAssertEqual(StagingSaveFailureProtocol.errorCode(for: request, instruction: "interrupted:\(stage)"), .networkConnectionLost)
            request.httpMethod = "DELETE"
            XCTAssertNil(StagingSaveFailureProtocol.errorCode(for: request, instruction: "interrupted:\(stage)"))
            request.httpMethod = "GET"
            XCTAssertNil(StagingSaveFailureProtocol.errorCode(for: request, instruction: "interrupted:\(stage)"))
        }
        for path in ["storage/v1/object/CompanyDocuments/any.png", "storage/v1/object/upload/sign/avatars/any.png", "auth/v1/token"] {
            var request = URLRequest(url: base.appendingPathComponent(path))
            request.httpMethod = "PUT"
            XCTAssertNil(StagingSaveFailureProtocol.errorCode(for: request, instruction: "interrupted:document-upload"))
        }
    }
    #endif

    @MainActor
    func testConfirmedBankCardServiceFailuresAndRetryPreserveDrafts() async throws {
        let failures: [Error] = [URLError(.notConnectedToInternet), URLError(.networkConnectionLost),
            URLError(.timedOut), PostgrestError(code: "42501", message: "private backend detail")]
        for editing in [false, true] {
            for failure in failures {
                let state = AppState(), vm = AppViewModel()
                let owner = UUID(), actor = UUID()
                let company = Company(userId: owner, name: "Shared")
                state.portfolioUserID = actor
                state.companies = [company]
                state.resourceShares = ["all_financials", "all_subscriptions"].map {
                    ResourceShare(resourceId: company.id, resourceType: $0, userId: actor, role: "Editor")
                }
                let bank = Institution(userId: owner, companyId: company.id, name: "Saved bank")
                let card = FinancialCard(userId: owner, companyId: company.id)
                let service = Subscription(userId: owner, companyId: company.id)
                state.institutions = editing ? [bank] : []
                state.cards = editing ? [card] : []
                state.subscriptions = editing ? [service] : []
                var bankDraft = bank, cardDraft = card, serviceDraft = service
                bankDraft.name = "Bank draft"
                cardDraft.name = "Card draft"
                serviceDraft.name = "Service draft"
                var attempts = 0
                do {
                    try await vm.saveInstitutionConfirmed(bankDraft, appState: state) { proposed, exists in
                        attempts += 1
                        XCTAssertEqual(proposed, bankDraft)
                        XCTAssertEqual(exists, editing)
                        XCTAssertEqual(state.institutions, editing ? [bank] : [])
                        await Task.yield()
                        throw failure
                    }
                    XCTFail("Bank failure swallowed")
                } catch {}
                do {
                    try await vm.saveCardConfirmed(cardDraft, appState: state) { proposed, exists in
                        attempts += 1
                        XCTAssertEqual(proposed, cardDraft)
                        XCTAssertEqual(exists, editing)
                        XCTAssertEqual(state.cards, editing ? [card] : [])
                        await Task.yield()
                        throw failure
                    }
                    XCTFail("Card failure swallowed")
                } catch {}
                do {
                    _ = try await vm.saveSubscriptionConfirmed(serviceDraft, appState: state) { proposed, exists in
                        attempts += 1
                        XCTAssertEqual(proposed.id, serviceDraft.id)
                        XCTAssertEqual(proposed.userId, owner)
                        XCTAssertEqual(proposed.name, serviceDraft.name)
                        XCTAssertEqual(exists, editing)
                        XCTAssertEqual(state.subscriptions, editing ? [service] : [])
                        await Task.yield()
                        throw failure
                    }
                    XCTFail("Service failure swallowed")
                } catch {}
                XCTAssertEqual(attempts, 3)
                XCTAssertNil(state.error, "Form errors must not trigger another global alert")
                XCTAssertEqual(state.institutions, editing ? [bank] : [])
                XCTAssertEqual(state.cards, editing ? [card] : [])
                XCTAssertEqual(state.subscriptions, editing ? [service] : [])
                // Retry the identical drafts, publish only after confirmation.
                try await vm.saveInstitutionConfirmed(bankDraft, appState: state) { _, exists in XCTAssertEqual(exists, editing) }
                try await vm.saveCardConfirmed(cardDraft, appState: state) { _, exists in XCTAssertEqual(exists, editing) }
                let saved = try await vm.saveSubscriptionConfirmed(serviceDraft, appState: state) { _, exists in XCTAssertEqual(exists, editing) }
                XCTAssertEqual(state.institutions, [bankDraft])
                XCTAssertEqual(state.cards, [cardDraft])
                XCTAssertEqual(state.subscriptions, [saved])
                XCTAssertEqual(saved.name, "Service draft")
                XCTAssertEqual(saved.id, serviceDraft.id)
            }
        }
    }

    @MainActor
    func testConfirmedResourceSavesFailClosedAndDiscardAccountSwitchedReceipts() async throws {
        let state = AppState(), vm = AppViewModel()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        let bank = Institution(userId: owner, companyId: company.id)
        let card = FinancialCard(userId: owner, companyId: company.id)
        let service = Subscription(userId: owner, companyId: company.id)
        // Exact item grants do not permit inserting a missing row, even with
        // its same ID. Revoked grants also fail before persistence.
        for grants in [[], [
            ResourceShare(resourceId: bank.id, resourceType: "institution", userId: actor, role: "Editor"),
            ResourceShare(resourceId: card.id, resourceType: "card", userId: actor, role: "Editor"),
            ResourceShare(resourceId: service.id, resourceType: "subscription", userId: actor, role: "Editor")
        ]] {
            state.resourceShares = grants
            do { try await vm.saveInstitutionConfirmed(bank, appState: state) { _, _ in XCTFail("Unauthorized bank write") }; XCTFail() }
            catch { XCTAssertEqual((error as NSError).code, 403) }
            do { try await vm.saveCardConfirmed(card, appState: state) { _, _ in XCTFail("Unauthorized card write") }; XCTFail() }
            catch { XCTAssertEqual((error as NSError).code, 403) }
            do { _ = try await vm.saveSubscriptionConfirmed(service, appState: state) { _, _ in XCTFail("Unauthorized service write") }; XCTFail() }
            catch { XCTAssertEqual((error as NSError).code, 403) }
        }
        state.resourceShares = [ResourceShare(resourceId: company.id, resourceType: "company", userId: actor, role: "Editor")]
        do { try await vm.saveInstitutionConfirmed(bank, appState: state) { _, _ in state.portfolioUserID = UUID() }; XCTFail() }
        catch { XCTAssertTrue(error is CancellationError) }
        state.portfolioUserID = actor
        do { try await vm.saveCardConfirmed(card, appState: state) { _, _ in state.portfolioUserID = UUID() }; XCTFail() }
        catch { XCTAssertTrue(error is CancellationError) }
        state.portfolioUserID = actor
        do { _ = try await vm.saveSubscriptionConfirmed(service, appState: state) { _, _ in state.portfolioUserID = UUID() }; XCTFail() }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(state.institutions.isEmpty)
        XCTAssertTrue(state.cards.isEmpty)
        XCTAssertTrue(state.subscriptions.isEmpty)
        XCTAssertNil(state.error)
    }

    @MainActor
    func testConfirmedSaveKeepsOwnerPlanGateAndOriginalOwnerBinding() async throws {
        let state = AppState(), vm = AppViewModel()
        let owner = UUID()
        var first = Company(userId: owner, name: "First")
        first.lastModified = Date(timeIntervalSince1970: 0)
        let second = Company(userId: owner, name: "Second")
        state.portfolioUserID = owner
        state.companies = [first, second]
        let allowed = Institution(userId: owner, companyId: first.id)
        try await vm.saveInstitutionConfirmed(allowed, appState: state) { _, _ in }
        let blocked = Institution(userId: owner, companyId: second.id)
        do { try await vm.saveInstitutionConfirmed(blocked, appState: state) { _, _ in XCTFail("Free plan bypass") }; XCTFail() }
        catch { XCTAssertEqual((error as NSError).code, 403) }
        let foreign = Institution(userId: UUID(), companyId: first.id)
        do { try await vm.saveInstitutionConfirmed(foreign, appState: state) { _, _ in XCTFail("Owner changed") }; XCTFail() }
        catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertEqual(state.institutions, [allowed])
    }

    func testResourceSaveErrorsAreSafeAndDoNotClaimNetworkRollback() {
        for resource in ["bank", "card", "service", "document", "loan"] {
            let failure = PostgrestError(code: "42501", message: "SECRET SQL payload")
            XCTAssertFalse(ResourceSaveFailure.message(for: failure, resource: resource).contains("SECRET"))
            XCTAssertTrue(ResourceSaveFailure.message(for: failure, resource: resource).contains("draft is still here"))
            let network = ResourceSaveFailure.message(for: URLError(.networkConnectionLost), resource: resource)
            XCTAssertTrue(network.contains("couldn’t confirm"))
            XCTAssertFalse(network.contains("not submitted"))
            XCTAssertTrue(ResourceSaveFailure.message(for: PostgrestError(code: "23505", message: "detail"), resource: resource).contains("already have been saved"))
        }
        for failure: LoanSaveError in [.changed, .accessDenied, .incompleteSnapshot, .unavailable, .unconfirmed] {
            XCTAssertEqual(ResourceSaveFailure.message(for: failure, resource: "loan"), failure.localizedDescription)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    func testStagingSaveFaultHookCannotTargetProductionAuthReadsOrDeviceBundle() {
        XCTAssertTrue(StagingSaveFailureProtocol.isAllowedInstructionPath("/private/tmp/miloom-staging-save-fault-check.txt"))
        XCTAssertTrue(StagingSaveFailureProtocol.isAllowedInstructionPath("/tmp/miloom-staging-save-fault-check.txt"))
        XCTAssertFalse(StagingSaveFailureProtocol.isAllowedInstructionPath("/private/tmp/unrelated.txt"))
        XCTAssertFalse(StagingSaveFailureProtocol.isAllowedInstructionPath("/private/tmp/miloom-staging-save-fault-test/../../unrelated"))
        let url = URL(string: "https://bvtuyzhyospqxvpzcrmv.supabase.co")!
        let arguments = ["--miloom-staging-save-faults"]
        XCTAssertTrue(StagingSaveFailureProtocol.isEnabled(url: url, bundleID: "com.vibing.miloom.staging", arguments: arguments))
        XCTAssertFalse(StagingSaveFailureProtocol.isEnabled(url: url, bundleID: "com.vibing.miloom", arguments: arguments))
        XCTAssertFalse(StagingSaveFailureProtocol.isEnabled(url: url, bundleID: "com.vibing.miloom.staging", arguments: []))
        XCTAssertFalse(StagingSaveFailureProtocol.isEnabled(url: URL(string: "https://xxqdytdbpiqjilhutvhz.supabase.co")!, bundleID: "com.vibing.miloom.staging", arguments: arguments))
        for resource in ["institutions", "financial_cards", "subscriptions", "company_documents", "rpc/miloom_save_loan"] {
            var request = URLRequest(url: url.appendingPathComponent("rest/v1/\(resource)"))
            request.httpMethod = "POST"
            XCTAssertEqual(StagingSaveFailureProtocol.errorCode(for: request, instruction: "offline:\(resource)"), .notConnectedToInternet)
            XCTAssertEqual(StagingSaveFailureProtocol.errorCode(for: request, instruction: "interrupted:\(resource)"), .networkConnectionLost)
            XCTAssertEqual(StagingSaveFailureProtocol.errorCode(for: request, instruction: "timeout:\(resource)"), .timedOut)
            request.httpMethod = "GET"
            XCTAssertNil(StagingSaveFailureProtocol.errorCode(for: request, instruction: "offline:\(resource)"))
        }
        for path in ["auth/v1/token", "rest/v1/activity_logs", "rest/v1/rpc/miloom_share_resource"] {
            var request = URLRequest(url: url.appendingPathComponent(path))
            request.httpMethod = "POST"
            XCTAssertNil(StagingSaveFailureProtocol.errorCode(for: request, instruction: "offline:institutions"))
        }
    }
    #endif

    @MainActor
    func testCollectionDocumentAndLoanDraftsSurviveConnectionFailures() async throws {
        // Exercise the real save coordinator with a failing transport boundary.
        // This is not native UI or physical network-interruption acceptance.
        for code in [URLError.notConnectedToInternet, .networkConnectionLost, .timedOut] {
            for editing in [false, true] {
                let state = AppState()
                let actor = UUID(), owner = UUID()
                let company = Company(userId: owner, name: "Shared")
                state.portfolioUserID = actor
                state.companies = [company]
                state.resourceShares = [
                    ResourceShare(resourceId: company.id, resourceType: "company", userId: actor, role: "Viewer"),
                    ResourceShare(resourceId: company.id, resourceType: "all_documents", userId: actor, role: "Editor"),
                    ResourceShare(resourceId: company.id, resourceType: "all_financials", userId: actor, role: "Editor")
                ]
                let originalDoc = CompanyDocument(userId: owner, companyId: company.id, name: "Saved document")
                let originalLoan = Loan(userId: owner, companyId: company.id, name: "Saved loan", payments: [])
                state.documents = editing ? [originalDoc] : []
                state.loans = editing ? [originalLoan] : []
                var doc = originalDoc
                var loan = originalLoan
                doc.name = "Document draft"
                loan.name = "Loan draft"
                let vm = AppViewModel()
                var documentAttempted = false, loanAttempted = false
                do {
                    try await vm.saveDocumentConfirmed(doc, appState: state) { proposed, exists in
                        documentAttempted = true
                        XCTAssertEqual(exists, editing)
                        XCTAssertEqual(proposed.userId, owner)
                        XCTAssertEqual(state.documents, editing ? [originalDoc] : [])
                        await Task.yield()
                        throw URLError(code)
                    }
                    XCTFail("Document connection failure was swallowed")
                } catch { XCTAssertEqual((error as? URLError)?.code, code) }
                do {
                    _ = try await vm.saveLoanConfirmed(loan, appState: state) { proposed in
                        loanAttempted = true
                        XCTAssertEqual(proposed.userId, owner)
                        XCTAssertEqual(state.loans, editing ? [originalLoan] : [])
                        await Task.yield()
                        throw URLError(code)
                    }
                    XCTFail("Loan connection failure was swallowed")
                } catch { XCTAssertEqual((error as? URLError)?.code, code) }
                XCTAssertTrue(documentAttempted)
                XCTAssertTrue(loanAttempted)
                XCTAssertEqual(state.documents, editing ? [originalDoc] : [])
                XCTAssertEqual(state.loans, editing ? [originalLoan] : [])
                XCTAssertEqual(doc.name, "Document draft")
                XCTAssertEqual(loan.name, "Loan draft")
            }
        }
    }

    @MainActor
    func testCollectionSavesPropagateServerRevocationDespiteCachedGrant() async throws {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        let grants = [
            ResourceShare(resourceId: company.id, resourceType: "all_documents", userId: actor, role: "Editor"),
            ResourceShare(resourceId: company.id, resourceType: "all_financials", userId: actor, role: "Editor")
        ]
        state.resourceShares = grants
        let document = CompanyDocument(userId: owner, companyId: company.id, name: "Unsaved document")
        let loan = Loan(userId: owner, companyId: company.id, name: "Unsaved loan", payments: [])
        let vm = AppViewModel()
        var attempts = 0
        do {
            try await vm.saveDocumentConfirmed(document, appState: state) { _, _ in
                attempts += 1
                await Task.yield()
                throw PostgrestError(code: "42501", message: "Synthetic revoked grant")
            }
            XCTFail("Stale cached document grant overrode server rejection")
        } catch { XCTAssertEqual((error as? PostgrestError)?.code, "42501") }
        do {
            _ = try await vm.saveLoanConfirmed(loan, appState: state) { _ in
                attempts += 1
                await Task.yield()
                throw LoanSaveError.accessDenied
            }
            XCTFail("Stale cached loan grant overrode server rejection")
        } catch { XCTAssertTrue(error is LoanSaveError) }
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(state.resourceShares, grants, "Test must retain stale local grants")
        XCTAssertTrue(state.documents.isEmpty)
        XCTAssertTrue(state.loans.isEmpty)
    }

    @MainActor
    func testRevokedBankCardAndServiceDraftsDoNotChangeSavedState() {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        state.resourceShares = [ResourceShare(resourceId: company.id, resourceType: "company", userId: actor, role: "Viewer")]
        let bank = Institution(userId: owner, companyId: company.id)
        let card = FinancialCard(userId: owner, companyId: company.id)
        let service = Subscription(userId: owner, companyId: company.id)
        state.institutions = [bank]
        state.cards = [card]
        state.subscriptions = [service]
        var bankDraft = bank, cardDraft = card, serviceDraft = service
        bankDraft.name = "Revoked bank draft"
        cardDraft.name = "Revoked card draft"
        serviceDraft.name = "Revoked service draft"
        let vm = AppViewModel()
        vm.saveInstitution(bankDraft, appState: state)
        XCTAssertNotNil(state.error)
        state.error = nil
        vm.saveCard(cardDraft, appState: state)
        XCTAssertNotNil(state.error)
        state.error = nil
        vm.saveSub(serviceDraft, appState: state)
        XCTAssertNotNil(state.error)
        XCTAssertEqual(state.institutions, [bank])
        XCTAssertEqual(state.cards, [card])
        XCTAssertEqual(state.subscriptions, [service])
        XCTAssertEqual(bankDraft.name, "Revoked bank draft")
        XCTAssertEqual(cardDraft.name, "Revoked card draft")
        XCTAssertEqual(serviceDraft.name, "Revoked service draft")
        // Legacy non-form entry points still use these synchronous wrappers;
        // the main forms now use the confirmed async coordinators above.
    }

    func testCreationUsesOnlyCompanyOrMatchingCollectionGrants() {
        let owner = UUID(), actor = UUID(), company = UUID(), otherCompany = UUID()
        let types = ["institution", "card", "loan", "subscription", "document"]
        let expectations: [(String, Set<String>)] = [
            ("all_institutions", ["institution"]),
            ("all_financials", ["institution", "card", "loan"]),
            ("all_subscriptions", ["subscription"]),
            ("all_documents", ["document"]),
            ("company", Set(types))
        ]
        for (scope, allowed) in expectations {
            for role in ["Viewer", "Editor", "Admin"] {
                let grant = ResourceShare(resourceId: company, resourceType: scope, userId: actor, role: role)
                for type in types {
                    XCTAssertEqual(AppViewModel.resourceAllowsCreation(
                        [grant], actorID: actor, ownerID: owner, companyID: company, resourceType: type
                    ), allowed.contains(type) && (role == "Editor" || (scope == "company" && role == "Admin")), "\(scope)/\(role)/\(type)")
                    XCTAssertFalse(AppViewModel.resourceAllowsCreation(
                        [grant], actorID: actor, ownerID: owner, companyID: otherCompany, resourceType: type
                    ))
                }
            }
        }
    }

    func testCreationRejectsExactItemsMissingActorAndUnrelatedRecipients() {
        let owner = UUID(), actor = UUID(), company = UUID()
        for type in ["institution", "card", "loan", "subscription", "document"] {
            // Even an exact resource ID equal to the company ID is not a collection.
            let item = ResourceShare(resourceId: company, resourceType: type, userId: actor, role: "Editor")
            XCTAssertFalse(AppViewModel.resourceAllowsCreation([item], actorID: actor, ownerID: owner, companyID: company, resourceType: type))
            XCTAssertFalse(AppViewModel.resourceAllowsCreation([], actorID: nil, ownerID: owner, companyID: company, resourceType: type))
            XCTAssertTrue(AppViewModel.resourceAllowsCreation([], actorID: owner, ownerID: owner, companyID: company, resourceType: type))
            XCTAssertFalse(AppViewModel.resourceAllowsCreation([], actorID: owner, ownerID: owner, companyID: company, resourceType: type, ownerCanEdit: false))
        }
        let foreign = ResourceShare(resourceId: company, resourceType: "company", userId: UUID(), role: "Admin")
        XCTAssertFalse(AppViewModel.resourceAllowsCreation([foreign], actorID: actor, ownerID: owner, companyID: company, resourceType: "card"))
        XCTAssertFalse(AppViewModel.resourceAllowsCreation([], actorID: owner, ownerID: owner, companyID: company, resourceType: "unknown"))
    }

    func testCreationMixedGrantsAreOrderIndependent() {
        let owner = UUID(), actor = UUID(), company = UUID()
        let viewer = ResourceShare(resourceId: company, resourceType: "company", userId: actor, role: "Viewer")
        let editor = ResourceShare(resourceId: company, resourceType: "all_documents", userId: actor, role: "Editor")
        for grants in [[viewer, editor], [editor, viewer]] {
            XCTAssertTrue(AppViewModel.resourceAllowsCreation(grants, actorID: actor, ownerID: owner, companyID: company, resourceType: "document"))
            XCTAssertFalse(AppViewModel.resourceAllowsCreation(grants, actorID: actor, ownerID: owner, companyID: company, resourceType: "loan"))
        }
    }

    func testDocumentFileFailuresDoNotExposeServerBodiesOrPaths() {
        let sensitiveDetail = "signed-token-and-private-object-path"
        let errors: [Error] = [
            FunctionsError.httpError(code: 403, data: Data(sensitiveDetail.utf8)),
            FunctionsError.httpError(code: 500, data: Data(sensitiveDetail.utf8)),
            StorageError(statusCode: "409", message: sensitiveDetail),
            PostgrestError(code: "42501", message: sensitiveDetail),
            NSError(domain: "Unknown", code: 0, userInfo: [NSLocalizedDescriptionKey: sensitiveDetail])
        ]
        for error in errors {
            let message = DocumentFileFailure.message(for: error)
            XCTAssertFalse(message.contains(sensitiveDetail))
            XCTAssertFalse(message.contains("Edge Function"))
            XCTAssertTrue(message.contains("Reopen"))
        }
    }

    func testDocumentFileFailuresGiveRecoveryActionsWithoutClaimingRollback() {
        XCTAssertTrue(DocumentFileFailure.message(for: URLError(.notConnectedToInternet)).contains("connection"))
        XCTAssertTrue(DocumentFileFailure.message(for: URLError(.timedOut)).contains("before trying again"))
        XCTAssertTrue(DocumentFileFailure.message(for: URLError(.userAuthenticationRequired)).contains("Sign in again"))
        XCTAssertTrue(DocumentFileFailure.message(for: FunctionsError.httpError(code: 429, data: Data())).contains("Wait"))
        XCTAssertTrue(DocumentFileFailure.message(for: NSError(domain: "App", code: -3)).contains("25 MB"))
        XCTAssertEqual(DocumentFileFailure.message(for: DocumentFileOwnershipError.saveDocumentFirst), "Save this document first, then add its file.")
    }

    func testEntitySharingChoicesKeepDistinctServerScopes() {
        XCTAssertEqual(EntitySharingScope.allCases.map(\.rawValue), [
            "company", "all_institutions", "all_financials", "all_subscriptions", "all_documents"
        ])
        XCTAssertEqual(Set(EntitySharingScope.allCases.map(\.id)).count, 5)
        XCTAssertEqual(EntitySharingScope.institutions.title, "All Institutions")
        XCTAssertEqual(EntitySharingScope.financials.title, "All Financials")
        XCTAssertNil(EntitySharingScope(rawValue: "institution"))
        XCTAssertNil(EntitySharingScope(rawValue: "unknown"))
    }

    func testSharingRolesRejectEntityEditorAndRetainScopedEditors() {
        XCTAssertEqual(EntitySharingScope.allowedRoles(resourceType: "company", isEntityAdmin: false), ["Viewer", "Admin"])
        for type in ["all_institutions", "all_financials", "all_subscriptions", "all_documents", "institution", "card", "loan", "subscription", "document"] {
            XCTAssertEqual(EntitySharingScope.allowedRoles(resourceType: type, isEntityAdmin: false), ["Viewer", "Editor"])
            XCTAssertEqual(EntitySharingScope.allowedRoles(resourceType: type, isEntityAdmin: true), ["Viewer"])
        }
        XCTAssertEqual(EntitySharingScope.allowedRoles(resourceType: "company", isEntityAdmin: true), ["Viewer"])
        XCTAssertTrue(EntitySharingScope.allowedRoles(resourceType: "unknown", isEntityAdmin: false).isEmpty)
        XCTAssertTrue(EntitySharingScope.allowedRoles(resourceType: "unknown", isEntityAdmin: true).isEmpty)
    }

    @MainActor
    func testDocumentSaveWaitsForReceiptAndRetainsDraftOnFailure() async throws {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        let original = CompanyDocument(userId: owner, companyId: company.id, name: "Original")
        state.documents = [original]
        state.resourceShares = [ResourceShare(resourceId: original.id, resourceType: "document", userId: actor, role: "Editor")]
        var draft = original
        draft.name = "Unsaved draft"
        let vm = AppViewModel()
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in
                XCTAssertTrue(exists)
                XCTAssertEqual(state.documents, [original])
                throw NSError(domain: "Documents", code: 403)
            }
            XCTFail("Server denial was swallowed")
        } catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertEqual(state.documents, [original])
        XCTAssertEqual(draft.name, "Unsaved draft")
        try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in XCTAssertTrue(exists) }
        XCTAssertEqual(state.documents, [draft])
        state.resourceShares = []
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, _ in XCTFail("Revoked edit reached persistence") }
            XCTFail("Revoked edit succeeded")
        } catch { XCTAssertEqual((error as NSError).code, 403) }
        XCTAssertEqual(state.documents, [draft])
    }

    @MainActor
    func testDocumentCreateFailureAndAccountChangeDoNotPublishDraft() async throws {
        let state = AppState()
        let owner = UUID()
        let company = Company(userId: owner, name: "Owned")
        state.portfolioUserID = owner
        state.companies = [company]
        let draft = CompanyDocument(userId: owner, companyId: company.id)
        let vm = AppViewModel()
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, exists in
                XCTAssertFalse(exists)
                throw URLError(.notConnectedToInternet)
            }
            XCTFail("Offline create succeeded")
        } catch { XCTAssertTrue(error is URLError) }
        XCTAssertTrue(state.documents.isEmpty)
        do {
            try await vm.saveDocumentConfirmed(draft, appState: state) { _, _ in state.portfolioUserID = UUID() }
            XCTFail("Saved data crossed account boundary")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(state.documents.isEmpty)
    }

    func testLoanSaveRequestKeepsLedgerAndRevisionInOneContract() throws {
        var loan = Loan(userId: UUID(), companyId: UUID(), name: "Loan")
        let encoder = JSONEncoder()
        let draftJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(LoanSaveRequest(loan))) as? [String: Any])
        XCTAssertTrue(draftJSON["p_expected_revision"] is NSNull)
        XCTAssertEqual((draftJSON["p_payments"] as? [Any])?.count, 0)
        loan.revision = 9
        XCTAssertThrowsError(try LoanSaveRequest(loan), "An unloaded ledger must not become an empty replacement")
        loan.payments = [LoanPayment(userId: loan.userId, loanId: loan.id, amount: 25)]
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(LoanSaveRequest(loan))) as? [String: Any])
        XCTAssertEqual(json["p_expected_revision"] as? Int, 9)
        XCTAssertEqual((json["p_payments"] as? [[String: Any]])?.first?["amount"] as? Double, 25)
        XCTAssertNil((json["p_loan"] as? [String: Any])?["payments"])
    }

    func testLoanSnapshotRestoresLedgerAndReturnedRevision() throws {
        var loan = Loan(userId: UUID(), companyId: UUID(), name: "Loan")
        loan.revision = 12
        let payment = LoanPayment(userId: loan.userId, loanId: loan.id, amount: 25)
        struct WireSnapshot: Encodable { let loan: Loan; let payments: [LoanPayment] }
        let data = try JSONEncoder().encode(WireSnapshot(loan: loan, payments: [payment]))
        let snapshot = try JSONDecoder().decode(LoanSnapshot.self, from: data)
        XCTAssertEqual(snapshot.value.revision, 12)
        XCTAssertEqual(snapshot.value.payments, [payment])
        loan.revision = nil
        XCTAssertNil(try JSONDecoder().decode(Loan.self, from: JSONEncoder().encode(loan)).revision)
    }

    @MainActor
    func testLoanSaveWaitsForConfirmationAndPreservesStateOnFailure() async throws {
        let state = AppState()
        let actor = UUID(), owner = UUID()
        let company = Company(userId: owner, name: "Shared")
        state.portfolioUserID = actor
        state.companies = [company]
        var original = Loan(userId: owner, companyId: company.id, name: "Original", payments: [])
        original.revision = 3
        state.loans = [original]
        state.resourceShares = [ResourceShare(resourceId: original.id, resourceType: "loan", userId: actor, role: "Editor")]
        var draft = original
        draft.name = "Edited"
        draft.payments = [LoanPayment(userId: owner, loanId: draft.id, amount: 25)]
        let vm = AppViewModel()
        do {
            _ = try await vm.saveLoanConfirmed(draft, appState: state) { _ in
                XCTAssertEqual(state.loans, [original], "Unconfirmed data must not replace saved state")
                throw LoanSaveError.changed
            }
            XCTFail("Failure was swallowed")
        } catch { XCTAssertTrue(error is LoanSaveError) }
        XCTAssertEqual(state.loans, [original])
        let saved = try await vm.saveLoanConfirmed(draft, appState: state) { value in
            var confirmed = value
            confirmed.revision = 5
            return confirmed
        }
        XCTAssertEqual(state.loans, [saved])
        XCTAssertEqual(state.loans.first?.revision, 5)
        XCTAssertEqual(state.loans.first?.payments?.count, 1)
        state.resourceShares = []
        do {
            _ = try await vm.saveLoanConfirmed(draft, appState: state) { _ in
                XCTFail("Revoked edit reached persistence")
                return original
            }
            XCTFail("Revoked edit succeeded")
        } catch { XCTAssertTrue(error is LoanSaveError) }
        XCTAssertEqual(state.loans, [saved])
    }

    func testResourceEditorPresentationIsExactFailClosedAndOrderIndependent() {
        let actor = UUID(), owner = UUID(), company = UUID(), item = UUID(), sibling = UUID()
        let companyViewer = ResourceShare(resourceId: company, resourceType: "company", userId: actor, role: "Viewer")
        for type in ["institution", "card", "loan", "document"] {
            let editor = ResourceShare(resourceId: item, resourceType: type, userId: actor, role: "Editor")
            for shares in [[companyViewer, editor], [editor, companyViewer]] {
                func allows(_ resourceID: UUID, _ resourceType: String = type, _ userID: UUID? = actor) -> Bool {
                    AppViewModel.resourceAllowsEdit(
                        shares, actorID: userID, ownerID: owner, companyID: company,
                        resourceType: resourceType, resourceID: resourceID
                    )
                }
                XCTAssertTrue(allows(item), type)
                XCTAssertFalse(allows(sibling), type)
                XCTAssertFalse(allows(company, "company"), type)
                XCTAssertFalse(allows(item, type, nil), type)
                XCTAssertFalse(allows(item, type, UUID()), type)
                // An item ID with the wrong type must not match either.
                XCTAssertFalse(allows(item, "subscription"), type)
            }
        }
        XCTAssertFalse(AppViewModel.resourceAllowsEdit(
            [], actorID: actor, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item
        ))
        XCTAssertTrue(AppViewModel.resourceAllowsEdit(
            [], actorID: owner, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item
        ))
        XCTAssertFalse(AppViewModel.resourceAllowsEdit(
            [], actorID: owner, ownerID: owner, companyID: company,
            resourceType: "document", resourceID: item, ownerCanEdit: false
        ))
    }

    func testCollectionEditorsDoNotInheritVisualChildPermissions() {
        let actor = UUID(), owner = UUID(), company = UUID(), item = UUID()
        let scopes: [String: Set<String>] = [
            "all_institutions": ["institution"],
            "all_financials": ["institution", "card", "loan"],
            "all_documents": ["document"],
            "all_subscriptions": ["subscription"]
        ]
        for (scope, allowedTypes) in scopes {
            let shares = [ResourceShare(resourceId: company, resourceType: scope, userId: actor, role: "Editor")]
            for type in ["company", "institution", "card", "loan", "document", "subscription"] {
                XCTAssertEqual(AppViewModel.resourceAllowsEdit(
                    shares, actorID: actor, ownerID: owner, companyID: company,
                    resourceType: type, resourceID: item
                ), allowedTypes.contains(type), "\(scope) → \(type)")
            }
            XCTAssertFalse(AppViewModel.resourceAllowsEdit(
                shares, actorID: actor, ownerID: owner, companyID: UUID(),
                resourceType: allowedTypes.first!, resourceID: item
            ))
        }
    }

    func testSharingManagementAndOwnerPrivateDocumentsRemainSeparateFromEditing() {
        let actor = UUID(), owner = UUID(), company = UUID(), document = UUID()
        for (type, id, role, expected) in [
            ("company", company, "Admin", true),
            ("company", company, "Editor", false),
            ("company", company, "Viewer", false),
            ("all_documents", company, "Admin", false),
            ("document", document, "Editor", false),
            ("document", document, "Admin", false),
            ("company", UUID(), "Admin", false)
        ] {
            let shares = [ResourceShare(resourceId: id, resourceType: type, userId: actor, role: role)]
            XCTAssertEqual(AppViewModel.resourceAllowsSharing(
                shares, actorID: actor, ownerID: owner, companyID: company
            ), expected, "\(type) / \(role)")
            XCTAssertFalse(AppViewModel.resourceAllowsEdit(
                shares, actorID: actor, ownerID: owner, companyID: company,
                resourceType: "document", resourceID: document, isOwnerPrivate: true
            ))
            XCTAssertFalse(AppViewModel.resourceAllowsSharing(
                shares, actorID: actor, ownerID: owner, companyID: company, isOwnerPrivate: true
            ))
        }
        XCTAssertTrue(AppViewModel.resourceAllowsSharing([], actorID: owner, ownerID: owner, companyID: company))
        XCTAssertFalse(AppViewModel.resourceAllowsSharing([], actorID: nil, ownerID: owner, companyID: company))
        XCTAssertFalse(AppViewModel.resourceAllowsSharing([], actorID: owner, ownerID: owner, companyID: company, isOwnerPrivate: true))
    }

    func testSharedEditorScopesMatchTheExactResourceAndCollections() {
        let actor = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let otherActor = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let company = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let card = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
        let document = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
        func share(_ type: String, _ id: UUID, _ role: String = "Editor", _ user: UUID? = nil) -> ResourceShare {
            ResourceShare(resourceId: id, resourceType: type, userId: user ?? actor, role: role)
        }
        func allows(_ shares: [ResourceShare], _ type: String, _ id: UUID) -> Bool {
            AppViewModel.shareAllowsEdit(
                shares, actorID: actor, companyID: company,
                resourceType: type, resourceID: id
            )
        }

        XCTAssertTrue(allows([share("document", document)], "document", document))
        XCTAssertFalse(allows([share("document", document)], "institution", bank))
        XCTAssertTrue(allows([share("institution", bank)], "institution", bank))
        XCTAssertFalse(allows([share("all_institutions", company)], "card", card))
        XCTAssertTrue(allows([share("all_institutions", company)], "institution", bank))
        XCTAssertTrue(allows([share("all_financials", company)], "card", card))
        XCTAssertFalse(allows([share("all_financials", company)], "document", document))
        XCTAssertFalse(allows([share("company", company, "Viewer")], "document", document))
        XCTAssertTrue(allows([
            share("company", company, "Viewer"), share("document", document)
        ], "document", document))
        XCTAssertFalse(allows([share("document", document, "Editor", otherActor)], "document", document))
        XCTAssertTrue(allows([share("company", company, "Admin")], "document", document))
        let service = UUID()
        let siblingService = UUID()
        XCTAssertTrue(allows([share("subscription", service)], "subscription", service))
        XCTAssertFalse(allows([share("subscription", service)], "subscription", siblingService))
        XCTAssertFalse(allows([share("subscription", service)], "company", company))
        XCTAssertTrue(allows([share("all_subscriptions", company)], "subscription", service))
        XCTAssertFalse(allows([share("all_subscriptions", company)], "company", company))
        XCTAssertFalse(allows([share("all_subscriptions", company)], "document", document))
        XCTAssertTrue(allows([
            share("company", company, "Viewer"), share("subscription", service)
        ], "subscription", service))
        XCTAssertFalse(allows([
            share("company", company, "Viewer"), share("subscription", service)
        ], "subscription", siblingService))
    }

    func testDocumentDeletionAcceptsOnlyAppGeneratedRelativeStoragePath() {
        let path = "00000000-0000-0000-0000-000000000001/document.pdf"
        XCTAssertEqual(DataRepository.companyDocumentStoragePath(path), path)
        XCTAssertNil(DataRepository.companyDocumentStoragePath(
            "https://example.com/CompanyDocuments/\(path)"
        ))
        XCTAssertNil(DataRepository.companyDocumentStoragePath("file:///private/tmp/document.pdf"))
        XCTAssertNil(DataRepository.companyDocumentStoragePath(
            "00000000-0000-0000-0000-000000000001/"
        ))
        XCTAssertNil(DataRepository.companyDocumentStoragePath("other/document.pdf"))
    }

    func testDocumentOpeningDistinguishesExternalLinksAndPrivateStorage() {
        let path = "00000000-0000-0000-0000-000000000001/document.pdf"
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(path), path)
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(
            "https://example.test/storage/v1/object/sign/CompanyDocuments/\(path)?token=old"
        ), path)
        XCTAssertEqual(DataRepository.companyDocumentStorageReadPath(
            "https://example.test/CompanyDocuments/\(path.replacingOccurrences(of: "/", with: "%2F"))#preview"
        ), path)
        XCTAssertNil(DataRepository.companyDocumentStorageReadPath("https://drive.example.test/report.pdf"))
        XCTAssertNil(DataRepository.companyDocumentStorageReadPath("file:///private/tmp/document.pdf"))
        XCTAssertEqual(DataRepository.externalDocumentURL("https://drive.example.test/report.pdf")?.host,
                       "drive.example.test")
        XCTAssertNil(DataRepository.externalDocumentURL(
            "https://example.test/CompanyDocuments/\(path)"
        ))
    }

    func testSessionDecodesServerCurrentFlag() throws {
        let data = Data(
            #"{"id":"25000000-0000-0000-0000-000000000001","created_at":0,"updated_at":0,"user_agent":"Miloom iOS App (iPhone; iOS 26.0)","ip_address":"203.0.113.10","is_current":true}"#.utf8
        )

        let session = try JSONDecoder().decode(ActiveSession.self, from: data)

        XCTAssertTrue(session.isCurrent)
        XCTAssertEqual(session.ipAddress, "203.0.113.10")
    }

    func testSessionDecodesLegacyResponseWithoutCurrentFlag() throws {
        let data = Data(
            #"{"id":"25000000-0000-0000-0000-000000000001","created_at":0,"updated_at":0,"user_agent":null,"ip_address":null}"#.utf8
        )

        let session = try JSONDecoder().decode(ActiveSession.self, from: data)

        XCTAssertFalse(session.isCurrent)
    }

    func testSessionIDDecodesFromAccessToken() {
        let expectedID = UUID(uuidString: "25000000-0000-0000-0000-000000000001")!
        let payload = Data(#"{"session_id":"25000000-0000-0000-0000-000000000001"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(sessionIDFromAccessToken("header.\(payload).signature"), expectedID)
        XCTAssertNil(sessionIDFromAccessToken("not-a-jwt"))
    }

    func testDeviceLabelsUseRecordedUserAgent() {
        XCTAssertEqual(parseUserAgent("Miloom iOS App (iPhone; iOS 26.0)").name, "iPhone")
        XCTAssertEqual(parseUserAgent("Miloom iOS App (iPad; iOS 26.0)").name, "iPad")
        XCTAssertEqual(parseUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X)").name, "MacBook")
        XCTAssertEqual(parseUserAgent("Miloom App (Mac)").name, "MacBook")
        XCTAssertEqual(parseUserAgent(nil).name, "Unknown Device")
    }

    func testSessionAddressMasksFullIPAddress() {
        XCTAssertEqual(maskedSessionAddress("203.0.113.10"), "Network 203.0.•••.•••")
        XCTAssertEqual(maskedSessionAddress("2001:db8:1234:5678::1"), "Network 2001:db8:…")
        XCTAssertNil(maskedSessionAddress("127.0.0.1"))
        XCTAssertNil(maskedSessionAddress("::1"))
        XCTAssertNil(maskedSessionAddress("not-an-ip"))
    }

    @MainActor
    func testSessionRowExpandsForAccessibilityText() {
        let session = ActiveSession(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(),
            userAgent: "Miloom iOS App (iPhone; iOS 26.0)",
            ipAddress: "203.0.113.10",
            isCurrent: true
        )

        func fittedHeight(_ sizeCategory: ContentSizeCategory) -> CGFloat {
            let content = SessionRow(session: session, isRevoking: false)
                .environment(\.sizeCategory, sizeCategory)
            let host = UIHostingController(rootView: content)
            return host.sizeThatFits(in: CGSize(width: 350, height: 1_000)).height
        }

        XCTAssertGreaterThan(
            fittedHeight(.accessibilityExtraExtraExtraLarge),
            fittedHeight(.large),
            "The session row should grow rather than clip accessibility text."
        )
    }
}

final class ResourceVaultCryptographyTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let otherBank = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
    private let recipient = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let device = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!

    func testResourceCiphertextIsBoundToOwnerResourceAndVersion() throws {
        let key = SymmetricKey(size: .bits256)
        let context = ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 1), fieldName: "password")
        let ciphertext = try VaultCryptography.encryptResourceSecret("example-secret", using: key, context: context)
        XCTAssertEqual(try VaultCryptography.decryptResourceSecret(ciphertext, using: key, context: context), "example-secret")
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: otherBank, keyVersion: 1), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: recipient, resourceType: "institution", resourceID: bank, keyVersion: 1), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 2), fieldName: "password")))
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(ciphertext, using: key,
            context: ResourceSecretFieldContext(resource: context.resource, fieldName: "username")))
    }

    func testResourceKeyWrapsCannotMoveToAnotherResourceOrDevice() throws {
        let resourceKey = SymmetricKey(size: .bits256)
        let accountKey = SymmetricKey(size: .bits256)
        let resource = ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: bank, keyVersion: 1)
        let otherResource = ResourceKeyContext(ownerUserID: owner, resourceType: "institution", resourceID: otherBank, keyVersion: 1)
        let ownerContext = ResourceOwnerWrapContext(resource: resource, accountKeyVersion: 3)
        let ownerWrap = try VaultCryptography.wrapResourceKeyForOwner(resourceKey, using: accountKey, context: ownerContext)
        XCTAssertNoThrow(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey, context: ownerContext))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey,
            context: ResourceOwnerWrapContext(resource: otherResource, accountKeyVersion: 3)))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForOwner(ownerWrap, using: accountKey,
            context: ResourceOwnerWrapContext(resource: resource, accountKeyVersion: 4)))

        let identity = P256.KeyAgreement.PrivateKey()
        let deviceContext = ResourceDeviceWrapContext(resource: resource, recipientUserID: recipient, recipientDeviceID: device)
        let envelope = try VaultCryptography.wrapResourceKeyForDevice(resourceKey,
            for: identity.publicKey.x963Representation.base64EncodedString(), context: deviceContext)
        XCTAssertNoThrow(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity, context: deviceContext))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity,
            context: ResourceDeviceWrapContext(resource: otherResource, recipientUserID: recipient, recipientDeviceID: device)))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope, using: identity,
            context: ResourceDeviceWrapContext(resource: resource, recipientUserID: recipient, recipientDeviceID: UUID())))
        XCTAssertThrowsError(try VaultCryptography.unwrapResourceKeyForDevice(envelope,
            using: P256.KeyAgreement.PrivateKey(), context: deviceContext))
    }

    func testDeviceSecretResponseDecodesAndRevealsOnlyBoundResource() throws {
        let identity = P256.KeyAgreement.PrivateKey()
        let key = SymmetricKey(size: .bits256)
        let resource = ResourceKeyContext(
            ownerUserID: owner, resourceType: "institution", resourceID: bank,
            keyVersion: 1
        )
        let context = ResourceDeviceWrapContext(
            resource: resource, recipientUserID: recipient, recipientDeviceID: device
        )
        let wrapped = try VaultCryptography.wrapResourceKeyForDevice(
            key, for: identity.publicKey.x963Representation.base64EncodedString(),
            context: context
        )
        let field = ResourceSecretFieldContext(resource: resource, fieldName: "password")
        let ciphertext = try VaultCryptography.encryptResourceSecret(
            "test-bank-secret", using: key, context: field
        )
        let response: [String: Any] = [
            "owner_user_id": owner.uuidString,
            "resource_type": "institution",
            "resource_id": bank.uuidString,
            "key_version": 1,
            "encrypted_fields": ["password": ciphertext],
            "ephemeral_public_key": wrapped.ephemeralPublicKey,
            "wrapped_resource_key": wrapped.wrappedKey
        ]
        let record = try JSONDecoder().decode(
            DeviceResourceSecretRecord.self,
            from: JSONSerialization.data(withJSONObject: response)
        )
        XCTAssertEqual(record.ownerUserID, owner)
        XCTAssertEqual(record.resourceID, bank)
        let deliveredKey = try VaultCryptography.unwrapResourceKeyForDevice(
            VaultDeviceKeyWrapEnvelope(
                version: 1, keyVersion: record.keyVersion,
                ephemeralPublicKey: record.ephemeralPublicKey,
                wrappedKey: record.wrappedResourceKey
            ), using: identity, context: context
        )
        XCTAssertEqual(try VaultCryptography.decryptResourceSecret(
            try XCTUnwrap(record.encryptedFields["password"]),
            using: deliveredKey, context: field
        ), "test-bank-secret")
        XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(
            ciphertext, using: deliveredKey,
            context: ResourceSecretFieldContext(
                resource: ResourceKeyContext(ownerUserID: owner,
                    resourceType: "institution", resourceID: otherBank,
                    keyVersion: 1), fieldName: "password"
            )
        ))
    }

    func testRotationReencryptsEveryFieldUnderNewVersion() throws {
        let originalKey = SymmetricKey(size: .bits256)
        let replacementKey = SymmetricKey(size: .bits256)
        let original = ResourceKeyContext(
            ownerUserID: owner, resourceType: "card", resourceID: bank,
            keyVersion: 1
        )
        let replacement = ResourceKeyContext(
            ownerUserID: owner, resourceType: "card", resourceID: bank,
            keyVersion: 2
        )
        let values = ["login": "test-user", "password": "test-password"]
        var rotated: [String: String] = [:]
        for (field, value) in values {
            let oldCiphertext = try VaultCryptography.encryptResourceSecret(
                value, using: originalKey,
                context: ResourceSecretFieldContext(resource: original, fieldName: field)
            )
            let recovered = try VaultCryptography.decryptResourceSecret(
                oldCiphertext, using: originalKey,
                context: ResourceSecretFieldContext(resource: original, fieldName: field)
            )
            rotated[field] = try VaultCryptography.encryptResourceSecret(
                recovered, using: replacementKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            )
        }
        XCTAssertEqual(Set(rotated.keys), Set(values.keys))
        for (field, value) in values {
            let newCiphertext = try XCTUnwrap(rotated[field])
            XCTAssertEqual(try VaultCryptography.decryptResourceSecret(
                newCiphertext, using: replacementKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            ), value)
            XCTAssertThrowsError(try VaultCryptography.decryptResourceSecret(
                newCiphertext, using: originalKey,
                context: ResourceSecretFieldContext(resource: replacement, fieldName: field)
            ))
        }
    }
}

final class ResourceSecretPreparationTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let device = UUID(uuidString: "70000000-0000-0000-0000-000000000001")!
    private let bank = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    private func snapshot() -> VaultKeySession.Snapshot {
        let key = SymmetricKey(size: .bits256)
        return VaultKeySession.Snapshot(
            userID: owner, deviceID: device, keyVersion: 1, key: key, keys: [1: key]
        )
    }

    func testReadableVaultFieldIsPreparedOnlyWithMatchingRecordContext() throws {
        let snapshot = snapshot()
        let field = VaultFieldContext(
            ownerUserID: owner, resourceType: "institution", resourceID: bank,
            fieldName: "password", keyVersion: 1
        )
        let encrypted = try VaultCryptography.encryptField(
            "test-password", using: snapshot.key, context: field
        )
        XCTAssertEqual(
            try ResourceSecretPreparation.verifiedPlaintext(
                encrypted, snapshot: snapshot, storedResourceType: "institution",
                resourceID: bank, fieldName: "password"
            ), "test-password"
        )
        XCTAssertThrowsError(try ResourceSecretPreparation.verifiedPlaintext(
            encrypted, snapshot: snapshot, storedResourceType: "institution",
            resourceID: bank, fieldName: "username"
        ))
        XCTAssertThrowsError(try ResourceSecretPreparation.verifiedPlaintext(
            encrypted, snapshot: snapshot, storedResourceType: "institution",
            resourceID: UUID(), fieldName: "password"
        ))
    }

    func testLockedFieldsSkipEntireResourceInsteadOfStagingLiteralCiphertext() throws {
        let snapshot = snapshot()
        let institution = Institution(
            userId: owner, companyId: UUID(), name: "Test Bank",
            username: "readable-user", password: "enc:not-a-readable-legacy-envelope"
        )
        var collection = ResourceSecretCandidateCollection()
        collection.append {
            try ResourceSecretPreparation.candidate(for: institution, snapshot: snapshot)
        }
        XCTAssertTrue(collection.candidates.isEmpty)
        XCTAssertEqual(collection.skippedLockedRecords, 1)
        XCTAssertEqual(collection.failedRecords, 0)
    }

    func testBankAccountNumbersAreBoundToAccountIdentityWithoutMetadata() throws {
        let snapshot = snapshot()
        let account = InstitutionAccount(
            id: "account-1", name: "Checking", accountNumber: "12345678",
            routingNumber: "021000021"
        )
        let institution = Institution(
            id: bank, userId: owner, companyId: UUID(), name: "Test Bank",
            accounts: [account]
        )
        let candidate = try XCTUnwrap(ResourceSecretPreparation.candidate(
            for: institution, snapshot: snapshot
        ))
        let json = try XCTUnwrap(candidate.plaintextFields["accounts_data"])
        XCTAssertEqual(candidate.resourceType, "institution")
        XCTAssertEqual(candidate.resourceID, bank)
        XCTAssertTrue(json.contains("account-1"))
        XCTAssertTrue(json.contains("12345678"))
        XCTAssertFalse(json.contains("Checking"))
        XCTAssertFalse(json.contains("Test Bank"))
    }
}


@MainActor
final class PortfolioLoadingTests: XCTestCase {
    private func fixture() -> (AppState, PortfolioSectionLoader, UUID) {
        let state = AppState()
        let user = UUID()
        state.portfolioUserID = user
        let loader = PortfolioSectionLoader(appState: state, userID: user, loadID: state.portfolioLoadID) { user }
        return (state, loader, user)
    }

    func testServicesAndDocumentsPublishWhileCompaniesAreStillPending() async {
        let (state, loader, user) = fixture()
        let company = Company(userId: user, name: "Example")
        let service = Subscription(userId: user, companyId: company.id, name: "Ready service")
        let document = CompanyDocument(userId: user, companyId: company.id, name: "Ready document")
        let pending = expectation(description: "Company request started")
        let visible = expectation(description: "Services and documents visible")
        var companyResponse: CheckedContinuation<[Company], Never>?
        let load = Task { @MainActor in
            let companies = Task { @MainActor in
                await loader.load("companies", operation: {
                    await withCheckedContinuation { continuation in
                        companyResponse = continuation
                        pending.fulfill()
                    }
                }, publish: { $0.companies = $1 })
            }
            async let services: [Subscription]? = loader.load("services", operation: { [service] }, publish: { $0.subscriptions = $1 })
            async let documents: [CompanyDocument]? = loader.load("documents", operation: { [document] }, publish: { $0.documents = $1 })
            _ = await (services, documents)
            visible.fulfill()
            _ = await companies.value
        }
        await fulfillment(of: [pending, visible], timeout: 2)
        XCTAssertTrue(state.companies.isEmpty)
        XCTAssertEqual(state.subscriptions, [service])
        XCTAssertEqual(state.documents, [document])
        XCTAssertFalse(state.hasLoadedPortfolio, "Lists must not depend on the full portfolio-ready flag")
        companyResponse?.resume(returning: [company])
        await load.value
        XCTAssertEqual(state.companies, [company])
    }

    func testFailedRefreshPreservesKnownServicesAndReportsIssue() async {
        let (state, loader, user) = fixture()
        let service = Subscription(userId: user, companyId: UUID(), name: "Saved service")
        state.subscriptions = [service]
        let result: [Subscription]? = await loader.load("services", operation: {
            throw URLError(.timedOut)
        }, publish: { $0.subscriptions = $1 })
        XCTAssertNil(result)
        XCTAssertEqual(state.subscriptions, [service])
        XCTAssertEqual(loader.failures, ["services"])
        XCTAssertTrue(state.portfolioLoadIssue?.contains("services") == true)
    }

    func testSuccessfulEmptyResponseRemovesDeletedServices() async {
        let (state, loader, user) = fixture()
        state.subscriptions = [Subscription(userId: user, companyId: UUID(), name: "Deleted")]
        let _: [Subscription]? = await loader.load("services", operation: { [] }, publish: { $0.subscriptions = $1 })
        XCTAssertTrue(state.subscriptions.isEmpty)
        XCTAssertTrue(loader.failures.isEmpty)
    }

    func testSupersededAndSignedOutResponsesCannotPublish() async {
        for changeAccount in [false, true] {
            let (state, _, user) = fixture()
            var currentUser: UUID? = user
            let loader = PortfolioSectionLoader(appState: state, userID: user, loadID: state.portfolioLoadID) { currentUser }
            let started = expectation(description: "Request pending")
            var response: CheckedContinuation<[CompanyDocument], Never>?
            let request = Task { @MainActor in
                await loader.load("documents", operation: {
                    await withCheckedContinuation { continuation in
                        response = continuation
                        started.fulfill()
                    }
                }, publish: { $0.documents = $1 })
            }
            await fulfillment(of: [started], timeout: 2)
            if changeAccount { currentUser = nil } else { state.portfolioLoadID = UUID() }
            response?.resume(returning: [CompanyDocument(userId: user, companyId: UUID(), name: "Stale")])
            let result = await request.value
            XCTAssertNil(result)
            XCTAssertTrue(state.documents.isEmpty)
            XCTAssertNil(state.portfolioLoadIssue)
        }
    }

    func testCancelledResponseCannotPublish() async {
        let (state, loader, user) = fixture()
        let started = expectation(description: "Request pending")
        var response: CheckedContinuation<[Company], Never>?
        let request = Task { @MainActor in
            await loader.load("companies", operation: {
                await withCheckedContinuation { continuation in
                    response = continuation
                    started.fulfill()
                }
            }, publish: { $0.companies = $1 })
        }
        await fulfillment(of: [started], timeout: 2)
        request.cancel()
        response?.resume(returning: [Company(userId: user, name: "Stale")])
        let result = await request.value
        XCTAssertNil(result)
        XCTAssertTrue(state.companies.isEmpty)
    }

    func testBiometricLockKeepsSameAccountSnapshotAndInvalidatesPendingWork() {
        let (state, loader, user) = fixture()
        let company = Company(userId: user, name: "Current account")
        state.companies = [company]
        state.subscriptions = [Subscription(userId: user, companyId: company.id)]
        state.hasLoadedCompanies = true
        state.hasLoadedCompanyContent = true
        state.hasLoadedPortfolio = true
        state.clearSearchSession(keepingPortfolio: true)
        XCTAssertFalse(loader.isCurrent)
        XCTAssertEqual(state.portfolioUserID, user)
        XCTAssertEqual(state.companies, [company])
        XCTAssertEqual(state.subscriptions.count, 1)
        XCTAssertTrue(state.hasLoadedCompanies && state.hasLoadedCompanyContent)
        XCTAssertFalse(state.hasLoadedPortfolio)
    }

    func testAccountResetClearsVisibleSectionsAndReadiness() {
        let (state, loader, user) = fixture()
        let company = Company(userId: user, name: "Previous account")
        state.companies = [company]
        state.subscriptions = [Subscription(userId: user, companyId: company.id)]
        state.institutions = [Institution(userId: user, companyId: company.id)]
        state.cards = [FinancialCard(userId: user, companyId: company.id)]
        state.loans = [Loan(userId: user, companyId: company.id)]
        state.documents = [CompanyDocument(userId: user, companyId: company.id)]
        state.hasLoadedCompanies = true
        state.hasLoadedCompanyContent = true
        state.hasLoadedPortfolio = true
        state.clearPortfolio()
        XCTAssertFalse(loader.isCurrent)
        XCTAssertNil(state.portfolioUserID)
        XCTAssertFalse(state.hasLoadedCompanies)
        XCTAssertFalse(state.hasLoadedCompanyContent)
        XCTAssertFalse(state.hasLoadedPortfolio)
        XCTAssertTrue(state.companies.isEmpty && state.subscriptions.isEmpty && state.institutions.isEmpty)
        XCTAssertTrue(state.cards.isEmpty && state.loans.isEmpty && state.documents.isEmpty)
    }
}

@MainActor
final class PortfolioCacheTests: XCTestCase {
    private var directory: URL!
    private let key = SymmetricKey(size: .bits256)

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("portfolio-cache-test-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func cache() -> PortfolioCache {
        let key = key
        return PortfolioCache(directory: directory, key: { _, _ in key }, deleteKey: { _ in })
    }

    private func snapshot(user: UUID = UUID(), savedAt: Date = Date()) -> PortfolioSnapshot {
        let company = Company(userId: user, name: "Saved company")
        var service = Subscription(userId: user, companyId: company.id, name: "Saved service")
        service.password = "miloom:v1:synthetic-opaque-vault-envelope"
        var bank = Institution(userId: user, companyId: company.id, name: "Saved bank")
        bank.accounts = [InstitutionAccount(name: "Checking", balance: 120)]
        let card = FinancialCard(userId: user, companyId: company.id, name: "Saved card")
        var loan = Loan(userId: user, companyId: company.id, name: "Saved loan")
        loan.revision = 3
        loan.payments = [LoanPayment(userId: user, loanId: loan.id, amount: 10)]
        let doc = CompanyDocument(userId: user, companyId: company.id, name: "Saved document")
        return PortfolioSnapshot(userID: user, savedAt: savedAt, companies: [company], subscriptions: [service],
            institutions: [bank], cards: [card], loans: [loan], documents: [doc])
    }

    func testDeviceKeychainKeyCanSaveRestoreAndRemoveSnapshot() async throws {
        // A random fixture account exercises the real device Keychain without
        // reading or modifying an authenticated user's key.
        let cache = PortfolioCache(directory: directory)
        let snapshot = snapshot()
        let generation = await cache.generation(for: snapshot.userID)
        do {
            let saved = try await cache.save(snapshot, generation: generation)
            XCTAssertTrue(saved)
            let restored = try await cache.load(for: snapshot.userID)
            XCTAssertEqual(restored?.companies, snapshot.companies)
            let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
            XCTAssertEqual(values.isExcludedFromBackup, true)
        } catch {
            await cache.remove(for: snapshot.userID)
            throw error
        }
        await cache.remove(for: snapshot.userID)
        let removed = try await cache.load(for: snapshot.userID)
        XCTAssertNil(removed)
    }

    func testNewCacheInstanceRestoresEverySectionAndLoanLedgerFromEncryptedDisk() async throws {
        let firstProcess = cache()
        let snapshot = snapshot()
        let generation = await firstProcess.generation(for: snapshot.userID)
        let saved = try await firstProcess.save(snapshot, generation: generation)
        XCTAssertTrue(saved)
        let file = await firstProcess.fileURL(for: snapshot.userID)
        let bytes = try Data(contentsOf: file)
        XCTAssertNil(String(data: bytes, encoding: .utf8)?.range(of: "Saved company"))
        XCTAssertNil(String(data: bytes, encoding: .utf8)?.range(of: "synthetic-opaque"))
        let anotherProcess = cache()
        let loaded = try await anotherProcess.load(for: snapshot.userID)
        XCTAssertEqual(loaded?.companies, snapshot.companies)
        XCTAssertEqual(loaded?.subscriptions, snapshot.subscriptions)
        XCTAssertEqual(loaded?.institutions, snapshot.institutions)
        XCTAssertEqual(loaded?.cards, snapshot.cards)
        XCTAssertEqual(loaded?.loans, snapshot.loans)
        XCTAssertEqual(loaded?.documents, snapshot.documents)
        XCTAssertEqual(loaded?.loans.first?.payments?.count, 1)
        XCTAssertEqual(loaded?.loans.first?.revision, 3)
        XCTAssertEqual(loaded?.subscriptions.first?.password, "miloom:v1:synthetic-opaque-vault-envelope")
    }

    func testColdStartShowsSavedContentWhileServerIsPending() async throws {
        let cache = cache()
        let snapshot = snapshot()
        let generation = await cache.generation(for: snapshot.userID)
        try await cache.save(snapshot, generation: generation)
        let state = AppState()
        state.portfolioUserID = snapshot.userID
        let loader = PortfolioSectionLoader(appState: state, userID: snapshot.userID, loadID: state.portfolioLoadID) { snapshot.userID }
        let started = expectation(description: "Server is pending")
        var response: CheckedContinuation<[Subscription], Never>?
        let server = Task { @MainActor in
            await loader.load("services", operation: {
                await withCheckedContinuation { continuation in
                    response = continuation
                    started.fulfill()
                }
            }, publish: { $0.subscriptions = $1 })
        }
        await fulfillment(of: [started], timeout: 2)
        defer {
            response?.resume(returning: [])
            server.cancel()
        }
        let start = Date()
        let disk = try await cache.load(for: snapshot.userID)
        let loaded = try XCTUnwrap(disk)
        XCTAssertTrue(state.restoreSavedPortfolio(loaded, loadID: state.portfolioLoadID))
        let elapsed = Date().timeIntervalSince(start) * 1_000
        let timing = XCTAttachment(string: "Synthetic disk load and state restoration: \(elapsed) ms, with the server response still suspended.")
        timing.name = "Saved portfolio restoration"
        timing.lifetime = .keepAlways
        add(timing)
        XCTAssertEqual(state.companies, snapshot.companies)
        XCTAssertEqual(state.subscriptions.count, 1)
        XCTAssertEqual(state.cards.count, 1)
        XCTAssertEqual(state.documents.count, 1)
        XCTAssertTrue(state.isShowingSavedPortfolio)
        XCTAssertTrue(state.hasLoadedCompanies && state.hasLoadedCompanyContent)
        XCTAssertFalse(state.hasLoadedPortfolio, "Cached metadata must not claim that search/history is complete")
        var fresh = snapshot.subscriptions[0]
        fresh.name = "Updated service from server"
        response?.resume(returning: [fresh])
        response = nil
        _ = await server.value
        XCTAssertEqual(state.subscriptions.first?.name, fresh.name)
    }

    func testSharedRecordsAreExcludedEvenInsideAnOwnedCompany() {
        let owner = UUID(), other = UUID()
        let owned = Company(userId: owner, name: "Owned")
        let shared = Company(userId: other, name: "Shared")
        let snapshot = PortfolioSnapshot(userID: owner, companies: [owned, shared], subscriptions: [
            Subscription(userId: other, companyId: owned.id), Subscription(userId: owner, companyId: shared.id)
        ], institutions: [Institution(userId: other, companyId: owned.id)],
           cards: [FinancialCard(userId: other, companyId: owned.id)], loans: [Loan(userId: other, companyId: owned.id)],
           documents: [CompanyDocument(userId: other, companyId: owned.id)])
        XCTAssertEqual(snapshot.companies, [owned])
        XCTAssertTrue(snapshot.subscriptions.isEmpty && snapshot.institutions.isEmpty && snapshot.cards.isEmpty)
        XCTAssertTrue(snapshot.loans.isEmpty && snapshot.documents.isEmpty)
    }

    func testWrongAccountAndSupersededLoadCannotRestore() {
        let snapshot = snapshot()
        let state = AppState()
        state.portfolioUserID = UUID()
        XCTAssertFalse(state.restoreSavedPortfolio(snapshot, loadID: state.portfolioLoadID))
        state.portfolioUserID = snapshot.userID
        XCTAssertFalse(state.restoreSavedPortfolio(snapshot, loadID: UUID()))
        XCTAssertTrue(state.companies.isEmpty)
        state.hasLoadedCompanies = true
        XCTAssertFalse(state.restoreSavedPortfolio(snapshot, loadID: state.portfolioLoadID))
    }

    func testMissingSnapshotAndUnavailableKeyFallBackToNetwork() async throws {
        let cache = cache()
        let snapshot = snapshot()
        let missing = try await cache.load(for: snapshot.userID)
        XCTAssertNil(missing)
        let generation = await cache.generation(for: snapshot.userID)
        try await cache.save(snapshot, generation: generation)
        let locked = PortfolioCache(directory: directory, key: { _, _ in nil }, deleteKey: { _ in })
        let unavailable = try await locked.load(for: snapshot.userID)
        XCTAssertNil(unavailable)
    }

    func testEmptySnapshotDoesNotHideSharedCompaniesBehindAnEmptyState() {
        let user = UUID()
        let snapshot = PortfolioSnapshot(userID: user, companies: [], subscriptions: [], institutions: [], cards: [], loans: [], documents: [])
        let state = AppState()
        state.portfolioUserID = user
        XCTAssertFalse(state.restoreSavedPortfolio(snapshot, loadID: state.portfolioLoadID))
        XCTAssertFalse(state.hasLoadedCompanies)
    }

    func testExpiredSnapshotsAreIgnored() async throws {
        let cache = cache()
        let old = snapshot(savedAt: Date().addingTimeInterval(-PortfolioSnapshot.maximumAge - 60))
        let generation = await cache.generation(for: old.userID)
        try await cache.save(old, generation: generation)
        let loaded = try await cache.load(for: old.userID)
        XCTAssertNil(loaded)
    }

    func testTamperedFileAndAccountSwapFailAuthentication() async throws {
        let cache = cache()
        let snapshot = snapshot()
        let generation = await cache.generation(for: snapshot.userID)
        try await cache.save(snapshot, generation: generation)
        let source = await cache.fileURL(for: snapshot.userID)
        let anotherUser = UUID()
        let destination = await cache.fileURL(for: anotherUser)
        try FileManager.default.copyItem(at: source, to: destination)
        do { _ = try await cache.load(for: anotherUser); XCTFail("Account-swapped ciphertext accepted") } catch {}
        var bytes = try Data(contentsOf: source)
        bytes[bytes.count - 1] ^= 1
        try bytes.write(to: source)
        do { _ = try await cache.load(for: snapshot.userID); XCTFail("Tampered ciphertext accepted") } catch {}
    }

    func testSignOutRemovesSnapshotAndRejectsDelayedSave() async throws {
        let cache = cache()
        let snapshot = snapshot()
        let oldGeneration = await cache.generation(for: snapshot.userID)
        try await cache.save(snapshot, generation: oldGeneration)
        await cache.remove(for: snapshot.userID)
        let loaded = try await cache.load(for: snapshot.userID)
        XCTAssertNil(loaded)
        let delayedSave = try await cache.save(snapshot, generation: oldGeneration)
        XCTAssertFalse(delayedSave)
        let newGeneration = await cache.generation(for: snapshot.userID)
        let saved = try await cache.save(snapshot, generation: newGeneration)
        XCTAssertTrue(saved)
    }
}
