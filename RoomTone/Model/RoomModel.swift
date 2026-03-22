import Foundation
import simd

@Observable
final class RoomModel {
    var dimensions: RoomDimensions?
    var modes: [RoomMode] = []
    var playerPosition: simd_float3 = .zero
    var scanProgress: Float = 0.0
    var isEnclosureConfirmed: Bool = false
    var octaveShiftActive: Bool = false
    var lfoPhase: Float = 0.0
    var dominantModeIndex: Int?

    /// Primary output consumed by OscillatorBank.
    /// Returns amplitude multiplier for each mode based on player position.
    func modeAmplitudes() -> [Float] {
        guard let dims = dimensions else {
            return Array(repeating: 0.0, count: modes.count)
        }
        return ModeAmplitudeController.calculateAmplitudes(
            playerPosition: playerPosition,
            dimensions: dims,
            modes: modes,
            lfoPhase: lfoPhase
        )
    }

    /// Advance the amplitude LFO by the given time delta (0.1Hz cycle).
    func advanceLFO(deltaTime: Float) {
        lfoPhase += 2.0 * Float.pi * 0.1 * deltaTime
        if lfoPhase >= 2.0 * Float.pi {
            lfoPhase -= 2.0 * Float.pi
        }
    }

    /// Called by ARSessionManager on every ARFrame (main thread).
    func updatePlayerPosition(_ transform: simd_float4x4) {
        playerPosition = simd_float3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    /// Called by RoomGeometryProcessor when new plane anchors confirmed,
    /// or directly with hardcoded dimensions in Phase 1.
    func updateDimensions(_ newDimensions: RoomDimensions) {
        dimensions = newDimensions
        modes = RoomModeCalculator.calculateModes(for: newDimensions)
        octaveShiftActive = newDimensions.requiresOctaveShift
    }
}
