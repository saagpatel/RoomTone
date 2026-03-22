import SwiftUI

/// Centered dominant frequency display with a radial gradient pulse
/// tied to the audio LFO phase for audiovisual coherence.
struct PulseIndicatorView: View {
    @Bindable var roomModel: RoomModel

    private let baseRadius: CGFloat = 40
    private let pulseRange: CGFloat = 8

    var body: some View {
        ZStack {
            // Radial gradient pulse
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: pulseRadius
                    )
                )
                .frame(width: pulseRadius * 2, height: pulseRadius * 2)

            // Frequency display
            VStack(spacing: 8) {
                if let idx = roomModel.dominantModeIndex, idx < roomModel.modes.count {
                    let mode = roomModel.modes[idx]

                    Text(String(format: "%.1f Hz", mode.frequency))
                        .font(.system(size: 52, weight: .light, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("(\(mode.n), \(mode.m), \(mode.l)) — \(mode.axis.displayLabel)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private var pulseRadius: CGFloat {
        baseRadius + pulseRange * CGFloat(sin(roomModel.lfoPhase))
    }
}
