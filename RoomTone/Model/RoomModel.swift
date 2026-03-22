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

    /// Primary output consumed by OscillatorBank on every audio frame.
    /// Returns amplitude multiplier [0.0–1.0] for each mode in self.modes.
    func modeAmplitudes() -> [Float] {
        // Stub for Phase 0 — real implementation in Phase 1
        Array(repeating: 0.0, count: modes.count)
    }

    /// Called by ARSessionManager on every ARFrame (main thread).
    func updatePlayerPosition(_ transform: simd_float4x4) {
        playerPosition = simd_float3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }

    /// Called by RoomGeometryProcessor when new plane anchors confirmed.
    func updateDimensions(_ newDimensions: RoomDimensions) {
        dimensions = newDimensions
    }
}
