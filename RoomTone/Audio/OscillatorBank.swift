import AVFoundation
import os

/// Manages 16 AVAudioSourceNode oscillators with lock-free amplitude updates.
///
/// Thread safety: the audio thread reads from `currentAmplitudes` without locking.
/// The main thread writes to `pendingAmplitudes` and swaps the pointers under `os_unfair_lock`.
/// The lock is NEVER held during a render callback.
final class OscillatorBank {
    static let oscillatorCount = 16

    private let logger = Logger(subsystem: "com.roomtone.app", category: "OscillatorBank")

    // MARK: - Audio nodes

    private(set) var sourceNodes: [AVAudioSourceNode] = []

    // MARK: - Per-oscillator state (audio thread only, pre-allocated)

    /// Contiguous block of per-oscillator state accessed ONLY by the audio thread.
    /// Layout per oscillator: [phase, harmonicPhase, lfoPhase, frequency, amplitude, droneEnabled]
    /// Total floats: oscillatorCount * stridePerOscillator
    private static let stridePerOscillator = 6
    private let stateBuffer: UnsafeMutablePointer<Float>

    // Offsets within each oscillator's stride
    private static let phaseOffset = 0
    private static let harmonicPhaseOffset = 1
    private static let lfoPhaseOffset = 2
    private static let frequencyOffset = 3
    private static let amplitudeOffset = 4
    private static let droneEnabledOffset = 5

    // MARK: - Double-buffer for amplitude updates

    private let bufferA: UnsafeMutablePointer<Float>
    private let bufferB: UnsafeMutablePointer<Float>
    private var currentAmplitudes: UnsafeMutablePointer<Float>
    private var pendingAmplitudes: UnsafeMutablePointer<Float>
    private var swapLock = os_unfair_lock()

    // MARK: - Init

    init(format: AVAudioFormat) {
        let count = Self.oscillatorCount

        // Pre-allocate per-oscillator state
        stateBuffer = .allocate(capacity: count * Self.stridePerOscillator)
        stateBuffer.initialize(repeating: 0.0, count: count * Self.stridePerOscillator)

        // Set droneEnabled = 1.0 (on) by default
        for i in 0..<count {
            stateBuffer[i * Self.stridePerOscillator + Self.droneEnabledOffset] = 1.0
        }

        // Pre-allocate double buffers
        bufferA = .allocate(capacity: count)
        bufferA.initialize(repeating: 0.0, count: count)
        bufferB = .allocate(capacity: count)
        bufferB.initialize(repeating: 0.0, count: count)
        currentAmplitudes = bufferA
        pendingAmplitudes = bufferB

        // Create 16 source nodes
        let sampleRate = Float(format.sampleRate)
        let twoPi = Float.pi * 2.0
        let state = stateBuffer
        let current = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: 1)
        current.initialize(to: bufferA)
        self.currentAmplitudesIndirect = current

