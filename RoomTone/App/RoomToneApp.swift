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
            #if DEBUG
            if let shot = AppStoreScreenshot.requested {
                AppStoreScreenshotView(shot: shot)
            } else {
                launchContent
            }
            #else
            launchContent
            #endif
        }
    }

    @ViewBuilder
    private var launchContent: some View {
        if !hasSeenOnboarding {
            OnboardingView()
        } else {
            mainContent
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

#if DEBUG
/// Global shot numbers match APPSTORE-METADATA.md, including device-only rows.
private enum AppStoreScreenshot: Int {
    case iPhoneScan = 1
    case iPhoneDrone = 2
    case iPhoneAmbient = 3
    case iPhoneTechnicalOverlay = 4
    case iPadScan = 5
    case iPadDrone = 6
    case iPadTechnicalOverlay = 7
    case iPadSettings = 8

    static var requested: AppStoreScreenshot? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-AppStoreScreenshot"),
              arguments.indices.contains(index + 1),
              let number = Int(arguments[index + 1]) else { return nil }
        return AppStoreScreenshot(rawValue: number)
    }
}

private struct AppStoreScreenshotView: View {
    let shot: AppStoreScreenshot
    @State private var roomModel: RoomModel
    @State private var showSettings = true
    private let settingsDefaults: UserDefaults

    init(shot: AppStoreScreenshot) {
        self.shot = shot
        let room = RoomModel()
        // Settings only reads dimensions; avoid generating random mode UUIDs,
        // running an AR session, or starting synthesis for this still image.
        room.dimensions = .testRoom
        _roomModel = State(initialValue: room)
        let defaults = UserDefaults(suiteName: "AppStoreScreenshot") ?? .standard
        defaults.set(false, forKey: "showTechnicalOverlay")
        settingsDefaults = defaults
    }

    var body: some View {
        Group {
            if shot == .iPadSettings {
                // The real Settings sheet over a plain background, with no
                // fabricated camera image or mock product controls.
                Color.black
                    .ignoresSafeArea()
                    .sheet(isPresented: $showSettings) {
                        SettingsView(roomModel: roomModel)
                            .defaultAppStorage(settingsDefaults)
                            .preferredColorScheme(.dark)
                    }
            } else {
                // Shots 1...7 require a real LiDAR scan and are skipped by the
                // capture script. Never substitute a simulated camera view.
                UnsupportedDeviceView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
