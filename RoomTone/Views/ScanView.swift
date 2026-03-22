import SwiftUI

struct ScanView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.primary)

            Text("Room Tone")
                .font(.system(size: 36, weight: .bold))

            Text("Scan your room to hear\nits resonant character.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            scanContent

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var scanContent: some View {
        switch appState.scanPhase {
        case .idle:
            Button {
                appState.scanPhase = .scanning(progress: 0.0)
            } label: {
                Text("Start Scanning")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)

        case .scanning(let progress):
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .tint(.primary)
                Text("Scanning — pan your device around the room")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .confirmed:
            Text("Room confirmed")
                .font(.headline)
                .foregroundStyle(.green)

        case .failed(let reason):
            VStack(spacing: 12) {
                Text("Scan failed")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(failureMessage(for: reason))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func failureMessage(for reason: ScanFailureReason) -> String {
        switch reason {
        case .noEnclosure:
            "No enclosed space detected. Room Tone works best in rooms with a ceiling."
        case .timeout:
            "Could not detect room geometry. Try scanning in a different room."
        case .deviceUnsupported:
            "This device does not support LiDAR scanning."
        }
    }
}

#Preview {
    ScanView(appState: AppState())
}
