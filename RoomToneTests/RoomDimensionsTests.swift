import Testing
@testable import RoomTone

@Suite("RoomDimensions")
struct RoomDimensionsTests {

    // MARK: - isValid

    @Test("valid dimensions")
    func validDimensions() {
        let dims = RoomDimensions(Lx: 4.0, Ly: 3.0, Lz: 2.5)
        #expect(dims.isValid)
    }

    @Test("invalid when any dimension <= 0.5")
    func invalidDimensions() {
        #expect(!RoomDimensions(Lx: 0.5, Ly: 3.0, Lz: 2.5).isValid)
        #expect(!RoomDimensions(Lx: 4.0, Ly: 0.3, Lz: 2.5).isValid)
        #expect(!RoomDimensions(Lx: 4.0, Ly: 3.0, Lz: 0.0).isValid)
    }

    @Test("boundary — just above 0.5 is valid")
    func boundaryValid() {
        let dims = RoomDimensions(Lx: 0.51, Ly: 0.51, Lz: 0.51)
        #expect(dims.isValid)
    }

    // MARK: - volume

    @Test("volume calculation")
    func volume() {
        let dims = RoomDimensions(Lx: 4.0, Ly: 3.0, Lz: 2.5)
        #expect(dims.volume == 30.0)
    }

    @Test("volume with unit cube")
    func unitVolume() {
        let dims = RoomDimensions(Lx: 1.0, Ly: 1.0, Lz: 1.0)
        #expect(dims.volume == 1.0)
    }

    // MARK: - requiresOctaveShift

    @Test("no octave shift for normal room")
    func noOctaveShift() {
        let dims = RoomDimensions(Lx: 5.0, Ly: 4.0, Lz: 2.5)
        #expect(!dims.requiresOctaveShift)
    }

    @Test("octave shift required when Lx > 8.5m")
    func octaveShiftLargeX() {
        let dims = RoomDimensions(Lx: 10.0, Ly: 4.0, Lz: 2.5)
        #expect(dims.requiresOctaveShift)
    }

    @Test("octave shift required when Lz > 8.5m (tall space)")
    func octaveShiftTallSpace() {
        let dims = RoomDimensions(Lx: 4.0, Ly: 3.0, Lz: 9.0)
        #expect(dims.requiresOctaveShift)
    }

    @Test("boundary — exactly 8.5m does not require shift")
    func octaveShiftBoundary() {
        let dims = RoomDimensions(Lx: 8.5, Ly: 4.0, Lz: 2.5)
        #expect(!dims.requiresOctaveShift)
    }

    @Test("boundary — 8.51m requires shift")
    func octaveShiftJustAbove() {
        let dims = RoomDimensions(Lx: 8.51, Ly: 4.0, Lz: 2.5)
        #expect(dims.requiresOctaveShift)
    }

    // MARK: - estimatedRT60

    @Test("RT60 for standard room (Sabine approximation)")
    func estimatedRT60() {
        // 4m × 3m × 2.5m room
        // volume = 30.0
        // surfaceArea = 2 * (12 + 10 + 7.5) = 59.0
        // RT60 = (0.161 * 30) / (0.15 * 59) = 4.83 / 8.85 ≈ 0.5458s
        let dims = RoomDimensions(Lx: 4.0, Ly: 3.0, Lz: 2.5)
        let rt60 = dims.estimatedRT60
        let expected: Float = (0.161 * 30.0) / (0.15 * 59.0)
        #expect(abs(rt60 - expected) < 0.001)
    }

    @Test("larger room has longer RT60")
    func largerRoomLongerRT60() {
        let small = RoomDimensions(Lx: 3.0, Ly: 3.0, Lz: 2.5)
        let large = RoomDimensions(Lx: 8.0, Ly: 6.0, Lz: 3.0)
        #expect(large.estimatedRT60 > small.estimatedRT60)
    }
}
