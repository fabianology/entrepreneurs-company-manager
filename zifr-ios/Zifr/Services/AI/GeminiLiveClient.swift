import Foundation
import Combine
import Supabase

class GeminiLiveClient {
    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var isConnected = false
    
    // Publishers to emit received data
    let audioDataPublisher = PassthroughSubject<Data, Never>()
    let toolCallPublisher = PassthroughSubject<ToolCall, Never>()
    let textDataPublisher = PassthroughSubject<String, Never>()
    
    // We need the system instructions and tools to send during setup
    private let systemInstruction: String
    private let tools: [Tool]
    private let responseModalities: [String]
    private let onLog: ((String) -> Void)?
    
    // Auto-reconnect state
    private var intentionalDisconnect = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var pingTimer: Timer?
    
    init(systemInstruction: String, tools: [Tool], responseModalities: [String] = ["AUDIO"], onLog: ((String) -> Void)? = nil) {
        self.systemInstruction = systemInstruction
        self.tools = tools
        self.responseModalities = responseModalities
        self.onLog = onLog
    }
    
    private func log(_ message: String) {
        onLog?(message)
    }
    
    func connect() async throws {
        intentionalDisconnect = false
        reconnectAttempts = 0
        try await establishConnection()
    }
    
    private func establishConnection() async throws {
        let wsString = "\(SupabaseService.shared.urlString.replacingOccurrences(of: "https://", with: "wss://"))/functions/v1/gemini-live-proxy"
        
        guard let url = URL(string: wsString) else {
            throw NSError(domain: "GeminiLiveClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        
        if let session = try? await SupabaseService.shared.client.auth.session {
            request.addValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            throw NSError(domain: "GeminiLiveClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Clean up any existing socket
        webSocket?.cancel(with: .goingAway, reason: nil)
        
        webSocket = self.session.webSocketTask(with: request)
        webSocket?.resume()
        isConnected = true
        log("WebSocket connected to Supabase Proxy")
        
        startPinging()
        
        // Start listening
        receiveMessages()
        
        // Send Setup Message
        sendSetup()
    }
    
    private func sendSetup() {
        let speechConfig = responseModalities.contains("AUDIO") ? SpeechConfig(
            voiceConfig: VoiceConfig(
                prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede")
            )
        ) : nil
        let generationConfig = GenerationConfig(
            responseModalities: responseModalities,
            speechConfig: speechConfig
        )
        let modelName = responseModalities.contains("AUDIO") ? "models/gemini-2.5-flash-native-audio-latest" : "models/gemini-2.0-flash-exp"
        let setup = Setup(
            model: modelName,
            generationConfig: generationConfig,
            systemInstruction: SystemInstruction(parts: [TextPart(text: systemInstruction)]),
            tools: tools.isEmpty ? nil : tools
        )
        
        let clientMsg = ClientMessage(setup: setup)
        log("Sending setup with model \(modelName) and modalities: \(responseModalities)...")
        send(clientMsg)
    }
    
    func sendAudio(pcmBufferData: Data) {
        let base64 = pcmBufferData.base64EncodedString()
        let chunk = MediaChunk(mimeType: "audio/pcm;rate=16000", data: base64)
        let msg = ClientMessage(realtimeInput: RealtimeInput(mediaChunks: [chunk]))
        send(msg)
    }
    
    func sendToolResponse(response: FunctionResponse) {
        let msg = ClientMessage(toolResponse: ToolResponseWrapper(functionResponses: [response]))
        send(msg)
    }
    
    func sendTextMessage(_ text: String) {
        let turn = Turn(role: "user", parts: [TextPart(text: text)])
        let content = ClientContent(turns: [turn], turnComplete: true)
        let msg = ClientMessage(clientContent: content)
        log("Sending text message: \(text)")
        send(msg)
    }
    
    private var messageQueue: [ClientMessage] = []
    private var isSending = false

    private func send(_ message: ClientMessage) {
        guard isConnected else { return }
        messageQueue.append(message)
        processQueue()
    }

    private func processQueue() {
        guard !isSending, !messageQueue.isEmpty, isConnected else { return }
        isSending = true
        let message = messageQueue.removeFirst()
        
        Task {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(message)
                let string = String(data: data, encoding: .utf8)!
                try await self.webSocket?.send(.string(string))
            } catch {
                self.log("Send error: \(error.localizedDescription)")
            }
            
            self.isSending = false
            self.processQueue()
        }
    }
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                // Reset reconnect counter on successful receive
                self.reconnectAttempts = 0
                
                switch message {
                case .string(let text):
                    self.handleServerMessage(jsonString: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleServerMessage(jsonString: text)
                    }
                @unknown default:
                    break
                }
                
                // Continue listening if still connected
                if self.isConnected {
                    self.receiveMessages()
                }
            case .failure(let error):
                if !self.intentionalDisconnect {
                    self.log("WebSocket receive error: \(error)")
                }
                self.handleDisconnect()
            }
        }
    }
    