        for i in 0..<count {
            let baseOffset = i * Self.stridePerOscillator
            let oscillatorIndex = i
            let amplitudesPtr = current

            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                let bufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let freq = state[baseOffset + Self.frequencyOffset]
                let droneOn = state[baseOffset + Self.droneEnabledOffset] > 0.5
                let amp = amplitudesPtr.pointee[oscillatorIndex]

                guard freq > 0 && amp > 0 else {
                    // Silence — zero the buffer
                    for buffer in bufferListPointer {
                        guard let data = buffer.mData else { continue }
                        memset(data, 0, Int(buffer.mDataByteSize))
                    }
                    return noErr
                }

                let phaseInc = twoPi * freq / sampleRate
                let harmonicInc = twoPi * (freq * 2.0) / sampleRate
                let lfoInc = twoPi * 0.1 / sampleRate // 0.1Hz LFO

                for frame in 0..<Int(frameCount) {
                    var sample: Float

                    if droneOn {
                        // Drone: fundamental + 2nd harmonic + LFO pitch drift
                        let lfoValue = sin(state[baseOffset + Self.lfoPhaseOffset])
                        let pitchDrift = lfoValue * 0.03 * freq / sampleRate * twoPi
                        sample = sin(state[baseOffset + Self.phaseOffset] + pitchDrift)
                        sample += 0.05 * sin(state[baseOffset + Self.harmonicPhaseOffset] + pitchDrift * 2.0)
                        state[baseOffset + Self.lfoPhaseOffset] += lfoInc
                    } else {
                        // Ambient: pure sine (TimePitch does the granular processing)
                        sample = sin(state[baseOffset + Self.phaseOffset])
                    }

                    sample *= amp

                    // Advance phase accumulators
                    state[baseOffset + Self.phaseOffset] += phaseInc
                    state[baseOffset + Self.harmonicPhaseOffset] += harmonicInc

                    // Wrap phases to prevent float precision loss
                    if state[baseOffset + Self.phaseOffset] >= twoPi {
                        state[baseOffset + Self.phaseOffset] -= twoPi
                    }
                    if state[baseOffset + Self.harmonicPhaseOffset] >= twoPi {
                        state[baseOffset + Self.harmonicPhaseOffset] -= twoPi
                    }
                    if state[baseOffset + Self.lfoPhaseOffset] >= twoPi {
                        state[baseOffset + Self.lfoPhaseOffset] -= twoPi
                    }

                    for buffer in bufferListPointer {
                        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        data[frame] = sample
                    }
                }

                return noErr
            }

            sourceNodes.append(node)
        }

        logger.info("OscillatorBank initialized: \(count) oscillators")
    }

    /// Indirect pointer so audio thread always reads the latest swapped buffer.
    private let currentAmplitudesIndirect: UnsafeMutablePointer<UnsafeMutablePointer<Float>>

    deinit {
        stateBuffer.deallocate()
        bufferA.deallocate()
        bufferB.deallocate()
        currentAmplitudesIndirect.deallocate()
    }

    // MARK: - Configuration (main thread)

    /// Assign frequencies from room modes. Call when modes change.
    func configure(modes: [RoomMode]) {
        let count = min(modes.count, Self.oscillatorCount)
        for i in 0..<Self.oscillatorCount {
            let baseOffset = i * Self.stridePerOscillator
            if i < count {
                stateBuffer[baseOffset + Self.frequencyOffset] = modes[i].frequency
            } else {
                stateBuffer[baseOffset + Self.frequencyOffset] = 0.0
            }
            // Reset phase accumulators on reconfigure
            stateBuffer[baseOffset + Self.phaseOffset] = 0.0
            stateBuffer[baseOffset + Self.harmonicPhaseOffset] = 0.0
            stateBuffer[baseOffset + Self.lfoPhaseOffset] = Float.random(in: 0..<(Float.pi * 2.0))
        }
        logger.info("Configured \(count) oscillator frequencies")
    }

    /// Update per-oscillator amplitudes. Called from main thread; audio thread reads lock-free.
    func setAmplitudes(_ amplitudes: [Float]) {
        let count = min(amplitudes.count, Self.oscillatorCount)
        for i in 0..<count {
            pendingAmplitudes[i] = amplitudes[i]
        }
        for i in count..<Self.oscillatorCount {
            pendingAmplitudes[i] = 0.0
        }

        // Swap buffers under lock — lock is NEVER held during render
        os_unfair_lock_lock(&swapLock)
        let temp = currentAmplitudes
        currentAmplitudes = pendingAmplitudes
        pendingAmplitudes = temp
        currentAmplitudesIndirect.pointee = currentAmplitudes
        os_unfair_lock_unlock(&swapLock)
    }

    /// Toggle drone timbre (harmonics + LFO pitch drift) on all oscillators.
    func setDroneEnabled(_ enabled: Bool) {
        let value: Float = enabled ? 1.0 : 0.0
        for i in 0..<Self.oscillatorCount {
            stateBuffer[i * Self.stridePerOscillator + Self.droneEnabledOffset] = value
        }
    }
}
