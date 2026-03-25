import SwiftUI
import SceneKit
import Combine

// MARK: - KostViewModel
class KostViewModel: ObservableObject {
    let cameraNode = SCNNode()
    var yaw: Float   = 0
    let eyeHeight: Float = 1.6
    let speed: Float     = 0.08
    let minX: Float = -2.5, maxX: Float =  2.5
    let minZ: Float = -1.5, maxZ: Float =  1.5

    @Published var isWalking         = false
    @Published var furnitureItems: [FurnitureItem] = []
    @Published var selectedFurniture: FurnitureItem?
    @Published var pendingType: FurnitureType? = nil
    @Published var weather: WeatherCondition?

    /// Called whenever selectedFurniture changes — used by ContentView to hide/show catalog
    var onSelectionChanged: ((FurnitureItem?) -> Void)?

    weak var scnView:          SCNView?
    weak var sceneRoot:        SCNNode?
    weak var glassNode:        SCNNode?
    weak var ambientNode:      SCNNode?
    weak var winLightNode:     SCNNode?
    weak var outsideNode:      SCNNode?
    weak var rainParticleNode: SCNNode?

    var rainDisplayLink: CADisplayLink?
    var rainTimeOffset: Double = 0
    var lastRainTimestamp: Double = 0

    init() {
        let cam = SCNCamera()
        cam.zNear = 0.01; cam.zFar = 50; cam.fieldOfView = 80
        cameraNode.camera      = cam
        cameraNode.position    = SCNVector3(0, 1.6, 1.0)
        cameraNode.eulerAngles = SCNVector3(0, Float.pi, 0)
    }

    // MARK: - Movement

    func move(dx: Float, dy: Float) {
        let fwdX =  sin(yaw) * dy * speed
        let fwdZ =  cos(yaw) * dy * speed
        let strX = -cos(yaw) * dx * speed
        let strZ =  sin(yaw) * dx * speed
        let newX = cameraNode.position.x + fwdX + strX
        let newZ = cameraNode.position.z + fwdZ + strZ
        let moving = abs(dx) > 0.05 || abs(dy) > 0.05
        if isWalking != moving {
            isWalking = moving
            if moving {
                FootstepPlayer.shared.start()
            } else {
                FootstepPlayer.shared.stop()
            }
        }
        cameraNode.position.x = max(minX, min(maxX, newX))
        cameraNode.position.z = max(minZ, min(maxZ, newZ))
        cameraNode.position.y = eyeHeight
    }

    func stopWalking() {
        guard isWalking else { return }
        isWalking = false
        FootstepPlayer.shared.stop()
    }

    func rotateCamera(by delta: Float) {
        yaw += delta
        cameraNode.eulerAngles.y = yaw + Float.pi
    }

    // MARK: - Furniture Placement

    func startPlacing(type: FurnitureType) {
        guard !furnitureItems.contains(where: { $0.type == type }) else { return }
        selectFurniture(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            pendingType = type
        }
    }

