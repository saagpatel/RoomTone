import SwiftUI
import ARKit

@main
struct RoomToneApp: App {
    @State private var appState = AppState()
    @State private var audioEngine = RoomAudioEngine()
    @State private var roomModel = RoomModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLiDARAvailable {
                    ScanView(appState: appState)
                        .onAppear {
                            audioEngine.start()
                        }
                        .onDisappear {
                            audioEngine.stop()
                        }
                } else {
                    UnsupportedDeviceView()
                }
            }
            .onAppear {
                appState.isLiDARAvailable = ARWorldTrackingConfiguration
                    .supportsSceneReconstruction(.mesh)
            }
        }
    }
}
