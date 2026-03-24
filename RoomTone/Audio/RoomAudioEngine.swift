import AVFoundation
import os

@Observable
final class RoomAudioEngine {
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var oscillatorBank: OscillatorBank?
    private var timbreProcessor: TimbreProcessor?
    private(set) var recorder: AudioRecorder?
    private var fadeTimer: Timer?

    private let logger = Logger(subsystem: "com.roomtone.app", category: "AudioEngine")

    var isRunning: Bool { engine.isRunning }

    /// Whether the audio graph has been configured with room dimensions.
    var isConfigured: Bool { oscillatorBank != nil }

    init() {
        configureAudioSession()
    }

    // MARK: - Lifecycle

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
        fadeTimer?.invalidate()
        fadeTimer = nil
        guard engine.isRunning else { return }
        engine.stop()
        logger.info("Audio engine stopped")
    }

    // MARK: - Configuration

    /// Build the full audio graph and configure for the given room.
    /// Safe to call once. Subsequent dimension changes should use updateForNewDimensions().
    func configure(dimensions: RoomDimensions, modes: [RoomMode]) {
        // Guard against double-configure — attaching already-attached nodes crashes AVAudioEngine
        guard !isConfigured else {
            updateForNewDimensions(dimensions: dimensions, modes: modes)
            return
        }

        let outputFormat = engine.outputNode.inputFormat(forBus: 0)

        // Create components
        let bank = OscillatorBank(format: outputFormat)
        let timbre = TimbreProcessor()
        let rec = AudioRecorder(engine: engine)

        // Attach nodes
        engine.attach(mixer)
        engine.attach(timbre.timePitchNode)
        engine.attach(timbre.reverbNode)

        for node in bank.sourceNodes {
            engine.attach(node)
            engine.connect(node, to: mixer, format: outputFormat)
        }

        // Wire graph: mixer → timePitch → reverb → output
        engine.connect(mixer, to: timbre.timePitchNode, format: outputFormat)
        engine.connect(timbre.timePitchNode, to: timbre.reverbNode, format: outputFormat)
        engine.connect(timbre.reverbNode, to: engine.outputNode, format: outputFormat)

        engine.prepare()

        // Configure
        bank.configure(modes: modes)
        timbre.configure(oscillatorBank: bank, mixer: mixer)
        timbre.configureReverb(rt60: dimensions.estimatedRT60)

        // Store references
        oscillatorBank = bank
        timbreProcessor = timbre
        recorder = rec

        logger.info("Audio graph configured: \(modes.count) modes, RT60=\(dimensions.estimatedRT60)s")
    }

    // MARK: - Controls

    /// Update per-oscillator amplitudes from RoomModel calculation.
    func updateAmplitudes(_ amplitudes: [Float]) {
        oscillatorBank?.setAmplitudes(amplitudes)
    }

    /// Switch between Drone and Ambient timbre.
    func setTimbre(_ timbre: AudioTimbre) {
        timbreProcessor?.setTimbre(timbre)
    }

    /// Set mixer volume directly (used for scan-progress audio fade).
    func setVolume(_ volume: Float) {
        mixer.volume = max(0.0, min(1.0, volume))
    }

    /// Update oscillator frequencies and reverb without rebuilding the audio graph.
    /// Use for live dimension refinement after initial configure().
    func updateForNewDimensions(dimensions: RoomDimensions, modes: [RoomMode]) {
        oscillatorBank?.configure(modes: modes)
        timbreProcessor?.configureReverb(rt60: dimensions.estimatedRT60)
        logger.info("Dimensions updated in-place: \(modes.count) modes, RT60=\(dimensions.estimatedRT60)s")
    }

    /// Start the engine and fade mixer volume from 0 to 1 over duration.
    func startWithFadeIn(duration: TimeInterval = 3.0) {
        fadeTimer?.invalidate()
        mixer.volume = 0.0
        start()

        let steps = 60
        let interval = duration / Double(steps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.mixer.volume = progress
            if currentStep >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                self?.mixer.volume = 1.0
            }
        }
    }

    /// Fade out and stop the engine.
    func stopWithFadeOut(duration: TimeInterval = 0.5) {
        fadeTimer?.invalidate()

        let steps = 15
        let interval = duration / Double(steps)
        var currentStep = 0
        let startVolume = mixer.volume

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            self?.mixer.volume = startVolume * (1.0 - progress)
            if currentStep >= steps {
                timer.invalidate()
                self?.fadeTimer = nil
                self?.stop()
            }
        }
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
}
