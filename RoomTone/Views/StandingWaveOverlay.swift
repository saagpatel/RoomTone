import SwiftUI

/// 2D screen-space standing wave visualization at 10fps.
///
/// Draws abstract sine wave patterns for axial modes, with brightness
/// encoding node/antinode positions and a marker showing player position.
struct StandingWaveOverlay: View {
    @Bindable var roomModel: RoomModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { _ in
            Canvas { context, size in
                guard let dims = roomModel.dimensions else { return }

                let amplitudes = roomModel.modeAmplitudes()
                let modes = roomModel.modes
                let pos = roomModel.playerPosition

                // Find strongest axial mode per axis
                let xMode = strongestAxialMode(for: .x, modes: modes, amplitudes: amplitudes)
                let yMode = strongestAxialMode(for: .y, modes: modes, amplitudes: amplitudes)
                let zMode = strongestAxialMode(for: .z, modes: modes, amplitudes: amplitudes)

                // X-axis wave — bottom region
                if let (mode, amp) = xMode {
                    let region = CGRect(
                        x: 24, y: size.height * 0.75,
                        width: size.width - 48, height: size.height * 0.15
                    )
                    drawWave(
                        context: &context,
                        modeIndex: mode.n,
                        amplitude: amp,
                        playerNormalized: pos.x / dims.Lx,
                        region: region,
                        horizontal: true
                    )
                }

                // Y-axis wave — middle region
                if let (mode, amp) = yMode {
                    let region = CGRect(
                        x: 24, y: size.height * 0.55,
                        width: size.width - 48, height: size.height * 0.15
                    )
                    drawWave(
                        context: &context,
                        modeIndex: mode.m,
                        amplitude: amp,
                        playerNormalized: pos.y / dims.Ly,
                        region: region,
                        horizontal: true
                    )
                }

                // Z-axis wave — left edge, vertical
                if let (mode, amp) = zMode {
                    let region = CGRect(
                        x: 8, y: size.height * 0.2,
                        width: size.width * 0.08, height: size.height * 0.5
                    )
                    drawWave(
                        context: &context,
                        modeIndex: mode.l,
                        amplitude: amp,
                        playerNormalized: pos.z / dims.Lz,
                        region: region,
                        horizontal: false
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func strongestAxialMode(
        for axis: WallAxis,
        modes: [RoomMode],
        amplitudes: [Float]
    ) -> (RoomMode, Float)? {
        var best: (RoomMode, Float)?
        for (i, mode) in modes.enumerated() where mode.wallAxis == axis {
            let amp = i < amplitudes.count ? amplitudes[i] : 0
            if best == nil || amp > (best?.1 ?? 0) {
                best = (mode, amp)
            }
        }
        return best
    }

    private func drawWave(
        context: inout GraphicsContext,
        modeIndex: Int,
        amplitude: Float,
        playerNormalized: Float,
        region: CGRect,
        horizontal: Bool
    ) {
        guard modeIndex > 0 else { return }

        let sampleCount = 60
        let overallOpacity = Double(min(amplitude * 15, 0.6)) // scale up for visibility

        for i in 0..<sampleCount {
            let t0 = Float(i) / Float(sampleCount)
            let t1 = Float(i + 1) / Float(sampleCount)

            let waveVal0 = sin(Float(modeIndex) * .pi * t0)
            let waveVal1 = sin(Float(modeIndex) * .pi * t1)

            let segmentBrightness = Double(abs(waveVal0 + waveVal1) / 2.0)

            let p0: CGPoint
            let p1: CGPoint

            if horizontal {
                let x0 = region.minX + CGFloat(t0) * region.width
                let x1 = region.minX + CGFloat(t1) * region.width
                let y0 = region.midY - CGFloat(waveVal0) * region.height * 0.4
                let y1 = region.midY - CGFloat(waveVal1) * region.height * 0.4
                p0 = CGPoint(x: x0, y: y0)
                p1 = CGPoint(x: x1, y: y1)
            } else {
                let y0 = region.minY + CGFloat(t0) * region.height
                let y1 = region.minY + CGFloat(t1) * region.height
                let x0 = region.midX + CGFloat(waveVal0) * region.width * 0.4
                let x1 = region.midX + CGFloat(waveVal1) * region.width * 0.4
                p0 = CGPoint(x: x0, y: y0)
                p1 = CGPoint(x: x1, y: y1)
            }

            var path = Path()
            path.move(to: p0)
            path.addLine(to: p1)

            context.stroke(
                path,
                with: .color(.white.opacity(segmentBrightness * overallOpacity)),
                lineWidth: 1.5
            )
        }

        // Player position marker
        let clampedPos = max(0, min(1, playerNormalized))
        let markerPoint: CGPoint
        if horizontal {
            let x = region.minX + CGFloat(clampedPos) * region.width
            let waveVal = sin(Float(modeIndex) * .pi * clampedPos)
            let y = region.midY - CGFloat(waveVal) * region.height * 0.4
            markerPoint = CGPoint(x: x, y: y)
        } else {
            let y = region.minY + CGFloat(clampedPos) * region.height
            let waveVal = sin(Float(modeIndex) * .pi * clampedPos)
            let x = region.midX + CGFloat(waveVal) * region.width * 0.4
            markerPoint = CGPoint(x: x, y: y)
        }

        let markerRect = CGRect(
            x: markerPoint.x - 4, y: markerPoint.y - 4,
            width: 8, height: 8
        )
        context.fill(
            Path(ellipseIn: markerRect),
            with: .color(.white.opacity(overallOpacity + 0.2))
        )
    }
}
