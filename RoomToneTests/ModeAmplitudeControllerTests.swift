import Testing
import Foundation
import simd
@testable import RoomTone

@Suite("ModeAmplitudeController")
struct ModeAmplitudeControllerTests {

    let testRoom = RoomDimensions.testRoom // 4x3x2.5
    let centerPosition = simd_float3(2.0, 1.5, 1.25)

    // Helper: create an axial mode on a given axis
    private func axialMode(_ axis: WallAxis, frequency: Float = 42.875) -> RoomMode {
        let (n, m, l): (Int, Int, Int) = switch axis {
        case .x: (1, 0, 0)
        case .y: (0, 1, 0)
        case .z: (0, 0, 1)
        }
        return RoomMode(
            id: UUID(), n: n, m: m, l: l,
            frequency: frequency,
            axis: .axial,
            perceptualWeight: 1.0 / (1.0 + frequency),
            wallAxis: axis
        )
    }

    private func tangentialMode() -> RoomMode {
        RoomMode(
            id: UUID(), n: 1, m: 1, l: 0,
            frequency: 71.5,
            axis: .tangential,
            perceptualWeight: 1.0 / (1.0 + 71.5),
            wallAxis: nil
        )
    }

    // MARK: - Wall proximity

    @Test("player at x=0 touching wall boosts x-axis mode")
    func playerAtWallBoostsXMode() {
        let mode = axialMode(.x)
        let atWall = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(0, 1.5, 1.25),
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        let atCenter = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        // At wall: pw * (1 + 1.0) = pw * 2.0
        // At center: pw * (1 + 0.0) = pw * 1.0
        #expect(atWall[0] / atCenter[0] > 1.9)
        #expect(atWall[0] / atCenter[0] < 2.1)
    }

    @Test("player at x=Lx touching opposite wall boosts x-axis mode")
    func playerAtOppositeWall() {
        let mode = axialMode(.x)
        let atWall = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(4.0, 1.5, 1.25),
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        let atCenter = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        #expect(atWall[0] / atCenter[0] > 1.9)
    }

    @Test("player at room center has zero proximity boost")
    func playerAtCenterNoBoost() {
        let mode = axialMode(.x)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        // Center is 2.0m from x-walls, well beyond 0.3m peakRadius
        #expect(abs(amps[0] - mode.perceptualWeight) < 0.001)
    }

    @Test("player at x=0.15 gets half proximity boost")
    func halfBoost() {
        let boost = ModeAmplitudeController.proximityBoost(distance: 0.15)
        #expect(abs(boost - 0.5) < 0.001)
    }

    @Test("player at x=0.3 gets zero proximity boost (boundary)")
    func zeroBoostAtBoundary() {
        let boost = ModeAmplitudeController.proximityBoost(distance: 0.3)
        #expect(abs(boost) < 0.001)
    }

    @Test("player at x=0.31 gets zero proximity boost")
    func zeroBoostBeyondBoundary() {
        let boost = ModeAmplitudeController.proximityBoost(distance: 0.31)
        #expect(boost == 0.0)
    }

    @Test("player at wall (distance=0) gets full boost")
    func fullBoostAtWall() {
        let boost = ModeAmplitudeController.proximityBoost(distance: 0.0)
        #expect(boost == 1.0)
    }

    // MARK: - Tangential/oblique immunity

    @Test("tangential mode amplitude unaffected by position")
    func tangentialUnaffected() {
        let mode = tangentialMode()
        let atWall = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(0, 0, 0),
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        let atCenter = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        #expect(abs(atWall[0] - atCenter[0]) < 0.001)
    }

    // MARK: - LFO

    @Test("LFO at phase=0 produces zero modulation")
    func lfoZero() {
        let mode = axialMode(.x)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 0
        )
        #expect(abs(amps[0] - mode.perceptualWeight) < 0.001)
    }

    @Test("LFO at phase=pi/2 produces +5% modulation")
    func lfoPositive() {
        let mode = axialMode(.x)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: Float.pi / 2.0
        )
        let expected = mode.perceptualWeight * 1.05
        #expect(abs(amps[0] - expected) < 0.001)
    }

    @Test("LFO at phase=3pi/2 produces -5% modulation")
    func lfoNegative() {
        let mode = axialMode(.x)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition,
            dimensions: testRoom,
            modes: [mode],
            lfoPhase: 3.0 * Float.pi / 2.0
        )
        let expected = mode.perceptualWeight * 0.95
        #expect(abs(amps[0] - expected) < 0.001)
    }

    // MARK: - Output validity

    @Test("all amplitudes are non-negative")
    func nonNegative() {
        let modes = RoomModeCalculator.calculateModes(for: testRoom)
        let positions: [simd_float3] = [
            .zero,
            centerPosition,
            simd_float3(4.0, 3.0, 2.5),
            simd_float3(0.1, 0.1, 0.1),
        ]
        for pos in positions {
            let amps = ModeAmplitudeController.calculateAmplitudes(
                playerPosition: pos, dimensions: testRoom, modes: modes, lfoPhase: 0
            )
            for amp in amps {
                #expect(amp >= 0.0)
            }
        }
    }

    @Test("output array length matches modes count")
    func outputLength() {
        let modes = RoomModeCalculator.calculateModes(for: testRoom)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition, dimensions: testRoom, modes: modes, lfoPhase: 0
        )
        #expect(amps.count == modes.count)
    }

    @Test("empty modes returns empty array")
    func emptyModes() {
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: centerPosition, dimensions: testRoom, modes: [], lfoPhase: 0
        )
        #expect(amps.isEmpty)
    }

    // MARK: - Multi-axis

    @Test("player near y-wall boosts y-axis mode, not x-axis mode")
    func yWallBoostsYOnly() {
        let xMode = axialMode(.x)
        let yMode = axialMode(.y, frequency: 57.167)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(2.0, 0.0, 1.25),
            dimensions: testRoom,
            modes: [xMode, yMode],
            lfoPhase: 0
        )
        // x-mode: wallDist = min(2.0, 2.0) = 2.0 → boost = 0
        // y-mode: wallDist = min(0, 3.0) = 0 → boost = 1.0
        #expect(abs(amps[0] - xMode.perceptualWeight) < 0.001) // no boost
        #expect(amps[1] > yMode.perceptualWeight * 1.9) // ~2x boost
    }

    @Test("player near floor boosts z-axis mode")
    func floorBoostsZMode() {
        let zMode = axialMode(.z, frequency: 68.6)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(2.0, 1.5, 0.0),
            dimensions: testRoom,
            modes: [zMode],
            lfoPhase: 0
        )
        #expect(amps[0] > zMode.perceptualWeight * 1.9)
    }

    @Test("player near ceiling boosts z-axis mode")
    func ceilingBoostsZMode() {
        let zMode = axialMode(.z, frequency: 68.6)
        let amps = ModeAmplitudeController.calculateAmplitudes(
            playerPosition: simd_float3(2.0, 1.5, 2.5),
            dimensions: testRoom,
            modes: [zMode],
            lfoPhase: 0
        )
        #expect(amps[0] > zMode.perceptualWeight * 1.9)
    }
}
