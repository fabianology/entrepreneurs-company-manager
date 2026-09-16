import Foundation
import AVFoundation
import Combine

/// Tokens invalidate audio captured before a mute, route change, or local secure speech.
final class LiveCaptureGate: @unchecked Sendable {
    private let lock = NSLock()
    private var epoch = UUID()
    private var enabled = false
    func setEnabled(_ enabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        self.enabled = enabled
        epoch = UUID()
    }
    func token() -> UUID? {
        lock.lock(); defer { lock.unlock() }
        return enabled ? epoch : nil
    }
    func accepts(_ token: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return enabled && token == epoch
    }
}

@MainActor
final class AudioCaptureManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let audioDataPublisher = PassthroughSubject<Data, Never>()
    @Published private(set) var volume: Float = 0
    @Published private(set) var outputVolume: Float = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var isAssistantSpeaking = false
    @Published private(set) var isReadingSecureField = false
    @Published private(set) var audioError: String?
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private let playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
    private let captureGate = LiveCaptureGate()
    private let synthesizer = AVSpeechSynthesizer()
    private var startGeneration = UUID()
    private var playbackGeneration = UUID()
    private var playbackLevels: [Float] = []
    private var requestedInput = false
    private var secureUtterance: AVSpeechUtterance?
    private var secureGeneration = UUID()
    private var secureCompletion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func setInputEnabled(_ enabled: Bool) {
        requestedInput = enabled
        captureGate.setEnabled(enabled && engine != nil && !isReadingSecureField)
        if !enabled { volume = 0 }
    }

    @discardableResult
    func start() async -> Bool {
        guard !isReadingSecureField else { return false }
        if let engine, engine.isRunning { return true }
        let id = UUID()
        startGeneration = id
        let audioSession = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard id == startGeneration, !Task.isCancelled else { return false }
        permissionDenied = !granted
        guard granted else { return false }
        audioError = nil
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            let newEngine = AVAudioEngine()
            let newPlayer = AVAudioPlayerNode()
            let input = newEngine.inputNode
            // Acoustic echo cancellation is required for an open mic during assistant playback.
            try input.setVoiceProcessingEnabled(true)
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0,
                  let pcm16 = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false),
                  let converter = AVAudioConverter(from: inputFormat, to: pcm16) else { throw LiveFailure.audio }
            let gate = captureGate
            input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let token = gate.token() else { return }
                let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / inputFormat.sampleRate)) + 32
                guard let output = AVAudioPCMBuffer(pcmFormat: pcm16, frameCapacity: capacity) else { return }
                var supplied = false
                var error: NSError?
                converter.convert(to: output, error: &error) { _, status in
                    if supplied { status.pointee = .noDataNow; return nil }
                    supplied = true
                    status.pointee = .haveData
                    return buffer
                }
                guard error == nil, output.frameLength > 0, let samples = output.int16ChannelData?[0] else { return }
                let count = Int(output.frameLength)
                let data = Data(bytes: samples, count: count * 2)
                var squares: Float = 0
                for i in 0..<count { let v = Float(samples[i]) / 32768; squares += v * v }
                let level = min(1, sqrt(squares / Float(count)) * 9)
                Task { @MainActor [weak self] in
                    guard let self, gate.accepts(token) else { return }
                    volume = volume * 0.65 + level * 0.35
                    audioDataPublisher.send(data)
                }
            }
            newEngine.attach(newPlayer)
            newEngine.connect(newPlayer, to: newEngine.mainMixerNode, format: playbackFormat)
            newEngine.prepare()
            try newEngine.start()
            newPlayer.play()
            engine = newEngine
            player = newPlayer
            captureGate.setEnabled(requestedInput)
            return true
        } catch {
            stop()
            audioError = LiveFailure.audio.localizedDescription
            AppDiagnostics.event("audio", "live_engine", status: "failed")
            return false
        }
    }

    func stop() {
        startGeneration = UUID()
        captureGate.setEnabled(false)
        interruptPlayback()
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        player = nil
        volume = 0
    }

    func interruptPlayback() {
        playbackGeneration = UUID()
        playbackLevels.removeAll()
        player?.stop()
        if engine?.isRunning == true { player?.play() }
        isAssistantSpeaking = false
        outputVolume = 0
    }

    func schedule(audioData: Data) {
        guard !isReadingSecureField, engine?.isRunning == true, let player,
              !audioData.isEmpty, audioData.count % 2 == 0 else { return }
        let frames = audioData.count / 2
        guard let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frames)),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        var squares: Float = 0
        audioData.withUnsafeBytes { bytes in
            for i in 0..<frames {
                let raw = bytes.loadUnaligned(fromByteOffset: i * 2, as: Int16.self)
                let value = Float(Int16(littleEndian: raw)) / 32768
                samples[i] = value
                squares += value * value
            }
        }
        let level = min(1, sqrt(squares / Float(frames)) * 7)
        playbackLevels.append(level)
        if playbackLevels.count == 1 { outputVolume = level }
        isAssistantSpeaking = true
        let id = playbackGeneration
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, playbackGeneration == id else { return }
                if !playbackLevels.isEmpty { playbackLevels.removeFirst() }
                if let next = playbackLevels.first { outputVolume = outputVolume * 0.4 + next * 0.6 }
                else { isAssistantSpeaking = false; outputVolume = 0 }
            }
        }
    }

    /// The value never enters the network client, transcript, or diagnostics.
    func speakSecurely(_ value: String, completion: @escaping () -> Void) {
        stop()
        isReadingSecureField = true
        secureCompletion = completion
        secureGeneration = UUID()
        let utterance = AVSpeechUtterance(string: value)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        secureUtterance = utterance
        synthesizer.speak(utterance)
    }

    func cancelSecureSpeech() {
        secureCompletion = nil
        secureUtterance = nil
        secureGeneration = UUID()
        synthesizer.stopSpeaking(at: .immediate)
        isReadingSecureField = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishSecureSpeech(utterance) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.finishSecureSpeech(utterance) }
    }
    private func finishSecureSpeech(_ utterance: AVSpeechUtterance) {
        guard secureUtterance === utterance else { return }
        secureUtterance = nil
        let id = secureGeneration
        // Let the speaker's acoustic tail decay before reopening the microphone.
        let completion = secureCompletion
        secureCompletion = nil
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, isReadingSecureField, id == secureGeneration else { return }
            isReadingSecureField = false
            completion?()
        }
    }
}
