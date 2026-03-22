import SwiftUI
import ARKit

/// UIViewRepresentable wrapper for ARSCNView.
/// The ARSCNView instance is owned by ARSessionManager and reused across view transitions.
struct ARSceneView: UIViewRepresentable {
    let sceneView: ARSCNView

    func makeUIView(context: Context) -> ARSCNView {
        sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No-op: ARSessionManager controls the session lifecycle
    }
}
