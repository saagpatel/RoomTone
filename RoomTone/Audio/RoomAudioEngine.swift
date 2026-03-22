import AVFoundation
import os

@Observable
final class RoomAudioEngine {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var sourceNode: AVAudioSourceNode?

    private let logger = Logger(subsystem: "com.roomtone.app", category: "AudioEngine")

    var isRunning: Bool { engine.isRunning }

    init() {
        configureAudioSession()
        setupGraph()
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
            logger.info("Audio engine started")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.stop()
        logger.info("Audio engine stopped")
    }

    // MARK: - Private

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            logger.info("Audio session configured: .playback")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    private func setupGraph() {
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = Float(outputFormat.sampleRate)

        engine.attach(mixer)

        // Phase accumulator — lives outside the closure, accessed only by the audio thread.
        // Using UnsafeMutablePointer for zero-overhead, lock-free access.
        let phasePointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        phasePointer.initialize(to: 0.0)

        let frequency: Float = 440.0
        let amplitude: Float = 0.3
        let twoPi = Float.pi * 2.0

        let source = AVAudioSourceNode(format: outputFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let phaseIncrement = twoPi * frequency / sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = amplitude * sin(phasePointer.pointee)
                phasePointer.pointee += phaseIncrement

                // Wrap phase to prevent float precision loss over time
                if phasePointer.pointee >= twoPi {
                    phasePointer.pointee -= twoPi
                }

                for buffer in bufferListPointer {
                    guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                    data[frame] = sample
                }
            }

            return noErr
        }

        engine.attach(source)
        engine.connect(source, to: mixer, format: outputFormat)
        engine.connect(mixer, to: engine.outputNode, format: outputFormat)
        engine.prepare()

        sourceNode = source

        logger.info("Audio graph configured: source(\(frequency)Hz) → mixer → output @ \(sampleRate)Hz")
    }
}
