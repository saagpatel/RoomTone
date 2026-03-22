import SwiftUI

struct SettingsView: View {
    @AppStorage("showTechnicalOverlay") private var showTechnicalOverlay = false
    @Environment(\.dismiss) private var dismiss

    var roomModel: RoomModel?

    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    Toggle("Technical Overlay", isOn: $showTechnicalOverlay)

                    Text("Shows all mode frequencies, room dimensions, and player position.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let dims = roomModel?.dimensions {
                    Section("Room") {
                        LabeledContent("Dimensions") {
                            Text(String(format: "%.1f × %.1f × %.1fm", dims.Lx, dims.Ly, dims.Lz))
                                .font(.caption.monospaced())
                        }
                        LabeledContent("Volume") {
                            Text(String(format: "%.1f m³", dims.volume))
                                .font(.caption.monospaced())
                        }
                        LabeledContent("RT60") {
                            Text(String(format: "%.2fs", dims.estimatedRT60))
                                .font(.caption.monospaced())
                        }
                        if dims.requiresOctaveShift {
                            LabeledContent("Octave Shift") {
                                Text("Active")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
