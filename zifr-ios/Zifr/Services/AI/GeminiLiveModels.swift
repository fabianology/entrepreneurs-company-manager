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
    var inputAudioTranscription: EmptyLiveConfig? = nil
    var outputAudioTranscription: EmptyLiveConfig? = nil
    var sessionResumption: LiveSessionResumption? = nil
    var contextWindowCompression: LiveContextCompression? = nil
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
    var behavior: String? = nil
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
    var audio: MediaChunk? = nil
    var audioStreamEnd: Bool? = nil
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
    var toolCallCancellation: LiveToolCancellation? = nil
    var sessionResumptionUpdate: LiveResumptionUpdate? = nil
    var goAway: LiveGoAway? = nil
    var error: LiveServerError? = nil
}

struct SetupComplete: Codable {
    // Empty – its presence alone means setup succeeded
}

struct ServerContent: Codable {
    let modelTurn: ModelTurn?
    var inputTranscription: LiveTranscription? = nil
    var outputTranscription: LiveTranscription? = nil
    var interrupted: Bool? = nil
    var generationComplete: Bool? = nil
    var turnComplete: Bool? = nil
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
    
    var doubleValue: Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return nil
    }

    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = NSNull() }
        else if let decoded = try? container.decode(Bool.self) { value = decoded }
        else if let decoded = try? container.decode(Int.self) { value = decoded }
        else if let decoded = try? container.decode(Double.self) { value = decoded }
        else if let decoded = try? container.decode(String.self) { value = decoded }
        else if let decoded = try? container.decode([String: AnyCodable].self) { value = decoded }
        else if let decoded = try? container.decode([AnyCodable].self) { value = decoded }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let value as Bool: try container.encode(value)
        case let value as Int: try container.encode(value)
        case let value as Double: try container.encode(value)
        case let value as String: try container.encode(value)
        case let value as [String: AnyCodable]: try container.encode(value)
        case let value as [AnyCodable]: try container.encode(value)
        default: throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }
}

// Live-only configuration stays out of the REST chat payload.
struct EmptyLiveConfig: Codable {}
struct LiveSessionResumption: Codable { var handle: String? = nil }
struct LiveContextCompression: Codable { var slidingWindow = EmptyLiveConfig() }
struct LiveTranscription: Codable { var text: String?; var finished: Bool? }
struct LiveToolCancellation: Codable { let ids: [String] }
struct LiveResumptionUpdate: Codable { let newHandle: String?; let resumable: Bool? }
struct LiveGoAway: Codable { let timeLeft: String? }

// The proxy sends strings; Google may send a structured API error.
struct LiveServerError: Codable {
    let message: String
    let code: Int?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) { message = text; code = nil }
        else {
            let object = try container.decode(Detail.self)
            message = object.message ?? "Voice connection failed."
            code = object.code
        }
    }
    private struct Detail: Decodable { let message: String?; let code: Int? }
}

enum LiveFailure: Error, LocalizedError, Equatable {
    case authentication, allowance, modelUnavailable, setup, disconnected, timeout, audio
    var errorDescription: String? {
        switch self {
        case .authentication: return "Please sign in again to use voice."
        case .allowance: return "Your voice allowance has been reached."
        case .modelUnavailable: return "Gemini 3.8 Live is unavailable for this account. Please try again later."
        case .setup: return "Voice could not start. Please try again."
        case .disconnected: return "The conversation could not reconnect. Restart voice to begin a new conversation."
        case .timeout: return "Voice took too long to connect. Please try again."
        case .audio: return "The microphone or audio output is unavailable. Check your audio connection and try again."
        }
    }
    static func classify(message: String, code: Int? = nil) -> LiveFailure? {
        let text = message.lowercased()
        if text.contains("miloom_limit") || code == 429 || text.contains("resource_exhausted") { return .allowance }
        if code == 401 || text.contains("unauthorized") || text.contains("unauthenticated") { return .authentication }
        if code == 403 || code == 404 || text.contains("not found") || text.contains("not supported") || text.contains("permission_denied") { return .modelUnavailable }
        if code == 400 || text.contains("invalid_argument") { return .setup }
        return nil
    }
}

