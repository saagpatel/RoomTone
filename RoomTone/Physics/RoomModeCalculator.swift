import Foundation

struct RoomModeCalculator {
    private init() {}

    /// Speed of sound in air at ~20°C, meters/second
    static let speedOfSound: Float = 343.0

    /// Maximum mode indices to iterate (0...maxModeIndex per axis)
    static let maxModeIndex: Int = 3

    /// Maximum number of modes returned
    static let maxActiveModes: Int = 16

    /// Minimum audible frequency — octave shift ensures no mode falls below this
    static let minimumFrequency: Float = 40.0

    // MARK: - Public

    /// Generate and rank room resonant modes for given dimensions.
    /// Returns at most `maxActiveModes` modes, sorted by perceptualWeight descending.
    /// Applies octave-shift when `dimensions.requiresOctaveShift` is true.
    static func calculateModes(for dimensions: RoomDimensions) -> [RoomMode] {
        guard dimensions.isValid else { return [] }

        var modes: [RoomMode] = []

        // Generate all modes for n,m,l in 0...3, excluding (0,0,0) — 63 total
        for n in 0...maxModeIndex {
            for m in 0...maxModeIndex {
                for l in 0...maxModeIndex {
                    guard !(n == 0 && m == 0 && l == 0) else { continue }

                    let freq = frequency(n: n, m: m, l: l, dimensions: dimensions)
                    let axis = classifyMode(n: n, m: m, l: l)
                    let wall = wallAxis(n: n, m: m, l: l)
                    let weight = 1.0 / (1.0 + freq)

                    modes.append(RoomMode(
                        id: UUID(),
                        n: n, m: m, l: l,
                        frequency: freq,
                        axis: axis,
                        perceptualWeight: weight,
                        wallAxis: wall
                    ))
                }
            }
        }

        // Sort by perceptualWeight descending (lowest frequencies first)
        modes.sort { $0.perceptualWeight > $1.perceptualWeight }

        // Take top 16
        modes = Array(modes.prefix(maxActiveModes))

        // Apply octave-shift if needed
        if dimensions.requiresOctaveShift, let lowestFreq = modes.first?.frequency {
            let multiplier = octaveShiftMultiplier(lowestFrequency: lowestFreq)
            if multiplier > 1.0 {
                modes = modes.map { mode in
                    RoomMode(
                        id: mode.id,
                        n: mode.n, m: mode.m, l: mode.l,
                        frequency: mode.frequency * multiplier,
                        axis: mode.axis,
                        perceptualWeight: mode.perceptualWeight,
                        wallAxis: mode.wallAxis
                    )
                }
            }
        }

        return modes
    }

    /// Calculate the resonant frequency for mode indices (n, m, l) in a room.
    /// Formula: f(n,m,l) = (c/2) * sqrt((n/Lx)² + (m/Ly)² + (l/Lz)²)
    static func frequency(n: Int, m: Int, l: Int, dimensions: RoomDimensions) -> Float {
        let nx = Float(n) / dimensions.Lx
        let ny = Float(m) / dimensions.Ly
        let nz = Float(l) / dimensions.Lz
        return (speedOfSound / 2.0) * sqrt(nx * nx + ny * ny + nz * nz)
    }

    /// Classify a mode based on how many indices are non-zero.
    static func classifyMode(n: Int, m: Int, l: Int) -> ModeAxis {
        let nonZeroCount = (n > 0 ? 1 : 0) + (m > 0 ? 1 : 0) + (l > 0 ? 1 : 0)
        switch nonZeroCount {
        case 1: return .axial
        case 2: return .tangential
        default: return .oblique
        }
    }

    /// Determine which wall axis an axial mode is associated with.
    /// Returns nil for tangential and oblique modes.
    static func wallAxis(n: Int, m: Int, l: Int) -> WallAxis? {
        switch (n > 0, m > 0, l > 0) {
        case (true, false, false): return .x
        case (false, true, false): return .y
        case (false, false, true): return .z
        default: return nil
        }
    }

    /// Calculate the octave-shift multiplier so all frequencies >= minimumFrequency.
    /// Returns 1.0 if no shift is needed.
    static func octaveShiftMultiplier(lowestFrequency: Float) -> Float {
        guard lowestFrequency > 0, lowestFrequency < minimumFrequency else { return 1.0 }
        let ratio = minimumFrequency / lowestFrequency
        let exponent = ceil(log2(ratio))
        return pow(2.0, exponent)
    }
}
