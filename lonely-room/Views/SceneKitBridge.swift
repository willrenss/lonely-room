import SwiftUI
import SceneKit
#if canImport(UIKit)
import UIKit

// MARK: - SceneKit Bridge
struct KostSceneView: UIViewRepresentable {
    @ObservedObject var vm: KostViewModel

    func makeUIView(context: Context) -> SCNView {
        let scene = makeScene()
        let view  = SCNView()
        view.scene                      = scene
        view.backgroundColor            = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1)
        view.antialiasingMode           = .multisampling4X
        view.autoenablesDefaultLighting = false

        vm.scnView   = view
        vm.sceneRoot = scene.rootNode
        vm.spawnDefaultFurniture()          // adds characterNode + cameraNode to scene

        view.pointOfView = vm.cameraNode    // set AFTER cameraNode is in scene tree
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
                if panIsDragging && !isRotating {
                    vm.saveFurniture()
                }
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

        func box(_ w: Float, _ h: Float, _ d: Float, color: UIColor, pos: SCNVector3, name: String? = nil) {
            let geo = SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0)
            geo.firstMaterial?.diffuse.contents = color
            geo.firstMaterial?.lightingModel = .lambert
            let n = SCNNode(geometry: geo); n.position = pos; n.name = name
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
        box(roomW + wT*2, wT, roomD + wT*2, color: ceilColor, pos: SCNVector3(0, roomH + wT/2, 0), name: "wall")

        // ── Left wall ──
        box(wT, roomH, roomD + wT*2, color: wallColor, pos: SCNVector3(innerLeft - wT/2, roomH/2, 0), name: "wall")

        // ── Right wall ──
        box(wT, roomH, roomD + wT*2, color: wallColor, pos: SCNVector3(innerRight + wT/2, roomH/2, 0), name: "wall")

