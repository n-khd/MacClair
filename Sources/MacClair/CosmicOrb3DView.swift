import SwiftUI
import SceneKit
import AppKit

// MARK: - SceneKit 3D Holographic Cosmic Orb

public struct CosmicOrb3DView: View {
    var scanning: Bool
    var hasScanned: Bool
    var isSuccess: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pointerX: Double = 0
    @State private var pointerY: Double = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    public init(scanning: Bool, hasScanned: Bool = false, isSuccess: Bool = false) {
        self.scanning = scanning
        self.hasScanned = hasScanned
        self.isSuccess = isSuccess
    }

    public var body: some View {
        ZStack {
            // Ambient soft glowing aura backdrop
            RadialGradient(
                colors: [
                    (scanning ? MacClairTheme.cyan : (hasScanned ? MacClairTheme.emerald : MacClairTheme.violet))
                        .opacity(scanning ? 0.35 : 0.22),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 130
            )
            .frame(width: 250, height: 250)
            .blur(radius: 18)
            .animation(.easeInOut(duration: 0.6), value: scanning)
            .animation(.easeInOut(duration: 0.6), value: hasScanned)

            // 3D SceneKit View
            CosmicOrbSceneRepresentable(
                scanning: scanning,
                hasScanned: hasScanned,
                isSuccess: isSuccess,
                pointerX: pointerX,
                pointerY: pointerY,
                dragOffset: dragOffset,
                reduceMotion: reduceMotion
            )
            .frame(width: 230, height: 230)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { val in
                        isDragging = true
                        dragOffset = val.translation
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                            dragOffset = .zero
                        }
                    }
            )
            .onContinuousHover { phase in
                guard !reduceMotion && !isDragging else { return }
                switch phase {
                case .active(let point):
                    // Normalize to [-1.0, 1.0] from center (115, 115)
                    pointerX = Double((point.x - 115) / 115)
                    pointerY = Double((point.y - 115) / 115)
                case .ended:
                    withAnimation(.easeOut(duration: 0.4)) {
                        pointerX = 0
                        pointerY = 0
                    }
                }
            }
        }
        .frame(width: 240, height: 240)
        .accessibilityLabel("Noyau 3D interactif MacClair")
    }
}

// MARK: - SceneKit NSViewRepresentable

private struct CosmicOrbSceneRepresentable: NSViewRepresentable {
    let scanning: Bool
    let hasScanned: Bool
    let isSuccess: Bool
    let pointerX: Double
    let pointerY: Double
    let dragOffset: CGSize
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false

        let scene = SCNScene()
        scnView.scene = scene

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 50.0
        cameraNode.position = SCNVector3(0, 0, 4.35)
        scene.rootNode.addChildNode(cameraNode)

        // Lighting Setup
        // 1. Ambient Fill
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.10, green: 0.14, blue: 0.25, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // 2. Key Omni Light (Cyan/Electric Blue)
        let keyLight = SCNLight()
        keyLight.type = .omni
        keyLight.color = NSColor(red: 0.10, green: 0.85, blue: 1.00, alpha: 1.0)
        keyLight.intensity = 1100
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.position = SCNVector3(-2.6, 2.8, 3.2)
        scene.rootNode.addChildNode(keyNode)

        // 3. Rim Omni Light (Magenta/Violet back-light)
        let rimLight = SCNLight()
        rimLight.type = .omni
        rimLight.color = NSColor(red: 0.75, green: 0.30, blue: 1.00, alpha: 1.0)
        rimLight.intensity = 950
        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.position = SCNVector3(2.8, -2.4, -2.2)
        scene.rootNode.addChildNode(rimNode)

        // Interactive Container Node (controlled by pointer parallax & drag)
        let container = SCNNode()
        container.name = "container"
        scene.rootNode.addChildNode(container)
        context.coordinator.containerNode = container

        // Floating Bobbing Node
        let floatingNode = SCNNode()
        floatingNode.name = "floating"
        container.addChildNode(floatingNode)
        context.coordinator.floatingNode = floatingNode

        // Setup 3D Geometry
        context.coordinator.setupGeometry(in: floatingNode)

