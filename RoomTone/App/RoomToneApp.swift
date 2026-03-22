import SwiftUI
import ARKit

@main
struct RoomToneApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var appState = AppState()
    @State private var audioEngine = RoomAudioEngine()
    @State private var roomModel = RoomModel()
    @State private var arSessionManager = ARSessionManager()

    var body: some Scene {
        WindowGroup {
            if !hasSeenOnboarding {
                OnboardingView()
            } else {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if appState.isLiDARAvailable {
                switch appState.scanPhase {
                case .idle, .scanning, .failed:
                    ScanView(
                        appState: appState,
                        arSessionManager: arSessionManager,
                        roomModel: roomModel
                    )
                case .confirmed(let dimensions):
                    MainExperienceView(
                        appState: appState,
                        audioEngine: audioEngine,
                        roomModel: roomModel,
                        arSessionManager: arSessionManager,
                        dimensions: dimensions
                    )
                }
            } else {
                UnsupportedDeviceView()
            }
        }
        .onAppear {
            appState.isLiDARAvailable = ARWorldTrackingConfiguration
                .supportsSceneReconstruction(.mesh)
            arSessionManager.bind(
                appState: appState,
                roomModel: roomModel,
                audioEngine: audioEngine
            )
        }
    }
}
