import ARKit
import AVFoundation
import SceneKit
import os

/// Manages the ARSession lifecycle, plane detection, coordinate remapping,
/// and bridges ARKit data into RoomModel and AppState.
///
/// ARSessionDelegate callbacks arrive on a background serial queue.
/// All @Observable state mutations are dispatched to the main thread.
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
    private var warningTimer: Timer?
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
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginARSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.beginARSession()
                    } else {
                        self?.appState?.scanPhase = .failed(reason: .cameraDenied)
                    }
                }
            }
        case .denied, .restricted:
            appState?.scanPhase = .failed(reason: .cameraDenied)
        @unknown default:
            appState?.scanPhase = .failed(reason: .cameraDenied)
        }
    }

    private func beginARSession() {
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

        startTimeoutTimers()
        logger.info("AR session started — scanning")
    }

    func pauseScanning() {
        sceneView.session.pause()
        isSessionRunning = false
        invalidateTimers()
        logger.info("AR session paused")
    }

    /// Continue position tracking without plane processing (for MainExperienceView).
    func resumeTracking() {
        isSessionRunning = true
        logger.info("AR session — tracking only")
    }

    // MARK: - Timeout

    private func startTimeoutTimers() {
        invalidateTimers()

        // 20s check for no-enclosure
        warningTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
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

    private func invalidateTimers() {
        warningTimer?.invalidate()
        warningTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    // MARK: - Plane processing bridge (always called on main thread)

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
                    roomModel.updateDimensions(candidate)
                    audioEngine.configure(dimensions: candidate, modes: roomModel.modes)
                    audioEngine.setVolume(0.0)
                    audioEngine.start()
                    logger.info("Audio started during scanning with preliminary dimensions")
                } else {
                    roomModel.updateDimensions(candidate)
                    audioEngine.updateForNewDimensions(dimensions: candidate, modes: roomModel.modes)
                }
                audioEngine.setVolume(progress)
            }

        case .confirmed(let dimensions):
            isConfirmed = true
            invalidateTimers()
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
//
// All callbacks arrive on ARKit's background serial queue.
// State mutations are dispatched to main thread to avoid data races
// with @Observable property reads from SwiftUI.

extension ARSessionManager: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let newPlanes = anchors.compactMap { $0 as? ARPlaneAnchor }.map(PlaneInfo.init)
        guard !newPlanes.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.detectedPlanes.append(contentsOf: newPlanes)
            self.processPlaneAnchors()
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let updatedPlanes = anchors.compactMap { $0 as? ARPlaneAnchor }.map(PlaneInfo.init)
        guard !updatedPlanes.isEmpty else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for plane in updatedPlanes {
                if let idx = self.detectedPlanes.firstIndex(where: { $0.id == plane.id }) {
                    self.detectedPlanes[idx] = plane
                }
            }
            self.processPlaneAnchors()
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isSessionRunning else { return }

        // Extract values from frame on the ARKit queue (safe — frame is retained)
        let arPos = frame.camera.transform.columns.3
        let modelPosition = simd_float3(arPos.x, arPos.z, arPos.y)
        let timestamp = frame.timestamp

        DispatchQueue.main.async { [weak self] in
            guard let self, let roomModel = self.roomModel, let audioEngine = self.audioEngine else { return }

            // 1. Coordinate remap: ARKit Y-up → model Z-up
            roomModel.playerPosition = modelPosition

            // Push audio updates once engine is configured
            guard audioEngine.isConfigured else { return }

            // 2. LFO advance with real deltaTime
            if self.lastFrameTime > 0 {
                let dt = Float(timestamp - self.lastFrameTime)
                roomModel.advanceLFO(deltaTime: min(dt, 0.1))
            }
            self.lastFrameTime = timestamp

            // 3. Push amplitudes to audio engine
            let amps = roomModel.modeAmplitudes()
            audioEngine.updateAmplitudes(amps)

            // 4. Cache dominant mode for UI
            roomModel.dominantModeIndex = amps.enumerated().max(by: { $0.element < $1.element })?.offset
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        logger.error("AR session failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.appState?.scanPhase = .failed(reason: .timeout)
        }
    }
}
