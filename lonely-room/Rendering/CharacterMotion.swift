import SceneKit
import QuartzCore

// MARK: - Character Motion
/// Gerak karakter + kamera orang ketiga, dijalankan di render loop SceneKit
/// (`renderer(_:updateAtTime:)`) sehingga tepat satu langkah per frame yang di-render.
///
/// Sebelumnya gerakan dihitung di main thread (Timer / CADisplayLink) sementara SceneKit
/// me-render di thread-nya sendiri. Keduanya tidak sinkron: sebagian frame mendapat 2 langkah,
/// sebagian 0 — itulah yang terasa "patah-patah" di HP.
///
/// State yang dipakai bersama main thread dilindungi lock. Event yang menyentuh UI
/// (mulai/berhenti jalan, cek proximity) dikirim balik ke main thread.
nonisolated final class CharacterMotion: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    private let character: SCNNode
    private let pivot: SCNNode
    private let camera: SCNNode
    private let lock = NSLock()

    /// Dipanggil di main thread saat status jalan berubah.
    var onWalkingChanged: ((Bool) -> Void)?
    /// Dipanggil di main thread ±10x/detik selama berjalan.
    var onProximityTick: (() -> Void)?

    // ── Konstanta area (sama dengan sebelumnya) ──
    private let speed: Float = 0.06          // per frame @60fps
    private let minX: Float = -2.0, maxX: Float = 2.0
    private let minZ: Float = -1.0, maxZ: Float = 1.0
    private let corridorMinX: Float = -3.8, corridorMaxX: Float = 3.8
    private let corridorMinZ: Float = 1.0,  corridorMaxZ: Float = 3.2
    private let doorMinX: Float = 0.8, doorMaxX: Float = 2.2

    // ── State bersama (akses lewat lock) ──
    private weak var _root: SCNNode?
    private var _input = SIMD2<Float>.zero
    private var _yaw: Float = 0
    private var _charFacing: Float = 0
    private var _isDoorOpen = false
    private var _isLyingDown = false
    private var _canWalk = true
    private var _idealCameraZ: Float = 2.0
    private var _minCameraZ: Float = 0.3

    // ── State khusus render thread ──
    private var lastTime: TimeInterval = 0
    private var isMoving = false
    private var proximityElapsed: TimeInterval = 0

    init(character: SCNNode, pivot: SCNNode, camera: SCNNode) {
        self.character = character
        self.pivot = pivot
        self.camera = camera
        super.init()
    }

    // MARK: - Thread-safe accessors

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    var root: SCNNode? {
        get { locked { _root } }
        set { locked { _root = newValue } }
    }
    var yaw: Float {
        get { locked { _yaw } }
        set { locked { _yaw = newValue } }
    }
    var charFacing: Float {
        get { locked { _charFacing } }
        set { locked { _charFacing = newValue } }
    }
    var isDoorOpen: Bool {
        get { locked { _isDoorOpen } }
        set { locked { _isDoorOpen = newValue } }
    }
    var isLyingDown: Bool {
        get { locked { _isLyingDown } }
        set { locked { _isLyingDown = newValue } }
    }
    var canWalk: Bool {
        get { locked { _canWalk } }
        set { locked { _canWalk = newValue } }
    }

    func setInput(_ v: SIMD2<Float>) { locked { _input = v } }

    func setCameraDistance(ideal: Float, min: Float) {
        locked { _idealCameraZ = ideal; _minCameraZ = min }
    }

    // MARK: - SCNSceneRendererDelegate (render thread)

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(max(time - lastTime, 0), 1.0 / 20)
        lastTime = time

        let (input, walkAllowed) = locked { (_input, _canWalk) }
        let active = walkAllowed && (abs(input.x) > 0.02 || abs(input.y) > 0.02)
        guard active else {
            if isMoving { setMoving(false) }
            return
        }
        step(input: input, dt: dt)
    }

    // MARK: - Movement

    private func step(input: SIMD2<Float>, dt: TimeInterval) {
        let dx = input.x, dy = input.y
        let frameScale = Float(dt * 60)
        let (camYaw, doorOpen) = locked { (_yaw, _isDoorOpen) }

        // forward = (-sin(yaw), 0, -cos(yaw)); strafe kanan = (cos(yaw), 0, -sin(yaw))
        let stepLen = speed * frameScale
        let fwdX = -sin(camYaw) * dy * stepLen
        let fwdZ = -cos(camYaw) * dy * stepLen
        let strX =  cos(camYaw) * dx * stepLen
        let strZ = -sin(camYaw) * dx * stepLen

        let oldX = Float(character.position.x)
        let oldZ = Float(character.position.z)
        let newX = oldX + fwdX + strX
        let newZ = oldZ + fwdZ + strZ

        let moving = abs(dx) > 0.05 || abs(dy) > 0.05
        if moving != isMoving { setMoving(moving) }

        var allowedMinX = minX, allowedMaxX = maxX
        var allowedMinZ = minZ, allowedMaxZ = maxZ

        let inCorridor = oldZ > corridorMinZ + 0.3
        let inRoom     = oldZ <= maxZ
        let inTransit  = oldZ > maxZ && oldZ <= corridorMinZ + 0.3

        if doorOpen {
            if inCorridor {
                // Di koridor: bebas kiri-kanan; masuk kamar hanya lewat pintu.
                allowedMinX = corridorMinX
                allowedMaxX = corridorMaxX
                allowedMaxZ = corridorMaxZ
                allowedMinZ = (newX > doorMinX && newX < doorMaxX) ? minZ : corridorMinZ + 0.4
            } else if inTransit {
                // Di ambang pintu
                allowedMinX = doorMinX
                allowedMaxX = doorMaxX
                allowedMinZ = minZ
                allowedMaxZ = corridorMaxZ
            } else if inRoom, oldX > doorMinX, oldX < doorMaxX {
                allowedMaxZ = corridorMaxZ
                if newZ > maxZ {
                    allowedMinX = doorMinX
                    allowedMaxX = doorMaxX
                }
            }
        }

        character.position = SCNVector3(max(allowedMinX, min(allowedMaxX, newX)),
                                        0,
                                        max(allowedMinZ, min(allowedMaxZ, newZ)))

        // Karakter berputar halus ke arah gerak
        if abs(fwdX + strX) > 0.001 || abs(fwdZ + strZ) > 0.001 {
            let target = atan2(fwdX + strX, -(fwdZ + strZ))
            let facing = locked { () -> Float in
                var diff = target - _charFacing
                while diff >  .pi { diff -= 2 * .pi }
                while diff < -.pi { diff += 2 * .pi }
                _charFacing += diff * (1 - pow(0.75, frameScale))
                return _charFacing
            }
            character.eulerAngles.y = SCNFloat(facing)
        }

        followCharacter(dt: dt)

        proximityElapsed += dt
        if proximityElapsed >= 0.1 {
            proximityElapsed = 0
            let cb = onProximityTick
            DispatchQueue.main.async { cb?() }
        }
    }

    private func setMoving(_ moving: Bool) {
        isMoving = moving
        let cb = onWalkingChanged
        DispatchQueue.main.async { cb?(moving) }
    }

    // MARK: - Camera

    /// Pivot kamera mengikuti karakter lalu kamera di-clamp terhadap dinding.
    /// Aman dipanggil dari main thread maupun render thread.
    func followCharacter(dt: TimeInterval = 1.0 / 60) {
        guard !isLyingDown else { return }   // FPP saat rebahan
        pivot.position = SCNVector3(character.position.x, 0, character.position.z)
        clampCamera(dt: dt)
    }

    /// Ray-cast dari kepala ke posisi kamera ideal; kalau terhalang dinding,
    /// kamera ditarik maju sampai tepat di depan dinding.
    func clampCamera(dt: TimeInterval = 1.0 / 60) {
        let (root, lying, doorOpen, idealZ, minZ) = locked {
            (_root, _isLyingDown, _isDoorOpen, _idealCameraZ, _minCameraZ)
        }
        guard let root else { return }

        let charPos  = character.worldPosition
        let headPos  = SCNVector3(charPos.x, charPos.y + (lying ? 0.15 : 1.1), charPos.z)

        let pivotYaw  = Float(pivot.eulerAngles.y)
        let localCamY = Float(camera.position.y)
        let idealCamPos = SCNVector3(charPos.x + sin(pivotYaw) * idealZ,
                                     charPos.y + localCamY,
                                     charPos.z + cos(pivotYaw) * idealZ)

        let dx = idealCamPos.x - headPos.x
        let dy = idealCamPos.y - headPos.y
        let dz = idealCamPos.z - headPos.z
        let dist = sqrt(dx*dx + dy*dy + dz*dz)
        guard dist > 0.001 else { return }

        // Hanya node dinding (categoryBitMask), cukup hit terdekat.
        let options: [String: Any] = [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.categoryBitMask.rawValue: KostViewModel.wallCategory,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
            SCNHitTestOption.backFaceCulling.rawValue: false
        ]
        let hit = root.hitTestWithSegment(from: headPos, to: idealCamPos, options: options).first

        let targetZ: Float
        if let hit {
            let hx = hit.worldCoordinates.x - headPos.x
            let hy = hit.worldCoordinates.y - headPos.y
            let hz = hit.worldCoordinates.z - headPos.z
            let hitDist = sqrt(hx*hx + hy*hy + hz*hz)
            targetZ = idealZ * (max(minZ, hitDist - 0.30) / dist)
        } else {
            targetZ = idealZ
        }

        // Snap saat mendekati dinding, kembali halus (independen frame rate).
        let current = Float(camera.position.z)
        let alpha: Float = targetZ < current ? 1.0 : 1 - pow(0.85, Float(dt * 60))
        let newZ = current + (targetZ - current) * alpha
        camera.position.z = SCNFloat(newZ)

        // Hard clamp posisi world kamera terhadap dinding kamar/koridor.
        let camMargin: Float = 0.25
        let camWorldX = charPos.x + sin(pivotYaw) * newZ
        let camWorldZ = charPos.z + cos(pivotYaw) * newZ

        var minCamX: Float = -2.8, maxCamX: Float = 2.8
        var minCamZ: Float = -1.8, maxCamZ: Float = 1.8
        let inDoorCamX = camWorldX > 0.5 && camWorldX < 2.5
        if doorOpen, camWorldZ > 0.8 {
            maxCamZ = 3.8
            if !inDoorCamX || camWorldZ > 1.8 {
                minCamX = -4.2; maxCamX = 4.2
                if camWorldZ > 1.2 && !inDoorCamX { minCamZ = 1.2 }
            }
        }

        let clampedX = max(minCamX + camMargin, min(maxCamX - camMargin, camWorldX))
        let clampedZ = max(minCamZ + camMargin, min(maxCamZ - camMargin, camWorldZ))
        if clampedX != camWorldX || clampedZ != camWorldZ {
            let dcx = clampedX - charPos.x
            let dcz = clampedZ - charPos.z
            camera.position.z = SCNFloat(min(newZ, max(minZ, sqrt(dcx*dcx + dcz*dcz))))
        }
    }
}
