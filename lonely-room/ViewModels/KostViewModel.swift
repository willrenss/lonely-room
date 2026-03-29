import SwiftUI
import SceneKit
import Combine

// MARK: - KostViewModel
class KostViewModel: ObservableObject {
    let cameraNode     = SCNNode()
    let characterNode  = SCNNode()
    let cameraPivot    = SCNNode()   // pivot untuk orbit kamera, terpisah dari karakter
    var yaw: Float     = 0
    var charFacing: Float = 0
    let speed: Float   = 0.06
    // Boundary karakter: hampir seluruh ruangan (roomW=5.6, roomD=3.6, wT=0.18, margin 0.25)
    let minX: Float    = -2.5, maxX: Float =  2.5
    let minZ: Float    = -1.5, maxZ: Float =  1.5

    @Published var isWalking         = false
    @Published var furnitureItems: [FurnitureItem] = []
    @Published var selectedFurniture: FurnitureItem?
    @Published var pendingType: FurnitureType? = nil
    @Published var weather: WeatherCondition?
    @Published var pendingStackSource: FurnitureItem? = nil

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

    // leg pivot nodes untuk animasi berjalan
    var legLPivot: SCNNode?
    var legRPivot: SCNNode?
    var armLPivot: SCNNode?
    var armRPivot: SCNNode?

    init() {
        let cam = SCNCamera()
        cam.zNear = 0.05; cam.zFar = 100; cam.fieldOfView = 60
        cameraNode.camera = cam

        // cameraNode di belakang karakter (+Z lokal = belakang saat yaw=0)
        // Jarak 2.0m, tinggi 1.1m, nunduk sedikit
        cameraNode.position    = SCNVector3(0, 1.1, 2.0)
        cameraNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        cameraPivot.addChildNode(cameraNode)

        characterNode.position = SCNVector3(0, 0, 0)
        charFacing = 0
        yaw = 0
        cameraPivot.position      = SCNVector3(0, 0, 0)
        cameraPivot.eulerAngles.y = 0
    }

    // MARK: - TPP Camera
    func updateCameraForTPP() {
        cameraPivot.position = SCNVector3(
            characterNode.position.x,
            0,
            Float(characterNode.position.z)
        )
        clampCameraAgainstWalls()
    }

    /// Ideal camera distance from pivot (in local Z)
    private let idealCameraZ: Float = 2.0
    /// Minimum camera distance (so it doesn't clip into character)
    private let minCameraZ:   Float = 0.3

    /// Ray-cast from character's head toward the ideal camera position.
    /// If a wall is in the way, pull the camera in to just in front of it.
    func clampCameraAgainstWalls() {
        guard let root = sceneRoot else { return }

        // Head position in world space (eye level ~1.1m)
        let charPos = characterNode.worldPosition
        let headPos = SCNVector3(charPos.x, charPos.y + 1.1, charPos.z)

        // Ideal camera world position — same transform as cameraPivot + cameraNode offset
        let idealCamPos = cameraNode.worldPosition

        // Direction from head to ideal camera
        let dx = idealCamPos.x - headPos.x
        let dy = idealCamPos.y - headPos.y
        let dz = idealCamPos.z - headPos.z
        let dist = sqrt(dx*dx + dy*dy + dz*dz)
        guard dist > 0.001 else { return }

        // SceneKit ray-cast options: only hit back-faces of wall geometry (opaque, named)
        let options: [String: Any] = [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ]

        let hits = root.hitTestWithSegment(from: headPos, to: idealCamPos, options: options)

        // Filter out character & camera nodes, and non-wall geometry (furniture, floor)
        let wallHit = hits.first { hit in
            // Walk up node hierarchy to skip character and camera pivot subtrees
            var n: SCNNode? = hit.node
            while let node = n {
                if node === characterNode || node === cameraPivot { return false }
                n = node.parent
            }
            // Only consider nodes that look like walls/ceiling (have a box geometry with no name
            // matching furniture or floor)
            let name = hit.node.name ?? ""
            if name == "floor" { return false }
            return true
        }

        if let hit = wallHit {
            // Distance from head to wall hit
            let hx = hit.worldCoordinates.x - headPos.x
            let hy = hit.worldCoordinates.y - headPos.y
            let hz = hit.worldCoordinates.z - headPos.z
            let hitDist = sqrt(hx*hx + hy*hy + hz*hz)

            // Pull back a tiny margin (0.1m) so camera doesn't poke through
            let clampedDist = max(minCameraZ, hitDist - 0.12)
            // Express as local Z in cameraPivot space
            let ratio = clampedDist / dist
            // New local Z for cameraNode (it's always at (0, 1.1, idealCameraZ) in pivot space)
            let newLocalZ = idealCameraZ * ratio
            cameraNode.position.z = newLocalZ
        } else {
            // No wall — restore to ideal distance smoothly
            if cameraNode.position.z != idealCameraZ {
                cameraNode.position.z = idealCameraZ
            }
        }
    }

