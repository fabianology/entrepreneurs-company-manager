import Foundation
import Combine

class GeminiLiveClient {
    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var isConnected = false
    
    // Publishers to emit received data
    let audioDataPublisher = PassthroughSubject<Data, Never>()
    let toolCallPublisher = PassthroughSubject<ToolCall, Never>()
    
    // We need the system instructions and tools to send during setup
    private let systemInstruction: String
    private let tools: [Tool]
    private let onLog: ((String) -> Void)?
    
    init(systemInstruction: String, tools: [Tool], onLog: ((String) -> Void)? = nil) {
        self.systemInstruction = systemInstruction
        self.tools = tools
        self.onLog = onLog
    }
    
    private func log(_ message: String) {
        print(message)
        onLog?(message)
    }
    
    // Gemini API key
    private static let apiKey = "AIzaSyDjMa5RCyBu5-IlNPNCs8JZhdRmXjkCBqk"
    
    func connect() async throws {
        let wsString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(Self.apiKey)"
        
        guard let url = URL(string: wsString) else {
            throw NSError(domain: "GeminiLiveClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        webSocket = self.session.webSocketTask(with: url)
        webSocket?.resume()
        isConnected = true
        log("WebSocket connected to Gemini directly")
        
        // Start listening
        receiveMessages()
        
        // Send Setup Message
        try await sendSetup()
    }
    
    private func sendSetup() async throws {
        let speechConfig = SpeechConfig(
            voiceConfig: VoiceConfig(
                prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede")
            )
        )
        let generationConfig = GenerationConfig(
            responseModalities: ["AUDIO"],
            speechConfig: speechConfig
        )
        let setup = Setup(
            model: "models/gemini-2.5-flash-native-audio-latest",
            generationConfig: generationConfig,
            systemInstruction: SystemInstruction(parts: [TextPart(text: systemInstruction)]),
            tools: tools.isEmpty ? nil : tools
        )
        
        let clientMsg = ClientMessage(setup: setup)
        log("Sending setup...")
        try await send(clientMsg)
    }
    
    func sendAudio(pcmBufferData: Data) async throws {
        let base64 = pcmBufferData.base64EncodedString()
        let chunk = MediaChunk(mimeType: "audio/pcm;rate=16000", data: base64)
        let msg = ClientMessage(realtimeInput: RealtimeInput(mediaChunks: [chunk]))
        try await send(msg)
    }
    
    func sendToolResponse(response: FunctionResponse) async throws {
        let msg = ClientMessage(toolResponse: ToolResponseWrapper(functionResponses: [response]))
        try await send(msg)
    }
    
    private func send(_ message: ClientMessage) async throws {
        guard isConnected else { return }
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let string = String(data: data, encoding: .utf8)!
        try await webSocket?.send(.string(string))
    }
    
    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
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
                self.log("WebSocket receive error: \(error)")
                self.disconnect()
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
            
            // Handle audio
            var receivedAudio = false
            if let parts = serverMsg.serverContent?.modelTurn?.parts {
                for part in parts {
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
            } else if serverMsg.toolCall == nil {
                self.log("Received message without audio/tools")
            }
        } catch {
            self.log("Decode error: \(error.localizedDescription)\nPreview: \(String(jsonString.prefix(100)))")
        }
    }
    
    func disconnect() {
        isConnected = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
}
