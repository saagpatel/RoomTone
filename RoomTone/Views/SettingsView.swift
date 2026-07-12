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

                Section("About") {
                    Link("Privacy Policy", destination: URL(string: "https://github.com/saagpatel/RoomTone/blob/main/PRIVACY.md")!)
                    Link("Support", destination: URL(string: "https://github.com/saagpatel/RoomTone/issues")!)

                    Text("Room geometry and synthesized recordings stay on this device unless you explicitly share a recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
