import Testing
@testable import RoomTone

@Suite("RoomModeCalculator")
struct RoomModeCalculatorTests {

    // MARK: - Frequency calculation

    @Test("5x4x3 room axial mode (1,0,0) at ~34.3Hz")
    func axialModeX() {
        let dims = RoomDimensions(Lx: 5.0, Ly: 4.0, Lz: 3.0)
        let freq = RoomModeCalculator.frequency(n: 1, m: 0, l: 0, dimensions: dims)
        // Expected: (343/2) * (1/5) = 34.3 Hz
        #expect(abs(freq - 34.3) < 1.5)
    }

    @Test("5x4x3 room axial mode (0,1,0) at ~42.9Hz")
    func axialModeY() {
        let dims = RoomDimensions(Lx: 5.0, Ly: 4.0, Lz: 3.0)
        let freq = RoomModeCalculator.frequency(n: 0, m: 1, l: 0, dimensions: dims)
        // Expected: (343/2) * (1/4) = 42.875 Hz
        #expect(abs(freq - 42.875) < 1.5)
    }

    @Test("5x4x3 room axial mode (0,0,1) at ~57.2Hz")
    func axialModeZ() {
        let dims = RoomDimensions(Lx: 5.0, Ly: 4.0, Lz: 3.0)
        let freq = RoomModeCalculator.frequency(n: 0, m: 0, l: 1, dimensions: dims)
        // Expected: (343/2) * (1/3) = 57.167 Hz
        #expect(abs(freq - 57.167) < 1.5)
    }

    @Test("4x3x2.5 test room (1,0,0) at ~42.9Hz")
    func testRoomAxialX() {
        let freq = RoomModeCalculator.frequency(n: 1, m: 0, l: 0, dimensions: .testRoom)
        #expect(abs(freq - 42.875) < 0.1)
    }

    // MARK: - Mode count

    @Test("calculateModes returns at most 16 modes")
    func maxModeCount() {
        let modes = RoomModeCalculator.calculateModes(for: .testRoom)
        #expect(modes.count == 16)
    }

    @Test("total possible modes for 0...3 range is 63")
    func totalModeCount() {
        // 4^3 - 1 = 63 (excluding 0,0,0)
        var count = 0
        for n in 0...3 {
            for m in 0...3 {
                for l in 0...3 {
                    if !(n == 0 && m == 0 && l == 0) { count += 1 }
                }
            }
        }
        #expect(count == 63)
    }

    // MARK: - Classification

    @Test("axial modes correctly classified with wallAxis")
    func axialClassification() {
        #expect(RoomModeCalculator.classifyMode(n: 1, m: 0, l: 0) == .axial)
        #expect(RoomModeCalculator.wallAxis(n: 1, m: 0, l: 0) == .x)

        #expect(RoomModeCalculator.classifyMode(n: 0, m: 2, l: 0) == .axial)
        #expect(RoomModeCalculator.wallAxis(n: 0, m: 2, l: 0) == .y)

        #expect(RoomModeCalculator.classifyMode(n: 0, m: 0, l: 3) == .axial)
        #expect(RoomModeCalculator.wallAxis(n: 0, m: 0, l: 3) == .z)
    }

    @Test("tangential modes classified without wallAxis")
    func tangentialClassification() {
        #expect(RoomModeCalculator.classifyMode(n: 1, m: 1, l: 0) == .tangential)
        #expect(RoomModeCalculator.wallAxis(n: 1, m: 1, l: 0) == nil)

        #expect(RoomModeCalculator.classifyMode(n: 1, m: 0, l: 1) == .tangential)
        #expect(RoomModeCalculator.wallAxis(n: 1, m: 0, l: 1) == nil)
    }

    @Test("oblique modes classified without wallAxis")
    func obliqueClassification() {
        #expect(RoomModeCalculator.classifyMode(n: 1, m: 1, l: 1) == .oblique)
        #expect(RoomModeCalculator.wallAxis(n: 1, m: 1, l: 1) == nil)

        #expect(RoomModeCalculator.classifyMode(n: 2, m: 1, l: 3) == .oblique)
        #expect(RoomModeCalculator.wallAxis(n: 2, m: 1, l: 3) == nil)
    }

