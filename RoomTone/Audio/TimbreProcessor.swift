import AVFoundation
import os

/// Manages timbre switching between Drone and Ambient modes.
///
/// Graph position: OscillatorBank → Mixer → TimePitch → Reverb → OutputNode
/// - Drone: TimePitch bypassed, OscillatorBank drone harmonics enabled
/// - Ambient: TimePitch active (rate=0.85, overlap=8), pure sine from oscillators
final class TimbreProcessor {
    let timePitchNode = AVAudioUnitTimePitch()
    let reverbNode = AVAudioUnitReverb()

    private weak var oscillatorBank: OscillatorBank?
    private weak var mixer: AVAudioMixerNode?
    private let logger = Logger(subsystem: "com.roomtone.app", category: "TimbreProcessor")

    private var isCrossfading = false

    init() {
        // Ambient timbre settings (active when not bypassed)
        timePitchNode.pitch = 0
        timePitchNode.rate = 0.85
        timePitchNode.overlap = 8

        // Start in Drone mode: TimePitch bypassed
        timePitchNode.bypass = true

        // Reverb defaults
        reverbNode.loadFactoryPreset(.mediumRoom)
        reverbNode.wetDryMix = 30
    }

    /// Wire dependencies after graph is built.
    func configure(oscillatorBank: OscillatorBank, mixer: AVAudioMixerNode) {
        self.oscillatorBank = oscillatorBank
        self.mixer = mixer
    }

    /// Set reverb wetDryMix based on RT60 estimate.
    /// Maps RT60 to wetDryMix: typical bedroom (~0.5s) → 20%, large hall (~1.5s) → 60%.
    func configureReverb(rt60: Float) {
        let wetDryMix = min(70.0, max(20.0, rt60 * 40.0))
        reverbNode.wetDryMix = wetDryMix
        logger.info("Reverb configured: RT60=\(rt60)s → wetDryMix=\(wetDryMix)%")
    }

    /// Switch timbre with 80ms crossfade (40ms down + toggle + 40ms up).
    func setTimbre(_ timbre: AudioTimbre) {
        guard let mixer, !isCrossfading else { return }
        isCrossfading = true

        let isDrone = timbre == .drone

        // Fade out over 40ms
        let fadeOutDuration = 0.04
        let savedVolume = mixer.volume

        // Ramp down
        mixer.volume = 0.0

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) { [weak self] in
            guard let self else { return }

            // Toggle timbre at silence
            self.timePitchNode.bypass = isDrone
            self.oscillatorBank?.setDroneEnabled(isDrone)

            // Fade back in over 40ms
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                mixer.volume = savedVolume
                self.isCrossfading = false
                self.logger.info("Timbre switched to \(isDrone ? "Drone" : "Ambient")")
            }
        }
    }
}
