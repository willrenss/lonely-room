import SwiftUI
import SceneKit

// MARK: - SceneKit Bridge
struct KostSceneView: UIViewRepresentable {
    @ObservedObject var vm: KostViewModel

    func makeUIView(context: Context) -> SCNView {
        let scene = makeScene()
        let view  = SCNView()
        view.scene                    = scene
        view.pointOfView              = vm.cameraNode
        view.backgroundColor          = .black
        view.antialiasingMode         = .multisampling4X
        view.autoenablesDefaultLighting = false

        vm.scnView   = view
        vm.sceneRoot = scene.rootNode

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        context.coordinator.tapGesture = tap
        context.coordinator.panGesture = pan

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.pointOfView = vm.cameraNode
    }

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm) }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let vm: KostViewModel
        weak var tapGesture: UITapGestureRecognizer?
        weak var panGesture: UIPanGestureRecognizer?

        private var dragOffset: SIMD2<Float> = .zero
        private var panIsDragging = false
        private var isRotating = false
        private var lastPanX: CGFloat = 0

        init(vm: KostViewModel) { self.vm = vm }

        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            if let pan = panGesture,
               (pan.state == .changed || pan.state == .began),
               panIsDragging { return }

            let pt = gesture.location(in: view)

            // Stack mode: tap on target furniture to stack source onto it
            if vm.pendingStackSource != nil {
                let hit = vm.hitTestFurniture(at: pt)
                if let target = hit {
                    vm.stackItemOnto(target)
                } else {
                    vm.cancelStacking()
                }
                return
            }

            if let type = vm.pendingType {
                if type.isWallMounted {
                    // Wall-mounted: ray-cast to nearest wall surface
                    if let result = vm.hitTestWall(at: pt) {
                        vm.placeWallFurniture(type: type, position: result.position, yaw: result.yaw)
                    }
                } else {
                    if let worldPos = vm.hitTestFloor(at: pt) {
                        vm.placeFurniture(at: worldPos)
                    }
                }
            } else {
                let hit = vm.hitTestFurniture(at: pt)
                vm.selectFurniture(hit)
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard vm.pendingType == nil else { return }
            guard let view = gesture.view as? SCNView else { return }
            let pt = gesture.location(in: view)

            switch gesture.state {
            case .began:
                panIsDragging = false
                isRotating = false
                dragOffset = .zero
                lastPanX = pt.x
                if let hit = vm.hitTestFurniture(at: pt) {
                    vm.selectFurniture(hit)
                    // Compute drag offset using the item's own Y plane
                    let itemY = hit.node.position.y
                    if let worldPos = vm.hitTestPlane(at: pt, y: itemY) {
                        let fp = hit.node.position
                        dragOffset = SIMD2<Float>(worldPos.x - fp.x, worldPos.z - fp.z)
                    }
                } else {
                    isRotating = true
                }
            case .changed:
                let translation = gesture.translation(in: view)
                let moveDist = hypot(translation.x, translation.y)
                if moveDist > 6 { panIsDragging = true }

                if isRotating {
                    let dx = pt.x - lastPanX
                    let sensitivity: Float = .pi / Float(view.bounds.width)
                    vm.rotateCamera(by: Float(dx) * sensitivity)
                    lastPanX = pt.x
                } else {
                    guard panIsDragging, let item = vm.selectedFurniture else { return }
                    // Always unproject onto the item's own Y plane — never drops to Y=0
                    let itemY = item.node.position.y
                    if let worldPos = vm.hitTestPlane(at: pt, y: itemY) {
                        let adjusted = SCNVector3(worldPos.x - dragOffset.x,
                                                 itemY,
                                                 worldPos.z - dragOffset.y)
                        vm.moveFurniture(item, to: adjusted)
                    }
                }
            case .ended, .cancelled:
                panIsDragging = false
                isRotating = false
                dragOffset = .zero
            default:
                break
            }
        }
    }

    // MARK: - Make Scene
    func makeScene() -> SCNScene {
        let scene = SCNScene()
        let wallColor  = UIColor(red:0.98, green:0.97, blue:0.94, alpha:1)
        let floorColor = UIColor(red:0.76, green:0.62, blue:0.44, alpha:1)
        let ceilColor  = UIColor(red:0.99, green:0.98, blue:0.96, alpha:1)

        let roomW: Float = 5.6
        let roomH: Float = 2.8
        let roomD: Float = 3.6
        let wT: Float = 0.18

        let innerLeft  = -roomW / 2
        let innerRight =  roomW / 2
        let innerFront =  roomD / 2
        let innerBack  = -roomD / 2

        func box(_ w: Float, _ h: Float, _ d: Float, color: UIColor, pos: SCNVector3) {
            let geo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0)
            geo.firstMaterial?.diffuse.contents = color
            geo.firstMaterial?.lightingModel = .lambert
            let n = SCNNode(geometry: geo); n.position = pos
            scene.rootNode.addChildNode(n)
        }

        // ── Floor ──
        let floorPlane = SCNPlane(width: CGFloat(roomW), height: CGFloat(roomD))
        floorPlane.firstMaterial?.diffuse.contents = floorColor
        floorPlane.firstMaterial?.lightingModel = .lambert
        floorPlane.firstMaterial?.isDoubleSided = true
        let floorNode = SCNNode(geometry: floorPlane)
        floorNode.name = "floor"
        floorNode.eulerAngles.x = -.pi / 2
        floorNode.position = SCNVector3(0, 0.001, 0)
        scene.rootNode.addChildNode(floorNode)

        // ── Grid lines ──
        let gridMat = SCNMaterial()
        gridMat.diffuse.contents = UIColor(white: 0.4, alpha: 0.18)
        gridMat.lightingModel = .constant
        let gridStep: Float = 0.5
        var gz = -roomD/2
        while gz <= roomD/2 {
            let lineGeo = SCNBox(width: CGFloat(roomW), height: 0.004, length: 0.012, chamferRadius: 0)
            lineGeo.materials = [gridMat]
            let ln = SCNNode(geometry: lineGeo); ln.position = SCNVector3(0, 0.005, gz)
            scene.rootNode.addChildNode(ln)
            gz += gridStep
        }
        var gx = -roomW/2
        while gx <= roomW/2 {
            let lineGeo = SCNBox(width: 0.012, height: 0.004, length: CGFloat(roomD), chamferRadius: 0)
            lineGeo.materials = [gridMat]
            let ln = SCNNode(geometry: lineGeo); ln.position = SCNVector3(gx, 0.005, 0)
            scene.rootNode.addChildNode(ln)
            gx += gridStep
        }

        // ── Ceiling ──
        box(roomW + wT*2, wT, roomD + wT*2, color: ceilColor, pos: SCNVector3(0, roomH + wT/2, 0))

        // ── Left wall ──
        box(wT, roomH, roomD + wT*2, color: wallColor, pos: SCNVector3(innerLeft - wT/2, roomH/2, 0))

        // ── Right wall ──
        box(wT, roomH, roomD + wT*2, color: wallColor, pos: SCNVector3(innerRight + wT/2, roomH/2, 0))

        // ── Front wall with door cutout ──
        let dW: Float = 0.95, dH: Float = 2.1, dCx: Float = 1.5
        let dLeft  = dCx - dW/2
        let dRight = dCx + dW/2
        let fZ = innerFront + wT/2
        box(dLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (dLeft - innerLeft)/2, roomH/2, fZ))
        box(innerRight - dRight, roomH, wT, color: wallColor,
            pos: SCNVector3(dRight + (innerRight - dRight)/2, roomH/2, fZ))
        box(dW, roomH - dH, wT, color: wallColor,
            pos: SCNVector3(dCx, dH + (roomH - dH)/2, fZ))

        let frameColor = UIColor(red:0.42, green:0.28, blue:0.14, alpha:1)
        let faceZ = innerFront + 0.01
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dLeft - 0.03, dH/2, faceZ))
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dRight + 0.03, dH/2, faceZ))
        box(dW + 0.06, 0.06, 0.10, color: frameColor, pos: SCNVector3(dCx, dH + 0.03, faceZ))
        box(dW - 0.08, dH - 0.04, 0.04, color: UIColor(red:0.60, green:0.42, blue:0.24, alpha:1),
            pos: SCNVector3(dCx, (dH - 0.04)/2, innerFront - 0.01))
        let handleGeo = SCNCylinder(radius: 0.018, height: 0.10)
        handleGeo.firstMaterial?.diffuse.contents = UIColor(red:0.80, green:0.68, blue:0.28, alpha:1)
        let handleNode = SCNNode(geometry: handleGeo)
        handleNode.eulerAngles.z = .pi/2
        handleNode.position = SCNVector3(dLeft + 0.12, 1.0, innerFront + 0.04)
        scene.rootNode.addChildNode(handleNode)

        // ── Back wall with window cutout ──
        let wW: Float = 1.1, wH: Float = 0.85, wCy: Float = 1.55, wCx: Float = -0.5
        let wBottom = wCy - wH/2, wTop = wCy + wH/2
        let wLeft   = wCx - wW/2, wRight = wCx + wW/2
        let bZ = innerBack - wT/2
        box(wLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (wLeft - innerLeft)/2, roomH/2, bZ))
        box(innerRight - wRight, roomH, wT, color: wallColor,
            pos: SCNVector3(wRight + (innerRight - wRight)/2, roomH/2, bZ))
        box(wW, wBottom, wT, color: wallColor, pos: SCNVector3(wCx, wBottom/2, bZ))
        box(wW, roomH - wTop, wT, color: wallColor, pos: SCNVector3(wCx, wTop + (roomH - wTop)/2, bZ))

        let wFrameColor = UIColor(red:0.90, green:0.88, blue:0.82, alpha:1)
        let bFaceZ = innerBack - 0.01
        let ft: Float = 0.055
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wBottom, bFaceZ))
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wTop,    bFaceZ))
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wLeft,  wCy, bFaceZ))
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wRight, wCy, bFaceZ))
        box(ft*0.5, wH, 0.08, color: wFrameColor, pos: SCNVector3(wCx, wCy, bFaceZ))

        // Window glass
        let glassGeo = SCNBox(width: CGFloat(wW), height: CGFloat(wH), length: 0.008, chamferRadius: 0)
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents  = UIColor(red:0.60, green:0.82, blue:0.98, alpha:1)
        glassMat.transparency      = 0.72
        glassMat.isDoubleSided     = true
        glassMat.lightingModel     = .constant
        glassGeo.materials = [glassMat]
        let glassNode = SCNNode(geometry: glassGeo)
        glassNode.position = SCNVector3(wCx, wCy, innerBack + 0.02)
        scene.rootNode.addChildNode(glassNode)
        vm.glassNode = glassNode

        // Outside weather scene
        let outsidePlane = SCNPlane(width: CGFloat(wW * 4.0), height: CGFloat(wH * 3.5))
        let outsideMat = SCNMaterial()
        let defaultTOD = TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date()))
        outsideMat.diffuse.contents = WeatherTextureRenderer.draw(
            condition: WeatherCondition(code: 0, isDay: true, tempC: 30),
            size: CGSize(width: 512, height: 320), timeOfDay: defaultTOD)
        outsideMat.lightingModel = .constant
        outsideMat.isDoubleSided = true
        outsidePlane.materials = [outsideMat]
        let outsideNode = SCNNode(geometry: outsidePlane)
        outsideNode.position = SCNVector3(wCx, wCy, innerBack - wT - 0.30)
        scene.rootNode.addChildNode(outsideNode)
        vm.outsideNode = outsideNode

        // Rain particle system — tepat di luar jendela
        let rainPS = vm.makeRainParticleSystem(heavy: true)
        let rainNode = SCNNode()
        rainNode.addParticleSystem(rainPS)
        // Posisi tepat di atas jendela, di depan outside plane
        rainNode.position = SCNVector3(wCx, wTop + 1.2, innerBack - wT - 0.15)
        rainNode.isHidden = true
        scene.rootNode.addChildNode(rainNode)
        vm.rainParticleNode = rainNode

        // ── Skirting boards ──
        let skirtColor = UIColor(red:0.80, green:0.72, blue:0.58, alpha:1)
        let sh: Float = 0.09, sd: Float = 0.025
        box(sd, sh, roomD, color: skirtColor, pos: SCNVector3(innerLeft + sd/2, sh/2, 0))
        box(sd, sh, roomD, color: skirtColor, pos: SCNVector3(innerRight - sd/2, sh/2, 0))
        box(dLeft - innerLeft, sh, sd, color: skirtColor,
            pos: SCNVector3(innerLeft + (dLeft - innerLeft)/2, sh/2, innerFront - sd/2))
        box(innerRight - dRight, sh, sd, color: skirtColor,
            pos: SCNVector3(dRight + (innerRight - dRight)/2, sh/2, innerFront - sd/2))
        box(wLeft - innerLeft, sh, sd, color: skirtColor,
            pos: SCNVector3(innerLeft + (wLeft - innerLeft)/2, sh/2, innerBack + sd/2))
        box(innerRight - wRight, sh, sd, color: skirtColor,
            pos: SCNVector3(wRight + (innerRight - wRight)/2, sh/2, innerBack + sd/2))

        scene.rootNode.addChildNode(vm.cameraNode)

        // ── Lighting ──
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color     = UIColor(white: 0.85, alpha: 1)
        ambient.intensity = 1000
        let ambNode = SCNNode(); ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)
        vm.ambientNode = ambNode

        // Main directional fill light (no shadow to avoid black screen on device)
        let sun = SCNLight(); sun.type = .directional
        sun.color     = UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1)
        sun.intensity = 800
        sun.castsShadow = false
        let sunNode = SCNNode(); sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/6, 0)
        scene.rootNode.addChildNode(sunNode)

        // Secondary fill from behind camera so no surface goes pitch black
        let fill = SCNLight(); fill.type = .directional
        fill.color     = UIColor(white: 0.60, alpha: 1)
        fill.intensity = 400
        fill.castsShadow = false
        let fillNode = SCNNode(); fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(Float.pi/6, -Float.pi/4, 0)
        scene.rootNode.addChildNode(fillNode)

        let winLight = SCNLight(); winLight.type = .omni
        winLight.color     = UIColor(red:1.0, green:0.97, blue:0.90, alpha:1)
        winLight.intensity = 800
        winLight.attenuationStartDistance = 0.5
        winLight.attenuationEndDistance   = 8.0
        let winLightNode = SCNNode(); winLightNode.light = winLight
        winLightNode.position = SCNVector3(wCx, wCy, innerBack + 0.5)
        scene.rootNode.addChildNode(winLightNode)
        vm.winLightNode = winLightNode

        // Apply current time-of-day immediately so window isn't dark on first load
        DispatchQueue.main.async {
            vm.applyTimeOfDay()
        }

        return scene
    }
}
