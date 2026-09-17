import Foundation
import Combine
import Supabase

@MainActor
protocol LiveSocket: AnyObject {
    var statusCode: Int? { get }
    func resume()
    func send(_ text: String) async throws
    func receive() async throws -> Data
    func ping() async throws
    func close()
}

@MainActor
private final class URLSessionLiveSocket: LiveSocket {
    private let task: URLSessionWebSocketTask
    init(request: URLRequest) { task = URLSession.shared.webSocketTask(with: request) }
    var statusCode: Int? { (task.response as? HTTPURLResponse)?.statusCode }
    func resume() { task.resume() }
    func send(_ text: String) async throws { try await task.send(.string(text)) }
    func receive() async throws -> Data {
        switch try await task.receive() {
        case .data(let data): return data
        case .string(let string): return Data(string.utf8)
        @unknown default: throw LiveFailure.setup
        }
    }
    func ping() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
    func close() { task.cancel(with: .goingAway, reason: nil) }
}

/// Main-actor ownership makes socket replacement, writes, and UI events ordered.
@MainActor
final class GeminiLiveClient {
    static let model = "models/gemini-3.8-live"
    let events = PassthroughSubject<LiveEvent, Never>()
    let state = CurrentValueSubject<LiveConnectionState, Never>(.idle)
    private let instruction: String
    private let tools: [Tool]
    private let makeRequest: () async throws -> URLRequest
    private let makeSocket: (URLRequest) -> LiveSocket
    private let setupTimeout: UInt64
    private let retryDelay: UInt64
    private var socket: LiveSocket?
    private var generation = UUID()
    private var receiveTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var openTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<Void, Error>?
    private var queue: [ClientMessage] = []
    private var pendingResponses: [String: FunctionResponse] = [:]
    private var resumeHandle: String?
    private var hasConnected = false
    private var stopped = true
    private var attempts = 0
    private var startedAt = Date()
    private var receivedFirstAudio = false
    private var sentFirstAudio = false

    init(systemInstruction: String, tools: [Tool],
         setupTimeout: UInt64 = 15_000_000_000, retryDelay: UInt64 = 1_000_000_000,
         makeRequest: (() async throws -> URLRequest)? = nil,
         makeSocket: ((URLRequest) -> LiveSocket)? = nil) {
        instruction = systemInstruction
        self.tools = tools
        self.setupTimeout = setupTimeout
        self.retryDelay = retryDelay
        self.makeRequest = makeRequest ?? Self.authenticatedRequest
        self.makeSocket = makeSocket ?? { URLSessionLiveSocket(request: $0) }
    }

