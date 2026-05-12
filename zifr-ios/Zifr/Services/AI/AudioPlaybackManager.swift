import Foundation
import AVFoundation

class AudioPlaybackManager: ObservableObject {
    @Published var volume: Float = 0
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    // Gemini Live responds with 24kHz PCM16 data
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
    private var isSetup = false
    
    init() {}
    
    func start() {
        if !isSetup {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            isSetup = true
        }
        try? engine.start()
        playerNode.play()
    }
    
    func schedule(audioData: Data) {
        let frameCount = UInt32(audioData.count / MemoryLayout<Int16>.size)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Compute volume (peak amplitude) for UI feedback
        var maxAmplitude: Int16 = 0
        audioData.withUnsafeBytes { bufferPointer in
            let ptr = bufferPointer.bindMemory(to: Int16.self).baseAddress!
            for i in 0..<Int(frameCount) {
                let sample = ptr[i]
                let absVal = sample >= 0 ? sample : -sample
                if absVal > maxAmplitude { maxAmplitude = absVal }
            }
        }
        let normalized = Float(maxAmplitude) / Float(Int16.max)
        DispatchQueue.main.async { self.volume = normalized }
        
        audioData.withUnsafeBytes { bufferPointer in
            guard let pointer = bufferPointer.bindMemory(to: Int16.self).baseAddress else { return }
            pcmBuffer.int16ChannelData?[0].update(from: pointer, count: Int(frameCount))
        }
        
        playerNode.scheduleBuffer(pcmBuffer)
    }
    
    func stop() {
        playerNode.stop()
        engine.stop()
    }
}