    private func handleServerMessage(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        
        do {
            let serverMsg = try decoder.decode(ServerMessage.self, from: data)
            
            // Handle setup complete
            if serverMsg.setupComplete != nil {
                self.log("✅ Setup complete! Gemini is ready.")
            }
            
            // Handle tool calls
            if let toolCall = serverMsg.toolCall {
                self.log("Received tool call: \(toolCall.functionCalls.first?.name ?? "unknown")")
                self.toolCallPublisher.send(toolCall)
            }
            
            // Handle content
            var receivedAudio = false
            var receivedText = false
            if let parts = serverMsg.serverContent?.modelTurn?.parts {
                for part in parts {
                    if let text = part.text, !text.isEmpty {
                        receivedText = true
                        self.textDataPublisher.send(text)
                    }
                    if let inlineData = part.inlineData,
                       inlineData.mimeType.starts(with: "audio/pcm"),
                       let audioData = Data(base64Encoded: inlineData.data) {
                        receivedAudio = true
                        self.audioDataPublisher.send(audioData)
                    }
                }
            }
            
            if receivedAudio {
                self.log("Received audio chunk")
            }
            if receivedText {
                self.log("Received text chunk")
            }
            if !receivedAudio && !receivedText && serverMsg.toolCall == nil && serverMsg.setupComplete == nil {
                self.log("Received message without audio/text/tools")
            }
        } catch {
            self.log("Decode error: \(error.localizedDescription)\nPreview: \(String(jsonString.prefix(200)))")
        }
    }
    
    // MARK: - Connection Lifecycle
    
    /// Called when the connection drops unexpectedly. Attempts auto-reconnect.
    private func handleDisconnect() {
        isConnected = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        
        // Don't reconnect if the user intentionally disconnected
        guard !intentionalDisconnect else { return }
        
        reconnectAttempts += 1
        guard reconnectAttempts <= maxReconnectAttempts else {
            log("❌ Max reconnect attempts (\(maxReconnectAttempts)) reached. Giving up.")
            return
        }
        
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = pow(2.0, Double(reconnectAttempts - 1))
        log("🔄 Connection lost. Reconnecting in \(Int(delay))s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))...")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.intentionalDisconnect else { return }
            Task {
                do {
                    try await self.establishConnection()
                    self.log("✅ Reconnected successfully!")
                } catch {
                    self.log("❌ Reconnect failed: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }
    
    /// Intentionally disconnect (user closed the assistant).
    func disconnect() {
        intentionalDisconnect = true
        isConnected = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    private func startPinging() {
        DispatchQueue.main.async {
            self.pingTimer?.invalidate()
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                guard self?.isConnected == true else { return }
                self?.webSocket?.sendPing { error in
                    if let error = error {
                        self?.log("Ping error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
