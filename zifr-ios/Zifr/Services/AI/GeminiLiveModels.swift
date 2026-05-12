import Foundation

// MARK: - Client to Server Messages

struct ClientMessage: Codable {
    let setup: Setup?
    let clientContent: ClientContent?
    let realtimeInput: RealtimeInput?
    let toolResponse: ToolResponseWrapper?
    
    init(setup: Setup? = nil, clientContent: ClientContent? = nil, realtimeInput: RealtimeInput? = nil, toolResponse: ToolResponseWrapper? = nil) {
        self.setup = setup
        self.clientContent = clientContent
        self.realtimeInput = realtimeInput
        self.toolResponse = toolResponse
    }
}

struct Setup: Codable {
    let model: String
    let generationConfig: GenerationConfig?
    let systemInstruction: SystemInstruction?
    let tools: [Tool]?
}

struct GenerationConfig: Codable {
    let responseModalities: [String]
    let speechConfig: SpeechConfig?
}

struct SpeechConfig: Codable {
    let voiceConfig: VoiceConfig
}

struct VoiceConfig: Codable {
    let prebuiltVoiceConfig: PrebuiltVoiceConfig
}

struct PrebuiltVoiceConfig: Codable {
    let voiceName: String
}

struct SystemInstruction: Codable {
    let parts: [TextPart]
}

struct TextPart: Codable {
    let text: String
}

struct Tool: Codable {
    let functionDeclarations: [FunctionDeclaration]
}

struct FunctionDeclaration: Codable {
    let name: String
    let description: String
    let parameters: Schema?
}

struct Schema: Codable {
    let type: String
    let properties: [String: SchemaProperty]?
    let required: [String]?
}

struct SchemaProperty: Codable {
    let type: String
    let description: String?
}

struct ClientContent: Codable {
    let turns: [Turn]
    let turnComplete: Bool
}

struct Turn: Codable {
    let role: String
    let parts: [TextPart]
}

struct RealtimeInput: Codable {
    let mediaChunks: [MediaChunk]
}

struct MediaChunk: Codable {
    let mimeType: String
    let data: String
}

struct ToolResponseWrapper: Codable {
    let functionResponses: [FunctionResponse]
}

struct FunctionResponse: Codable {
    let id: String
    let name: String
    let response: [String: AnyCodable]
}

// MARK: - Server to Client Messages

struct ServerMessage: Codable {
    let setupComplete: SetupComplete?
    let serverContent: ServerContent?
    let toolCall: ToolCall?
}

struct SetupComplete: Codable {
    // Empty – its presence alone means setup succeeded
}

struct ServerContent: Codable {
    let modelTurn: ModelTurn?
}

struct ModelTurn: Codable {
    let parts: [ServerPart]?
}

struct ServerPart: Codable {
    let inlineData: InlineData?
    let text: String?
}

struct InlineData: Codable {
    let mimeType: String
    let data: String
}

struct ToolCall: Codable {
    let functionCalls: [FunctionCall]
}

struct FunctionCall: Codable {
    let id: String
    let name: String
    let args: [String: AnyCodable]
}

// MARK: - Helpers

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let stringVal = try? container.decode(String.self) { value = stringVal }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded") }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let stringVal = value as? String { try container.encode(stringVal) }
        else { throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")) }
    }
}
