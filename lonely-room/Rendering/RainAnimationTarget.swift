import Foundation
import QuartzCore
import SceneKit

// MARK: - Rain Animation Target
// Menggunakan CADisplayLink untuk update texture hujan setiap frame
final class RainAnimationTarget: NSObject {
    weak var vm: KostViewModel?
    let heavy: Bool
    let storm: Bool
    let timeOfDay: TimeOfDay
    let condition: WeatherCondition

    init(vm: KostViewModel, heavy: Bool, storm: Bool,
         timeOfDay: TimeOfDay, condition: WeatherCondition) {
        self.vm        = vm
        self.heavy     = heavy
        self.storm     = storm
        self.timeOfDay = timeOfDay
        self.condition = condition
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let vm else { return }
        let dt = link.timestamp - vm.lastRainTimestamp
        vm.lastRainTimestamp = link.timestamp
        vm.rainTimeOffset   += dt

        let tex = WeatherTextureRenderer.draw(
            condition:   condition,
            size:        CGSize(width: 512, height: 320),
            timeOfDay:   timeOfDay,
            rainTime:    vm.rainTimeOffset
        )
        vm.outsideNode?.geometry?.firstMaterial?.diffuse.contents = tex
    }
}
