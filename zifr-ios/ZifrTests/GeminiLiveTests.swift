import XCTest
import Combine
import SwiftUI
import Supabase
import AVFoundation
@testable import Zifr

@MainActor
final class GeminiLiveTests: XCTestCase {
    private var subscriptions: Set<AnyCancellable> = []

    private func tool(_ id: String) -> FunctionCall {
        FunctionCall(id: id, name: "draftCompany", args: ["name": AnyCodable("Example")])
    }
    private func response(_ id: String) -> FunctionResponse {
        FunctionResponse(id: id, name: "draftCompany", response: ["success": AnyCodable(true)])
    }
    private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    private func waitFor(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<500 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }
    private func client(_ sockets: [MockLiveSocket], timeout: UInt64 = 1_000_000_000, retryDelay: UInt64 = 1_000_000) -> GeminiLiveClient {
        var next = 0
        return GeminiLiveClient(systemInstruction: "Synthetic test context", tools: [],
            setupTimeout: timeout, retryDelay: retryDelay,
            makeRequest: { URLRequest(url: URL(string: "wss://example.invalid/voice")!) },
            makeSocket: { _ in
                let socket = sockets[min(next, sockets.count - 1)]
                next += 1
                return socket
            })
    }

    func testOrbRenderForVisualReview() throws {
        for (name, time, energy) in [("orb-rest", 0.0, 0.0), ("orb-speaking", 4.0, 0.8)] {
            let view = Canvas { context, size in
                PulsingOrbView.draw(context: &context, size: size, time: time, energy: energy)
            }.frame(width: 360, height: 360).background(Color.black)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testVoicePanelRenderForVisualReview() async throws {
        let entries = [LiveTranscriptEntry(speaker: .user, text: "What subscriptions renew this week?"),
                       LiveTranscriptEntry(speaker: .assistant, text: "Two services renew this week. Would you like to review them?")]
        let panel = LiveVoicePanel(entries: entries, inputVolume: 0, outputVolume: 0,
                                   isActive: false, microphoneMuted: false,
                                   onToggleMicrophone: {}, onType: {}, onEnd: {})
        let view = VStack { Spacer(); panel; Spacer() }
            .frame(width: 393, height: 760).background(Color.black)
        // ImageRenderer does not render ScrollView's UIKit-backed content. Use a hosted view.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousKey = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 760)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 300_000_000)
        let image = UIGraphicsImageRenderer(size: host.view.bounds.size).image { _ in
            XCTAssertTrue(host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "voice-panel"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testVoicePortfolioExcludesLocalLoginIdentifiers() {
        let owner = UUID()
        let company = Company(userId: owner, name: "Example Co", structure: "LLC")
        let state = AppState()
        state.companies = [company]
        state.institutions = [Institution(userId: owner, companyId: company.id, name: "Example Bank",
                                         username: "private-login", email: "private@example.invalid",
                                         password: "local-only-password")]
        let context = AppViewModel().generateMinifiedPortfolio(appState: state, includeLoginIdentifiers: false)
        XCTAssertTrue(context.contains("Example Bank"))
        XCTAssertFalse(context.contains("private-login"))
        XCTAssertFalse(context.contains("private@example.invalid"))
        XCTAssertFalse(context.contains("local-only-password"))
    }

    func testTranscriptWithoutFinishedFlagsSeparatesOrdinaryTurnsAndBargeIn() {
        var transcript = LiveTranscript()
        transcript.append(LiveTranscription(text: "First question", finished: nil), speaker: .user)
        transcript.append(LiveTranscription(text: "First answer", finished: nil), speaker: .assistant)
        transcript.endTurn()
        transcript.append(LiveTranscription(text: "Second question", finished: nil), speaker: .user)
        transcript.append(LiveTranscription(text: "Second answer", finished: nil), speaker: .assistant)
        transcript.interrupt()
        transcript.append(LiveTranscription(text: "Actually", finished: nil), speaker: .user)
        transcript.endTurn()
        transcript.append(LiveTranscription(text: " stop", finished: nil), speaker: .user)
        XCTAssertEqual(transcript.entries.map(\.text), ["First question", "First answer", "Second question", "Second answer", "Actually stop"])
        XCTAssertTrue(transcript.entries[3].interrupted)
        XCTAssertFalse(transcript.entries[1].interrupted)
    }

    func testMalformedToolArgumentsProduceValidationErrorWithoutLosingSession() throws {
        let json = #"{"id":"one","name":"draftSubscription","args":{"name":null,"cost":"twenty","extra":{"nested":[1,true,null]}}}"#
        let call = try JSONDecoder().decode(FunctionCall.self, from: Data(json.utf8))
        let declaration = FunctionDeclaration(name: "draftSubscription", description: "Draft",
            parameters: Schema(type: "OBJECT", properties: ["name": SchemaProperty(type: "STRING", description: nil),
                                                            "cost": SchemaProperty(type: "NUMBER", description: nil)],
                               required: ["name", "cost"]))
        XCTAssertNotNil(call.validationError(for: declaration))
        XCTAssertNoThrow(try JSONEncoder().encode(call))
    }

    func testWholeNumberFinancialArgumentsKeepTheirValue() throws {
        let call = try JSONDecoder().decode(FunctionCall.self, from: Data(#"{"id":"one","name":"draftSubscription","args":{"cost":25,"fractional":12.5}}"#.utf8))
        XCTAssertEqual(call.args["cost"]?.doubleValue, 25)
        XCTAssertEqual(call.args["fractional"]?.doubleValue, 12.5)
    }

    func testStructuredAuthenticationAndModelErrorsAreTerminal() async {
        for (code, expected) in [(401, LiveFailure.authentication), (403, .modelUnavailable), (404, .modelUnavailable), (400, .setup)] {
            let socket = MockLiveSocket()
            let client = client([socket])
            let connection = Task { try await client.connect() }
            await waitFor { !socket.sent.isEmpty }
            socket.push("{\"error\":{\"code\":\(code),\"message\":\"Test failure\"}}")
            do { try await connection.value; XCTFail("Expected error") }
            catch { XCTAssertEqual(error as? LiveFailure, expected) }
            XCTAssertTrue(socket.closed)
        }
    }

    func testAuthenticatedLiveHandshakeWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["MILOOM_LIVE_INTEGRATION"] == "1" else {
            throw XCTSkip("Enable MILOOM_LIVE_INTEGRATION for the authenticated, metered smoke test.")
        }
        guard (try? await SupabaseService.shared.client.auth.session) != nil else {
            XCTFail("Use a normally signed simulator build and sign in before running the opted-in handshake test.")
            return
        }
        let client = GeminiLiveClient(systemInstruction: "This is an audio connection test. No user data is provided. Respond only with the short phrase requested by the user.", tools: [])
        defer { client.disconnect() }
        let playback = AudioCaptureManager()
        let verifyPlayback = ProcessInfo.processInfo.environment["MILOOM_LIVE_PLAYBACK"] == "1"
        if verifyPlayback {
            let started = await playback.start()
            XCTAssertTrue(started, playback.audioError ?? "Playback engine did not start")
            guard started else { return }
            playback.setInputEnabled(false)
        }
        defer { playback.stop() }
        let audioReceived = expectation(description: "Gemini returns nonempty PCM audio")
        let responseFinished = expectation(description: "Gemini finishes the spoken response")
        let speechPlayed = verifyPlayback ? expectation(description: "Entire Gemini response plays through audio output") : nil
        var receivedAudio = false
        var receivedNonSilentAudio = false
        var turnComplete = false
        var speaking = false
        var playbackFinished = false
        func finishPlaybackIfReady() {
            if receivedAudio && turnComplete && !speaking && !playbackFinished {
                playbackFinished = true
                speechPlayed?.fulfill()
            }
        }
        let playbackSubscription = playback.$isAssistantSpeaking.sink { value in
            speaking = value
            finishPlaybackIfReady()
        }
        defer { playbackSubscription.cancel() }
        let subscription = client.events.sink { event in
            if case .audio(let data) = event, !data.isEmpty {
                receivedNonSilentAudio = receivedNonSilentAudio || data.contains(where: { $0 != 0 })
                if !receivedAudio {
                    receivedAudio = true
                    audioReceived.fulfill()
                }
                if verifyPlayback { playback.schedule(audioData: data) }
            }
            if case .turnComplete = event, !turnComplete {
                turnComplete = true
                responseFinished.fulfill()
                finishPlaybackIfReady()
            }
        }
        defer { subscription.cancel() }
        try await client.connect()
        XCTAssertEqual(client.state.value, .ready)
        client.sendTextMessage("Say: Voice connection verified.")
        await fulfillment(of: [audioReceived, responseFinished], timeout: 20)
        if let speechPlayed { await fulfillment(of: [speechPlayed], timeout: 15) }
        XCTAssertTrue(receivedNonSilentAudio, "Gemini must return speech, not only zero-valued PCM")
    }

    func testSpokenInputIsTranscribedAndAnsweredWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["MILOOM_LIVE_INTEGRATION"] == "1" else {
            throw XCTSkip("Enable MILOOM_LIVE_INTEGRATION for the authenticated spoken-input test.")
        }
        guard (try? await SupabaseService.shared.client.auth.session) != nil else {
            XCTFail("Sign in before running the opted-in spoken-input test.")
            return
        }
        // Synthetic speech only; no user recordings or portfolio context.
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "GeminiSpokenQuestion", withExtension: "wav"))
        let file = try AVAudioFile(forReading: url)
        guard file.length > AVAudioFramePosition(file.processingFormat.sampleRate) else {
            XCTFail("The synthetic speech fixture must contain at least one second of audio")
            return
        }
        let encoder = try LivePCMEncoder(inputFormat: file.processingFormat)
        let frames = AVAudioFrameCount(file.processingFormat.sampleRate * 0.02)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
        let client = GeminiLiveClient(systemInstruction: "Answer the spoken question briefly in English. No user data is provided.", tools: [])
        defer { client.disconnect() }
        let answered = expectation(description: "Gemini answers a spoken question")
        var input = "", output = ""
        var completed = false, nonSilentAudio = false, nonSilentInput = false
        var inputBytes = 0
        let subscription = client.events.sink { event in
            switch event {
            case .inputTranscript(let value): input += value.text ?? ""
            case .outputTranscript(let value): output += value.text ?? ""
            case .audio(let data): nonSilentAudio = nonSilentAudio || data.contains(where: { $0 != 0 })
            case .turnComplete where !completed:
                completed = true
                answered.fulfill()
            default: break
            }
        }
        defer { subscription.cancel() }
        try await client.connect()
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: frames)
            if let chunk = encoder.encode(buffer) {
                inputBytes += chunk.data.count
                nonSilentInput = nonSilentInput || chunk.rms > 0.005
                client.sendAudio(pcmBufferData: chunk.data)
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Keep streaming silence so automatic voice activity detection closes the turn.
        // This mirrors an open microphone; no text prompt or forced turn completion.
        for _ in 0..<75 {
            client.sendAudio(pcmBufferData: Data(repeating: 0, count: 640))
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        await fulfillment(of: [answered], timeout: 20)
        XCTAssertTrue(nonSilentInput, "The production encoder must retain speech energy")
        let expectedBytes = Double(file.length) / file.processingFormat.sampleRate * 32000
        XCTAssertEqual(Double(inputBytes), expectedBytes, accuracy: 1280, "Resampling must preserve duration")
        XCTAssertTrue(input.lowercased().contains("two") || input.contains("2"), "Gemini must transcribe the synthetic spoken question; received: \(input)")
        XCTAssertTrue(output.lowercased().contains("four") || output.contains("4"), "Gemini must correctly answer the synthetic spoken question; received: \(output)")
        XCTAssertTrue(nonSilentAudio, "Gemini must return a spoken answer")
    }

    func testSetupUses38AndBlockingToolsWithoutChangingRESTDeclarations() throws {
        let declaration = FunctionDeclaration(name: "draftCompany", description: "Draft", parameters: nil)
        let original = Tool(functionDeclarations: [declaration])
        let setup = GeminiLiveClient.setup(instruction: "Test", tools: [original], handle: "resume-1")
        let json = try object(setup)
        XCTAssertEqual(json["model"] as? String, "models/gemini-3.8-live")
        XCTAssertNotNil(json["inputAudioTranscription"])
        XCTAssertNotNil(json["outputAudioTranscription"])
        XCTAssertNotNil(json["contextWindowCompression"])
        XCTAssertEqual((json["sessionResumption"] as? [String: Any])?["handle"] as? String, "resume-1")
        XCTAssertNil((json["generationConfig"] as? [String: Any])?["thinkingConfig"])
        XCTAssertEqual(setup.tools?.first?.functionDeclarations.first?.behavior, "BLOCKING")
        XCTAssertNil(try object(declaration)["behavior"])
    }

    func testTextTurnWaitsForSetupAndRequestsSpokenResponse() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        client.sendTextMessage("Too early")
        XCTAssertTrue(socket.sent.isEmpty)
        let connection = Task { try await client.connect() }
        await waitFor { !socket.sent.isEmpty }
        client.sendTextMessage("Still too early")
        XCTAssertEqual(socket.sent.count, 1)
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        client.sendTextMessage("Hello")
        await waitFor { socket.sent.count == 2 }
        let message = try JSONDecoder().decode(ClientMessage.self, from: JSONSerialization.data(withJSONObject: socket.sent[1]))
        XCTAssertEqual(message.clientContent?.turns.first?.role, "user")
        XCTAssertEqual(message.clientContent?.turns.first?.parts.first?.text, "Hello")
        XCTAssertEqual(message.clientContent?.turnComplete, true)
        client.disconnect()
    }

    func testAudioEngineCaptureAndPlaybackWhenOptedIn() async throws {
        guard ProcessInfo.processInfo.environment["MILOOM_LIVE_INTEGRATION"] == "1" else {
            throw XCTSkip("Enable MILOOM_LIVE_INTEGRATION for microphone and playback verification.")
        }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw XCTSkip("Grant microphone permission in Miloom before this audio-engine check.")
        }
        let manager = AudioCaptureManager()
        defer { manager.stop() }
        let captured = expectation(description: "Microphone delivers converted PCM buffers")
        var hasCaptured = false
        let capture = manager.audioDataPublisher.sink { data in
            if !data.isEmpty && !hasCaptured {
                hasCaptured = true
                captured.fulfill()
            }
        }
        defer { capture.cancel() }
        let started = await manager.start()
        XCTAssertTrue(started, manager.audioError ?? "Audio engine did not start")
        guard started else { return }
        manager.setInputEnabled(true)
        await fulfillment(of: [captured], timeout: 5)
        manager.setInputEnabled(false)
        // Verify scheduling and completion without playing a test tone aloud.
        let played = expectation(description: "Playback reaches the audio device")
        var hasScheduled = false
        let playback = manager.$isAssistantSpeaking.sink { speaking in
            if speaking { hasScheduled = true }
            else if hasScheduled { hasScheduled = false; played.fulfill() }
        }
        defer { playback.cancel() }
        manager.schedule(audioData: Data(repeating: 0, count: 12_000))
        await fulfillment(of: [played], timeout: 5)
    }

    func testMicrophoneWaitsForSetupAndUsesAudioField() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { socket.sent.count == 1 }
        client.sendAudio(pcmBufferData: Data([1, 0]))
        XCTAssertEqual(socket.sent.count, 1)
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        client.sendAudio(pcmBufferData: Data([1, 0]))
        await waitFor { socket.sent.count == 2 }
        let audio = try XCTUnwrap(socket.sent.last?["realtimeInput"] as? [String: Any])
        XCTAssertNil(audio["mediaChunks"])
        XCTAssertEqual((audio["audio"] as? [String: Any])?["mimeType"] as? String, "audio/pcm;rate=16000")
    }

    func testMixedMessagesEmitBothTranscriptsAndEveryAudioPart() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        var chunks: [Data] = []
        var input = "", output = ""
        client.events.sink { event in
            switch event {
            case .audio(let data): chunks.append(data)
            case .inputTranscript(let value): input += value.text ?? ""
            case .outputTranscript(let value): output += value.text ?? ""
            default: break
            }
        }.store(in: &subscriptions)
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { !socket.sent.isEmpty }
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        socket.push(#"{"serverContent":{"inputTranscription":{"text":"Hello","finished":true},"outputTranscription":{"text":"Hi"},"modelTurn":{"parts":[{"text":"not a spoken transcript"},{"inlineData":{"mimeType":"audio/pcm;rate=24000","data":"AQA="}},{"inlineData":{"mimeType":"audio/pcm;rate=24000","data":"AgA="}}]}}}"#)
        await waitFor { chunks.count == 2 }
        XCTAssertEqual(input, "Hello")
        XCTAssertEqual(output, "Hi")
        XCTAssertEqual(chunks, [Data([1, 0]), Data([2, 0])])
    }

    func testInterruptionDiscardsAudioInSameEventAndStillCompletesTurn() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        var interrupted = false, complete = false, audioCount = 0
        client.events.sink { event in
            switch event {
            case .interrupted: interrupted = true
            case .turnComplete: complete = true
            case .audio: audioCount += 1
            default: break
            }
        }.store(in: &subscriptions)
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { !socket.sent.isEmpty }
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        socket.push(#"{"serverContent":{"interrupted":true,"turnComplete":true,"modelTurn":{"parts":[{"inlineData":{"mimeType":"audio/pcm","data":"AQA="}}]}}}"#)
        await waitFor { complete }
        XCTAssertTrue(interrupted)
        XCTAssertEqual(audioCount, 0)
    }

    func testTranscriptAndInterruptionInSameMessagePreserveSpeakerBoundaries() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        var transcript = LiveTranscript()
        client.events.sink { event in
            switch event {
            case .inputTranscript(let value): transcript.append(value, speaker: .user)
            case .outputTranscript(let value): transcript.append(value, speaker: .assistant)
            case .interrupted: transcript.interrupt()
            case .turnComplete: transcript.endTurn()
            default: break
            }
        }.store(in: &subscriptions)
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { !socket.sent.isEmpty }
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        socket.push(#"{"serverContent":{"outputTranscription":{"text":"Previous response"},"interrupted":true,"inputTranscription":{"text":"Stop"},"turnComplete":true}}"#)
        await waitFor { transcript.entries.count == 2 }
        XCTAssertEqual(transcript.entries[0].text, "Previous response")
        XCTAssertTrue(transcript.entries[0].interrupted)
        XCTAssertEqual(transcript.entries[1].speaker, .user)
        XCTAssertEqual(transcript.entries[1].text, "Stop")
    }

    func testResumeRetainsHandleWithoutReplayingCapturedAudio() async throws {
        let first = MockLiveSocket(), second = MockLiveSocket()
        let client = client([first, second])
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { !first.sent.isEmpty }
        first.push(#"{"setupComplete":{}}"#)
        try await connection.value
        first.push(#"{"sessionResumptionUpdate":{"newHandle":"retained","resumable":true}}"#)
        first.push(#"{"sessionResumptionUpdate":{"resumable":false}}"#)
        first.push(#"{"goAway":{"timeLeft":"1s"}}"#)
        await waitFor { !second.sent.isEmpty }
        let setup = try XCTUnwrap(second.sent.first?["setup"] as? [String: Any])
        XCTAssertEqual((setup["sessionResumption"] as? [String: Any])?["handle"] as? String, "retained")
        XCTAssertEqual(client.state.value, .reconnecting)
        client.sendAudio(pcmBufferData: Data([1, 0]))
        second.push(#"{"setupComplete":{}}"#)
        await waitFor { client.state.value == .ready }
        XCTAssertEqual(second.sent.count, 1)
    }

    func testTransientFailuresStopAfterFiveReconnectAttempts() async {
        let sockets = (0..<6).map { _ in MockLiveSocket() }
        let client = client(sockets)
        let connection = Task { try await client.connect() }
        for socket in sockets {
            await waitFor { !socket.sent.isEmpty }
            socket.close()
        }
        do { try await connection.value; XCTFail("Expected retry exhaustion") }
        catch { XCTAssertEqual(error as? LiveFailure, .disconnected) }
        XCTAssertEqual(client.state.value, .failed(.disconnected))
        XCTAssertTrue(sockets.allSatisfy(\.closed))
    }

    func testEndingDuringReconnectPreventsAnotherSocket() async throws {
        let first = MockLiveSocket(), second = MockLiveSocket()
        let client = client([first, second], retryDelay: 50_000_000)
        let connection = Task { try await client.connect() }
        await waitFor { !first.sent.isEmpty }
        first.close()
        await waitFor { client.state.value == .reconnecting }
        client.disconnect()
        do { try await connection.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(second.sent.isEmpty)
        XCTAssertEqual(client.state.value, .idle)
    }

    func testMissingResumeHandleRequiresExplicitRestart() async throws {
        let socket = MockLiveSocket()
        let client = client([socket])
        let connection = Task { try await client.connect() }
        defer { client.disconnect() }
        await waitFor { !socket.sent.isEmpty }
        socket.push(#"{"setupComplete":{}}"#)
        try await connection.value
        socket.push(#"{"goAway":{"timeLeft":"1s"}}"#)
        await waitFor { client.state.value == .failed(.disconnected) }
        XCTAssertTrue(socket.closed)
    }

    func testQuotaErrorDoesNotReconnect() async {
        let socket = MockLiveSocket()
        let client = client([socket])
        let connection = Task { try await client.connect() }
        await waitFor { !socket.sent.isEmpty }
        socket.push(#"{"error":"MILOOM_LIMIT:voice_seconds"}"#)
        do { try await connection.value; XCTFail("Expected allowance error") }
        catch { XCTAssertEqual(error as? LiveFailure, .allowance) }
        XCTAssertEqual(client.state.value, .failed(.allowance))
        XCTAssertTrue(socket.closed)
    }

    func testSetupTimeoutClosesSocketAndEndingCancelsPendingSetup() async {
        let socket = MockLiveSocket()
        let client = client([socket], timeout: 20_000_000)
        do { try await client.connect(); XCTFail("Expected setup timeout") }
        catch { XCTAssertEqual(error as? LiveFailure, .timeout) }
        XCTAssertTrue(socket.closed)
        let second = MockLiveSocket()
        let other = self.client([second])
        let connection = Task { try await other.connect() }
        await waitFor { !second.sent.isEmpty }
        other.disconnect()
        do { try await connection.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(other.state.value, .idle)
    }

    func testToolsQueueConfirmationsDeduplicatesAndCancels() {
        var queue = LiveToolQueue()
        XCTAssertTrue(queue.enqueue([tool("one"), tool("two"), tool("one")]).isEmpty)
        XCTAssertEqual(queue.next()?.id, "one")
        XCTAssertNil(queue.next())
        XCTAssertTrue(queue.enqueue([tool("one")]).isEmpty)
        queue.finish(response("one"))
        XCTAssertEqual(queue.enqueue([tool("one")]).first?.id, "one")
        XCTAssertEqual(queue.next()?.id, "two")
        queue.cancel(["two"])
        XCTAssertNil(queue.active)
        XCTAssertTrue(queue.enqueue([tool("two")]).isEmpty)
        XCTAssertNil(queue.next())
    }

    func testTranscriptHandlesIndependentSpeakersAndInterruptedTurns() {
        var transcript = LiveTranscript()
        transcript.append(LiveTranscription(text: "Hello", finished: false), speaker: .user)
        transcript.append(LiveTranscription(text: "Hi", finished: false), speaker: .assistant)
        transcript.append(LiveTranscription(text: " there", finished: true), speaker: .user)
        transcript.append(LiveTranscription(text: "!", finished: true), speaker: .assistant)
        transcript.interrupt()
        transcript.endTurn()
        transcript.append(LiveTranscription(text: "Next", finished: true), speaker: .assistant)
        XCTAssertEqual(transcript.entries.map(\.text), ["Hello there", "Hi!", "Next"])
        XCTAssertTrue(transcript.entries[1].interrupted)
        XCTAssertFalse(transcript.entries[2].interrupted)
    }

    func testPrivacyPauseInvalidatesPreviouslyCapturedBuffers() throws {
        let gate = LiveCaptureGate()
        XCTAssertNil(gate.token())
        gate.setEnabled(true)
        let before = try XCTUnwrap(gate.token())
        XCTAssertTrue(gate.accepts(before))
        gate.setEnabled(false)
        XCTAssertFalse(gate.accepts(before))
        gate.setEnabled(true)
        XCTAssertFalse(gate.accepts(before))
        XCTAssertTrue(gate.accepts(try XCTUnwrap(gate.token())))
    }
}

@MainActor
private final class MockLiveSocket: LiveSocket {
    var statusCode: Int? = 101
    var sent: [[String: Any]] = []
    var closed = false
    private var messages: [Data] = []
    private var receiver: CheckedContinuation<Data, Error>?
    func resume() {}
    func send(_ text: String) async throws {
        sent.append(try JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any])
    }
    func receive() async throws -> Data {
        if !messages.isEmpty { return messages.removeFirst() }
        if closed { throw URLError(.networkConnectionLost) }
        return try await withCheckedThrowingContinuation { receiver = $0 }
    }
    func push(_ text: String) {
        let data = Data(text.utf8)
        if let receiver { self.receiver = nil; receiver.resume(returning: data) }
        else { messages.append(data) }
    }
    func ping() async throws {}
    func close() {
        closed = true
        receiver?.resume(throwing: CancellationError())
        receiver = nil
    }
}