    // MARK: - Movement

    func move(dx: Float, dy: Float) {
        // Kamera ada di posisi (sin(yaw)*Z, 1.1, cos(yaw)*Z) relatif pivot.
        // "Maju" (dy+) = bergerak menjauh dari kamera = arah berlawanan dari kamera
        // forward = (-sin(yaw), 0, -cos(yaw))
        // strafe kanan (dx+) = (cos(yaw), 0, -sin(yaw))
        let camYaw = yaw
        let fwdX = -sin(camYaw) * dy * speed
        let fwdZ = -cos(camYaw) * dy * speed
        let strX =  cos(camYaw) * dx * speed
        let strZ = -sin(camYaw) * dx * speed

        let newX = Float(characterNode.position.x) + fwdX + strX
        let newZ = Float(characterNode.position.z) + fwdZ + strZ

        let moving = abs(dx) > 0.05 || abs(dy) > 0.05
        if isWalking != moving {
            isWalking = moving
            if moving {
                FootstepPlayer.shared.start()
                startWalkAnimation()
            } else {
                FootstepPlayer.shared.stop()
                stopWalkAnimation()
            }
        }

        let clampedX = SCNFloat(max(minX, min(maxX, newX)))
        let clampedZ = SCNFloat(max(minZ, min(maxZ, newZ)))
        characterNode.position.x = clampedX
        characterNode.position.z = clampedZ
        characterNode.position.y = 0

        // Karakter smooth rotate ke arah gerak
        if abs(fwdX + strX) > 0.001 || abs(fwdZ + strZ) > 0.001 {
            let targetFacing = atan2(fwdX + strX, -(fwdZ + strZ))
            var diff = targetFacing - charFacing
            while diff >  Float.pi { diff -= 2 * Float.pi }
            while diff < -Float.pi { diff += 2 * Float.pi }
            charFacing += diff * 0.25
            characterNode.eulerAngles.y = SCNFloat(charFacing)
        }

        // CameraPivot selalu ikut posisi karakter
        updateCameraForTPP()
    }

    func stopWalking() {
        guard isWalking else { return }
        isWalking = false
        FootstepPlayer.shared.stop()
        stopWalkAnimation()
    }

    // MARK: - Walk Animation

    func startWalkAnimation() {
        let stepAngle: CGFloat = 0.45
        let duration: TimeInterval = 0.32

        func swing(_ node: SCNNode?, fwd: Bool) {
            guard let n = node else { return }
            let a = SCNAction.rotateTo(x: fwd ? stepAngle : -stepAngle, y: 0, z: 0, duration: duration, usesShortestUnitArc: true)
            let b = SCNAction.rotateTo(x: fwd ? -stepAngle : stepAngle, y: 0, z: 0, duration: duration, usesShortestUnitArc: true)
            n.runAction(.repeatForever(.sequence([a, b])), forKey: "walk")
        }

        swing(legLPivot, fwd: true)
        swing(legRPivot, fwd: false)
        swing(armLPivot, fwd: false)  // lengan berlawanan dengan kaki
        swing(armRPivot, fwd: true)
    }

    func stopWalkAnimation() {
        [legLPivot, legRPivot, armLPivot, armRPivot].forEach { node in
            guard let n = node else { return }
            n.removeAction(forKey: "walk")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            n.eulerAngles.x = 0
            SCNTransaction.commit()
        }
    }

    func rotateCamera(by delta: Float) {
        yaw += delta
        cameraPivot.eulerAngles.y = SCNFloat(yaw)
        clampCameraAgainstWalls()
    }
    // MARK: - Furniture Placement

    func hasItem(ofType type: FurnitureType) -> Bool {
        furnitureItems.contains { $0.type == type }
    }

    func startPlacing(type: FurnitureType) {
        guard !hasItem(ofType: type) else { return }
        selectFurniture(nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingType = type }
    }

