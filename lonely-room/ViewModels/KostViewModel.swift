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
    // Dinding inner: X ±2.8, Z ±1.8. Kamera ideal di belakang 2m.
    // Karakter dibatasi lebih ketat agar kamera tidak pernah menyentuh dinding.
    let minX: Float    = -2.0, maxX: Float =  2.0
    let minZ: Float    = -1.0, maxZ: Float =  1.0
    
    @Published var isWalking         = false
    @Published var isNearBed         = false
    @Published var isLyingDown       = false
    @Published var isNearSwitch      = false
    @Published var isLightOn         = true
    @Published var roomBrightness: Float = 0.85
    @Published var isNearMusicPlayer = false
    @Published var isNearChair       = false
    @Published var isSitting         = false
    @Published var isNearWindow      = false
    @Published var isWindowOpen      = false
    @Published var isNearLamp        = false
    @Published var isLampOn          = false
    @Published var isNearPlant       = false
    @Published var isWatering        = false

    weak var wateringCanNode: SCNNode?   // node kaleng di tangan kanan karakter

    // Posisi world jendela untuk proximity check
    var windowWorldPos: SIMD3<Float> = .zero
    weak var windowPanelL: SCNNode?
    weak var windowPanelR: SCNNode?
    var windowPanelLOriginX: Float = 0
    var windowPanelROriginX: Float = 0
    weak var curtainL: SCNNode?
    weak var curtainR: SCNNode?
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
    weak var sunLightNode:     SCNNode?
    weak var fillLightNode:    SCNNode?
    weak var winLightNode:     SCNNode?
    weak var outsideNode:      SCNNode?
    weak var rainParticleNode: SCNNode?
    weak var roomLightNode:    SCNNode?
    weak var switchNode:       SCNNode?
    var switchWorldPos: SIMD3<Float> = .zero
    
    var rainDisplayLink: CADisplayLink?
    var rainTimeOffset: Double = 0
    var lastRainTimestamp: Double = 0
    
    // leg pivot nodes untuk animasi berjalan
    var legLPivot: SCNNode?
    var legRPivot: SCNNode?
    var kneeLPivot: SCNNode?
    var kneeRPivot: SCNNode?
    var armLPivot: SCNNode?
    var armRPivot: SCNNode?
    
    init() {
        let cam = SCNCamera()
        cam.zNear = 0.15; cam.zFar = 100; cam.fieldOfView = 60
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
        
        // Head position in world space.
        // Saat berdiri: charPos.y ≈ 0, kepala di +1.1.
        // Saat rebahan: charPos.y ≈ 0.42 (kasur), tubuh flat, kepala hanya +0.15 di atasnya.
        let charPos  = characterNode.worldPosition
        let headOffY: Float = isLyingDown ? 0.15 : 1.1
        let headPos  = SCNVector3(charPos.x, charPos.y + headOffY, charPos.z)
        
        // Compute IDEAL camera world position from pivot yaw + current local Y/Z offsets.
        // Must NOT use cameraNode.worldPosition (may already be clamped).
        let pivotYaw  = Float(cameraPivot.eulerAngles.y)
        let localCamZ = idealCameraZ
        let localCamY = Float(cameraNode.position.y)   // 1.1 normal, 2.8 saat rebahan
        let worldCamX = charPos.x + sin(pivotYaw) * localCamZ
        let worldCamY = charPos.y + localCamY
        let worldCamZ = charPos.z + cos(pivotYaw) * localCamZ
        let idealCamPos = SCNVector3(worldCamX, worldCamY, worldCamZ)
        
        let dx = idealCamPos.x - headPos.x
        let dy = idealCamPos.y - headPos.y
        let dz = idealCamPos.z - headPos.z
        let dist = sqrt(dx*dx + dy*dy + dz*dz)
        guard dist > 0.001 else { return }
        
        // Ray-cast — hanya peduli node bernama "wall"
        let options: [String: Any] = [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ]
        
        let hits = root.hitTestWithSegment(from: headPos, to: idealCamPos, options: options)
        
        let wallHit = hits.first { hit in
            var n: SCNNode? = hit.node
            while let node = n {
                if node.name == "wall" { return true }
                n = node.parent
            }
            return false
        }
        
        let targetZ: Float
        if let hit = wallHit {
            let hx = hit.worldCoordinates.x - headPos.x
            let hy = hit.worldCoordinates.y - headPos.y
            let hz = hit.worldCoordinates.z - headPos.z
            let hitDist = sqrt(hx*hx + hy*hy + hz*hz)
            // margin 0.30m agar kamera tidak pernah menyentuh dinding
            let clampedDist = max(minCameraZ, hitDist - 0.30)
            targetZ = idealCameraZ * (clampedDist / dist)
        } else {
            targetZ = idealCameraZ
        }
        
        // Langsung snap saat kamera perlu mundur (mendekati dinding), smooth saat kembali
        let current = cameraNode.position.z
        let alpha: Float = targetZ < current ? 1.0 : 0.15
        let newZ = current + (targetZ - current) * alpha
        cameraNode.position.z = newZ
        
        // ── Hard clamp: pastikan posisi WORLD kamera tidak menembus dinding apapun ──
        // Dinding inner: X ∈ [-2.8, 2.8], Z ∈ [-1.8, 1.8], margin kamera 0.25m
        let camMargin: Float = 0.25
        let camWorldX = charPos.x + sin(pivotYaw) * newZ
        let camWorldZ = charPos.z + cos(pivotYaw) * newZ
        let clampedCamX = max(-2.8 + camMargin, min(2.8 - camMargin, camWorldX))
        let clampedCamZ = max(-1.8 + camMargin, min(1.8 - camMargin, camWorldZ))
        
        // Jika hard clamp memotong posisi kamera, kurangi jarak Z kamera
        if clampedCamX != camWorldX || clampedCamZ != camWorldZ {
            // Hitung jarak yang aman berdasarkan posisi ter-clamp
            let dcx = clampedCamX - charPos.x
            let dcz = clampedCamZ - charPos.z
            let safeDist = sqrt(dcx*dcx + dcz*dcz)
            // Proyeksikan ke arah kamera (pivot Z)
            let safeZ = max(minCameraZ, safeDist)
            cameraNode.position.z = min(newZ, safeZ)
        }
    }
    
    // MARK: - Movement
    
    func move(dx: Float, dy: Float) {
        guard !isLyingDown, !isSitting else { return }
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
        
        // Cek apakah dekat kasur / saklar
        checkNearBed()
        checkNearSwitch()
        checkNearMusicPlayer()
        checkNearChair()
        checkNearWindow()
        checkNearLamp()
        checkNearPlant()
        
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
    
    // MARK: - Bed Proximity & Lie Down
    
    func checkNearBed() {
        guard !isLyingDown else { return }
        let bedItem = furnitureItems.first(where: { $0.type == .bed })
        guard let bed = bedItem else { isNearBed = false; return }
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let bx = Float(bed.node.position.x)
        let bz = Float(bed.node.position.z)
        let dist = sqrt((cx - bx) * (cx - bx) + (cz - bz) * (cz - bz))
        isNearBed = dist < 1.2
    }
    
    func layDown() {
        guard !isLyingDown, let bed = furnitureItems.first(where: { $0.type == .bed }) else { return }
        isLyingDown = true
        isNearBed   = false
        stopWalking()
        
        let bedNode = bed.node
        let bedYaw  = Float(bedNode.eulerAngles.y)
        let bx = Float(bedNode.position.x)
        let bz = Float(bedNode.position.z)
        
        // ── Posisi rebahan ──
        // eulerAngles = (-π/2, lyingFacing, 0): kepala (local +Y) → world (sin(Y), 0, cos(Y))
        // Dari hasil test: lyingFacing = bedYaw + π → kepala/kaki sudah di arah yang benar
        // tapi posisi masih di tengah kasur. Geser karakter ke arah bantal (~0.5m)
        // agar kepala tepat di atas bantal.
        //
        // Arah bantal (local -Z kasur) di world = (-sin(bedYaw), 0, -cos(bedYaw))
        let lyingFacing: Float = bedYaw   // flip: kepala kiri, kaki kanan
        let pillarDirX = sin(bedYaw)    // arah dari center ke bantal (berlawanan dari sebelumnya)
        let pillarDirZ = cos(bedYaw)
        // Geser origin karakter 0.5m ke arah bantal dari center kasur
        let charOriginX = bx + pillarDirX * 0.5
        let charOriginZ = bz + pillarDirZ * 0.5
        let mattressTopY: Float = 0.42
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.7
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        characterNode.position    = SCNVector3(charOriginX, mattressTopY, charOriginZ)
        characterNode.eulerAngles = SCNVector3(-.pi / 2, lyingFacing, 0)
        charFacing = lyingFacing
        SCNTransaction.commit()
        
        // Kamera bird-eye dari atas kasur
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.7
        cameraNode.position    = SCNVector3(0, 2.8, 1.4)
        cameraNode.eulerAngles = SCNVector3(-0.60, 0, 0)
        SCNTransaction.commit()
        
        updateCameraForTPP()
    }
    
    func standUp() {
        guard isLyingDown else { return }
        isLyingDown = false
        
        // Geser karakter ke sisi kasur (arah local +X kasur = lebar) supaya tidak berdiri di dalam kasur
        if let bed = furnitureItems.first(where: { $0.type == .bed }) {
            let bedYaw = Float(bed.node.eulerAngles.y)
            let bx = Float(bed.node.position.x)
            let bz = Float(bed.node.position.z)
            // Sisi kasur arah local +X → world: (cos(bedYaw), 0, sin(bedYaw)) * 0.75
            let sideX = bx + cos(bedYaw) * 0.75
            let sideZ = bz + sin(bedYaw) * 0.75
            
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            characterNode.position    = SCNVector3(sideX, 0, sideZ)
            characterNode.eulerAngles = SCNVector3(0, charFacing, 0)
            SCNTransaction.commit()
        } else {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            characterNode.position.y  = 0
            characterNode.eulerAngles = SCNVector3(0, charFacing, 0)
            SCNTransaction.commit()
        }
        
        // Kembalikan posisi & sudut kamera normal
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        cameraNode.position    = SCNVector3(0, 1.1, 2.0)
        cameraNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        SCNTransaction.commit()
        
        updateCameraForTPP()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.checkNearBed(); self.checkNearSwitch(); self.checkNearMusicPlayer() }
    }
    
    // MARK: - Music Player Proximity
    
    func checkNearMusicPlayer() {
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let item = furnitureItems.first(where: { $0.type == .musicPlayer })
        guard let mp = item else { isNearMusicPlayer = false; return }
        let dx = cx - Float(mp.node.position.x)
        let dz = cz - Float(mp.node.position.z)
        isNearMusicPlayer = sqrt(dx*dx + dz*dz) < 1.2
    }

    // MARK: - Chair Proximity & Sit

    func checkNearChair() {
        guard !isSitting else { return }
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let chair = furnitureItems.first(where: { $0.type == .chair })
        guard let ch = chair else { isNearChair = false; return }
        let dx = cx - Float(ch.node.position.x)
        let dz = cz - Float(ch.node.position.z)
        isNearChair = sqrt(dx*dx + dz*dz) < 1.0
    }

    func sitDown() {
        guard let chair = furnitureItems.first(where: { $0.type == .chair }) else { return }
        isSitting   = true
        isNearChair = false
        stopWalking()

        let cx   = Float(chair.node.position.x)
        let cz   = Float(chair.node.position.z)
        let yaw  = Float(chair.node.eulerAngles.y)

        // Karakter duduk di tengah seat, menghadap ke depan kursi
        let facingYaw: Float = yaw

        // seatTopY = tinggi atas seat kursi
        // hipY     = tinggi hip pivot dari root karakter (0.54)
        // characterNode.y = seatTopY - hipY agar pantat tepat duduk di seat
        let seatTopY: Float = 0.50   // seat position.y=0.46 + half height 0.04
        let hipY:     Float = 0.54
        let charY:    Float = seatTopY - hipY   // ≈ -0.04

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.45
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        characterNode.position    = SCNVector3(cx, charY, cz)
        characterNode.eulerAngles = SCNVector3(0, facingYaw, 0)
        charFacing = facingYaw
        SCNTransaction.commit()

        // Kamera sedikit lebih rendah dan dekat
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.45
        cameraNode.position    = SCNVector3(0, 0.75, 1.6)
        cameraNode.eulerAngles = SCNVector3(-0.10, 0, 0)
        SCNTransaction.commit()

        // Reset semua pivot kaki dulu
        legLPivot?.eulerAngles  = SCNVector3(0, 0, 0)
        legRPivot?.eulerAngles  = SCNVector3(0, 0, 0)
        kneeLPivot?.eulerAngles = SCNVector3(0, 0, 0)
        kneeRPivot?.eulerAngles = SCNVector3(0, 0, 0)

        // Paha rotate -π/2 di X → horizontal ke depan
        let thighAngle = CGFloat.pi / 2
        legLPivot?.runAction(.rotateTo(x: -thighAngle, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        legRPivot?.runAction(.rotateTo(x: -thighAngle, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        // Betis rotate +π/2 di X dari knee pivot → tegak lurus ke bawah
        kneeLPivot?.runAction(.rotateTo(x: thighAngle, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        kneeRPivot?.runAction(.rotateTo(x: thighAngle, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        // Turunkan lengan
        armLPivot?.runAction(.rotateTo(x: CGFloat.pi * 0.15, y: 0, z: 0, duration: 0.45))
        armRPivot?.runAction(.rotateTo(x: CGFloat.pi * 0.15, y: 0, z: 0, duration: 0.45))
    }

    func standUpChair() {
        guard isSitting else { return }
        isSitting = false

        // Berdiri di depan kursi (geser sedikit ke depan dari seat)
        if let chair = furnitureItems.first(where: { $0.type == .chair }) {
            let cx  = Float(chair.node.position.x)
            let cz  = Float(chair.node.position.z)
            let yaw = Float(chair.node.eulerAngles.y)
            // Geser 0.5m ke depan dari kursi supaya tidak nge-clip
            let standX = cx + sin(yaw) * 0.55
            let standZ = cz + cos(yaw) * 0.55 * -1

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            characterNode.position    = SCNVector3(standX, 0, standZ)
            characterNode.eulerAngles = SCNVector3(0, charFacing, 0)
            SCNTransaction.commit()
        } else {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            characterNode.position.y = 0
            SCNTransaction.commit()
        }

        // Kembalikan kamera normal
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.45
        cameraNode.position    = SCNVector3(0, 1.1, 2.0)
        cameraNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        SCNTransaction.commit()

        // Luruskan kembali kaki dan lengan ke posisi berdiri
        legLPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        legRPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        kneeLPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        kneeRPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        armLPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))
        armRPivot?.runAction(.rotateTo(x: 0, y: 0, z: 0, duration: 0.45, usesShortestUnitArc: true))

        updateCameraForTPP()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.legLPivot?.eulerAngles  = SCNVector3(0, 0, 0)
            self.legRPivot?.eulerAngles  = SCNVector3(0, 0, 0)
            self.kneeLPivot?.eulerAngles = SCNVector3(0, 0, 0)
            self.kneeRPivot?.eulerAngles = SCNVector3(0, 0, 0)
            self.armLPivot?.eulerAngles  = SCNVector3(0, 0, 0)
            self.armRPivot?.eulerAngles  = SCNVector3(0, 0, 0)
            self.checkNearChair()
            self.checkNearBed()
            self.checkNearSwitch()
            self.checkNearMusicPlayer()
            self.checkNearWindow()
        }
    }

    // MARK: - Window

    func checkNearWindow() {
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let dx = cx - windowWorldPos.x
        let dz = cz - windowWorldPos.z
        isNearWindow = sqrt(dx*dx + dz*dz) < 1.4
    }

    // MARK: - Floor Lamp

    func checkNearLamp() {
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        // Cek semua lamp item, aktif kalau dekat salah satu
        let near = furnitureItems.filter { $0.type == .lamp }.contains { item in
            let dx = cx - Float(item.node.position.x)
            let dz = cz - Float(item.node.position.z)
            return sqrt(dx*dx + dz*dz) < 1.0
        }
        isNearLamp = near
    }

    func toggleLamp() {
        isLampOn.toggle()
        // Update omni light di semua lamp node
        for item in furnitureItems where item.type == .lamp {
            item.node.enumerateChildNodes { node, _ in
                guard let light = node.light, light.type == .omni else { return }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.3
                light.intensity = self.isLampOn ? 600 : 0
                SCNTransaction.commit()
            }
        }
    }

    func toggleWindow() {
        isWindowOpen.toggle()
        guard let panelL = windowPanelL, let panelR = windowPanelR else { return }

        let targetLx: Float = isWindowOpen ? windowPanelLOriginX - 0.28 : windowPanelLOriginX
        let targetRx: Float = isWindowOpen ? windowPanelROriginX + 0.28 : windowPanelROriginX

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        panelL.position.x = targetLx
        panelR.position.x = targetRx
        panelL.opacity = isWindowOpen ? 0.25 : 0.72
        panelR.opacity = isWindowOpen ? 0.25 : 0.72
        SCNTransaction.commit()

        // Animasi tirai berbasis pivot — tirai berayun dari ujung atas seperti tertiup angin
        if isWindowOpen {
            // Tirai berayun ke dalam ruangan (rotasi X negatif = ayun ke depan/dalam)
            // pivot ada di atas, jadi rotateBy X negatif = bawah tirai ke dalam ruangan
            //
            // 1) Hembusan awal: ayunan besar masuk, lalu damp seperti pendulum
            _  = CAMediaTimingFunction(name: .easeIn)
            _ = CAMediaTimingFunction(name: .easeOut)

            func windBlast(for curtain: SCNNode) {
                // Fase 1 – hembus kencang ke dalam (sudut ~30°)
                let phase1 = SCNAction.customAction(duration: 0.55) { node, t in
                    let progress = Float(t / 0.55)
                    // easeOut: cepat di awal, lambat di akhir
                    let eased = 1 - pow(1 - progress, 3)
                    node.eulerAngles.x = -eased * Float.pi * 0.17   // max ~30°
                }
                // Fase 2 – balik ke luar sedikit (rebound ~12°)
                let phase2 = SCNAction.customAction(duration: 0.38) { node, t in
                    let progress = Float(t / 0.38)
                    let eased = sin(progress * Float.pi)
                    let baseAngle: Float = -Float.pi * 0.17
                    node.eulerAngles.x = baseAngle + eased * Float.pi * 0.08
                }
                // Fase 3 – settle ke posisi angin steady (~18°)
                let phase3 = SCNAction.customAction(duration: 0.45) { node, t in
                    let progress = Float(t / 0.45)
                    let eased = 1 - pow(1 - progress, 2)
                    let fromAngle: Float = -Float.pi * 0.17 + Float.pi * 0.08 * sin(Float.pi)
                    let toAngle:   Float = -Float.pi * 0.105   // ~19° steady
                    node.eulerAngles.x = fromAngle + (toAngle - fromAngle) * eased
                }

                // Loop angin halus: berayun perlahan ±4° di sekitar posisi steady
                let swayAmp:  Float = Float.pi * 0.025   // ±4.5°
                let baseAngle: Float = -Float.pi * 0.105
                let gentleSway = SCNAction.repeatForever(.sequence([
                    // Hembus sedikit lebih dalam
                    SCNAction.customAction(duration: 1.4) { node, t in
                        let p = Float(t / 1.4)
                        let wave = sin(p * Float.pi)                // 0→1→0
                        node.eulerAngles.x = baseAngle - wave * swayAmp
                    },
                    // Balik sedikit
                    SCNAction.customAction(duration: 1.1) { node, t in
                        let p = Float(t / 1.1)
                        let wave = sin(p * Float.pi)
                        node.eulerAngles.x = baseAngle + wave * (swayAmp * 0.5)
                    }
                ]))

                curtain.removeAllActions()
                curtain.runAction(.sequence([phase1, phase2, phase3, gentleSway]))
            }

            if let cL = curtainL { windBlast(for: cL) }
            if let cR = curtainR { windBlast(for: cR) }

        } else {
            // Jendela tutup → tirai jatuh kembali diam perlahan
            [curtainL, curtainR].forEach { c in
                guard let c else { return }
                c.removeAllActions()
                // Ayun kecil sebelum berhenti (efek pendulum mati)
                let settle = SCNAction.sequence([
                    SCNAction.customAction(duration: 0.6) { node, t in
                        let p = Float(t / 0.6)
                        let decay = exp(-p * 3.5)
                        let current = node.eulerAngles.x
                        node.eulerAngles.x = current * (1 - p) * decay
                    },
                    SCNAction.customAction(duration: 0.3) { node, _ in
                        node.eulerAngles.x = 0
                    }
                ])
                c.runAction(settle)
            }
        }

        // Suara angin
        if isWindowOpen { WindPlayer.shared.start() }
        else            { WindPlayer.shared.stop()  }
    }

    // MARK: - Plant Proximity & Watering

    func checkNearPlant() {
        guard !isWatering else { return }
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let near = furnitureItems.filter { $0.type == .plant }.contains { item in
            let dx = cx - Float(item.node.position.x)
            let dz = cz - Float(item.node.position.z)
            return sqrt(dx*dx + dz*dz) < 1.0
        }
        isNearPlant = near
    }

    func waterPlant() {
        guard !isWatering else { return }
        isWatering  = true
        isNearPlant = false

        // Pasang kaleng penyiram di tangan kanan
        if let armR = armRPivot {
            let can = buildWateringCanNode()
            can.name = "wateringCan"
            // Posisi di ujung tangan (hand berada di y=-0.24 dari pivot)
            can.position = SCNVector3(0.06, -0.30, 0.06)
            can.eulerAngles = SCNVector3(0, Float.pi * 0.1, Float.pi * 0.15)
            can.scale = SCNVector3(0.55, 0.55, 0.55)
            can.opacity = 0
            armR.addChildNode(can)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.25
            can.opacity = 1
            SCNTransaction.commit()
            wateringCanNode = can
        }

        // Animasi lengan kanan terangkat ke depan-atas (menyiram)
        armRPivot?.runAction(.sequence([
            .rotateTo(x: -CGFloat.pi * 0.45, y: CGFloat.pi * 0.08, z: 0, duration: 0.4, usesShortestUnitArc: true),
            .wait(duration: 1.2),
            .rotateTo(x: 0, y: 0, z: 0, duration: 0.4, usesShortestUnitArc: true)
        ]))

        // Mulai suara siram
        WateringPlayer.shared.start()

        // Lepas kaleng setelah animasi selesai
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            // Stop suara siram
            WateringPlayer.shared.stop()
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            self.wateringCanNode?.opacity = 0
            SCNTransaction.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.wateringCanNode?.removeFromParentNode()
                self.wateringCanNode = nil
                self.isWatering = false
                self.checkNearPlant()
            }
        }
    }

    /// Buat SCNNode kaleng penyiram mini yang ditempel ke lengan karakter
    private func buildWateringCanNode() -> SCNNode {
        let root = SCNNode()
        let green = UIColor(red: 0.22, green: 0.62, blue: 0.42, alpha: 1)
        let darkGreen = UIColor(red: 0.14, green: 0.42, blue: 0.28, alpha: 1)

        // Badan kaleng
        let body = SCNBox(width: 0.18, height: 0.14, length: 0.10, chamferRadius: 0.02)
        body.firstMaterial?.diffuse.contents = green
        body.firstMaterial?.lightingModel = .lambert
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0, 0)
        root.addChildNode(bodyNode)

        // Tutup atas
        let lid = SCNBox(width: 0.14, height: 0.03, length: 0.08, chamferRadius: 0.01)
        lid.firstMaterial?.diffuse.contents = darkGreen
        lid.firstMaterial?.lightingModel = .lambert
        let lidNode = SCNNode(geometry: lid)
        lidNode.position = SCNVector3(0, 0.085, 0)
        root.addChildNode(lidNode)

        // Gagang (handle) melengkung — pakai torus
        let handle = SCNTorus(ringRadius: 0.055, pipeRadius: 0.012)
        handle.firstMaterial?.diffuse.contents = darkGreen
        handle.firstMaterial?.lightingModel = .lambert
        let handleNode = SCNNode(geometry: handle)
        handleNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        handleNode.position = SCNVector3(0.12, 0, 0)
        root.addChildNode(handleNode)

        // Moncong (spout) — silinder miring ke depan
        let spout = SCNCylinder(radius: 0.018, height: 0.14)
        spout.firstMaterial?.diffuse.contents = green
        spout.firstMaterial?.lightingModel = .lambert
        let spoutNode = SCNNode(geometry: spout)
        spoutNode.eulerAngles = SCNVector3(Float.pi * 0.35, 0, 0)
        spoutNode.position = SCNVector3(-0.06, 0.06, -0.10)
        root.addChildNode(spoutNode)

        // Kepala sprinkler (rose)
        let rose = SCNCylinder(radius: 0.032, height: 0.018)
        rose.firstMaterial?.diffuse.contents = darkGreen
        rose.firstMaterial?.lightingModel = .lambert
        let roseNode = SCNNode(geometry: rose)
        roseNode.eulerAngles = SCNVector3(Float.pi * 0.35, 0, 0)
        roseNode.position = SCNVector3(-0.06, 0.115, -0.155)
        root.addChildNode(roseNode)

        return root
    }

    // MARK: - Light Switch
    
    func checkNearSwitch() {
        let cx = Float(characterNode.position.x)
        let cz = Float(characterNode.position.z)
        let dx = cx - switchWorldPos.x
        let dz = cz - switchWorldPos.z
        isNearSwitch = sqrt(dx*dx + dz*dz) < 1.2
    }
    
    func toggleLight() {
        isLightOn.toggle()
        applyRoomLight()
        // Visual feedback: saklar berubah warna
        if let sw = switchNode, let mat = sw.geometry?.firstMaterial {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.2
            mat.diffuse.contents = isLightOn
            ? UIColor(red:0.95, green:0.95, blue:0.88, alpha:1)
            : UIColor(red:0.30, green:0.30, blue:0.30, alpha:1)
            mat.emission.contents = isLightOn
            ? UIColor(red:1.0, green:0.97, blue:0.80, alpha:0.6)
            : UIColor.black
            SCNTransaction.commit()
        }
    }
    
    func setBrightness(_ value: Float) {
        roomBrightness = max(0.0, min(1.0, value))
        if isLightOn { applyRoomLight() }
    }

    func applyRoomLight() {
        let b = CGFloat(roomBrightness)   // 0.0 – 1.0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        if isLightOn {
            // Ceiling omni: 0 (redup) → 2000 (terang)
            roomLightNode?.light?.intensity  = b * 2000
            roomLightNode?.light?.color      = UIColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 1)
            // Ambient: 150 (redup) → 900 (terang)
            ambientNode?.light?.intensity    = 150 + b * 750
            // Sun directional: 200 → 800
            sunLightNode?.light?.intensity   = 200 + b * 600
            // Fill: 100 → 400
            fillLightNode?.light?.intensity  = 100 + b * 300
        } else {
            // Lampu mati — semua gelap, sisakan sedikit ambient supaya tidak pitch black
            roomLightNode?.light?.intensity  = 0
            ambientNode?.light?.intensity    = 80
            sunLightNode?.light?.intensity   = 100
            fillLightNode?.light?.intensity  = 60
        }

        SCNTransaction.commit()
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
    // MARK: - Persistence
    
    func saveFurniture() {
        let data = furnitureItems.map { item in
            FurnitureSaveData(
                id:            item.id.uuidString,
                type:          item.type.rawValue,
                x:             Float(item.node.position.x),
                y:             Float(item.node.position.y),
                z:             Float(item.node.position.z),
                yaw:           Float(item.node.eulerAngles.y),
                stackedOnID:   item.stackedOnID?.uuidString,
                stackedItemID: item.stackedItemID?.uuidString
            )
        }
        FurniturePersistence.save(data)
    }
    
    // MARK: - Furniture Placement
    
    func hasItem(ofType type: FurnitureType) -> Bool {
        furnitureItems.contains { $0.type == type }
    }

    func startPlacing(type: FurnitureType) {
        guard type.allowsMultiple || !hasItem(ofType: type) else { return }
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
        saveFurniture()
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
            saveFurniture()
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
        saveFurniture()
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
        // Save dilakukan saat gesture ended, bukan setiap frame
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
        saveFurniture()
    }
    
    func rotateSelected(by angle: Float) {
        guard let item = selectedFurniture else { return }
        item.node.eulerAngles.y += SCNFloat(angle)
        saveFurniture()
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
        saveFurniture()
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
        // Weather hanya ubah winLight — room light dikontrol saklar dinding
        winLightNode?.light?.intensity = effective.code == 0 && effective.isDay ? 1200 :
            effective.code <= 2 && effective.isDay ? 900 :
            effective.isDay ? 600 : 300
        // Terapkan room light sesuai state saklar saat ini
        applyRoomLight()
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

        // ── Migrasi save lama ──
        FurniturePersistence.migrateIfNeeded()

        // ── Load dari save jika ada ──
        if let saved = FurniturePersistence.load() {
            loadSavedFurniture(saved, into: root)
        } else {
            spawnHardcodedLayout(into: root)
        }
        // Selalu save setelah spawn/load agar state terkini tersimpan
        saveFurniture()
        
        // ── Spawn karakter ──
        isLyingDown = false   // selalu mulai dalam posisi berdiri
        isNearBed   = false
        characterNode.position    = SCNVector3(0, 0, 0)
        characterNode.eulerAngles = SCNVector3(0, 0, 0)
        charFacing = 0
        let charNode = buildCharacterNode()
        characterNode.addChildNode(charNode)
        root.addChildNode(characterNode)
        
        cameraPivot.eulerAngles.y = SCNFloat(yaw)
        cameraNode.position    = SCNVector3(0, 1.1, 2.0)
        cameraNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        root.addChildNode(cameraPivot)
        updateCameraForTPP()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.checkNearBed(); self.checkNearSwitch(); self.checkNearMusicPlayer() }
    }
    
    // MARK: - Load Saved Layout
    
    private func loadSavedFurniture(_ saved: [FurnitureSaveData], into root: SCNNode) {
        // Pass 1: buat semua node dengan UUID yang sama persis agar relasi stacking bisa di-restore
        var uuidMap: [String: FurnitureItem] = [:]   // savedID → FurnitureItem
        
        // Item tanpa stackedOnID (base / standalone) dulu
        let bases  = saved.filter { $0.stackedOnID == nil }
        let stacked = saved.filter { $0.stackedOnID != nil }
        
        for data in bases {
            guard let type = FurnitureType(rawValue: data.type) else { continue }
            let node = buildFurnitureNode(type: type)
            node.position = SCNVector3(data.x, data.y, data.z)
            node.eulerAngles.y = SCNFloat(data.yaw)
            root.addChildNode(node)
            let item = FurnitureItem(type: type, position: node.position, node: node, savedID: UUID(uuidString: data.id))
            uuidMap[data.id] = item
            furnitureItems.append(item)
            if type == .wallClock { ClockPlayer.shared.start() }
        }
        
        // Pass 2: item yang di-stack di atas item lain
        for data in stacked {
            guard let type = FurnitureType(rawValue: data.type),
                  let parentID = data.stackedOnID,
                  let parentIdx = furnitureItems.firstIndex(where: { $0.savedID?.uuidString == parentID })
            else { continue }
            
            let node = buildFurnitureNode(type: type)
            node.position = SCNVector3(data.x, data.y, data.z)
            node.eulerAngles.y = SCNFloat(data.yaw)
            root.addChildNode(node)
            var item = FurnitureItem(type: type, position: node.position, node: node, savedID: UUID(uuidString: data.id))
            item.stackedOnID = furnitureItems[parentIdx].id
            furnitureItems[parentIdx].stackedItemID = item.id
            furnitureItems.append(item)
        }
    }
    
    // MARK: - Default Hardcoded Layout
    
    private func spawnHardcodedLayout(into root: SCNNode) {
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
        
        spawnFloor(type: .rug,      x:  0,    z:  0.2)
        spawnFloor(type: .bed,      x: -1.55, z: -0.6,  yaw: .pi / 2)
        spawnFloor(type: .wardrobe, x:  2.1,  z: -1.1,  yaw: .pi / 2)
        spawnFloor(type: .desk,     x: -1.8,  z:  0.9,  yaw: .pi)
        spawnFloor(type: .lamp,     x:  2.1,  z:  1.2)
        if let deskIdx = furnitureItems.firstIndex(where: { $0.type == .desk }) {
            spawnStacked(type: .bag, on: deskIdx)
        }
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
        
        func makeLeg(side: Float) -> (hip: SCNNode, knee: SCNNode) {
            let pivot = SCNNode()
            pivot.position = SCNVector3(side * legOffX, hipY, 0)
            // Paha (celana) — tergantung dari hip pivot
            let thigh = geo(0.11, 0.26, 0.12, color: pants)
            thigh.position = SCNVector3(0, -0.13, 0)
            pivot.addChildNode(thigh)
            // Knee pivot — di ujung bawah paha
            let kneePivot = SCNNode()
            kneePivot.position = SCNVector3(0, -0.26, 0)
            pivot.addChildNode(kneePivot)
            // Betis (celana) — menggantung dari knee pivot
            let shin = geo(0.10, 0.24, 0.11, color: pants)
            shin.position = SCNVector3(0, -0.12, 0)
            kneePivot.addChildNode(shin)
            // Sepatu
            let shoe = geo(0.11, 0.08, 0.17, color: shoes)
            shoe.position = SCNVector3(0, -0.28, 0.02)
            kneePivot.addChildNode(shoe)
            return (pivot, kneePivot)
        }

        let (lLegPivot, lKneePivot) = makeLeg(side: -1)
        let (rLegPivot, rKneePivot) = makeLeg(side:  1)
        root.addChildNode(lLegPivot)
        root.addChildNode(rLegPivot)
        legLPivot  = lLegPivot
        legRPivot  = rLegPivot
        kneeLPivot = lKneePivot
        kneeRPivot = rKneePivot
        
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
            
            
        case .musicPlayer:
            // Body utama radio — dark charcoal
            let body = SCNBox(width: CGFloat(w), height: 0.22, length: CGFloat(d), chamferRadius: 0.018)
            body.firstMaterial?.diffuse.contents  = UIColor(red:0.15, green:0.15, blue:0.18, alpha:1)
            body.firstMaterial?.specular.contents = UIColor(white:0.3, alpha:1)
            body.firstMaterial?.lightingModel     = .phong
            let bodyNode = SCNNode(geometry: body); bodyNode.position.y = 0.11
            root.addChildNode(bodyNode)
            
            // Speaker grille kiri (woven pattern — kotak kecil grid)
            let grilleW: CGFloat = 0.14, grilleH: CGFloat = 0.12, grilleD: CGFloat = 0.008
            let grille = SCNBox(width: grilleW, height: grilleH, length: grilleD, chamferRadius: 0.004)
            grille.firstMaterial?.diffuse.contents = UIColor(red:0.08, green:0.08, blue:0.10, alpha:1)
            let grilleNode = SCNNode(geometry: grille)
            grilleNode.position = SCNVector3(-Float(w)*0.22, 0.11, Float(d)/2 + 0.001)
            root.addChildNode(grilleNode)
            // Speaker grille kanan
            let grilleR = grilleNode.clone()
            grilleR.position.x = Float(w)*0.22
            root.addChildNode(grilleR)
            
            // Speaker cone kiri (circle)
            let cone = SCNCylinder(radius: 0.045, height: 0.006)
            cone.firstMaterial?.diffuse.contents = UIColor(red:0.22, green:0.22, blue:0.28, alpha:1)
            let coneNode = SCNNode(geometry: cone); coneNode.eulerAngles.x = -.pi/2
            coneNode.position = SCNVector3(-Float(w)*0.22, 0.11, Float(d)/2 + 0.005)
            root.addChildNode(coneNode)
            let coneR = coneNode.clone(); coneR.position.x = Float(w)*0.22
            root.addChildNode(coneR)
            
            // Display LCD kecil di tengah
            let lcd = SCNBox(width: 0.09, height: 0.045, length: 0.006, chamferRadius: 0.004)
            lcd.firstMaterial?.diffuse.contents  = UIColor(red:0.05, green:0.55, blue:0.35, alpha:1)
            lcd.firstMaterial?.emission.contents = UIColor(red:0.05, green:0.90, blue:0.50, alpha:0.8)
            lcd.firstMaterial?.lightingModel     = .constant
            let lcdNode = SCNNode(geometry: lcd)
            lcdNode.position = SCNVector3(0, 0.165, Float(d)/2 + 0.002)
            root.addChildNode(lcdNode)
            
            // Tombol putar (knob) kanan atas
            let knob = SCNCylinder(radius: 0.020, height: 0.018)
            knob.firstMaterial?.diffuse.contents  = UIColor(red:0.70, green:0.60, blue:0.20, alpha:1)
            knob.firstMaterial?.specular.contents = UIColor(white:0.8, alpha:1)
            knob.firstMaterial?.lightingModel     = .phong
            let knobNode = SCNNode(geometry: knob); knobNode.eulerAngles.x = -.pi/2
            knobNode.position = SCNVector3(Float(w)*0.35, 0.175, Float(d)/2 + 0.005)
            root.addChildNode(knobNode)
            
            // Antena
            let antGeo = SCNCylinder(radius: 0.005, height: 0.18)
            antGeo.firstMaterial?.diffuse.contents = UIColor(red:0.55, green:0.55, blue:0.58, alpha:1)
            let antNode = SCNNode(geometry: antGeo)
            antNode.position = SCNVector3(Float(w)*0.42, 0.29, 0)
            antNode.eulerAngles.z = 0.2   // sedikit miring
            root.addChildNode(antNode)

        case .chair:
            let woodColor = UIColor(red:0.65, green:0.45, blue:0.22, alpha:1)
            let cushionColor = UIColor(red:0.25, green:0.35, blue:0.55, alpha:1)
            let legGeo = SCNBox(width: 0.04, height: 0.44, length: 0.04, chamferRadius: 0.01)
            legGeo.firstMaterial?.diffuse.contents = woodColor
            for (xm, zm) in [(-1.0,-1.0),(1.0,-1.0),(-1.0,1.0),(1.0,1.0)] {
                let leg = SCNNode(geometry: legGeo)
                leg.position = SCNVector3(Float(xm)*0.22, 0.22, Float(zm)*0.22)
                root.addChildNode(leg)
            }
            // Seat cushion
            let seatGeo = SCNBox(width: 0.52, height: 0.08, length: 0.50, chamferRadius: 0.03)
            seatGeo.firstMaterial?.diffuse.contents = cushionColor
            let seatNode = SCNNode(geometry: seatGeo); seatNode.position.y = 0.46
            root.addChildNode(seatNode)
            // Backrest frame
            let backGeo = SCNBox(width: 0.48, height: 0.42, length: 0.06, chamferRadius: 0.02)
            backGeo.firstMaterial?.diffuse.contents = cushionColor
            let backNode = SCNNode(geometry: backGeo)
            backNode.position = SCNVector3(0, 0.72, -0.22)
            root.addChildNode(backNode)
            // Back support bar
            let barGeo = SCNBox(width: 0.04, height: 0.46, length: 0.04, chamferRadius: 0.01)
            barGeo.firstMaterial?.diffuse.contents = woodColor
            for xm in [-0.21, 0.21] as [Float] {
                let bar = SCNNode(geometry: barGeo)
                bar.position = SCNVector3(xm, 0.70, -0.22)
                root.addChildNode(bar)
            }
        }

        return root
    }
}