        // ── Front wall with door cutout ──
        let dW: Float = 0.95, dH: Float = 2.1, dCx: Float = 1.5
        let dLeft  = dCx - dW/2
        let dRight = dCx + dW/2
        let fZ = innerFront + wT/2
        box(dLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (dLeft - innerLeft)/2, roomH/2, fZ), name: "wall")
        box(innerRight - dRight, roomH, wT, color: wallColor,
            pos: SCNVector3(dRight + (innerRight - dRight)/2, roomH/2, fZ), name: "wall")
        box(dW, roomH - dH, wT, color: wallColor,
            pos: SCNVector3(dCx, dH + (roomH - dH)/2, fZ), name: "wall")

        let frameColor = UIColor(red:0.42, green:0.28, blue:0.14, alpha:1)
        let faceZ = innerFront + 0.01
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dLeft - 0.03, dH/2, faceZ))
        box(0.06, dH, 0.10, color: frameColor, pos: SCNVector3(dRight + 0.03, dH/2, faceZ))
        box(dW + 0.06, 0.06, 0.10, color: frameColor, pos: SCNVector3(dCx, dH + 0.03, faceZ))
        
        let doorPivot = SCNNode()
        doorPivot.position = SCNVector3(dLeft, 0, innerFront - 0.01)
        scene.rootNode.addChildNode(doorPivot)
        
        let doorWidth = dW - 0.08
        let doorHeight = dH - 0.04
        let doorPanel = SCNBox(width: CGFloat(doorWidth), height: CGFloat(doorHeight), length: 0.04, chamferRadius: 0)
        doorPanel.firstMaterial?.diffuse.contents = UIColor(red:0.60, green:0.42, blue:0.24, alpha:1)
        let doorPanelNode = SCNNode(geometry: doorPanel)
        doorPanelNode.position = SCNVector3(doorWidth / 2, doorHeight / 2, 0)
        doorPivot.addChildNode(doorPanelNode)
        
        let handleGeo = SCNCylinder(radius: 0.018, height: 0.10)
        handleGeo.firstMaterial?.diffuse.contents = UIColor(red:0.80, green:0.68, blue:0.28, alpha:1)
        let handleNode = SCNNode(geometry: handleGeo)
        handleNode.eulerAngles.z = .pi/2
        handleNode.position = SCNVector3(doorWidth - 0.12, 1.0, 0.04) 
        doorPivot.addChildNode(handleNode)
        
        let handleNode2 = handleNode.clone()
        handleNode2.position = SCNVector3(doorWidth - 0.12, 1.0, -0.04)
        doorPivot.addChildNode(handleNode2)
        
        vm.doorNode = doorPivot
        vm.doorWorldPos = SIMD3<Float>(dCx, 0, innerFront)
        
        // ── Corridor (Koridor) ──
        let corrWidth: Float = 8.0 // panjang koridor ke kiri-kanan
        let corrDepth: Float = 1.5
        let corrHeight: Float = 2.8
        let corrColor = UIColor(red: 0.88, green: 0.86, blue: 0.84, alpha: 1)
        let floorCorrColor = UIColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1)
        
        let cCenterZ = fZ + corrDepth/2
        
        // Floor koridor utama (menutupi gap threshold pintu dengan memperpanjang ke dalam)
        box(corrWidth, 0.02, corrDepth, color: floorCorrColor, pos: SCNVector3(0, -0.01, cCenterZ))
        // Gap filler depan pintu
        box(dW, 0.02, wT + 0.02, color: floorCorrColor, pos: SCNVector3(dCx, -0.01, innerFront + wT/2))
        
        // Ceiling
        box(corrWidth, 0.02, corrDepth, color: UIColor(white: 0.92, alpha: 1), pos: SCNVector3(0, corrHeight, cCenterZ))
        
        // Front Wall (dinding seberang kamar kost)
        box(corrWidth, corrHeight, 0.04, color: corrColor, pos: SCNVector3(0, corrHeight/2, fZ + corrDepth), name: "wall")
        // Left Wall (ujung buntu koridor)
        box(0.04, corrHeight, corrDepth, color: corrColor, pos: SCNVector3(-corrWidth/2, corrHeight/2, cCenterZ), name: "wall")
        
        // Dinding koridor sisi kamar kost (selain kamar ini, buat dinding memanjang)
        let wEndKamar = innerRight + wT/2
        let wStartKamar = innerLeft - wT/2
        // Dinding kanan kamar ini
        box(corrWidth/2 - wEndKamar, corrHeight, 0.04, color: corrColor, pos: SCNVector3(wEndKamar + (corrWidth/2 - wEndKamar)/2, corrHeight/2, fZ), name: "wall")
        // Dinding kiri kamar ini
        box(wStartKamar - (-corrWidth/2), corrHeight, 0.04, color: corrColor, pos: SCNVector3(-corrWidth/2 + (wStartKamar - (-corrWidth/2))/2, corrHeight/2, fZ), name: "wall")

        // ── Pintu-pintu tetangga (fake doors) ──
        let neighborDoorColor = UIColor(red:0.55, green:0.35, blue:0.20, alpha:1)
        
        let doorPositionsX: [Float] = [-2.5, -0.6, 3.2] // Posisi pintu kamar lain di koridor
        for nx in doorPositionsX {
            // Kusen (Frame)
            box(0.96, 2.13, 0.10, color: frameColor, pos: SCNVector3(nx, 1.065, fZ + 0.01))
            
            // Daun pintu
            let nDoorGeo = SCNBox(width: 0.86, height: 2.06, length: 0.04, chamferRadius: 0)
            nDoorGeo.firstMaterial?.diffuse.contents = neighborDoorColor
            let nDoorNode = SCNNode(geometry: nDoorGeo)
            // Agak masuk dari kusen
            nDoorNode.position = SCNVector3(nx, 1.03, fZ + 0.03)
            scene.rootNode.addChildNode(nDoorNode)
            
            // Gagang Pintu (Handle)
            let nHandleGeo = SCNCylinder(radius: 0.018, height: 0.10)
            nHandleGeo.firstMaterial?.diffuse.contents = UIColor(red:0.80, green:0.68, blue:0.28, alpha:1)
            let nHandleNode = SCNNode(geometry: nHandleGeo)
            nHandleNode.eulerAngles.z = .pi/2
            // Pasang di sebelah kiri daun pintu
            nHandleNode.position = SCNVector3(nx - 0.35, 1.0, fZ + 0.06)
            scene.rootNode.addChildNode(nHandleNode)
        }
        
        // ── Tangga Turun (Staircase) di Ujung Kanan Koridor ──
        let stairW: Float = 1.4
        let stairStart = corrWidth/2 - stairW // posisi X ruang tangga
        
        // Lantai landing atas (sambung koridor)
        box(stairW, 0.02, corrDepth, color: floorCorrColor, pos: SCNVector3(stairStart + stairW/2, -0.01, cCenterZ))
        
        // Buat anak tangga turun
        let stepCount = 12
        let stepH: Float = 0.18
        let stepD: Float = 0.28
        let stairColor = UIColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1)
        
        let stairBoxNode = SCNNode()
        stairBoxNode.position = SCNVector3(stairStart + stairW/2, 0, cCenterZ + corrDepth/2)
        scene.rootNode.addChildNode(stairBoxNode)
        
        for i in 0..<stepCount {
            let sY = -Float(i+1) * stepH
            let sZ = Float(i+1) * stepD
            
            let st = SCNBox(width: CGFloat(stairW), height: CGFloat(stepH), length: CGFloat(stepD), chamferRadius: 0)
            st.firstMaterial?.diffuse.contents = stairColor
            let stN = SCNNode(geometry: st)
            stN.position = SCNVector3(0, sY + stepH/2, sZ + stepD/2)
            stairBoxNode.addChildNode(stN)
        }
        
        // Dinding ruang tangga
        let sDepth = Float(stepCount) * stepD
        box(0.04, corrHeight, sDepth, color: corrColor, pos: SCNVector3(stairStart, corrHeight/2 - 1.0, cCenterZ + corrDepth/2 + sDepth/2), name: "wall")
        box(0.04, corrHeight, sDepth, color: corrColor, pos: SCNVector3(stairStart + stairW, corrHeight/2 - 1.0, cCenterZ + corrDepth/2 + sDepth/2), name: "wall")
        box(stairW, corrHeight, 0.04, color: corrColor, pos: SCNVector3(stairStart + stairW/2, corrHeight/2 - 1.0, cCenterZ + corrDepth/2 + sDepth), name: "wall")
        
        // Plafon ruang tangga
        box(stairW, 0.02, sDepth, color: UIColor(white: 0.92, alpha: 1), pos: SCNVector3(stairStart + stairW/2, corrHeight, cCenterZ + corrDepth/2 + sDepth/2))

        // ── Back wall with window cutout ──
        let wW: Float = 1.1, wH: Float = 0.85, wCy: Float = 1.55, wCx: Float = -0.5
        let wBottom = wCy - wH/2, wTop = wCy + wH/2
        let wLeft   = wCx - wW/2, wRight = wCx + wW/2
        let bZ = innerBack - wT/2
        box(wLeft - innerLeft, roomH, wT, color: wallColor,
            pos: SCNVector3(innerLeft + (wLeft - innerLeft)/2, roomH/2, bZ), name: "wall")
        box(innerRight - wRight, roomH, wT, color: wallColor,
            pos: SCNVector3(wRight + (innerRight - wRight)/2, roomH/2, bZ), name: "wall")
        box(wW, wBottom, wT, color: wallColor, pos: SCNVector3(wCx, wBottom/2, bZ), name: "wall")
        box(wW, roomH - wTop, wT, color: wallColor, pos: SCNVector3(wCx, wTop + (roomH - wTop)/2, bZ), name: "wall")

        let wFrameColor = UIColor(red:0.90, green:0.88, blue:0.82, alpha:1)
        let bFaceZ = innerBack - 0.01
        let ft: Float = 0.055
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wBottom, bFaceZ))
        box(wW + ft*2, ft, 0.10, color: wFrameColor, pos: SCNVector3(wCx, wTop,    bFaceZ))
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wLeft,  wCy, bFaceZ))
        box(ft, wH, 0.10, color: wFrameColor, pos: SCNVector3(wRight, wCy, bFaceZ))
        box(ft*0.5, wH, 0.08, color: wFrameColor, pos: SCNVector3(wCx, wCy, bFaceZ))

        // Window glass — 2 panel kiri & kanan yang bisa digeser
        let halfW = CGFloat(wW / 2) - 0.01
        let glassMat: () -> SCNMaterial = {
            let m = SCNMaterial()
            m.diffuse.contents  = UIColor(red:0.60, green:0.82, blue:0.98, alpha:1)
            m.transparency      = 0.72
            m.isDoubleSided     = true
            m.lightingModel     = .constant
            return m
        }
        let glassGeoL = SCNBox(width: halfW, height: CGFloat(wH), length: 0.008, chamferRadius: 0)
        glassGeoL.materials = [glassMat()]
        let glassPanelL = SCNNode(geometry: glassGeoL)
        glassPanelL.position = SCNVector3(wCx - Float(halfW)/2, wCy, innerBack + 0.02)
        scene.rootNode.addChildNode(glassPanelL)
        vm.windowPanelL = glassPanelL
        vm.windowPanelLOriginX = glassPanelL.position.x

        let glassGeoR = SCNBox(width: halfW, height: CGFloat(wH), length: 0.008, chamferRadius: 0)
        glassGeoR.materials = [glassMat()]
        let glassPanelR = SCNNode(geometry: glassGeoR)
        glassPanelR.position = SCNVector3(wCx + Float(halfW)/2, wCy, innerBack + 0.02)
        scene.rootNode.addChildNode(glassPanelR)
        vm.windowPanelR = glassPanelR
        vm.windowPanelROriginX = glassPanelR.position.x

        // ── Curtains — kain tirai yang bisa berayun saat angin ──
        // Tirai dipasang di kiri dan kanan jendela, pivot di ujung atas
        // sehingga berayun realistis seperti tertiup angin.
        let curtainColor = UIColor(red: 0.92, green: 0.86, blue: 0.76, alpha: 0.82)
        let curtainW: Float = (wW / 2) + 0.05   // sedikit overlap ke tengah
        let curtainH: Float = wH + 0.12          // sedikit lebih panjang dari jendela
        let curtainZ = innerBack + 0.035          // sedikit di depan kaca jendela

        // Fungsi bantu buat satu panel tirai dengan pivot di ujung atas
        func makeCurtainPanel(isLeft: Bool) -> SCNNode {
            // pivot node — posisinya di tepi luar tirai (tepi yang menempel kusen)
            let pivot = SCNNode()
            let edgeX: Float = isLeft ? wLeft : wRight
            pivot.position = SCNVector3(edgeX, wTop, curtainZ)
            pivot.name = isLeft ? "curtainPivotL" : "curtainPivotR"

            // Geometri kain tirai — origin-nya di center,
            // jadi kita geser child node ke bawah dan ke dalam
            // agar tepi atas menyentuh pivot
            _ = 6
            let geo = SCNBox(
                width: CGFloat(curtainW),
                height: CGFloat(curtainH),
                length: 0.012,
                chamferRadius: 0.002
            )
            // Buat beberapa material untuk efek kain berlipat (fold gradient)
            let mat = SCNMaterial()
            mat.diffuse.contents  = curtainColor
            mat.transparency      = 0.18           // tirai tipis / transparan ringan
            mat.isDoubleSided     = true
            mat.lightingModel     = .phong
            mat.specular.contents = UIColor(white: 0.3, alpha: 1)
            geo.materials = [mat]

            let clothNode = SCNNode(geometry: geo)
            // Geser ke bawah separuh tinggi dan ke arah tengah jendela
            let halfW = curtainW / 2
            let centerOffsetX: Float = isLeft ? halfW : -halfW
            clothNode.position = SCNVector3(centerOffsetX, -curtainH / 2, 0)
            clothNode.name = "curtainCloth"

            // Tirai lipatan dekoratif: tambah strip vertikal untuk kesan kerutan
            let foldCount = 3
            for i in 0..<foldCount {
                let foldGeo = SCNBox(width: 0.018, height: CGFloat(curtainH), length: 0.016, chamferRadius: 0.002)
                let foldMat = SCNMaterial()
                foldMat.diffuse.contents = UIColor(red: 0.78, green: 0.70, blue: 0.58, alpha: 0.60)
                foldMat.isDoubleSided = true
                foldMat.lightingModel = .phong
                foldGeo.materials = [foldMat]
                let foldNode = SCNNode(geometry: foldGeo)
                let spread: Float = curtainW / Float(foldCount + 1)
                let fxOffset: Float = isLeft
                    ? -curtainW/2 + spread * Float(i + 1)
                    : curtainW/2  - spread * Float(i + 1)
                foldNode.position = SCNVector3(fxOffset, 0, 0.007)
                clothNode.addChildNode(foldNode)
            }

            // Batang tirai (rod ring) atas
            let ringGeo = SCNCylinder(radius: 0.014, height: CGFloat(curtainW))
            ringGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1)
            ringGeo.firstMaterial?.lightingModel = .lambert
            let ringNode = SCNNode(geometry: ringGeo)
            ringNode.eulerAngles.z = .pi / 2
            ringNode.position = SCNVector3(centerOffsetX, 0.010, 0)
            pivot.addChildNode(ringNode)

            pivot.addChildNode(clothNode)
            return pivot
        }

        let curtainPivotL = makeCurtainPanel(isLeft: true)
        let curtainPivotR = makeCurtainPanel(isLeft: false)
        scene.rootNode.addChildNode(curtainPivotL)
        scene.rootNode.addChildNode(curtainPivotR)
        vm.curtainL = curtainPivotL
        vm.curtainR = curtainPivotR

        // Simpan posisi world jendela — agak ke dalam ruangan dari dinding belakang
        vm.windowWorldPos = SIMD3<Float>(wCx, 0, innerBack + 0.8)
        vm.glassNode = glassPanelL   // backward compat

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

        // ── Lighting ──
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color     = UIColor(white: 0.85, alpha: 1)
        ambient.intensity = 1000
        let ambNode = SCNNode(); ambNode.light = ambient
        scene.rootNode.addChildNode(ambNode)
        vm.ambientNode = ambNode

        // Main directional fill light
        let sun = SCNLight(); sun.type = .directional
        sun.color     = UIColor(red: 1.0, green: 0.97, blue: 0.90, alpha: 1)
        sun.intensity = 800
        sun.castsShadow = false
        let sunNode = SCNNode(); sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi/4, Float.pi/6, 0)
        scene.rootNode.addChildNode(sunNode)
        vm.sunLightNode = sunNode

        // Secondary fill
        let fill = SCNLight(); fill.type = .directional
        fill.color     = UIColor(white: 0.60, alpha: 1)
        fill.intensity = 400
        fill.castsShadow = false
        let fillNode = SCNNode(); fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(Float.pi/6, -Float.pi/4, 0)
        scene.rootNode.addChildNode(fillNode)
        vm.fillLightNode = fillNode

        // Ceiling room light — dikontrol saklar dinding
        let roomLight = SCNLight(); roomLight.type = .omni
        roomLight.color     = UIColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1)
        roomLight.intensity = 1000
        roomLight.attenuationStartDistance = 0.5
        roomLight.attenuationEndDistance   = 8.0
        let roomLightNode = SCNNode(); roomLightNode.light = roomLight
        roomLightNode.position = SCNVector3(0, roomH - 0.1, 0)   // tepat di plafon tengah
        scene.rootNode.addChildNode(roomLightNode)
        vm.roomLightNode = roomLightNode

        let winLight = SCNLight(); winLight.type = .omni
        winLight.color     = UIColor(red:1.0, green:0.97, blue:0.90, alpha:1)
        winLight.intensity = 800
        winLight.attenuationStartDistance = 0.5
        winLight.attenuationEndDistance   = 8.0
        let winLightNode = SCNNode(); winLightNode.light = winLight
        winLightNode.position = SCNVector3(wCx, wCy, innerBack + 0.5)
        scene.rootNode.addChildNode(winLightNode)
        vm.winLightNode = winLightNode
        
        // ── Corridor Lights ──
        for cx in [-2.0, 0.0, 2.0] as [Float] {
            let cl = SCNLight(); cl.type = .omni
            cl.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1)
            cl.intensity = 800
            cl.attenuationStartDistance = 0.5
            cl.attenuationEndDistance = 6.0
            let cln = SCNNode(); cln.light = cl
            cln.position = SCNVector3(cx, corrHeight - 0.2, cCenterZ)
            scene.rootNode.addChildNode(cln)
        }

        // ── Saklar lampu — dinding depan, kanan pintu ──
        let swX = dRight + 0.20
        let swY: Float = 1.25
        let swZ = innerFront - 0.01  

        let plateGeo = SCNBox(width: 0.09, height: 0.13, length: 0.015, chamferRadius: 0.008)
        let plateMat = SCNMaterial()
        plateMat.diffuse.contents  = UIColor(red:0.95, green:0.95, blue:0.88, alpha:1)
        plateMat.lightingModel     = .phong
        plateMat.specular.contents = UIColor(white:0.4, alpha:1)
        plateGeo.materials = [plateMat]
        let plateNode = SCNNode(geometry: plateGeo)
        plateNode.position = SCNVector3(swX, swY, swZ)
        plateNode.name = "lightSwitch"
        scene.rootNode.addChildNode(plateNode)
        vm.switchNode = plateNode

        let btnGeo = SCNBox(width: 0.045, height: 0.065, length: 0.012, chamferRadius: 0.005)
        let btnMat = SCNMaterial()
        btnMat.diffuse.contents  = UIColor(red:0.90, green:0.88, blue:0.78, alpha:1)
        btnMat.lightingModel     = .phong
        btnGeo.materials = [btnMat]
        let btnNode = SCNNode(geometry: btnGeo)
        btnNode.position = SCNVector3(0, 0, 0.009)
        plateNode.addChildNode(btnNode)

        vm.switchWorldPos = SIMD3<Float>(swX, 0, swZ)

        // Apply current time-of-day immediately so window isn't dark on first load
        DispatchQueue.main.async {
            vm.applyTimeOfDay()
        }

        return scene
    }
}
#endif