    // MARK: - Sorting

    @Test("modes sorted by perceptualWeight descending (frequency ascending)")
    func sortOrder() {
        let modes = RoomModeCalculator.calculateModes(for: .testRoom)
        for i in 0..<(modes.count - 1) {
            #expect(modes[i].perceptualWeight >= modes[i + 1].perceptualWeight)
            #expect(modes[i].frequency <= modes[i + 1].frequency)
        }
    }

    @Test("first mode of 5x4x3 room is (1,0,0)")
    func lowestModeFirst() {
        let dims = RoomDimensions(Lx: 5.0, Ly: 4.0, Lz: 3.0)
        let modes = RoomModeCalculator.calculateModes(for: dims)
        guard let first = modes.first else {
            Issue.record("No modes generated")
            return
        }
        #expect(first.n == 1)
        #expect(first.m == 0)
        #expect(first.l == 0)
        #expect(abs(first.frequency - 34.3) < 1.5)
    }

    // MARK: - Octave shift

    @Test("10x8x4 room: no frequencies below 40Hz after shift")
    func octaveShiftLargeRoom() {
        let dims = RoomDimensions(Lx: 10.0, Ly: 8.0, Lz: 4.0)
        #expect(dims.requiresOctaveShift)
        let modes = RoomModeCalculator.calculateModes(for: dims)
        for mode in modes {
            #expect(mode.frequency >= 40.0, "Mode (\(mode.n),\(mode.m),\(mode.l)) at \(mode.frequency)Hz is below 40Hz")
        }
    }

    @Test("8.5m dimension does NOT trigger shift")
    func noShiftAt8_5() {
        let dims = RoomDimensions(Lx: 8.5, Ly: 4.0, Lz: 2.5)
        #expect(!dims.requiresOctaveShift)
        let modes = RoomModeCalculator.calculateModes(for: dims)
        // (1,0,0) at Lx=8.5: (343/2) * (1/8.5) = 20.18Hz — below 40Hz but no shift applied
        guard let first = modes.first else { return }
        #expect(first.frequency < 40.0)
    }

    @Test("8.51m dimension triggers shift")
    func shiftAt8_51() {
        let dims = RoomDimensions(Lx: 8.51, Ly: 4.0, Lz: 2.5)
        #expect(dims.requiresOctaveShift)
        let modes = RoomModeCalculator.calculateModes(for: dims)
        for mode in modes {
            #expect(mode.frequency >= 40.0)
        }
    }

    @Test("octave shift preserves mode ordering")
    func shiftPreservesOrder() {
        let dims = RoomDimensions(Lx: 10.0, Ly: 8.0, Lz: 4.0)
        let modes = RoomModeCalculator.calculateModes(for: dims)
        for i in 0..<(modes.count - 1) {
            #expect(modes[i].perceptualWeight >= modes[i + 1].perceptualWeight)
        }
    }

    @Test("octave shift multiplier for frequency already above 40Hz is 1.0")
    func noShiftNeeded() {
        #expect(RoomModeCalculator.octaveShiftMultiplier(lowestFrequency: 50.0) == 1.0)
    }

    @Test("octave shift multiplier for 17.15Hz is 4.0")
    func shiftMultiplier() {
        // ceil(log2(40/17.15)) = ceil(1.22) = 2, so 2^2 = 4.0
        let multiplier = RoomModeCalculator.octaveShiftMultiplier(lowestFrequency: 17.15)
        #expect(abs(multiplier - 4.0) < 0.01)
    }

    // MARK: - Edge cases

    @Test("invalid dimensions returns empty array")
    func invalidDimensions() {
        let dims = RoomDimensions(Lx: 0.3, Ly: 3.0, Lz: 2.5)
        #expect(RoomModeCalculator.calculateModes(for: dims).isEmpty)
    }

    @Test("modes have unique IDs")
    func uniqueIDs() {
        let modes = RoomModeCalculator.calculateModes(for: .testRoom)
        let idSet = Set(modes.map(\.id))
        #expect(idSet.count == modes.count)
    }
}