    private static func authenticatedRequest() async throws -> URLRequest {
        guard let session = try? await SupabaseService.shared.client.auth.session else {
            throw LiveFailure.authentication
        }
        let base = SupabaseService.shared.urlString.replacingOccurrences(of: "https://", with: "wss://")
        guard let url = URL(string: base + "/functions/v1/gemini-live-proxy") else { throw LiveFailure.setup }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    func connect() async throws {
        disconnect()
        stopped = false
        attempts = 0
        hasConnected = false
        startedAt = Date()
        receivedFirstAudio = false
        sentFirstAudio = false
        state.send(.connecting)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                open()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.disconnect() }
        }
    }

    static func setup(instruction: String, tools: [Tool], handle: String?) -> Setup {
        let liveTools = tools.map { tool in
            Tool(functionDeclarations: tool.functionDeclarations.map { original in
                var declaration = original
                declaration.behavior = "BLOCKING"
                return declaration
            })
        }
        return Setup(model: model,
                     generationConfig: GenerationConfig(responseModalities: ["AUDIO"],
                        speechConfig: SpeechConfig(voiceConfig: VoiceConfig(
                            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede")))),
                     systemInstruction: SystemInstruction(parts: [TextPart(text: instruction)]),
                     tools: liveTools.isEmpty ? nil : liveTools,
                     inputAudioTranscription: EmptyLiveConfig(), outputAudioTranscription: EmptyLiveConfig(),
                     sessionResumption: LiveSessionResumption(handle: handle),
                     contextWindowCompression: LiveContextCompression())
    }

    private func open() {
        invalidateSocket()
        let id = generation
        timeoutTask = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(nanoseconds: setupTimeout) } catch { return }
            guard id == generation, !stopped else { return }
            fail(.timeout)
        }
        openTask = Task { [weak self] in
            guard let self else { return }
            do {
                let request = try await makeRequest()
                guard generation == id, !stopped else { return }
                let newSocket = makeSocket(request)
                socket = newSocket
                newSocket.resume()
                receiveTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        while !Task.isCancelled {
                            let data = try await newSocket.receive()
                            guard id == generation, !stopped else { return }
                            try handle(data)
                        }
                    } catch {
                        guard id == generation, !stopped else { return }
                        connectionLost(error, status: newSocket.statusCode)
                    }
                }
                enqueue(ClientMessage(setup: Self.setup(instruction: instruction, tools: tools, handle: resumeHandle)))
            } catch {
                guard generation == id, !stopped else { return }
                connectionLost(error)
            }
        }
    }

    func sendAudio(pcmBufferData: Data) {
        guard state.value == .ready, queue.count < 12 else { return }
        enqueue(ClientMessage(realtimeInput: RealtimeInput(audio: MediaChunk(
            mimeType: "audio/pcm;rate=16000", data: pcmBufferData.base64EncodedString()))))
    }

    func sendTextMessage(_ text: String) {
        guard state.value == .ready, !text.isEmpty else { return }
        enqueue(ClientMessage(clientContent: ClientContent(
            turns: [Turn(role: "user", parts: [TextPart(text: text)])], turnComplete: true)))
    }

    func endAudioStream() {
        // Remove captured audio still waiting to send, including any before a privacy pause.
        queue.removeAll { $0.realtimeInput?.audio != nil }
        guard state.value == .ready else { return }
        enqueue(ClientMessage(realtimeInput: RealtimeInput(audioStreamEnd: true)))
    }

    func sendToolResponse(response: FunctionResponse) {
        guard !stopped else { return }
        pendingResponses[response.id] = response
        if state.value == .ready { enqueue(ClientMessage(toolResponse: ToolResponseWrapper(functionResponses: [response]))) }
    }

    func flushResponses() async {
        for _ in 0..<100 {
            if stopped || (queue.isEmpty && sendTask == nil) { return }
            do { try await Task.sleep(nanoseconds: 10_000_000) } catch { return }
        }
    }

    private func enqueue(_ message: ClientMessage) {
        queue.append(message)
        guard sendTask == nil else { return }
        let id = generation
        sendTask = Task { [weak self] in
            guard let self else { return }
            defer { if generation == id { sendTask = nil } }
            while !queue.isEmpty, id == generation, !stopped, let socket {
                let message = queue.removeFirst()
                do {
                    let data = try JSONEncoder().encode(message)
                    try await socket.send(String(decoding: data, as: UTF8.self))
                    guard id == generation else { return }
                    if message.realtimeInput?.audio != nil, !sentFirstAudio {
                        sentFirstAudio = true
                        AppDiagnostics.event("ai", "live_microphone_audio", status: "sent")
                    }
                    for response in message.toolResponse?.functionResponses ?? [] {
                        pendingResponses.removeValue(forKey: response.id)
                    }
                } catch {
                    guard id == generation, !stopped else { return }
                    connectionLost(error, status: socket.statusCode)
                    return
                }
            }
        }
    }

    private func handle(_ data: Data) throws {
        let message = try JSONDecoder().decode(ServerMessage.self, from: data)
        if let error = message.error {
            if let failure = LiveFailure.classify(message: error.message, code: error.code) { fail(failure) }
            else { connectionLost(LiveFailure.disconnected) }
            return
        }
        if let update = message.sessionResumptionUpdate {
            if update.resumable == true, let handle = update.newHandle, !handle.isEmpty { resumeHandle = handle }
            // Keep the last resumable checkpoint during generation/tool execution.
            // Newer uncheckpointed audio is discarded; completed tools are deduplicated by the caller.
        }
        if message.setupComplete != nil {
            timeoutTask?.cancel()
            hasConnected = true
            attempts = 0
            state.send(.ready)
            continuation?.resume()
            continuation = nil
            AppDiagnostics.event("ai", "live_setup", status: "ready")
            for response in pendingResponses.values {
                enqueue(ClientMessage(toolResponse: ToolResponseWrapper(functionResponses: [response])))
            }
            startPinging()
        }
        if let ids = message.toolCallCancellation?.ids {
            for id in ids { pendingResponses.removeValue(forKey: id) }
            queue.removeAll { $0.toolResponse?.functionResponses.contains(where: { ids.contains($0.id) }) == true }
            events.send(.cancelledTools(ids))
        }
        if let content = message.serverContent {
            if content.interrupted == true {
                // Finish the interrupted response's text before opening the interrupting user turn.
                if let transcript = content.outputTranscription { events.send(.outputTranscript(transcript)) }
                events.send(.interrupted)
                if let transcript = content.inputTranscription { events.send(.inputTranscript(transcript)) }
            } else {
                if let transcript = content.inputTranscription { events.send(.inputTranscript(transcript)) }
                if let transcript = content.outputTranscription { events.send(.outputTranscript(transcript)) }
            }
            // Transcription is authoritative; model text may be reasoning, not spoken text.
            if content.interrupted != true {
                for part in content.modelTurn?.parts ?? [] {
                    if let inline = part.inlineData, inline.mimeType.hasPrefix("audio/pcm"),
                       let audio = Data(base64Encoded: inline.data), !audio.isEmpty {
                        if !receivedFirstAudio {
                            receivedFirstAudio = true
                            let milliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
                            AppDiagnostics.event("ai", "live_first_audio", status: "elapsed_ms_\(milliseconds)")
                        }
                        events.send(.audio(audio))
                    }
                }
            }
            if content.generationComplete == true { events.send(.generationComplete) }
            if content.turnComplete == true { events.send(.turnComplete) }
        }
        if let calls = message.toolCall { events.send(.tools(calls)) }
        if message.goAway != nil { connectionLost(LiveFailure.disconnected, immediate: true) }
    }

    private func connectionLost(_ error: Error, status: Int? = nil, immediate: Bool = false) {
        if let terminal = LiveFailure.classify(message: "", code: status) { fail(terminal); return }
        if let failure = error as? LiveFailure, failure != .disconnected { fail(failure); return }
        if hasConnected && resumeHandle == nil { fail(.disconnected); return }
        guard attempts < 5 else { fail(.disconnected); return }
        attempts += 1
        invalidateSocket()
        state.send(.reconnecting)
        let delay = immediate ? 0 : retryDelay * UInt64(1 << (attempts - 1))
        let id = generation
        retryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: delay) } catch { return }
            guard let self, !stopped, id == generation else { return }
            open()
        }
    }

    private func startPinging() {
        pingTask?.cancel()
        let id = generation
        pingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    guard id == generation, !stopped, let socket else { return }
                    try await socket.ping()
                } catch {
                    guard !Task.isCancelled, id == generation, !stopped else { return }
                    connectionLost(error)
                    return
                }
            }
        }
    }

    private func fail(_ failure: LiveFailure) {
        stopped = true
        invalidateSocket()
        continuation?.resume(throwing: failure)
        continuation = nil
        resumeHandle = nil
        pendingResponses.removeAll()
        state.send(.failed(failure))
        AppDiagnostics.event("ai", "live_connection", status: "failed")
    }

    private func invalidateSocket() {
        generation = UUID()
        openTask?.cancel(); receiveTask?.cancel(); sendTask?.cancel()
        timeoutTask?.cancel(); retryTask?.cancel(); pingTask?.cancel()
        openTask = nil; receiveTask = nil; sendTask = nil
        timeoutTask = nil; retryTask = nil; pingTask = nil
        socket?.close(); socket = nil
        queue.removeAll()
    }

    func disconnect() {
        stopped = true
        invalidateSocket()
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        resumeHandle = nil
        pendingResponses.removeAll()
        state.send(.idle)
    }
}