    /// Place a wall-mounted item. Called from the coordinator when user taps on a wall surface.
    func placeWallFurniture(type: FurnitureType, position: SCNVector3, yaw: Float) {
        guard let root = sceneRoot else { return }
        let node = buildFurnitureNode(type: type)
        node.position = position
        node.eulerAngles.y = SCNFloat(yaw)
        root.addChildNode(node)
        let item = FurnitureItem(type: type, position: position, node: node)
        furnitureItems.append(item)
        if type == .wallClock { ClockPlayer.shared.start() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingType = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.selectFurniture(item) }
    }

    func placeFurniture(at worldPos: SCNVector3) {
        guard let type = pendingType, let root = sceneRoot else { return }
        if type.isWallMounted { return }

        // Stack onto existing furniture
        if let baseIdx = furnitureItems.indices.first(where: { i in
            let base = furnitureItems[i]
            guard base.stackedItemID == nil else { return false }
            guard base.type.canStack(type) else { return false }
            let dx = abs(Float(worldPos.x) - Float(base.node.position.x))
            let dz = abs(Float(worldPos.z) - Float(base.node.position.z))
            return dx < Float(base.type.footprint.width  / 2) &&
                   dz < Float(base.type.footprint.height / 2)
        }) {
            let base = furnitureItems[baseIdx]
            let node = buildFurnitureNode(type: type)
            node.position = SCNVector3(Float(base.node.position.x),
                                       Float(base.node.position.y) + Float(base.type.topHeight),
                                       Float(base.node.position.z))
            root.addChildNode(node)
            var item = FurnitureItem(type: type, position: node.position, node: node)
            item.stackedOnID = base.id
            furnitureItems[baseIdx].stackedItemID = item.id
            furnitureItems.append(item)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingType = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.selectFurniture(item) }
            return
        }

