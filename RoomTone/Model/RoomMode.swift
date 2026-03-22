import Foundation

struct RoomMode: Identifiable, Equatable, Sendable {
    let id: UUID
    let n: Int            // x-axis index (0 = no variation along x)
    let m: Int            // y-axis index
    let l: Int            // z-axis index
    let frequency: Float  // Hz, post octave-shift if applied
    let axis: ModeAxis
    let perceptualWeight: Float  // 0.0–1.0; lower modes weight higher
    let wallAxis: WallAxis?      // which wall pair this mode is associated with (axial only)
}

enum ModeAxis: Equatable, Sendable {
    case axial      // energy in one dimension only (n,0,0 or 0,m,0 or 0,0,l)
    case tangential // energy in two dimensions
    case oblique    // energy in all three dimensions
}

enum WallAxis: Equatable, Sendable {
    case x  // associated with Lx walls (left/right)
    case y  // associated with Ly walls (front/back)
    case z  // associated with Lz surfaces (floor/ceiling)
}
