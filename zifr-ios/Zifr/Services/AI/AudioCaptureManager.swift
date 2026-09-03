import Foundation
import AVFoundation
import Combine

class AudioCaptureManager: ObservableObject {
    let audioDataPublisher = PassthroughSubject<Data, Never>()
    @Published var volume: Float = 0.0
    @Published var permissionDenied: Bool = false
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    private var isRecording = false
    
    // Half-duplex: mute mic while assistant speaks to prevent echo feedback
    private var isMuted = false
    private var unmuteTimer: Timer?
    @Published var isAssistantSpeaking = false
    
    func start() async {
        guard !isRecording else { return }
        
        let session = AVAudioSession.sharedInstance()
        
        // Request microphone permission
        let granted: Bool = await withCheckedContinuation { continuation in
            session.requestRecordPermission { response in
                continuation.resume(returning: response)
            }
        }
        
        guard granted else {
            AppDiagnostics.event("audio", "microphone_permission", status: "denied")
            permissionDenied = true
            return
        }
        
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            AppDiagnostics.failure("audio", "capture_session_setup", error: error)
            return
        }
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Gemini Live requires 16kHz PCM16 for input
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false) else {
            AppDiagnostics.failure("audio", "capture_output_format")
            return
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            AppDiagnostics.failure("audio", "capture_converter")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Calculate Volume for the Orb
            self.calculateVolume(buffer: buffer)
            
            // Convert to 16kHz
            let capacity = AVAudioFrameCount(outputFormat.sampleRate * 0.1) // 100ms
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
            
            var error: NSError? = nil
            class Context { var allDone = false }
            let ctx = Context()
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if ctx.allDone {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                ctx.allDone = true
                outStatus.pointee = .haveData
                return buffer
            }
            
            let status = converter.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
            
            if status == .haveData || status == .endOfStream, let channelData = pcmBuffer.int16ChannelData {
                let dataSize = Int(pcmBuffer.frameLength) * MemoryLayout<Int16>.size
                let data: Data
                
                // If muted (assistant is speaking), send pure silence to keep the WebSocket 
                // alive without triggering Gemini's Voice Activity Detection echo.
                if self.isMuted {
                    data = Data(count: dataSize) // Zero-filled buffer
                } else {
                    data = Data(bytes: channelData[0], count: dataSize)
                }
                
                self.audioDataPublisher.send(data)
            }
        }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
        
        engine.prepare()
        do {
            try engine.start()
            playerNode.play()
            isRecording = true
        } catch {
            AppDiagnostics.failure("audio", "capture_engine_start", error: error)
        }
    }
    
    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        engine.stop()
        isRecording = false
        unmuteTimer?.invalidate()
        unmuteTimer = nil
    }
    
    func schedule(audioData: Data) {
        // Mute mic while we play assistant audio to prevent echo
        muteInput()
        
        let frameCount = UInt32(audioData.count / MemoryLayout<Int16>.size)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        audioData.withUnsafeBytes { bufferPointer in
            guard let pointer = bufferPointer.bindMemory(to: Int16.self).baseAddress else { return }
            pcmBuffer.int16ChannelData?[0].update(from: pointer, count: Int(frameCount))
        }
        
        playerNode.scheduleBuffer(pcmBuffer)
    }
    
    // MARK: - Half-Duplex Mic Control
    
    /// Mutes the microphone input stream to Gemini.
    /// Each call resets the unmute timer so the mic stays muted while audio chunks keep arriving.
    private func muteInput() {
        isMuted = true
        DispatchQueue.main.async {
            self.isAssistantSpeaking = true
            self.unmuteTimer?.invalidate()
            self.unmuteTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.isMuted = false
                self?.isAssistantSpeaking = false
            }
        }
    }
    
    private func calculateVolume(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frames = buffer.frameLength
        
        var rms: Float = 0.0
        for i in 0..<Int(frames) {
            let sample = channelData[i]
            rms += sample * sample
        }
        rms = sqrt(rms / Float(frames))
        
        // Normalize to 0-1 range roughly, applying a multiplier to make the pulse more visible
        let normalizedVolume = min(max((rms * 15.0), 0.0), 1.0)
        
        DispatchQueue.main.async {
            // Apply smoothing
            self.volume = (self.volume * 0.8) + (normalizedVolume * 0.2)
        }
    }
}
