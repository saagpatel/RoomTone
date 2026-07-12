import SwiftUI
import UIKit

struct ScanView: View {
    @Bindable var appState: AppState
    var arSessionManager: ARSessionManager
    @Bindable var roomModel: RoomModel

    var body: some View {
        ZStack {
            // AR camera feed
            ARSceneView(sceneView: arSessionManager.sceneView)
                .ignoresSafeArea()

            // Overlay
            VStack {
                Spacer()
                scanOverlay
            }
            .padding(.bottom, 48)
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var scanOverlay: some View {
        switch appState.scanPhase {
        case .idle:
            idleOverlay

        case .scanning(let progress):
            scanningOverlay(progress: progress)

        case .confirmed:
            // Transitioning to MainExperienceView — show nothing
            EmptyView()

        case .failed(let reason):
            failedOverlay(reason: reason)
        }
    }

    // MARK: - Idle

    private var idleOverlay: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .thin))

            Text("Room Tone")
                .font(.system(size: 32, weight: .bold))

            Text("Scan your room to hear\nits resonant character.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                arSessionManager.startScanning()
            } label: {
                Text("Start Scanning")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .padding(.top, 8)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Scanning

    private func scanningOverlay(progress: Float) -> some View {
        VStack(spacing: 20) {
            Text("Pan your device around the room")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                detectionRow(label: "Floor", detected: roomModel.scanProgress >= 0.33)
                detectionRow(label: "Wall", detected: roomModel.scanProgress >= 0.66)
                detectionRow(label: "Perpendicular wall", detected: roomModel.scanProgress >= 1.0)
            }

            ProgressView(value: progress)
                .tint(.white)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func detectionRow(label: String, detected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: detected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(detected ? .green : .secondary)
                .font(.body)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(detected ? .primary : .secondary)
        }
    }

    // MARK: - Failed

    private func failedOverlay(reason: ScanFailureReason) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.yellow)

            Text(failureTitle(for: reason))
                .font(.headline)

            Text(failureMessage(for: reason))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                appState.scanPhase = .idle
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)

            if reason == .noEnclosure {
                Button("Try Anyway") {
                    // Force confirmation with default dimensions
                    let estimated = RoomDimensions(
                        Lx: 4.0, Ly: 3.0,
                        Lz: RoomGeometryProcessor.defaultCeilingHeight
                    )
                    roomModel.updateDimensions(estimated)
                    roomModel.isEnclosureConfirmed = true
                    appState.scanPhase = .confirmed(dimensions: estimated)
                }
                .buttonStyle(.bordered)
            }

            if reason == .cameraDenied {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func failureTitle(for reason: ScanFailureReason) -> String {
        switch reason {
        case .noEnclosure: "No Enclosed Space"
        case .timeout: "Scan Timed Out"
        case .deviceUnsupported: "Unsupported Device"
        case .cameraDenied: "Camera Access Required"
        }
    }

    private func failureMessage(for reason: ScanFailureReason) -> String {
        switch reason {
        case .noEnclosure:
            "Room Tone works best in enclosed spaces with walls and a ceiling."
        case .timeout:
            "Could not detect room geometry. Try panning slowly around all walls."
        case .deviceUnsupported:
            "This device does not support LiDAR scanning."
        case .cameraDenied:
            "Allow camera access in Settings so ARKit can map room geometry. Room Tone does not save images or video."
        }
    }
}