    func placeFurniture(at worldPos: SCNVector3) {
        guard let type = pendingType, let root = sceneRoot else { return }
        let node = buildFurnitureNode(type: type)
        let clampedX = max(-2.5, min(2.5, worldPos.x))
        let clampedZ = max(-1.5, min(1.5, worldPos.z))
        node.position = SCNVector3(clampedX, 0, clampedZ)
        root.addChildNode(node)
        let item = FurnitureItem(type: type, position: node.position, node: node)
        furnitureItems.append(item)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            pendingType = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.selectFurniture(item)
        }
    }

    func selectFurniture(_ item: FurnitureItem?) {
        selectedFurniture?.node.childNodes
            .filter { $0.name == "sel_outline" }
            .forEach { $0.removeFromParentNode() }
        selectedFurniture = item
        onSelectionChanged?(item)
        guard let item = item else { return }
        let fp = item.type.footprint
        let w = CGFloat(fp.width) + 0.15
        let d = CGFloat(fp.height) + 0.15
        let geo = SCNBox(width: w, height: 0.02, length: d, chamferRadius: 0.04)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.65)
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        geo.materials = [mat]
        let outline = SCNNode(geometry: geo)
        outline.name = "sel_outline"
        outline.position = SCNVector3(0, 0.02, 0)
        item.node.addChildNode(outline)
    }

    func moveFurniture(_ item: FurnitureItem, to worldPos: SCNVector3) {
        let clampedX = max(-2.5, min(2.5, worldPos.x))
        let clampedZ = max(-1.5, min(1.5, worldPos.z))
        item.node.position = SCNVector3(clampedX, 0, clampedZ)
        if let idx = furnitureItems.firstIndex(where: { $0.id == item.id }) {
            furnitureItems[idx].position = item.node.position
        }
    }

    func deleteSelected() {
        guard let item = selectedFurniture else { return }
        item.node.removeFromParentNode()
        furnitureItems.removeAll { $0.id == item.id }
        selectedFurniture = nil
    }

    func rotateSelected(by angle: Float) {
        guard let item = selectedFurniture else { return }
        item.node.eulerAngles.y += angle
    }

    // MARK: - Hit Testing

    func hitTestFloor(at point: CGPoint) -> SCNVector3? {
        guard let scnView = scnView else { return nil }
        let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far  = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dir  = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(dir.y) > 1e-5 else { return nil }
        let t = -near.y / dir.y
        guard t > 0 else { return nil }
        return SCNVector3(near.x + dir.x * t, 0, near.z + dir.z * t)
    }

    func hitTestFurniture(at point: CGPoint) -> FurnitureItem? {
        guard let scnView = scnView else { return nil }
        let hits = scnView.hitTest(point, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .boundingBoxOnly: false,
            .ignoreHiddenNodes: true
        ])
        let rootMap: [ObjectIdentifier: FurnitureItem] = Dictionary(
            uniqueKeysWithValues: furnitureItems.map { (ObjectIdentifier($0.node), $0) }
        )
        for hit in hits {
            var node: SCNNode? = hit.node
            while let n = node {
                if let item = rootMap[ObjectIdentifier(n)] { return item }
                node = n.parent
            }
        }
        return nil
    }

    // MARK: - Weather

    func applyWeather(_ w: WeatherCondition) {
        applyWeather(w, timeOfDay: TimeOfDay.from(hour: Calendar.current.component(.hour, from: Date())))
    }

    func applyWeather(_ w: WeatherCondition, timeOfDay tod: TimeOfDay) {
        let effective = w.applying(timeOfDay: tod)
        weather = effective
        if let geo = glassNode?.geometry as? SCNBox,
           let mat = geo.materials.first {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            mat.diffuse.contents  = effective.glassColor
            mat.transparency      = effective.glassTransparency
            SCNTransaction.commit()
        }
        ambientNode?.light?.intensity = effective.isDay ? 1000 : 600
        ambientNode?.light?.color     = UIColor(white: effective.ambientIntensity, alpha: 1)
        winLightNode?.light?.intensity = effective.code == 0 && effective.isDay ? 1200 :
                                         effective.code <= 2 && effective.isDay ? 900 :
                                         effective.isDay ? 600 : 300

        let isRain  = [51,53,55,61,63,65,80,81,82,95,96,99].contains(effective.code)
        let isHeavy = [65,80,81,82,95,96,99].contains(effective.code)
        let isStorm = [95,96,99].contains(effective.code)

        if isRain {
            // Gunakan CADisplayLink untuk animasi hujan bergerak di texture
            startRainAnimation(heavy: isHeavy, storm: isStorm,
                               timeOfDay: tod, condition: effective)
        } else {
            stopRainAnimation()
            // Update texture statis kalau tidak hujan
            if let mat = outsideNode?.geometry?.firstMaterial {
                let tex = WeatherTextureRenderer.draw(condition: effective,
                                                     size: CGSize(width: 512, height: 320),
                                                     timeOfDay: tod)
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.0
                mat.diffuse.contents = tex
                SCNTransaction.commit()
            }
        }
    }

    func applyTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        let tod = TimeOfDay.from(hour: hour)
        let base = weather ?? WeatherCondition(code: 0, isDay: tod.isDay, tempC: 30)
        applyWeather(base, timeOfDay: tod)
    }

    // MARK: - Animated Rain on Window Texture

    func startRainAnimation(heavy: Bool, storm: Bool, timeOfDay: TimeOfDay, condition: WeatherCondition) {
        stopRainAnimation()
        lastRainTimestamp = CACurrentMediaTime()
        let link = CADisplayLink(target: RainAnimationTarget(vm: self,
                                                              heavy: heavy,
                                                              storm: storm,
                                                              timeOfDay: timeOfDay,
                                                              condition: condition),
                                 selector: #selector(RainAnimationTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        rainDisplayLink = link
    }

    func stopRainAnimation() {
        rainDisplayLink?.invalidate()
        rainDisplayLink = nil
        rainTimeOffset  = 0
    }

    // MARK: - Rain Particle System

    func makeRainParticleSystem(heavy: Bool = true) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleSize             = 0.008
        ps.particleSizeVariation    = 0.003
        ps.particleColor            = UIColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 0.65)
        ps.particleColorVariation   = SCNVector4(0.02, 0.05, 0.05, 0.10)
        ps.birthRate                = heavy ? 600 : 250
        ps.birthRateVariation       = 30
        ps.emissionDuration         = CGFloat.greatestFiniteMagnitude
        ps.loops                    = true
        // Emitter shape pas lebar jendela (wW = 1.1)
        ps.emitterShape             = SCNBox(width: 1.4, height: 0.01, length: 0.01, chamferRadius: 0)
        ps.birthLocation            = .surface
        ps.particleLifeSpan         = 0.55
        ps.particleLifeSpanVariation = 0.15
        ps.particleVelocity         = 5.0
        ps.particleVelocityVariation = 0.6
        ps.isAffectedByGravity      = true
        ps.acceleration             = SCNVector3(0.2, -9.8, 0)
        ps.blendMode                = .additive
        ps.orientationMode          = .free
        ps.stretchFactor            = 0.10
        return ps
    }

    // MARK: - Build Furniture Nodes

    func buildFurnitureNode(type: FurnitureType) -> SCNNode {
        let root = SCNNode()
        root.name = "furniture_\(type.rawValue)"
        let fp = type.footprint
        let w = CGFloat(fp.width), d = CGFloat(fp.height)

        switch type {
        case .bed:
            let frame = SCNBox(width: w, height: 0.3, length: d, chamferRadius: 0.05)
            frame.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.53,blue:0.38,alpha:1)
            let frameNode = SCNNode(geometry: frame); frameNode.position.y = 0.15
            root.addChildNode(frameNode)
            let mattress = SCNBox(width: w-0.06, height: 0.12, length: d-0.25, chamferRadius: 0.04)
            mattress.firstMaterial?.diffuse.contents = UIColor(red:0.92,green:0.90,blue:0.88,alpha:1)
            let mNode = SCNNode(geometry: mattress); mNode.position = SCNVector3(0, 0.36, 0.05)
            root.addChildNode(mNode)
            let pillow = SCNBox(width: w-0.2, height: 0.08, length: 0.28, chamferRadius: 0.04)
            pillow.firstMaterial?.diffuse.contents = UIColor(red:0.95,green:0.85,blue:0.75,alpha:1)
            let pNode = SCNNode(geometry: pillow); pNode.position = SCNVector3(0, 0.44, -d/2 + 0.25)
            root.addChildNode(pNode)

        case .desk:
            let top = SCNBox(width: w, height: 0.05, length: d, chamferRadius: 0.02)
            top.firstMaterial?.diffuse.contents = UIColor(red:0.80,green:0.60,blue:0.35,alpha:1)
            let topNode = SCNNode(geometry: top); topNode.position.y = 0.72
            root.addChildNode(topNode)
            let legGeo = SCNBox(width: 0.05, height: 0.70, length: 0.05, chamferRadius: 0.01)
            legGeo.firstMaterial?.diffuse.contents = UIColor(red:0.55,green:0.38,blue:0.20,alpha:1)
            for xm in [-1.0, 1.0] { for zm in [-1.0, 1.0] {
                let leg = SCNNode(geometry: legGeo)
                leg.position = SCNVector3(Float(xm)*(Float(w)/2-0.05), 0.35, Float(zm)*(Float(d)/2-0.05))
                root.addChildNode(leg)
            }}
            let screen = SCNBox(width: 0.45, height: 0.28, length: 0.02, chamferRadius: 0.01)
            screen.firstMaterial?.diffuse.contents = UIColor(red:0.10,green:0.10,blue:0.15,alpha:1)
            let sNode = SCNNode(geometry: screen); sNode.position = SCNVector3(0.18, 1.06, d/2 - 0.04)
            root.addChildNode(sNode)

        case .wardrobe:
            let body = SCNBox(width: w, height: 1.8, length: d, chamferRadius: 0.03)
            body.firstMaterial?.diffuse.contents = UIColor(red:0.70,green:0.52,blue:0.32,alpha:1)
            let bNode = SCNNode(geometry: body); bNode.position.y = 0.9
            root.addChildNode(bNode)
            let line = SCNBox(width: 0.02, height: 1.78, length: 0.02, chamferRadius: 0)
            line.firstMaterial?.diffuse.contents = UIColor(red:0.40,green:0.28,blue:0.15,alpha:1)
            let lNode = SCNNode(geometry: line); lNode.position = SCNVector3(0, 0.89, d/2 + 0.01)
            root.addChildNode(lNode)
            for side in [-0.22, 0.22] as [Float] {
                let handle = SCNCylinder(radius: 0.015, height: 0.07)
                handle.firstMaterial?.diffuse.contents = UIColor(red:0.9,green:0.8,blue:0.5,alpha:1)
                let hn = SCNNode(geometry: handle); hn.eulerAngles.x = .pi/2
                hn.position = SCNVector3(side, 0.9, Float(1/2) + 0.03)
                root.addChildNode(hn)
            }

        case .tv:
            let stand = SCNCylinder(radius: 0.12, height: 0.04)
            stand.firstMaterial?.diffuse.contents = UIColor.darkGray
            let stNode = SCNNode(geometry: stand); stNode.position.y = 0.02
            root.addChildNode(stNode)
            let pole = SCNCylinder(radius: 0.025, height: 0.55)
            pole.firstMaterial?.diffuse.contents = UIColor.darkGray
            let plNode = SCNNode(geometry: pole); plNode.position.y = 0.295
            root.addChildNode(plNode)
            let screen = SCNBox(width: w, height: 0.58, length: 0.06, chamferRadius: 0.02)
            screen.firstMaterial?.diffuse.contents = UIColor(red:0.08,green:0.08,blue:0.12,alpha:1)
            let scNode = SCNNode(geometry: screen); scNode.position.y = 0.80
            root.addChildNode(scNode)

        case .plant:
            let pot = SCNCylinder(radius: 0.14, height: 0.18)
            pot.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.42,blue:0.22,alpha:1)
            let ptNode = SCNNode(geometry: pot); ptNode.position.y = 0.09
            root.addChildNode(ptNode)
            let stem = SCNCylinder(radius: 0.02, height: 0.3)
            stem.firstMaterial?.diffuse.contents = UIColor(red:0.25,green:0.55,blue:0.15,alpha:1)
            let stNode = SCNNode(geometry: stem); stNode.position.y = 0.33
            root.addChildNode(stNode)
            for (angle, h) in [(0.0, 0.48), (2.09, 0.44), (4.19, 0.46)] as [(Float, Float)] {
                let leaf = SCNSphere(radius: 0.15)
                leaf.firstMaterial?.diffuse.contents = UIColor(red:0.15,green:0.60,blue:0.15,alpha:0.95)
                let ln = SCNNode(geometry: leaf)
                ln.position = SCNVector3(sin(angle)*0.10, h, cos(angle)*0.10)
                root.addChildNode(ln)
            }

        case .rug:
            let rug = SCNBox(width: w, height: 0.02, length: d, chamferRadius: 0.06)
            rug.firstMaterial?.diffuse.contents = UIColor(red:0.72,green:0.18,blue:0.18,alpha:1)
            let rNode = SCNNode(geometry: rug); rNode.position.y = 0.01
            root.addChildNode(rNode)
            let pattern = SCNBox(width: w-0.2, height: 0.025, length: d-0.2, chamferRadius: 0.04)
            pattern.firstMaterial?.diffuse.contents = UIColor(red:0.90,green:0.78,blue:0.55,alpha:0.6)
            let pNode2 = SCNNode(geometry: pattern); pNode2.position.y = 0.013
            root.addChildNode(pNode2)

        case .lamp:
            let base = SCNCylinder(radius: 0.12, height: 0.04)
            base.firstMaterial?.diffuse.contents = UIColor.darkGray
            let bNode = SCNNode(geometry: base); bNode.position.y = 0.02
            root.addChildNode(bNode)
            let pole = SCNCylinder(radius: 0.018, height: 1.4)
            pole.firstMaterial?.diffuse.contents = UIColor(red:0.6,green:0.6,blue:0.6,alpha:1)
            let plNode = SCNNode(geometry: pole); plNode.position.y = 0.74
            root.addChildNode(plNode)
            let shade = SCNCone(topRadius: 0.06, bottomRadius: 0.22, height: 0.28)
            shade.firstMaterial?.diffuse.contents = UIColor(red:0.95,green:0.88,blue:0.60,alpha:1)
            let shNode = SCNNode(geometry: shade); shNode.position.y = 1.58
            root.addChildNode(shNode)
            let omni = SCNLight(); omni.type = .omni
            omni.color = UIColor(red:1.0,green:0.92,blue:0.70,alpha:1)
            omni.intensity = 600
            omni.attenuationStartDistance = 0.3; omni.attenuationEndDistance = 3.0
            let lNode = SCNNode(); lNode.light = omni; lNode.position = SCNVector3(0, 1.55, 0)
            root.addChildNode(lNode)

        case .bag:
            let body = SCNBox(width: 0.36, height: 0.28, length: 0.14, chamferRadius: 0.04)
            body.firstMaterial?.diffuse.contents = UIColor(red:0.18,green:0.22,blue:0.65,alpha:1)
            let bNode = SCNNode(geometry: body); bNode.position.y = 0.14
            root.addChildNode(bNode)
            let handle = SCNTorus(ringRadius: 0.09, pipeRadius: 0.015)
            handle.firstMaterial?.diffuse.contents = UIColor(red:0.12,green:0.14,blue:0.45,alpha:1)
            let hNode = SCNNode(geometry: handle); hNode.eulerAngles.x = .pi/2
            hNode.position = SCNVector3(0, 0.36, 0)
            root.addChildNode(hNode)
        }

        return root
    }
}
