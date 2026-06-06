import SwiftUI
import Combine

struct AssistantOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(AuthViewModel.self) private var authViewModel
    @Bindable var vm: AppViewModel
    
    @StateObject private var captureManager = AudioCaptureManager()
    @State private var showPermissionAlert = false
    @State private var client: GeminiLiveClient?
    @State private var debugLog: String = "Waiting..."
    
    @State private var isConnecting = true
    @State private var connectionError: String? = nil
    @State private var activeToolCall: FunctionCall? = nil
    @State private var pendingCompany: Company? = nil
    
    // New draft states for expanded capabilities
    @State private var pendingSubscription: Subscription? = nil
    @State private var pendingLoan: Loan? = nil
    @State private var pendingCard: FinancialCard? = nil
    @State private var pendingDelete: PendingDelete? = nil
    
    // Chat Mode states
    @State private var isChatMode = false
    @State private var chatMessages: [ChatMessage] = []
    @State private var textInput = ""
    @State private var isAIThinking = false
    @State private var restHistory: [[String: Any]] = []
    
    @State private var showManualForm = false
    @State private var manualName = ""
    @State private var manualStructure = "LLC"
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let sender: Sender
        var text: String
        var isPending: Bool = false
        
        enum Sender {
            case user
            case assistant
        }
    }
    
    struct PendingDelete {
        let type: String
        let name: String
        let id: UUID
        let companyId: UUID
    }
    
    private let tools = [
        Tool(functionDeclarations: [
            FunctionDeclaration(
                name: "draftCompany",
                description: "Creates a draft for a new company/entity. Trigger this when the user has provided enough information.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "name": SchemaProperty(type: "STRING", description: "The name of the company."),
                        "structure": SchemaProperty(type: "STRING", description: "The legal structure of the company (e.g. LLC, S-Corp, C-Corp, Sole Proprietorship, Personal).")
                    ],
                    required: ["name", "structure"]
                )
            ),
            FunctionDeclaration(
                name: "draftSubscription",
                description: "Creates a draft for a new subscription/service for a company. Trigger this when the user wants to add a subscription or service (e.g., Figma, Netflix, GitHub).",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "companyName": SchemaProperty(type: "STRING", description: "The name of the company/entity this subscription belongs to."),
                        "name": SchemaProperty(type: "STRING", description: "The name of the subscription/service."),
                        "cost": SchemaProperty(type: "NUMBER", description: "The cost/price of the subscription."),
                        "billingCycle": SchemaProperty(type: "STRING", description: "The billing cycle: 'Monthly' or 'Yearly'.")
                    ],
                    required: ["companyName", "name", "cost", "billingCycle"]
                )
            ),
            FunctionDeclaration(
                name: "draftLoan",
                description: "Creates a draft for a new loan or debt for a company.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "companyName": SchemaProperty(type: "STRING", description: "The name of the company this loan belongs to."),
                        "name": SchemaProperty(type: "STRING", description: "The name/title of the loan."),
                        "lender": SchemaProperty(type: "STRING", description: "The lender name (e.g. SBA, Chase)."),
                        "remainingBalance": SchemaProperty(type: "NUMBER", description: "The remaining balance on the loan."),
                        "monthlyPayment": SchemaProperty(type: "NUMBER", description: "The monthly payment amount.")
                    ],
                    required: ["companyName", "name", "lender", "remainingBalance", "monthlyPayment"]
                )
            ),
            FunctionDeclaration(
                name: "draftCard",
                description: "Creates a draft for a new financial card (credit or debit) for a company.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "companyName": SchemaProperty(type: "STRING", description: "The name of the company this card belongs to."),
                        "name": SchemaProperty(type: "STRING", description: "The name of the card (e.g. Ink Business, Gold Card)."),
                        "type": SchemaProperty(type: "STRING", description: "The card type: 'Credit' or 'Debit'."),
                        "balance": SchemaProperty(type: "NUMBER", description: "The current balance on the card."),
                        "limit": SchemaProperty(type: "NUMBER", description: "The credit limit of the card.")
                    ],
                    required: ["companyName", "name", "type", "balance", "limit"]
                )
            ),
            FunctionDeclaration(
                name: "navigateTo",
                description: "Navigates the user to a specific screen or tab in the app. Call this whenever they say things like 'go to services', 'show my documents', 'view Spatula Bakery financials'.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "tab": SchemaProperty(type: "STRING", description: "The tab name to open: 'Home', 'Services', 'Financial', or 'Docs'."),
                        "companyName": SchemaProperty(type: "STRING", description: "The optional name of the company to switch focus to.")
                    ],
                    required: ["tab"]
                )
            ),
            FunctionDeclaration(
                name: "deleteEntity",
                description: "Deletes a company, subscription, card, loan, or document by name.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "entityType": SchemaProperty(type: "STRING", description: "The type of entity: 'company', 'subscription', 'card', 'loan', or 'document'."),
                        "name": SchemaProperty(type: "STRING", description: "The name of the entity to delete (case insensitive match).")
                    ],
                    required: ["entityType", "name"]
                )
            )
        ])
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        disconnectAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding()
                }
                
                Spacer()
                if let error = connectionError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Connection Failed")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            connectionError = nil
                            isConnecting = true
                            setupConnection()
                        } label: {
                            Text("Retry")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#0A84FF"))
                                .clipShape(Capsule())
                        }
                        
                        Button {
                            showManualForm = true
                        } label: {
                            Text("Create Manually")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                } else if isConnecting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    if isChatMode {
                        chatView
                    } else {
                        VStack(spacing: 24) {
                            PulsingOrbView(volume: captureManager.volume)
                            
                            Button {
                                toggleMode()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "keyboard")
                                    Text("Type Instead")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Draft Subscription Confirmation Dialog
            if let sub = pendingSubscription, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Draft Service")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name: \(sub.name)")
                            .foregroundStyle(.white)
                        Text("Cost: $\(sub.cost, specifier: "%.2f") / \(sub.billingCycle)")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sendToolResponse(for: call, success: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Confirm & Save") {
                            saveSubscription(sub)
                            sendToolResponse(for: call, success: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Draft Loan Confirmation Dialog
            if let loan = pendingLoan, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Draft Loan")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name: \(loan.name)")
                            .foregroundStyle(.white)
                        Text("Lender: \(loan.lender ?? "Unknown")")
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Remaining Balance: $\(loan.remainingBalance, specifier: "%.2f")")
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Monthly Payment: $\(loan.monthlyPayment, specifier: "%.2f")")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sendToolResponse(for: call, success: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Confirm & Save") {
                            saveLoan(loan)
                            sendToolResponse(for: call, success: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Draft Card Confirmation Dialog
            if let card = pendingCard, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Draft Card")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name: \(card.name)")
                            .foregroundStyle(.white)
                        Text("Type: \(card.type)")
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Limit: $\(card.limit, specifier: "%.2f")")
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Balance: $\(card.balance, specifier: "%.2f")")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sendToolResponse(for: call, success: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Confirm & Save") {
                            saveCard(card)
                            sendToolResponse(for: call, success: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Delete Confirmation Dialog
            if let del = pendingDelete, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Delete Confirmation")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    Text("Are you sure you want to delete the \(del.type) '\(del.name)'?")
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sendToolResponse(for: call, success: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Delete", role: .destructive) {
                            executeDelete(del)
                            sendToolResponse(for: call, success: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Voice Assistant Draft Confirmation Dialog
            if let company = pendingCompany, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Draft Business")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name: \(company.name)")
                            .foregroundStyle(.white)
                        Text("Structure: \(company.structure)")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1C1C1E"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            sendToolResponse(for: call, success: false)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Confirm & Save") {
                            saveCompany(company)
                            sendToolResponse(for: call, success: true)
                            // Purge sandbox if they added a real business
                            SandboxSeeder.purge(appState: appState)
                            disconnectAndDismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Manual Text Input Fallback Form
            if showManualForm {
                Color.black.opacity(0.85).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("New Business")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("BUSINESS NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("e.g. Spatula Bakery", text: $manualName)
                            .padding()
                            .background(Color(hex: "#1C1C1E"))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.words)
                        
                        Text("STRUCTURE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 8)
                        
                        Picker("Structure", selection: $manualStructure) {
                            ForEach(Company.structures, id: \.self) { s in
                                Text(s).tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .clipped()
                    }
                    .padding()
                    .background(Color(hex: "#1C1C1E").opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            showManualForm = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        
                        Button("Save Business") {
                            let userId = authViewModel.currentUser?.id ?? UUID()
                            vm.addCompany(
                                appState: appState,
                                userId: userId,
                                name: manualName,
                                structure: manualStructure,
                                colorHex: Company.brandColors.first ?? "#000000",
                                logoData: nil,
                                website: ""
                            )
                            // Purge sandbox if they added a real business
                            SandboxSeeder.purge(appState: appState)
                            disconnectAndDismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#0A84FF"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.bold)
                        .disabled(manualName.isEmpty)
                    }
                }
                .padding()
                .background(Color(hex: "#2C2C2E"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)
            }
            
            // Debug overlay
            VStack {
                Spacer()
                Text(debugLog)
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.8))
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            setupConnection()
        }
        .onDisappear {
            captureManager.stop()
            client?.disconnect()
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Microphone Permission"),
                message: Text("Microphone access was denied. Please enable it in Settings."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private func setupConnection() {
        client?.disconnect()
        cancellables.removeAll()
        
        isConnecting = true
        connectionError = nil
        
        if isChatMode {
            DispatchQueue.main.async {
                self.isConnecting = false
                self.debugLog = "Chat mode active. Ready for typed questions."
            }
            return
        }
        
        let minifiedData = vm.generateMinifiedPortfolio(appState: appState)
        let dynamicInstruction = """
        You are Miloom, an elite AI Executive Assistant for the Miloom app. Your job is to help the user onboard and manage their businesses and finances.
        You can create companies, subscriptions, loans, and credit/debit cards. You can also delete them, or navigate the user to different parts of the app.
        When asked to add or register any of these items, gather the information and trigger the appropriate tool call. Do not ask for details unless they are missing.
        When answering questions, be brief, professional, and conversational.
        
        Here is the exact current state of the user's finances and businesses:
        \(minifiedData)
        
        Use this data to answer their questions about their portfolio directly. Do not make up any information.
        """
        
        client = GeminiLiveClient(
            systemInstruction: dynamicInstruction,
            tools: tools,
            responseModalities: ["AUDIO"]
        ) { log in
            DispatchQueue.main.async {
                self.debugLog = log
            }
        }
        
        Task {
            do {
                try await client?.connect()
                
                // Subscribe to audio data (only play if not in chat mode)
                client?.audioDataPublisher
                    .receive(on: RunLoop.main)
                    .sink { data in
                        if !self.isChatMode {
                            self.captureManager.schedule(audioData: data)
                        }
                    }
                    .store(in: &cancellables)
                
                // Subscribe to text response chunks (fallback)
                client?.textDataPublisher
                    .receive(on: RunLoop.main)
                    .sink { text in
                        self.handleIncomingText(text)
                    }
                    .store(in: &cancellables)
                
                // Subscribe to tool calls
                client?.toolCallPublisher
                    .receive(on: RunLoop.main)
                    .sink { call in
                        self.handleToolCall(call)
                    }
                    .store(in: &cancellables)
                
                // Send audio to Gemini
                captureManager.audioDataPublisher
                    .sink { data in
                        client?.sendAudio(pcmBufferData: data)
                    }
                    .store(in: &cancellables)
                
                await captureManager.start()
                
                DispatchQueue.main.async {
                    self.isConnecting = false
                }
            } catch {
                print("Connection failed: \(error)")
                await MainActor.run {
                    self.connectionError = error.localizedDescription
                    self.isConnecting = false
                }
            }
        }
    }
    
    private func handleToolCall(_ toolCall: ToolCall) {
        guard let firstCall = toolCall.functionCalls.first else { return }
        let args = firstCall.args
        let currentUserId = authViewModel.currentUser?.id ?? UUID()
        
        switch firstCall.name {
        case "draftCompany":
            let name = (args["name"]?.value as? String) ?? "Unknown"
            let structure = (args["structure"]?.value as? String) ?? "LLC"
            
            let newCompany = Company(
                id: UUID(),
                userId: currentUserId,
                name: name,
                structure: structure,
                colorHex: Company.brandColors.first ?? "#000000",
                website: ""
            )
            
            withAnimation {
                self.pendingCompany = newCompany
                self.activeToolCall = firstCall
            }
            captureManager.stop()
            
        case "draftSubscription":
            let companyName = (args["companyName"]?.value as? String) ?? ""
            let name = (args["name"]?.value as? String) ?? "Subscription"
            let cost = (args["cost"]?.value as? Double) ?? 0.0
            let billingCycle = (args["billingCycle"]?.value as? String) ?? "Monthly"
            
            guard let company = findCompany(named: companyName) else {
                sendToolResponse(for: firstCall, success: false, errorMessage: "Company named '\(companyName)' not found.")
                return
            }
            
            let newSub = Subscription(
                id: UUID(),
                userId: currentUserId,
                companyId: company.id,
                name: name,
                cost: cost,
                billingCycle: billingCycle
            )
            
            withAnimation {
                self.pendingSubscription = newSub
                self.activeToolCall = firstCall
            }
            captureManager.stop()
            
        case "draftLoan":
            let companyName = (args["companyName"]?.value as? String) ?? ""
            let name = (args["name"]?.value as? String) ?? "Loan"
            let lender = (args["lender"]?.value as? String) ?? ""
            let remainingBalance = (args["remainingBalance"]?.value as? Double) ?? 0.0
            let monthlyPayment = (args["monthlyPayment"]?.value as? Double) ?? 0.0
            
            guard let company = findCompany(named: companyName) else {
                sendToolResponse(for: firstCall, success: false, errorMessage: "Company named '\(companyName)' not found.")
                return
            }
            
            let newLoan = Loan(
                id: UUID(),
                userId: currentUserId,
                companyId: company.id,
                lender: lender,
                name: name,
                remainingBalance: remainingBalance,
                monthlyPayment: monthlyPayment
            )
            
            withAnimation {
                self.pendingLoan = newLoan
                self.activeToolCall = firstCall
            }
            captureManager.stop()
            
        case "draftCard":
            let companyName = (args["companyName"]?.value as? String) ?? ""
            let name = (args["name"]?.value as? String) ?? "Card"
            let cardType = (args["type"]?.value as? String) ?? "Credit"
            let balance = (args["balance"]?.value as? Double) ?? 0.0
            let limit = (args["limit"]?.value as? Double) ?? 0.0
            
            guard let company = findCompany(named: companyName) else {
                sendToolResponse(for: firstCall, success: false, errorMessage: "Company named '\(companyName)' not found.")
                return
            }
            
            let newCard = FinancialCard(
                id: UUID(),
                userId: currentUserId,
                companyId: company.id,
                name: name,
                type: cardType,
                limit: limit,
                balance: balance
            )
            
            withAnimation {
                self.pendingCard = newCard
                self.activeToolCall = firstCall
            }
            captureManager.stop()
            
        case "navigateTo":
            let tabStr = (args["tab"]?.value as? String) ?? "Home"
            let companyName = (args["companyName"]?.value as? String) ?? ""
            let targetCompany = companyName.isEmpty ? nil : findCompany(named: companyName)
            
            DispatchQueue.main.async {
                if let company = targetCompany {
                    self.vm.selectedCompany = company
                    if self.vm.path.isEmpty {
                        self.vm.path.append(company)
                    }
                }
                
                let tabMap: [String: AppViewModel.CompanyTab] = [
                    "home": .home,
                    "services": .subscriptions,
                    "subscriptions": .subscriptions,
                    "financial": .financial,
                    "financials": .financial,
                    "docs": .documents,
                    "documents": .documents
                ]
                
                if let tab = tabMap[tabStr.lowercased()] {
                    self.vm.activeTab = tab
                }
                
                self.sendToolResponse(for: firstCall, success: true)
                self.disconnectAndDismiss()
            }
            
        case "deleteEntity":
            let entityType = (args["entityType"]?.value as? String) ?? ""
            let entityName = (args["name"]?.value as? String) ?? ""
            let cleanedName = entityName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if entityType.lowercased() == "company" {
                if let comp = appState.companies.first(where: { $0.name.lowercased() == cleanedName }) {
                    self.pendingDelete = PendingDelete(type: "company", name: comp.name, id: comp.id, companyId: comp.id)
                    self.activeToolCall = firstCall
                    captureManager.stop()
                    return
                }
            } else if entityType.lowercased() == "subscription" {
                if let sub = appState.subscriptions.first(where: { $0.name.lowercased() == cleanedName }) {
                    self.pendingDelete = PendingDelete(type: "subscription", name: sub.name, id: sub.id, companyId: sub.companyId)
                    self.activeToolCall = firstCall
                    captureManager.stop()
                    return
                }
            } else if entityType.lowercased() == "card" {
                if let card = appState.cards.first(where: { $0.name.lowercased() == cleanedName }) {
                    self.pendingDelete = PendingDelete(type: "card", name: card.name, id: card.id, companyId: card.companyId)
                    self.activeToolCall = firstCall
                    captureManager.stop()
                    return
                }
            } else if entityType.lowercased() == "loan" {
                if let loan = appState.loans.first(where: { $0.name.lowercased() == cleanedName }) {
                    self.pendingDelete = PendingDelete(type: "loan", name: loan.name, id: loan.id, companyId: loan.companyId)
                    self.activeToolCall = firstCall
                    captureManager.stop()
                    return
                }
            } else if entityType.lowercased() == "document" {
                if let doc = appState.documents.first(where: { $0.name.lowercased() == cleanedName }) {
                    self.pendingDelete = PendingDelete(type: "document", name: doc.name, id: doc.id, companyId: doc.companyId)
                    self.activeToolCall = firstCall
                    captureManager.stop()
                    return
                }
            }
            
            sendToolResponse(for: firstCall, success: false, errorMessage: "Could not find \(entityType) named '\(entityName)'.")
            
        default:
            sendToolResponse(for: firstCall, success: false, errorMessage: "Unknown tool call: \(firstCall.name)")
        }
    }
    
    private func saveCompany(_ company: Company) {
        let userId = authViewModel.currentUser?.id ?? UUID()
        vm.addCompany(
            appState: appState,
            userId: userId,
            name: company.name,
            structure: company.structure,
            colorHex: company.colorHex,
            logoData: nil,
            website: company.website ?? ""
        )
    }
    
    private func saveSubscription(_ sub: Subscription) {
        vm.saveSub(sub, appState: appState)
    }
    
    private func saveLoan(_ loan: Loan) {
        vm.saveLoan(loan, appState: appState)
    }
    
    private func saveCard(_ card: FinancialCard) {
        vm.saveCard(card, appState: appState)
    }
    
    private func executeDelete(_ delete: PendingDelete) {
        if delete.type == "company" {
            if let comp = appState.companies.first(where: { $0.id == delete.id }) {
                vm.deleteCompany(comp, appState: appState, currentUserId: authViewModel.currentUser?.id)
            }
        } else if delete.type == "subscription" {
            if let sub = appState.subscriptions.first(where: { $0.id == delete.id }) {
                vm.deleteSub(sub, appState: appState)
            }
        } else if delete.type == "card" {
            if let card = appState.cards.first(where: { $0.id == delete.id }) {
                vm.deleteCard(card, appState: appState)
            }
        } else if delete.type == "loan" {
            if let loan = appState.loans.first(where: { $0.id == delete.id }) {
                vm.deleteLoan(loan, appState: appState)
            }
        } else if delete.type == "document" {
            if let doc = appState.documents.first(where: { $0.id == delete.id }) {
                vm.deleteDoc(doc, appState: appState)
            }
        }
    }
    
    private func sendToolResponse(for call: FunctionCall, success: Bool, errorMessage: String? = nil) {
        var payload: [String: AnyCodable] = ["success": AnyCodable(success)]
        if let err = errorMessage {
            payload["error"] = AnyCodable(err)
        }
        
        if isChatMode {
            let responsePart: [String: Any] = [
                "functionResponse": [
                    "name": call.name,
                    "response": [
                        "output": [
                            "success": success,
                            "error": errorMessage ?? ""
                        ]
                    ]
                ]
            ]
            self.restHistory.append([
                "role": "user",
                "parts": [responsePart]
            ])
            
            isAIThinking = true
            chatMessages.append(ChatMessage(sender: .assistant, text: "", isPending: true))
            
            Task {
                await executeRESTTurn()
            }
            
            DispatchQueue.main.async {
                withAnimation {
                    self.pendingCompany = nil
                    self.pendingSubscription = nil
                    self.pendingLoan = nil
                    self.pendingCard = nil
                    self.pendingDelete = nil
                    self.activeToolCall = nil
                }
            }
        } else {
            let response = FunctionResponse(
                id: call.id,
                name: call.name,
                response: payload
            )
            
            client?.sendToolResponse(response: response)
                
            DispatchQueue.main.async {
                withAnimation {
                    self.pendingCompany = nil
                    self.pendingSubscription = nil
                    self.pendingLoan = nil
                    self.pendingCard = nil
                    self.pendingDelete = nil
                    self.activeToolCall = nil
                }
                // Resume mic if in audio mode
                if !self.isChatMode {
                    Task { await self.captureManager.start() }
                    
                    // Show permission alert if needed
                    if self.captureManager.permissionDenied {
                        self.showPermissionAlert = true
                    }
                }
            }
        }
    }
    
    private func disconnectAndDismiss() {
        captureManager.stop()
        client?.disconnect()
        dismiss()
    }
    
    // MARK: - Chat view and Helpers
    
    private func toggleMode() {
        withAnimation {
            isChatMode.toggle()
        }
        captureManager.stop()
        setupConnection()
    }
    
    private func sendUserMessage() {
        let input = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        chatMessages.append(ChatMessage(sender: .user, text: input))
        textInput = ""
        isAIThinking = true
        
        chatMessages.append(ChatMessage(sender: .assistant, text: "", isPending: true))
        
        self.restHistory.append([
            "role": "user",
            "parts": [["text": input]]
        ])
        
        Task {
            await executeRESTTurn()
        }
    }
    
    private func executeRESTTurn() async {
        let minifiedData = vm.generateMinifiedPortfolio(appState: appState)
        let dynamicInstruction = """
        You are Miloom, an elite AI Executive Assistant for the Miloom app. Your job is to help the user onboard and manage their businesses and finances.
        You can create companies, subscriptions, loans, and credit/debit cards. You can also delete them, or navigate the user to different parts of the app.
        When asked to add or register any of these items, gather the information and trigger the appropriate tool call. Do not ask for details unless they are missing.
        When answering questions, be brief, professional, and conversational.
        
        Here is the exact current state of the user's finances and businesses:
        \(minifiedData)
        
        Use this data to answer their questions about their portfolio directly. Do not make up any information.
        """
        
        do {
            let json = try await GeminiService.shared.askPortfolioQuestionREST(
                contents: restHistory,
                systemInstruction: dynamicInstruction,
                tools: tools
            )
            
            await MainActor.run {
                if let pendingIndex = chatMessages.lastIndex(where: { $0.isPending }) {
                    chatMessages.remove(at: pendingIndex)
                }
                isAIThinking = false
                
                guard let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else {
                    chatMessages.append(ChatMessage(sender: .assistant, text: "I couldn't get a proper response from the assistant. Please try again."))
                    return
                }
                
                var responseText = ""
                var functionCallPart: [String: Any] = [:]
                var mappedCall: FunctionCall? = nil
                
                for part in parts {
                    if let text = part["text"] as? String {
                        responseText += text
                    }
                    if let functionCall = part["functionCall"] as? [String: Any],
                       let name = functionCall["name"] as? String {
                        let argsDict = functionCall["args"] as? [String: Any] ?? [:]
                        var anyCodableArgs: [String: AnyCodable] = [:]
                        for (key, val) in argsDict {
                            anyCodableArgs[key] = AnyCodable(val)
                        }
                        let callId = UUID().uuidString
                        mappedCall = FunctionCall(id: callId, name: name, args: anyCodableArgs)
                        functionCallPart = functionCall
                    }
                }
                
                if !responseText.isEmpty {
                    chatMessages.append(ChatMessage(sender: .assistant, text: responseText))
                    self.restHistory.append([
                        "role": "model",
                        "parts": [["text": responseText]]
                    ])
                }
                
                if let call = mappedCall {
                    self.restHistory.append([
                        "role": "model",
                        "parts": [["functionCall": functionCallPart]]
                    ])
                    self.handleToolCall(ToolCall(functionCalls: [call]))
                }
            }
        } catch {
            print("REST Turn Error: \(error)")
            await MainActor.run {
                if let pendingIndex = chatMessages.lastIndex(where: { $0.isPending }) {
                    chatMessages.remove(at: pendingIndex)
                }
                isAIThinking = false
                chatMessages.append(ChatMessage(sender: .assistant, text: "Sorry, I had trouble processing that request. Please try again."))
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        self.isAIThinking = false
        if let lastMsgIndex = chatMessages.lastIndex(where: { $0.sender == .assistant }) {
            var msg = chatMessages[lastMsgIndex]
            if msg.isPending {
                msg.isPending = false
            }
            msg.text += text
            chatMessages[lastMsgIndex] = msg
        } else {
            let newMsg = ChatMessage(sender: .assistant, text: text)
            chatMessages.append(newMsg)
        }
    }
    
    private func findCompany(named name: String) -> Company? {
        let cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return appState.companies.first { $0.name.lowercased() == cleaned }
    }
    
    @ViewBuilder
    private var chatView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if chatMessages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LinearGradient(
                                        colors: [Color(hex: "#5AC8FA"), Color(hex: "#0A84FF")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                Text("Ask Miloom anything")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Manage your companies, subscriptions, cards, loans, or navigate the app.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(chatMessages) { msg in
                                chatBubble(for: msg)
                                    .id(msg.id)
                            }
                        }
                        
                        if isAIThinking {
                            typingIndicator
                                .id("typingIndicator")
                        }
                    }
                    .padding()
                }
                .onChange(of: chatMessages.count) { _, _ in
                    withAnimation {
                        if let last = chatMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isAIThinking) { _, thinking in
                    if thinking {
                        withAnimation {
                            proxy.scrollTo("typingIndicator", anchor: .bottom)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Bottom Chat Bar
            HStack(spacing: 12) {
                Button {
                    toggleMode()
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                HStack {
                    TextField("Ask Miloom...", text: $textInput)
                        .foregroundStyle(.white)
                        .font(.system(size: 15))
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .onSubmit {
                            sendUserMessage()
                        }
                    
                    if !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            sendUserMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(hex: "#0A84FF"))
                        }
                        .padding(.trailing, 8)
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    @ViewBuilder
    private func chatBubble(for msg: ChatMessage) -> some View {
        HStack {
            if msg.sender == .user {
                Spacer()
                Text(msg.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#0A84FF"))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16))
                    .frame(maxWidth: 280, alignment: .trailing)
            } else {
                if msg.isPending {
                    typingIndicatorBubble
                } else {
                    Text(msg.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16))
                        .frame(maxWidth: 280, alignment: .leading)
                }
                Spacer()
            }
        }
        .transition(.opacity.combined(with: .slide))
    }
    
    @ViewBuilder
    private var typingIndicatorBubble: some View {
        HStack(spacing: 4) {
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
            Circle().fill(Color.white.opacity(0.4)).frame(width: 6, height: 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16))
    }
    
    @ViewBuilder
    private var typingIndicator: some View {
        HStack {
            typingIndicatorBubble
            Spacer()
        }
    }
}
