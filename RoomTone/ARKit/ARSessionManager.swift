import ARKit
import SceneKit
import os

/// Manages the ARSession lifecycle, plane detection, coordinate remapping,
/// and bridges ARKit data into RoomModel and AppState.
@Observable
final class ARSessionManager: NSObject {

    // MARK: - Public state

    let sceneView: ARSCNView
    var detectedPlanes: [PlaneInfo] = []
    var isSessionRunning: Bool = false

    // MARK: - Dependencies (set via bind())

    private weak var roomModel: RoomModel?
    private weak var appState: AppState?
    private weak var audioEngine: RoomAudioEngine?

    // MARK: - Private

    private var geometryProcessor = RoomGeometryProcessor()
    private var lastFrameTime: TimeInterval = 0
    private var timeoutTimer: Timer?
    private var isConfirmed = false
    private let logger = Logger(subsystem: "com.roomtone.app", category: "ARSessionManager")
    private let wireframeManager = WireframeOverlayManager()

    // MARK: - Init

    override init() {
        sceneView = ARSCNView()
        sceneView.automaticallyUpdatesLighting = false
        sceneView.rendersCameraGrain = false
        super.init()
        sceneView.session.delegate = self
        sceneView.delegate = wireframeManager
    }

    /// Wire dependencies after init to avoid circular references.
    func bind(appState: AppState, roomModel: RoomModel, audioEngine: RoomAudioEngine) {
        self.appState = appState
        self.roomModel = roomModel
        self.audioEngine = audioEngine
    }

    // MARK: - Lifecycle

    func startScanning() {
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .none

        geometryProcessor.reset()
        detectedPlanes.removeAll()
        isConfirmed = false
        lastFrameTime = 0

        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        appState?.scanPhase = .scanning(progress: 0.0)

        startTimeoutTimer()
        logger.info("AR session started — scanning")
    }

    func pauseScanning() {
        sceneView.session.pause()
        isSessionRunning = false
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        logger.info("AR session paused")
    }

    /// Continue position tracking without plane processing (for MainExperienceView).
    func resumeTracking() {
        isSessionRunning = true
        logger.info("AR session — tracking only")
    }

    // MARK: - Timeout

    private func startTimeoutTimer() {
        timeoutTimer?.invalidate()

        // 20s check for no-enclosure
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, !self.isConfirmed else { return }
            if self.geometryProcessor.scanProgress < 0.66 {
                self.appState?.scanPhase = .failed(reason: .noEnclosure)
                self.logger.warning("Scan timeout (20s) — no enclosure detected")
            }
        }

        // 30s hard timeout
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            guard let self, !self.isConfirmed else { return }
            self.appState?.scanPhase = .failed(reason: .timeout)
            self.logger.warning("Scan timeout (30s) — no valid geometry")
        }
    }

    // MARK: - Plane processing bridge

    private func processPlaneAnchors() {
        guard !isConfirmed else { return }

        // Collect mesh max Y for ceiling fallback
        let meshMaxY = computeMeshMaxY()

        let result = geometryProcessor.process(
            planes: detectedPlanes,
            meshMaxY: meshMaxY,
            currentTime: CACurrentMediaTime()
        )

        switch result {
        case .scanning(let progress):
            appState?.scanPhase = .scanning(progress: progress)
            roomModel?.scanProgress = progress

            // Start audio during scanning with preliminary dimensions
            if let candidate = geometryProcessor.latestCandidate,
               let audioEngine, let roomModel {
                if !audioEngine.isConfigured {
                    // First valid dimensions — configure and start at volume 0
                    roomModel.updateDimensions(candidate)
                    audioEngine.configure(dimensions: candidate, modes: roomModel.modes)
                    audioEngine.setVolume(0.0)
                    audioEngine.start()
                    logger.info("Audio started during scanning with preliminary dimensions")
                } else {
                    // Update frequencies as dimensions refine
                    roomModel.updateDimensions(candidate)
                    audioEngine.updateForNewDimensions(dimensions: candidate, modes: roomModel.modes)
                }
                // Tie volume to scan progress
                audioEngine.setVolume(progress)
            }

        case .confirmed(let dimensions):
            isConfirmed = true
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            roomModel?.updateDimensions(dimensions)
            roomModel?.isEnclosureConfirmed = true
            appState?.scanPhase = .confirmed(dimensions: dimensions)
            logger.info("Room confirmed: \(dimensions.Lx)×\(dimensions.Ly)×\(dimensions.Lz)m")
        }
    }

    // MARK: - Mesh bounding box

    private func computeMeshMaxY() -> Float? {
        guard let anchors = sceneView.session.currentFrame?.anchors else { return nil }
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        guard !meshAnchors.isEmpty else { return nil }

        var maxY: Float = -.greatestFiniteMagnitude

        for anchor in meshAnchors {
            let vertices = anchor.geometry.vertices
            let buffer = vertices.buffer.contents()
            let stride = vertices.stride
            let worldTransform = anchor.transform

            for i in 0..<vertices.count {
                let offset = buffer.advanced(by: stride * i)
                let localVertex = offset.assumingMemoryBound(to: simd_float3.self).pointee
                let worldVertex = worldTransform * simd_float4(localVertex, 1.0)
                maxY = max(maxY, worldVertex.y)
            }
        }

        return maxY > -.greatestFiniteMagnitude ? maxY : nil
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return }

        for plane in planes {
            detectedPlanes.append(PlaneInfo(plane))
        }
        processPlaneAnchors()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return }

        for plane in planes {
            let info = PlaneInfo(plane)
            if let idx = detectedPlanes.firstIndex(where: { $0.id == info.id }) {
                detectedPlanes[idx] = info
            }
        }
        processPlaneAnchors()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isSessionRunning, let roomModel, let audioEngine else { return }

        // 1. Coordinate remap: ARKit Y-up → model Z-up
        let arPos = frame.camera.transform.columns.3
        roomModel.playerPosition = simd_float3(arPos.x, arPos.z, arPos.y)

        // Push audio updates once engine is configured (during scanning or after confirmation)
        guard audioEngine.isConfigured else { return }

        // 2. LFO advance with real deltaTime
        let timestamp = frame.timestamp
        if lastFrameTime > 0 {
            let dt = Float(timestamp - lastFrameTime)
            roomModel.advanceLFO(deltaTime: min(dt, 0.1)) // cap at 100ms to handle pauses
        }
        lastFrameTime = timestamp

        // 3. Push amplitudes to audio engine
        let amps = roomModel.modeAmplitudes()
        audioEngine.updateAmplitudes(amps)

        // 4. Cache dominant mode for UI
        roomModel.dominantModeIndex = amps.enumerated().max(by: { $0.element < $1.element })?.offset
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        logger.error("AR session failed: \(error.localizedDescription)")
        appState?.scanPhase = .failed(reason: .timeout)
    }
}
