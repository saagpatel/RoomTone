import ARKit
import os

// MARK: - PlaneInfo (testable value type)

/// Value type wrapping ARPlaneAnchor properties for testability.
/// ARPlaneAnchor has no public initializer, so geometry logic operates on this instead.
struct PlaneInfo: Identifiable, Equatable {
    let id: UUID
    let classification: ARPlaneAnchor.Classification
    let alignment: ARPlaneAnchor.Alignment
    let transform: simd_float4x4
    let extentX: Float  // width in plane's local space
    let extentZ: Float  // height in plane's local space

    /// Production initializer from ARPlaneAnchor.
    init(_ anchor: ARPlaneAnchor) {
        self.id = anchor.identifier
        self.classification = anchor.classification
        self.alignment = anchor.alignment
        self.transform = anchor.transform
        self.extentX = anchor.planeExtent.width
        self.extentZ = anchor.planeExtent.height
    }

    /// Test initializer with explicit values.
    init(
        id: UUID = UUID(),
        classification: ARPlaneAnchor.Classification,
        alignment: ARPlaneAnchor.Alignment,
        transform: simd_float4x4 = matrix_identity_float4x4,
        extentX: Float,
        extentZ: Float
    ) {
        self.id = id
        self.classification = classification
        self.alignment = alignment
        self.transform = transform
        self.extentX = extentX
        self.extentZ = extentZ
    }

    /// World-space Y position of this plane's center.
    var worldY: Float { transform.columns.3.y }

    /// Area in square meters.
    var area: Float { extentX * extentZ }

    /// Normal vector in world space (Z-axis of local frame projected into world).
    var worldNormal: simd_float3 {
        let localZ = simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        return simd_normalize(localZ)
    }

    /// Horizontal component of normal (Y zeroed, re-normalized).
    var horizontalNormal: simd_float2 {
        let n = worldNormal
        let h = simd_float2(n.x, n.z)
        let len = simd_length(h)
        guard len > 0.001 else { return .zero }
        return h / len
    }
}

// MARK: - RoomGeometryProcessor

/// Converts detected plane anchors into RoomDimensions with debouncing.
///
/// All internal calculations use ARKit's Y-up coordinate system.
/// The output RoomDimensions maps vertical (Y) to Lz (ceiling height).
struct RoomGeometryProcessor {

    // MARK: - Configuration

    static let defaultCeilingHeight: Float = 2.7
    static let debounceCount = 3
    static let stabilityThreshold: Float = 0.10
    static let minWallArea: Float = 0.5
    static let perpendicularityThreshold: Float = 0.15  // radians (~8.6°)
    static let minProcessingInterval: TimeInterval = 0.1

    // MARK: - Result

    enum ProcessingResult: Equatable {
        case scanning(progress: Float)
        case confirmed(dimensions: RoomDimensions)
    }

    // MARK: - Detection state

    private(set) var hasFloor = false
    private(set) var wallCount = 0
    private(set) var hasPerpendicularity = false

    /// Most recent dimension estimate, even before debounce confirms.
    /// Used by ARSessionManager to start audio with preliminary dimensions.
    private(set) var latestCandidate: RoomDimensions?

    // MARK: - Debounce

    private var readingBuffer: [RoomDimensions] = []
    private var lastProcessedTime: TimeInterval = 0

    private let logger = Logger(subsystem: "com.roomtone.app", category: "GeometryProcessor")

    // MARK: - Public

    var scanProgress: Float {
        var progress: Float = 0.0
        if hasFloor { progress += 0.33 }
        if wallCount >= 1 { progress += 0.33 }
        if hasPerpendicularity { progress += 0.34 }
        return min(progress, 1.0)
    }

    /// Process plane anchors and return current scan status.
    mutating func process(
        planes: [PlaneInfo],
        meshMaxY: Float? = nil,
        currentTime: TimeInterval
    ) -> ProcessingResult {
        // Throttle
        guard currentTime - lastProcessedTime >= Self.minProcessingInterval else {
            return .scanning(progress: scanProgress)
        }
        lastProcessedTime = currentTime

        // 1. Find floor
        let floor = findFloor(in: planes)
        hasFloor = floor != nil

        // 2. Find walls
        let walls = findWalls(in: planes)
        wallCount = walls.count

        // 3. Find perpendicular pair
        let pair = findPerpendicularWalls(walls)
        hasPerpendicularity = pair != nil

        guard let floor, let (wall1, wall2) = pair else {
            return .scanning(progress: scanProgress)
        }

        // 4. Extract horizontal dimensions
        let hA = wall1.extentX
        let hB = wall2.extentX
        let Lx = max(hA, hB)
        let Ly = min(hA, hB)

        // 5. Ceiling height (fallback chain)
        let Lz = determineCeilingHeight(floor: floor, planes: planes, meshMaxY: meshMaxY)

        let candidate = RoomDimensions(Lx: Lx, Ly: Ly, Lz: Lz)
        guard candidate.isValid else {
            return .scanning(progress: scanProgress)
        }

        latestCandidate = candidate

        // 6. Debounce
        if let stable = debounce(candidate) {
            logger.info("Room confirmed: \(stable.Lx)×\(stable.Ly)×\(stable.Lz)m")
            return .confirmed(dimensions: stable)
        }

        return .scanning(progress: scanProgress)
    }

