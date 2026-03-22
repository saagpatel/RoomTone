import ARKit
import SceneKit

/// Manages translucent wireframe overlays on detected wall plane anchors.
///
/// Set as `ARSCNView.delegate` (separate from `ARSession.delegate`).
/// Creates SCNPlane geometry with wireframe material for each wall anchor,
/// and updates size/position as anchors are refined by ARKit.
final class WireframeOverlayManager: NSObject, ARSCNViewDelegate {

    private static func makeWireframeMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.fillMode = .lines
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.10)
        material.isDoubleSided = true
        material.lightingModel = .constant
        return material
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: any SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.classification == .wall else {
            return nil
        }
        // Return empty container node — child geometry added in didAdd
        return SCNNode()
    }

    func renderer(_ renderer: any SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.classification == .wall else { return }

        let extent = planeAnchor.planeExtent
        let plane = SCNPlane(width: CGFloat(extent.width), height: CGFloat(extent.height))
        plane.firstMaterial = Self.makeWireframeMaterial()

        let planeNode = SCNNode(geometry: plane)
        // Rotate to stand upright — ARKit plane anchors use a Y-up local frame
        // even for vertical planes. SCNPlane renders in the XY plane by default.
        planeNode.eulerAngles.x = -.pi / 2
        planeNode.name = "wireframe"

        node.addChildNode(planeNode)
    }

    func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
              planeAnchor.classification == .wall,
              let planeNode = node.childNode(withName: "wireframe", recursively: false),
              let plane = planeNode.geometry as? SCNPlane else { return }

        let extent = planeAnchor.planeExtent
        plane.width = CGFloat(extent.width)
        plane.height = CGFloat(extent.height)
    }
}
