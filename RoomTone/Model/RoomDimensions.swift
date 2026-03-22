import Foundation

struct RoomDimensions: Equatable, Sendable {
    let Lx: Float    // meters, longest horizontal dimension
    let Ly: Float    // meters, shortest horizontal dimension
    let Lz: Float    // meters, ceiling height

    var isValid: Bool { Lx > 0.5 && Ly > 0.5 && Lz > 0.5 }
    var volume: Float { Lx * Ly * Lz }

    /// True when any dimension > 8.5m (modes drop below audible threshold)
    var requiresOctaveShift: Bool { max(Lx, Ly, Lz) > 8.5 }

    /// Reverberation time estimate (Sabine approximation, assumes avg absorption 0.15)
    var estimatedRT60: Float {
        let surfaceArea = 2.0 * (Lx * Ly + Lx * Lz + Ly * Lz)
        return (0.161 * volume) / (0.15 * surfaceArea)
    }
}