enum LiveConnectionState: Equatable {
    case idle, connecting, ready, reconnecting, failed(LiveFailure)
}

enum LiveEvent {
    case audio(Data), inputTranscript(LiveTranscription), outputTranscript(LiveTranscription)
    case interrupted, generationComplete, turnComplete, tools(ToolCall), cancelledTools([String])
}

/// Serializes confirmation requests and makes repeated calls safe across resumed sockets.
struct LiveToolQueue {
    private(set) var pending: [FunctionCall] = []
    private(set) var active: FunctionCall?
    private(set) var completed: [String: FunctionResponse] = [:]
    private var cancelled: Set<String> = []

    mutating func enqueue(_ calls: [FunctionCall]) -> [FunctionResponse] {
        var repeats: [FunctionResponse] = []
        for call in calls {
            if let response = completed[call.id] { repeats.append(response); continue }
            guard !cancelled.contains(call.id), active?.id != call.id,
                  !pending.contains(where: { $0.id == call.id }) else { continue }
            pending.append(call)
        }
        return repeats
    }
    mutating func next() -> FunctionCall? {
        guard active == nil, !pending.isEmpty else { return nil }
        active = pending.removeFirst()
        return active
    }
    mutating func finish(_ response: FunctionResponse) {
        guard !cancelled.contains(response.id) else { return }
        completed[response.id] = response
        if active?.id == response.id { active = nil }
    }
    mutating func cancel(_ ids: [String]) {
        cancelled.formUnion(ids)
        pending.removeAll { ids.contains($0.id) }
        if let current = active, ids.contains(current.id) { active = nil }
    }
}

struct LiveTranscriptEntry: Identifiable, Equatable {
    enum Speaker { case user, assistant }
    let id = UUID()
    let speaker: Speaker
    var text: String
    var interrupted = false
}
struct LiveTranscript {
    private(set) var entries: [LiveTranscriptEntry] = []
    private var userID: UUID?
    private var assistantID: UUID?
    private var interruptedTurn = false
    private var hasAssistantTurn = false
    mutating func append(_ value: LiveTranscription, speaker: LiveTranscriptEntry.Speaker) {
        guard let text = value.text, !text.isEmpty else {
            if value.finished == true { close(speaker) }
            return
        }
        if speaker == .assistant { hasAssistantTurn = true; interruptedTurn = false }
        let id = speaker == .user ? userID : assistantID
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].text += text
        } else {
            let entry = LiveTranscriptEntry(speaker: speaker, text: text)
            entries.append(entry)
            if speaker == .user { userID = entry.id } else { assistantID = entry.id }
        }
        if value.finished == true { close(speaker) }
    }
    mutating func interrupt() {
        if hasAssistantTurn, let index = entries.lastIndex(where: { $0.speaker == .assistant }) {
            entries[index].interrupted = true
        }
        assistantID = nil
        userID = nil
        interruptedTurn = true
        hasAssistantTurn = false
    }
    mutating func endTurn() {
        assistantID = nil
        // An interrupting user's transcript can arrive before the old turnComplete.
        if !interruptedTurn { userID = nil }
        interruptedTurn = false
        hasAssistantTurn = false
    }
    private mutating func close(_ speaker: LiveTranscriptEntry.Speaker) {
        if speaker == .user { userID = nil } else { assistantID = nil }
    }
}

extension FunctionCall {
    func validationError(for declaration: FunctionDeclaration) -> String? {
        let schema = declaration.parameters
        for name in schema?.required ?? [] {
            guard let value = args[name]?.value, !(value is NSNull) else { return "Missing required field: \(name)." }
        }
        for (name, property) in schema?.properties ?? [:] {
            guard let value = args[name], !(value.value is NSNull) else { continue }
            switch property.type {
            case "STRING":
                guard let text = value.value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(schema?.required?.contains(name) ?? false) else {
                    return "Provide a valid value for \(name)."
                }
            case "NUMBER":
                guard let number = value.doubleValue, number.isFinite else { return "Provide a number for \(name)." }
            default: break
            }
        }
        return nil
    }
}