        // Start Bobbing & Rotations
        context.coordinator.startAnimations(reduceMotion: reduceMotion, scanning: scanning)

        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        context.coordinator.updateState(
            scanning: scanning,
            hasScanned: hasScanned,
            isSuccess: isSuccess,
            pointerX: pointerX,
            pointerY: pointerY,
            dragOffset: dragOffset,
            reduceMotion: reduceMotion
        )
    }

    // MARK: - Scene Coordinator

    final class Coordinator {
        weak var containerNode: SCNNode?
        weak var floatingNode: SCNNode?

        var coreShellNode: SCNNode?
        var coreFacetNode: SCNNode?
        var coreLightNode: SCNNode?

        var outerRingNode: SCNNode?
        var middleRingNode: SCNNode?
        var innerRingNode: SCNNode?

        var particlesNode: SCNNode?
        var particleSystem: SCNParticleSystem?

        private var currentScanning = false

        func setupGeometry(in parent: SCNNode) {
            // 1. Central Core Sphere - Outer Crystal Shell
            let shellGeo = SCNSphere(radius: 0.88)
            shellGeo.segmentCount = 48
            let shellMat = SCNMaterial()
            shellMat.lightingModel = .physicallyBased
            shellMat.diffuse.contents = NSColor(red: 0.08, green: 0.18, blue: 0.45, alpha: 0.50)
            shellMat.metalness.contents = 0.2
            shellMat.roughness.contents = 0.1
            shellMat.transparency = 0.85
            shellMat.fresnelExponent = 2.2
            shellMat.emission.contents = NSColor(red: 0.05, green: 0.35, blue: 0.85, alpha: 0.35)
            shellGeo.materials = [shellMat]

            let shell = SCNNode(geometry: shellGeo)
            parent.addChildNode(shell)
            self.coreShellNode = shell

            // 2. Inner Faceted Geodesic Nucleus
            let facetGeo = SCNSphere(radius: 0.52)
            facetGeo.segmentCount = 14 // Geodesic facets
            let facetMat = SCNMaterial()
            facetMat.lightingModel = .constant
            facetMat.diffuse.contents = NSColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.95)
            facetMat.emission.contents = NSColor(red: 0.10, green: 0.55, blue: 1.0, alpha: 0.80)
            facetGeo.materials = [facetMat]

            let facet = SCNNode(geometry: facetGeo)
            parent.addChildNode(facet)
            self.coreFacetNode = facet

            // 3. Core Pulse Light
            let coreLight = SCNLight()
            coreLight.type = .omni
            coreLight.color = NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1.0)
            coreLight.intensity = 850
            let coreLightN = SCNNode()
            coreLightN.light = coreLight
            parent.addChildNode(coreLightN)
            self.coreLightNode = coreLightN

            // 4. Outer Ring (Azure Torus) + Satellites
            let outerTorus = SCNTorus(ringRadius: 1.54, pipeRadius: 0.024)
            outerTorus.ringSegmentCount = 48
            outerTorus.pipeSegmentCount = 18
            let outerMat = SCNMaterial()
            outerMat.lightingModel = .constant
            outerMat.diffuse.contents = NSColor(red: 0.10, green: 0.85, blue: 1.0, alpha: 0.95)
            outerMat.emission.contents = NSColor(red: 0.05, green: 0.50, blue: 0.95, alpha: 0.70)
            outerTorus.materials = [outerMat]

            let outerRing = SCNNode(geometry: outerTorus)
            outerRing.eulerAngles = SCNVector3(x: 1.12, y: 0.22, z: 0)
            parent.addChildNode(outerRing)
            self.outerRingNode = outerRing

            // Satellites on outer ring
            let sat1 = makeSatellite(radius: 0.054, color: NSColor(red: 0.90, green: 0.98, blue: 1.0, alpha: 1.0))
            sat1.position = SCNVector3(1.54, 0, 0)
            outerRing.addChildNode(sat1)

            let sat2 = makeSatellite(radius: 0.046, color: NSColor(red: 0.20, green: 0.90, blue: 1.0, alpha: 1.0))
            sat2.position = SCNVector3(-1.54, 0, 0)
            outerRing.addChildNode(sat2)

            // 5. Middle Ring (Cosmic Violet Torus) + Satellite
            let midTorus = SCNTorus(ringRadius: 1.30, pipeRadius: 0.022)
            midTorus.ringSegmentCount = 48
            midTorus.pipeSegmentCount = 18
            let midMat = SCNMaterial()
            midMat.lightingModel = .constant
            midMat.diffuse.contents = NSColor(red: 0.65, green: 0.38, blue: 1.0, alpha: 0.92)
            midMat.emission.contents = NSColor(red: 0.45, green: 0.18, blue: 0.90, alpha: 0.65)
            midTorus.materials = [midMat]

            let midRing = SCNNode(geometry: midTorus)
            midRing.eulerAngles = SCNVector3(x: -0.92, y: 0.42, z: 0.20)
            parent.addChildNode(midRing)
            self.middleRingNode = midRing

            let sat3 = makeSatellite(radius: 0.050, color: NSColor(red: 0.85, green: 0.50, blue: 1.0, alpha: 1.0))
            sat3.position = SCNVector3(0, 1.30, 0)
            midRing.addChildNode(sat3)

            // 6. Inner Ring (Electric Mint / Cyan)
            let inTorus = SCNTorus(ringRadius: 1.08, pipeRadius: 0.018)
            inTorus.ringSegmentCount = 48
            let inMat = SCNMaterial()
            inMat.lightingModel = .constant
            inMat.diffuse.contents = NSColor(red: 0.0, green: 0.92, blue: 0.65, alpha: 0.90)
            inMat.emission.contents = NSColor(red: 0.0, green: 0.60, blue: 0.45, alpha: 0.60)
            inTorus.materials = [inMat]

            let inRing = SCNNode(geometry: inTorus)
            inRing.eulerAngles = SCNVector3(x: 0.28, y: -1.05, z: 0.38)
            parent.addChildNode(inRing)
            self.innerRingNode = inRing

            // 7. Ambient Stardust Particles
            let pSystem = SCNParticleSystem()
            pSystem.birthRate = 18
            pSystem.particleLifeSpan = 4.0
            pSystem.particleSize = 0.028
            pSystem.particleColor = NSColor(red: 0.30, green: 0.85, blue: 1.0, alpha: 0.70)
            pSystem.emitterShape = SCNSphere(radius: 1.6)
            pSystem.spreadingAngle = 180
            pSystem.speedFactor = 0.12
            pSystem.isLightingEnabled = false

            let pNode = SCNNode()
            pNode.addParticleSystem(pSystem)
            parent.addChildNode(pNode)
            self.particlesNode = pNode
            self.particleSystem = pSystem
        }

        private func makeSatellite(radius: CGFloat, color: NSColor) -> SCNNode {
            let geo = SCNSphere(radius: radius)
            geo.segmentCount = 18
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = color
            mat.emission.contents = color
            geo.materials = [mat]
            return SCNNode(geometry: geo)
        }

        func startAnimations(reduceMotion: Bool, scanning: Bool) {
            guard !reduceMotion else { return }

            // Floating bobbing motion
            let floatUp = SCNAction.moveBy(x: 0, y: 0.07, z: 0, duration: 2.2)
            floatUp.timingMode = .easeInEaseOut
            let floatDown = floatUp.reversed()
            let bobSeq = SCNAction.sequence([floatUp, floatDown])
            floatingNode?.runAction(SCNAction.repeatForever(bobSeq), forKey: "bobbing")

            // Inner faceted core rotation
            let facetRot = SCNAction.rotateBy(x: CGFloat.pi * 2, y: -CGFloat.pi * 2, z: CGFloat.pi, duration: 16.0)
            coreFacetNode?.runAction(SCNAction.repeatForever(facetRot), forKey: "facetRot")

            // Apply ring spin actions
            applyRingRotations(scanning: scanning)
        }

        private func applyRingRotations(scanning: Bool) {
            currentScanning = scanning

            let outerDuration: Double = scanning ? 2.2 : 11.0
            let midDuration: Double = scanning ? 1.7 : 8.5
            let inDuration: Double = scanning ? 1.3 : 6.8

            // Outer ring rotates around Z
            let outerAction = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: outerDuration)
            )
            outerRingNode?.runAction(outerAction, forKey: "outerSpin")

            // Mid ring rotates around Z in reverse
            let midAction = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: 0, z: -CGFloat.pi * 2, duration: midDuration)
            )
            middleRingNode?.runAction(midAction, forKey: "midSpin")

            // Inner ring rotates around Y
            let inAction = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: inDuration)
            )
            innerRingNode?.runAction(inAction, forKey: "inSpin")

            // Particle birth rate & core light
            particleSystem?.birthRate = scanning ? 48 : 18
            coreLightNode?.light?.intensity = scanning ? 2100 : 850
        }

        func updateState(
            scanning: Bool,
            hasScanned: Bool,
            isSuccess: Bool,
            pointerX: Double,
            pointerY: Double,
            dragOffset: CGSize,
            reduceMotion: Bool
        ) {
            // Check scanning transition
            if scanning != currentScanning {
                applyRingRotations(scanning: scanning)
            }

            // Mouse parallax tilt & drag orientation
            guard !reduceMotion else { return }

            let dragYaw = Double(dragOffset.width) * 0.012
            let dragPitch = -Double(dragOffset.height) * 0.012

            let targetYaw = (pointerX * 0.42) + dragYaw
            let targetPitch = (-pointerY * 0.42) + dragPitch

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.22
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
            containerNode?.eulerAngles = SCNVector3(x: CGFloat(targetPitch), y: CGFloat(targetYaw), z: 0)
            SCNTransaction.commit()

            // Success pulse
            if isSuccess || (hasScanned && !scanning) {
                // Flash green/cyan on core light
                let emeraldColor = NSColor(red: 0.00, green: 0.92, blue: 0.65, alpha: 1.0)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                coreLightNode?.light?.color = emeraldColor
                SCNTransaction.commit()
            } else {
                let cyanColor = NSColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1.0)
                coreLightNode?.light?.color = cyanColor
            }
        }
    }
}