        // Normal floor placement
        let node = buildFurnitureNode(type: type)
        node.position = SCNVector3(max(-2.5, min(2.5, worldPos.x)), 0, max(-1.5, min(1.5, worldPos.z)))
        root.addChildNode(node)
        let item = FurnitureItem(type: type, position: node.position, node: node)
        furnitureItems.append(item)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pendingType = nil }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.selectFurniture(item) }
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
        guard item.stackedOnID == nil else { return }
        let clampedX = max(-2.5, min(2.5, Float(worldPos.x)))
        let clampedZ = max(-1.5, min(1.5, Float(worldPos.z)))
        let newY = Float(item.node.position.y)
        item.node.position = SCNVector3(clampedX, newY, clampedZ)
        if let idx = furnitureItems.firstIndex(where: { $0.id == item.id }) {
            furnitureItems[idx].position = item.node.position
            if let childID = item.stackedItemID,
               let childIdx = furnitureItems.firstIndex(where: { $0.id == childID }) {
                let childY = Float(furnitureItems[childIdx].node.position.y)
                furnitureItems[childIdx].node.position = SCNVector3(clampedX, childY, clampedZ)
                furnitureItems[childIdx].position = furnitureItems[childIdx].node.position
            }
        }
    }

    func deleteSelected() {
        guard let item = selectedFurniture else { return }
        if let childID = item.stackedItemID,
           let childIdx = furnitureItems.firstIndex(where: { $0.id == childID }) {
            furnitureItems[childIdx].node.removeFromParentNode()
            furnitureItems.remove(at: childIdx)
        }
        if let parentID = item.stackedOnID,
           let parentIdx = furnitureItems.firstIndex(where: { $0.id == parentID }) {
            furnitureItems[parentIdx].stackedItemID = nil
        }
        let wasClockItem = item.type == .wallClock
        item.node.removeFromParentNode()
        furnitureItems.removeAll { $0.id == item.id }
        selectedFurniture = nil
        if wasClockItem && !furnitureItems.contains(where: { $0.type == .wallClock }) {
            ClockPlayer.shared.stop()
        }
    }

    func rotateSelected(by angle: Float) {
        guard let item = selectedFurniture else { return }
        item.node.eulerAngles.y += SCNFloat(angle)
    }

    func moveSelected(dx: Float, dz: Float) {
        guard let item = selectedFurniture, item.stackedOnID == nil else { return }
        if item.type.isWallMounted {
            let yawVal = Float(item.node.eulerAngles.y)
            let onSideWall = abs(sin(yawVal)) > 0.7
            if onSideWall {
                item.node.position.z = SCNFloat(max(-1.5, min(1.5, Float(item.node.position.z) + dz)))
            } else {
                item.node.position.x = SCNFloat(max(-2.5, min(2.5, Float(item.node.position.x) + dx)))
            }
            if let idx = furnitureItems.firstIndex(where: { $0.id == item.id }) {
                furnitureItems[idx].position = item.node.position
            }
            return
        }
        let newX = max(-2.5, min(2.5, Float(item.node.position.x) + dx))
        let newZ = max(-1.5, min(1.5, Float(item.node.position.z) + dz))
        item.node.position.x = SCNFloat(newX)
        item.node.position.z = SCNFloat(newZ)
        if let idx = furnitureItems.firstIndex(where: { $0.id == item.id }) {
            furnitureItems[idx].position = item.node.position
            if let childID = item.stackedItemID,
               let childIdx = furnitureItems.firstIndex(where: { $0.id == childID }) {
                furnitureItems[childIdx].node.position.x = SCNFloat(newX)
                furnitureItems[childIdx].node.position.z = SCNFloat(newZ)
                furnitureItems[childIdx].position = furnitureItems[childIdx].node.position
            }
        }
    }

    // MARK: - Stacking

    func startStacking() {
        guard let item = selectedFurniture else { return }
        pendingStackSource = item
        selectFurniture(nil)
    }

    func cancelStacking() { pendingStackSource = nil }

    @discardableResult
    func stackItemOnto(_ base: FurnitureItem) -> Bool {
        guard let source = pendingStackSource else { return false }
        guard base.id != source.id, base.stackedItemID == nil, base.type.canStack(source.type) else {
            pendingStackSource = nil; return false
        }
        if let oldParentID = source.stackedOnID,
           let oldIdx = furnitureItems.firstIndex(where: { $0.id == oldParentID }) {
            furnitureItems[oldIdx].stackedItemID = nil
        }
        let newY = Float(base.node.position.y) + Float(base.type.topHeight)
        source.node.position = SCNVector3(Float(base.node.position.x), newY, Float(base.node.position.z))
        guard let sourceIdx = furnitureItems.firstIndex(where: { $0.id == source.id }),
              let baseIdx   = furnitureItems.firstIndex(where: { $0.id == base.id }) else {
            pendingStackSource = nil; return false
        }
        furnitureItems[sourceIdx].position    = source.node.position
        furnitureItems[sourceIdx].stackedOnID = base.id
        furnitureItems[baseIdx].stackedItemID = source.id
        pendingStackSource = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.selectFurniture(self.furnitureItems[sourceIdx])
        }
        return true
    }

    // MARK: - Hit Testing

    func hitTestFloor(at point: CGPoint) -> SCNVector3? { hitTestPlane(at: point, y: 0) }

    /// Unproject screen point onto a horizontal plane at world Y = `planeY`.
    func hitTestPlane(at point: CGPoint, y planeY: Float) -> SCNVector3? {
        guard let scnView = scnView else { return nil }
        let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far  = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dirX = Float(far.x) - Float(near.x)
        let dirY = Float(far.y) - Float(near.y)
        let dirZ = Float(far.z) - Float(near.z)
        guard abs(dirY) > 1e-6 else { return nil }
        let t = (planeY - Float(near.y)) / dirY
        guard t > 0 else { return nil }
        return SCNVector3(Float(near.x) + dirX * t, planeY, Float(near.z) + dirZ * t)
    }

    /// Ray-cast to the nearest wall surface for wall-clock placement.
    func hitTestWall(at point: CGPoint) -> (position: SCNVector3, yaw: Float)? {
        guard let scnView = scnView else { return nil }
        let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far  = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let nearX = Float(near.x), nearY = Float(near.y), nearZ = Float(near.z)
        let dirX  = Float(far.x) - nearX
        _  = Float(far.y) - nearY
        let dirZ  = Float(far.z) - nearZ

        let wallY: Float = 1.65
        let off: Float = 0.03
        let xMin: Float = -2.8, xMax: Float = 2.8
        let zMin: Float = -1.8, zMax: Float = 1.8

        var bestT = Float.greatestFiniteMagnitude
        var bestPos = SCNVector3Zero
        var bestYaw: Float = 0

        func tryWall(t: Float, pos: SCNVector3, yaw: Float) {
            if t > 0 && t < bestT { bestT = t; bestPos = pos; bestYaw = yaw }
        }

        if abs(dirX) > 1e-6 {
            let tL = (xMin + off - nearX) / dirX
            let zL = nearZ + dirZ * tL
            if zL >= zMin && zL <= zMax { tryWall(t: tL, pos: SCNVector3(xMin + off, wallY, zL), yaw: -.pi/2) }
            let tR = (xMax - off - nearX) / dirX
            let zR = nearZ + dirZ * tR
            if zR >= zMin && zR <= zMax { tryWall(t: tR, pos: SCNVector3(xMax - off, wallY, zR), yaw: .pi/2) }
        }
        if abs(dirZ) > 1e-6 {
            let tB = (zMin + off - nearZ) / dirZ
            let xB = nearX + dirX * tB
            if xB >= xMin && xB <= xMax { tryWall(t: tB, pos: SCNVector3(xB, wallY, zMin + off), yaw: 0) }
            let tF = (zMax - off - nearZ) / dirZ
            let xF = nearX + dirX * tF
            if xF >= xMin && xF <= xMax { tryWall(t: tF, pos: SCNVector3(xF, wallY, zMax - off), yaw: .pi) }
        }
        guard bestT < Float.greatestFiniteMagnitude else { return nil }
        return (bestPos, bestYaw)
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
        if let geo = glassNode?.geometry as? SCNBox, let mat = geo.materials.first {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 1.5
            mat.diffuse.contents = effective.glassColor
            mat.transparency     = effective.glassTransparency
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
            RainPlayer.shared.start(heavy: isHeavy || isStorm)
            startRainAnimation(heavy: isHeavy, storm: isStorm, timeOfDay: tod, condition: effective)
        } else {
            RainPlayer.shared.stop()
            stopRainAnimation()
            if let mat = outsideNode?.geometry?.firstMaterial {
                let tex = WeatherTextureRenderer.draw(condition: effective,
                                                     size: CGSize(width: 512, height: 320),
                                                     timeOfDay: tod)
                SCNTransaction.begin(); SCNTransaction.animationDuration = 2.0
                mat.diffuse.contents = tex; SCNTransaction.commit()
            }
        }
    }

    func applyTimeOfDay() {
        let hour = Calendar.current.component(.hour, from: Date())
        let tod  = TimeOfDay.from(hour: hour)
        let base = weather ?? WeatherCondition(code: 0, isDay: tod.isDay, tempC: 30)
        applyWeather(base, timeOfDay: tod)
    }

    // MARK: - Rain Animation

    func startRainAnimation(heavy: Bool, storm: Bool, timeOfDay: TimeOfDay, condition: WeatherCondition) {
        stopRainAnimation()
        lastRainTimestamp = CACurrentMediaTime()
        let link = CADisplayLink(target: RainAnimationTarget(vm: self, heavy: heavy, storm: storm,
                                                              timeOfDay: timeOfDay, condition: condition),
                                 selector: #selector(RainAnimationTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        rainDisplayLink = link
    }

    func stopRainAnimation() {
        rainDisplayLink?.invalidate(); rainDisplayLink = nil; rainTimeOffset = 0
    }

    // MARK: - Rain Particle System

    func makeRainParticleSystem(heavy: Bool = true) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleSize = 0.008; ps.particleSizeVariation = 0.003
        ps.particleColor = UIColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 0.65)
        ps.particleColorVariation = SCNVector4(0.02, 0.05, 0.05, 0.10)
        ps.birthRate = heavy ? 600 : 250; ps.birthRateVariation = 30
        ps.emissionDuration = .greatestFiniteMagnitude; ps.loops = true
        ps.emitterShape = SCNBox(width: 1.4, height: 0.01, length: 0.01, chamferRadius: 0)
        ps.birthLocation = .surface
        ps.particleLifeSpan = 0.55; ps.particleLifeSpanVariation = 0.15
        ps.particleVelocity = 5.0; ps.particleVelocityVariation = 0.6
        ps.isAffectedByGravity = true; ps.acceleration = SCNVector3(0.2, -9.8, 0)
        ps.blendMode = .additive; ps.orientationMode = .free; ps.stretchFactor = 0.10
        return ps
    }

    // MARK: - Default Furniture Layout + Character Spawn

    func spawnDefaultFurniture() {
        guard let root = sceneRoot else { return }

        func spawnFloor(type: FurnitureType, x: Float, z: Float, yaw: Float = 0) {
            let node = buildFurnitureNode(type: type)
            node.position = SCNVector3(x, 0, z)
            node.eulerAngles.y = SCNFloat(yaw)
            root.addChildNode(node)
            let item = FurnitureItem(type: type, position: node.position, node: node)
            furnitureItems.append(item)
        }

        func spawnWall(type: FurnitureType, x: Float, z: Float, yaw: Float) {
            let node = buildFurnitureNode(type: type)
            node.position = SCNVector3(x, 1.65, z)
            node.eulerAngles.y = SCNFloat(yaw)
            root.addChildNode(node)
            let item = FurnitureItem(type: type, position: node.position, node: node)
            furnitureItems.append(item)
            if type == .wallClock { ClockPlayer.shared.start() }
        }

        func spawnStacked(type: FurnitureType, on baseIdx: Int) {
            let base = furnitureItems[baseIdx]
            let node = buildFurnitureNode(type: type)
            let stackY = Float(base.node.position.y) + Float(base.type.topHeight)
            node.position = SCNVector3(Float(base.node.position.x), stackY, Float(base.node.position.z))
            root.addChildNode(node)
            var item = FurnitureItem(type: type, position: node.position, node: node)
            item.stackedOnID = base.id
            furnitureItems[baseIdx].stackedItemID = item.id
            furnitureItems.append(item)
        }

        // Karpet — di tengah kamar
        spawnFloor(type: .rug,      x:  0,    z:  0.2)
        // Kasur — pojok kiri belakang
        spawnFloor(type: .bed,      x: -1.55, z: -0.6,  yaw: .pi / 2)
        // Lemari — dinding kanan belakang
        spawnFloor(type: .wardrobe, x:  2.1,  z: -1.1,  yaw: .pi / 2)
        // Meja — sudut kiri depan
        spawnFloor(type: .desk,     x: -1.8,  z:  0.9,  yaw: .pi)
        // Lampu — pojok kanan depan
        spawnFloor(type: .lamp,     x:  2.1,  z:  1.2)
        // Tas di atas meja
        if let deskIdx = furnitureItems.firstIndex(where: { $0.type == .desk }) {
            spawnStacked(type: .bag, on: deskIdx)
        }
        // Jam dinding
        spawnWall(type: .wallClock, x: 1.2, z: -1.79, yaw: 0)

        // ── Spawn karakter ──
        let charNode = buildCharacterNode()
        characterNode.addChildNode(charNode)
        root.addChildNode(characterNode)

        // cameraPivot di posisi karakter, orbit kamera di sekelilingnya
        cameraPivot.eulerAngles.y = SCNFloat(yaw)
        root.addChildNode(cameraPivot)
        updateCameraForTPP()
    }

    // MARK: - Build Character Node

    func buildCharacterNode() -> SCNNode {
        let root = SCNNode()
        root.name = "character"

        let skin  = UIColor(red: 0.95, green: 0.78, blue: 0.65, alpha: 1)
        let shirt = UIColor(red: 0.25, green: 0.45, blue: 0.80, alpha: 1)
        let pants = UIColor(red: 0.20, green: 0.22, blue: 0.35, alpha: 1)
        let shoes = UIColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1)
        let hair  = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)

        func geo(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, color: UIColor) -> SCNNode {
            let g = SCNBox(width: w, height: h, length: d, chamferRadius: 0.025)
            g.firstMaterial?.diffuse.contents = color
            g.firstMaterial?.lightingModel = .lambert
            return SCNNode(geometry: g)
        }

        // ── Badan ──
        let body = geo(0.30, 0.36, 0.16, color: shirt)
        body.position = SCNVector3(0, 0.72, 0)
        root.addChildNode(body)

        // ── Leher ──
        let neck = geo(0.10, 0.08, 0.10, color: skin)
        neck.position = SCNVector3(0, 0.94, 0)
        root.addChildNode(neck)

        // ── Kepala ──
        let headGeo = SCNBox(width: 0.24, height: 0.24, length: 0.22, chamferRadius: 0.05)
        headGeo.firstMaterial?.diffuse.contents = skin
        headGeo.firstMaterial?.lightingModel = .lambert
        let head = SCNNode(geometry: headGeo)
        head.position = SCNVector3(0, 1.07, 0)
        root.addChildNode(head)

        // Rambut
        let hairGeo = SCNBox(width: 0.25, height: 0.09, length: 0.23, chamferRadius: 0.03)
        hairGeo.firstMaterial?.diffuse.contents = hair
        hairGeo.firstMaterial?.lightingModel = .lambert
        let hairNode = SCNNode(geometry: hairGeo)
        hairNode.position = SCNVector3(0, 1.21, 0)
        root.addChildNode(hairNode)

        // Mata
        for xOff: Float in [-0.06, 0.06] {
            let eyeGeo = SCNSphere(radius: 0.022)
            eyeGeo.firstMaterial?.diffuse.contents = UIColor(white: 0.1, alpha: 1)
            eyeGeo.firstMaterial?.lightingModel = .constant
            let eye = SCNNode(geometry: eyeGeo)
            eye.position = SCNVector3(xOff, 1.07, 0.115)
            root.addChildNode(eye)
        }

        // ── Lengan — pivot di bahu ──
        let shoulderY: Float = 0.88
        let armOffX:   Float = 0.20

        func makeArm(side: Float) -> (pivot: SCNNode, arm: SCNNode) {
            let pivot = SCNNode()
            pivot.position = SCNVector3(side * armOffX, shoulderY, 0)
            // Upper arm
            let upper = geo(0.09, 0.20, 0.09, color: shirt)
            upper.position = SCNVector3(0, -0.10, 0)
            pivot.addChildNode(upper)
            // Hand
            let hand = geo(0.08, 0.09, 0.08, color: skin)
            hand.position = SCNVector3(0, -0.24, 0)
            pivot.addChildNode(hand)
            return (pivot, upper)
        }

        let (lArmPivot, _) = makeArm(side: -1)
        let (rArmPivot, _) = makeArm(side:  1)
        root.addChildNode(lArmPivot)
        root.addChildNode(rArmPivot)
        armLPivot = lArmPivot
        armRPivot = rArmPivot

        // ── Kaki — pivot di pinggul ──
        let hipY:    Float = 0.54
        let legOffX: Float = 0.07

        func makeLeg(side: Float) -> SCNNode {
            let pivot = SCNNode()
            pivot.position = SCNVector3(side * legOffX, hipY, 0)
            // Paha (celana)
            let thigh = geo(0.11, 0.26, 0.12, color: pants)
            thigh.position = SCNVector3(0, -0.13, 0)
            pivot.addChildNode(thigh)
            // Betis (celana)
            let shin = geo(0.10, 0.24, 0.11, color: pants)
            shin.position = SCNVector3(0, -0.35, 0)
            pivot.addChildNode(shin)
            // Sepatu
            let shoe = geo(0.11, 0.08, 0.17, color: shoes)
            shoe.position = SCNVector3(0, -0.52, 0.02)
            pivot.addChildNode(shoe)
            return pivot
        }

        let lLegPivot = makeLeg(side: -1)
        let rLegPivot = makeLeg(side:  1)
        root.addChildNode(lLegPivot)
        root.addChildNode(rLegPivot)
        legLPivot = lLegPivot
        legRPivot = rLegPivot

        return root
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
                hn.position = SCNVector3(side, 0.9, Float(d/2) + 0.03)
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

        case .wallClock:
            let R: CGFloat = 0.175
            let depth: CGFloat = 0.04

            let rimGeo = SCNCylinder(radius: R, height: depth)
            rimGeo.firstMaterial?.diffuse.contents = UIColor(red:0.38, green:0.24, blue:0.10, alpha:1)
            let rimNode = SCNNode(geometry: rimGeo)
            rimNode.eulerAngles.x = -.pi / 2
            root.addChildNode(rimNode)

            let faceGeo = SCNCylinder(radius: R - 0.012, height: depth + 0.002)
            faceGeo.firstMaterial?.diffuse.contents = UIColor(red:0.97, green:0.95, blue:0.88, alpha:1)
            faceGeo.firstMaterial?.lightingModel = .constant
            let faceNode = SCNNode(geometry: faceGeo)
            faceNode.eulerAngles.x = -.pi / 2
            root.addChildNode(faceNode)

            for i in 0..<12 {
                let angle = Float(i) * (.pi * 2 / 12)
                let isMain = (i % 3 == 0)
                let tickW: CGFloat = isMain ? 0.014 : 0.007
                let tickH: CGFloat = isMain ? 0.036 : 0.022
                let tickGeo = SCNBox(width: tickW, height: tickH, length: 0.008, chamferRadius: 0.002)
                tickGeo.firstMaterial?.diffuse.contents = UIColor(red:0.15, green:0.10, blue:0.06, alpha:1)
                tickGeo.firstMaterial?.lightingModel = .constant
                let tickNode = SCNNode(geometry: tickGeo)
                let r = Float(R) - Float(tickH) / 2 - 0.010
                tickNode.position = SCNVector3(sin(angle) * r, cos(angle) * r, Float(depth)/2 + 0.003)
                tickNode.eulerAngles.z = SCNFloat(-angle)
                root.addChildNode(tickNode)
            }

            let pivotGeo = SCNCylinder(radius: 0.014, height: 0.018)
            pivotGeo.firstMaterial?.diffuse.contents = UIColor(red:0.25, green:0.16, blue:0.08, alpha:1)
            pivotGeo.firstMaterial?.lightingModel = .constant
            let pivotNode = SCNNode(geometry: pivotGeo)
            pivotNode.eulerAngles.x = -.pi / 2
            pivotNode.position = SCNVector3(0, 0, Float(depth)/2 + 0.006)
            root.addChildNode(pivotNode)

            let now = Date(); let cal = Calendar.current
            let hour   = Float(cal.component(.hour,   from: now) % 12)
            let minute = Float(cal.component(.minute, from: now))
            let second = Float(cal.component(.second, from: now))
            let hourAngle   = -(hour + minute / 60.0) * (.pi * 2 / 12)
            let minuteAngle = -(minute + second / 60.0) * (.pi * 2 / 60)

            let hourHandGeo = SCNBox(width: 0.014, height: 0.095, length: 0.008, chamferRadius: 0.003)
            hourHandGeo.firstMaterial?.diffuse.contents = UIColor(red:0.12, green:0.08, blue:0.04, alpha:1)
            hourHandGeo.firstMaterial?.lightingModel = .constant
            let hourPivot = SCNNode()
            hourPivot.position = SCNVector3(0, 0, Float(depth)/2 + 0.008)
            let hourHand = SCNNode(geometry: hourHandGeo); hourHand.position = SCNVector3(0, 0.047, 0)
            hourPivot.addChildNode(hourHand); hourPivot.eulerAngles.z = SCNFloat(hourAngle)
            root.addChildNode(hourPivot)
            hourPivot.runAction(SCNAction.repeatForever(.rotateBy(x: 0, y: 0, z: -2 * .pi, duration: 43200)))

            let minHandGeo = SCNBox(width: 0.010, height: 0.130, length: 0.008, chamferRadius: 0.003)
            minHandGeo.firstMaterial?.diffuse.contents = UIColor(red:0.12, green:0.08, blue:0.04, alpha:1)
            minHandGeo.firstMaterial?.lightingModel = .constant
            let minPivot = SCNNode()
            minPivot.position = SCNVector3(0, 0, Float(depth)/2 + 0.010)
            let minHand = SCNNode(geometry: minHandGeo); minHand.position = SCNVector3(0, 0.065, 0)
            minPivot.addChildNode(minHand); minPivot.eulerAngles.z = SCNFloat(minuteAngle)
            root.addChildNode(minPivot)
            minPivot.runAction(SCNAction.repeatForever(.rotateBy(x: 0, y: 0, z: -2 * .pi, duration: 3600)))

            let secHandGeo = SCNBox(width: 0.006, height: 0.150, length: 0.006, chamferRadius: 0.002)
            secHandGeo.firstMaterial?.diffuse.contents = UIColor(red:0.85, green:0.12, blue:0.10, alpha:1)
            secHandGeo.firstMaterial?.lightingModel = .constant
            let secPivot = SCNNode()
            secPivot.position = SCNVector3(0, 0, Float(depth)/2 + 0.012)
            let secHand = SCNNode(geometry: secHandGeo); secHand.position = SCNVector3(0, 0.072, 0)
            secPivot.addChildNode(secHand)
            let tailGeo = SCNBox(width: 0.006, height: 0.040, length: 0.006, chamferRadius: 0.001)
            tailGeo.firstMaterial?.diffuse.contents = UIColor(red:0.85, green:0.12, blue:0.10, alpha:1)
            tailGeo.firstMaterial?.lightingModel = .constant
            let tailNode = SCNNode(geometry: tailGeo); tailNode.position = SCNVector3(0, -0.022, 0)
            secPivot.addChildNode(tailNode)
            secPivot.eulerAngles.z = SCNFloat(-second * (.pi * 2 / 60))
            root.addChildNode(secPivot)
            secPivot.runAction(SCNAction.repeatForever(.rotateBy(x: 0, y: 0, z: -2 * .pi, duration: 60)))
        }

        return root
    }
}