    /// Reset processor state for a new scan.
    mutating func reset() {
        hasFloor = false
        wallCount = 0
        hasPerpendicularity = false
        readingBuffer.removeAll()
        lastProcessedTime = 0
    }

    // MARK: - Floor detection

    func findFloor(in planes: [PlaneInfo]) -> PlaneInfo? {
        // Prefer .floor classification
        let floors = planes.filter { $0.classification == .floor }
        if let best = floors.max(by: { $0.area < $1.area }) {
            return best
        }
        // Fallback: lowest-Y horizontal plane
        return planes
            .filter { $0.alignment == .horizontal }
            .min(by: { $0.worldY < $1.worldY })
    }

    // MARK: - Wall detection

    func findWalls(in planes: [PlaneInfo]) -> [PlaneInfo] {
        planes.filter { plane in
            (plane.classification == .wall || plane.alignment == .vertical)
            && plane.area >= Self.minWallArea
        }
    }

    // MARK: - Perpendicularity

    func findPerpendicularWalls(_ walls: [PlaneInfo]) -> (PlaneInfo, PlaneInfo)? {
        guard walls.count >= 2 else { return nil }

        var bestPair: (PlaneInfo, PlaneInfo)?
        var bestArea: Float = 0

        for i in 0..<walls.count {
            for j in (i + 1)..<walls.count {
                let dot = abs(simd_dot(walls[i].horizontalNormal, walls[j].horizontalNormal))
                if dot < Self.perpendicularityThreshold {
                    let combinedArea = walls[i].area + walls[j].area
                    if combinedArea > bestArea {
                        bestPair = (walls[i], walls[j])
                        bestArea = combinedArea
                    }
                }
            }
        }

        return bestPair
    }

    // MARK: - Ceiling height

    func determineCeilingHeight(floor: PlaneInfo, planes: [PlaneInfo], meshMaxY: Float?) -> Float {
        let floorY = floor.worldY

        // 1. Ceiling plane anchor
        if let ceiling = planes.first(where: { $0.classification == .ceiling }) {
            let height = ceiling.worldY - floorY
            if height > 0.5 {
                return height
            }
        }

        // 2. LiDAR mesh bounding box
        if let maxY = meshMaxY {
            let height = maxY - floorY
            if height > 0.5 {
                return height
            }
        }

        // 3. Default
        logger.warning("No ceiling detected — using default \(Self.defaultCeilingHeight)m")
        return Self.defaultCeilingHeight
    }

    // MARK: - Debounce

    mutating func debounce(_ candidate: RoomDimensions) -> RoomDimensions? {
        readingBuffer.append(candidate)
        if readingBuffer.count > Self.debounceCount {
            readingBuffer.removeFirst()
        }

        guard readingBuffer.count == Self.debounceCount else { return nil }

        // Check all pairs within threshold
        for i in 0..<readingBuffer.count {
            for j in (i + 1)..<readingBuffer.count {
                guard isWithinThreshold(readingBuffer[i], readingBuffer[j]) else {
                    return nil
                }
            }
        }

        return medianDimensions(readingBuffer)
    }

    func isWithinThreshold(_ a: RoomDimensions, _ b: RoomDimensions) -> Bool {
        func within(_ v1: Float, _ v2: Float) -> Bool {
            abs(v1 - v2) / max(v1, v2) < Self.stabilityThreshold
        }
        return within(a.Lx, b.Lx) && within(a.Ly, b.Ly) && within(a.Lz, b.Lz)
    }

    func medianDimensions(_ readings: [RoomDimensions]) -> RoomDimensions {
        let sortedLx = readings.map(\.Lx).sorted()
        let sortedLy = readings.map(\.Ly).sorted()
        let sortedLz = readings.map(\.Lz).sorted()
        return RoomDimensions(
            Lx: sortedLx[1],
            Ly: sortedLy[1],
            Lz: sortedLz[1]
        )
    }
}
