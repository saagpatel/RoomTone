import SwiftUI

struct MainExperienceView: View {
    @Bindable var appState: AppState
    var audioEngine: RoomAudioEngine
    @Bindable var roomModel: RoomModel
    var arSessionManager: ARSessionManager
    let dimensions: RoomDimensions

    @AppStorage("showTechnicalOverlay") private var showTechnicalOverlay = false
    @State private var showSettings = false
    @State private var lastRecordingURL: URL?
    @State private var recordingError: String?

    var body: some View {
        ZStack {
            // Layer 1: AR camera feed + SceneKit wireframes
            ARSceneView(sceneView: arSessionManager.sceneView)
                .ignoresSafeArea()

            // Layer 2: Standing wave overlay (10fps Canvas)
            StandingWaveOverlay(roomModel: roomModel)

            // Layer 3: Technical overlay (conditional)
            if showTechnicalOverlay {
                TechnicalOverlayView(roomModel: roomModel, dimensions: dimensions)
            }

            // Layer 4: Controls overlay
            VStack {
                topBar
                Spacer()
                PulseIndicatorView(roomModel: roomModel)
                Spacer()
                bottomControls
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(roomModel: roomModel)
        }
        .alert("Recording Unavailable", isPresented: Binding(
            get: { recordingError != nil },
            set: { if !$0 { recordingError = nil } }
        )) {
            Button("OK", role: .cancel) { recordingError = nil }
        } message: {
            Text(recordingError ?? "The recording could not be started.")
        }
        .onAppear {
            if !audioEngine.isConfigured {
                // Fallback: configure if not already started during scanning
                audioEngine.configure(dimensions: dimensions, modes: roomModel.modes)
                audioEngine.startWithFadeIn()
            } else {
                // Audio already running from scan-progress fade — ensure full volume
                audioEngine.setVolume(1.0)
            }
            arSessionManager.resumeTracking()
        }
        .onDisappear {
            audioEngine.stopWithFadeOut()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text(String(format: "%.1fm × %.1fm × %.1fm", dimensions.Lx, dimensions.Ly, dimensions.Lz))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Timbre toggle
            HStack {
                Text("Timbre")
                    .font(.subheadline)
                Spacer()
                Picker("Timbre", selection: $appState.audioTimbre) {
                    Text("Drone").tag(AudioTimbre.drone)
                    Text("Ambient").tag(AudioTimbre.ambient)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .onChange(of: appState.audioTimbre) { _, newTimbre in
                audioEngine.setTimbre(newTimbre)
            }

            // Record button
            if let recorder = audioEngine.recorder {
                Button {
                    if recorder.isRecording {
                        if let url = recorder.stopRecording() {
                            lastRecordingURL = url
                        }
                    } else {
                        lastRecordingURL = nil
                        do {
                            try recorder.startRecording()
                        } catch {
                            recordingError = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                            .foregroundStyle(recorder.isRecording ? .red : .white)
                        Text(recorder.isRecording ? "Stop Recording" : "Record")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(.white)

                if let lastRecordingURL {
                    ShareLink(item: lastRecordingURL) {
                        Label("Share Recording", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

}
