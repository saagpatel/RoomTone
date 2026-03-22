import Foundation
import simd

struct ModeAmplitudeController {
    private init() {}

    /// Radius within which proximity boost is active (meters)
    static let peakRadius: Float = 0.3

    /// LFO amplitude modulation depth (±5%)
    static let lfoDepth: Float = 0.05

    // MARK: - Public

    /// Calculate per-mode amplitudes based on player position.
    ///
    /// - Parameters:
    ///   - playerPosition: Player's position in model space
    ///   - dimensions: Current room dimensions
    ///   - modes: Active room modes (max 16)
    ///   - lfoPhase: Current LFO phase in radians (0...2π, advances at 0.1Hz externally)
    /// - Returns: Array of Float amplitudes, one per mode, in same order as `modes`
    static func calculateAmplitudes(
        playerPosition: simd_float3,
        dimensions: RoomDimensions,
        modes: [RoomMode],
        lfoPhase: Float
    ) -> [Float] {
        let lfoModulation = sin(lfoPhase) * lfoDepth

        return modes.map { mode in
            let boost: Float
            if let axis = mode.wallAxis {
                let dist = wallDistance(
                    playerPosition: playerPosition,
                    wallAxis: axis,
                    dimensions: dimensions
                )
                boost = proximityBoost(distance: dist)
            } else {
                boost = 0.0
            }

            return mode.perceptualWeight * (1.0 + boost) * (1.0 + lfoModulation)
        }
    }

    /// Calculate distance from player to nearest wall on a given axis.
    static func wallDistance(
        playerPosition: simd_float3,
        wallAxis: WallAxis,
        dimensions: RoomDimensions
    ) -> Float {
        switch wallAxis {
        case .x:
            return min(playerPosition.x, dimensions.Lx - playerPosition.x)
        case .y:
            return min(playerPosition.y, dimensions.Ly - playerPosition.y)
        case .z:
            return min(playerPosition.z, dimensions.Lz - playerPosition.z)
        }
    }

    /// Calculate proximity boost for a given wall distance.
    /// Linear falloff from 1.0 (at wall) to 0.0 (at peakRadius distance).
    static func proximityBoost(distance: Float) -> Float {
        guard distance > 0 else { return 1.0 }
        return max(0.0, 1.0 - (distance / peakRadius))
    }
}
