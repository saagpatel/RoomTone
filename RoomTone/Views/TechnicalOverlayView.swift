import SwiftUI

/// Debug overlay showing all mode frequencies, room dimensions, and player position.
/// Positioned top-left with compact monospaced text on a translucent background.
struct TechnicalOverlayView: View {
    @Bindable var roomModel: RoomModel
    let dimensions: RoomDimensions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room info
            Text(String(format: "Lx:%.2f Ly:%.2f Lz:%.2fm", dimensions.Lx, dimensions.Ly, dimensions.Lz))
            Text(String(format: "Vol:%.1fm³ RT60:%.2fs", dimensions.volume, dimensions.estimatedRT60))
            Text(String(format: "Pos:(%.2f, %.2f, %.2f)",
                        roomModel.playerPosition.x,
                        roomModel.playerPosition.y,
                        roomModel.playerPosition.z))

            Divider()
                .background(.white.opacity(0.3))
                .padding(.vertical, 2)

            // All active modes
            let amplitudes = roomModel.modeAmplitudes()
            ForEach(Array(roomModel.modes.enumerated()), id: \.element.id) { i, mode in
                let amp = i < amplitudes.count ? amplitudes[i] : 0
                let axisLabel: String = switch mode.axis {
                case .axial: "Ax"
                case .tangential: "Tg"
                case .oblique: "Ob"
                }
                Text(String(format: "%6.1fHz (%d,%d,%d) %@ %.3f",
                            mode.frequency, mode.n, mode.m, mode.l, axisLabel, amp))
            }
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.white.opacity(0.8))
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 8)
        .padding(.top, 52) // below safe area
        .allowsHitTesting(false)
    }
}
