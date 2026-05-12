import SwiftUI
import Combine

struct AssistantOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Bindable var vm: AppViewModel
    
    @StateObject private var captureManager = AudioCaptureManager()
    @State private var showPermissionAlert = false
    @State private var client: GeminiLiveClient?
    @State private var debugLog: String = "Waiting..."
    
    @State private var isConnecting = true
    @State private var connectionError: String? = nil
    @State private var activeToolCall: FunctionCall? = nil
    @State private var pendingCompany: Company? = nil
    
    private let systemInstruction = """
    You are Miloom, an elite AI Executive Assistant for the Miloom app. Your job is to help the user onboard and manage their companies and finances.
    When the user asks to add a company, gather the necessary information. Once you have the name and structure, trigger the draftCompany tool. Do not ask for details unless they are missing. Be brief, professional, and conversational.
    """
    
    private let tools = [
        Tool(functionDeclarations: [
            FunctionDeclaration(
                name: "draftCompany",
                description: "Creates a draft for a new company/entity. Trigger this when the user has provided enough information.",
                parameters: Schema(
                    type: "OBJECT",
                    properties: [
                        "name": SchemaProperty(type: "STRING", description: "The name of the company."),
                        "structure": SchemaProperty(type: "STRING", description: "The legal structure of the company (e.g. LLC, S-Corp).")
                    ],
                    required: ["name", "structure"]
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
                        .padding(.top, 8)
                    }
                } else if isConnecting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    PulsingOrbView(volume: captureManager.volume)
                }
                
                Spacer()
            }
            
            if let company = pendingCompany, let call = activeToolCall {
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Draft Entity")
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
        client = GeminiLiveClient(systemInstruction: systemInstruction, tools: tools) { log in
            DispatchQueue.main.async {
                self.debugLog = log
            }
        }
        
        Task {
            do {
                try await client?.connect()
                
                // Subscribe to audio data
                client?.audioDataPublisher
                    .receive(on: RunLoop.main)
                    .sink { data in
                        self.captureManager.schedule(audioData: data)
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
                        Task { try? await client?.sendAudio(pcmBufferData: data) }
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
        
        if firstCall.name == "draftCompany" {
            let args = firstCall.args
            let name = (args["name"]?.value as? String) ?? "Unknown"
            let structure = (args["structure"]?.value as? String) ?? "Individual"
            
            let newCompany = Company(
                id: UUID(),
                userId: UUID(),
                name: name,
                structure: structure,
                colorHex: Company.brandColors.first ?? "#000000",
                website: ""
            )
            
            withAnimation {
                self.pendingCompany = newCompany
                self.activeToolCall = firstCall
            }
            
            // Pause microphone while user decides
            captureManager.stop()
        }
    }
    
    private func saveCompany(_ company: Company) {
        Task {
            if let session = try? await SupabaseService.shared.client.auth.session {
                await MainActor.run {
                    vm.addCompany(
                        appState: appState,
                        userId: session.user.id,
                        name: company.name,
                        structure: company.structure,
                        colorHex: company.colorHex,
                        logoData: nil,
                        website: company.website ?? ""
                    )
                }
            }
        }
    }
    
    private func sendToolResponse(for call: FunctionCall, success: Bool) {
        let response = FunctionResponse(
            id: call.id,
            name: call.name,
            response: ["success": AnyCodable(success)]
        )
        
        Task {
            try? await client?.sendToolResponse(response: response)
            
            DispatchQueue.main.async {
                withAnimation {
                    self.pendingCompany = nil
                    self.activeToolCall = nil
                }
                // Resume mic
                Task { await self.captureManager.start() }
                
                // Show permission alert if needed
                if self.captureManager.permissionDenied {
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func disconnectAndDismiss() {
        captureManager.stop()
        client?.disconnect()
        dismiss()
    }
}
