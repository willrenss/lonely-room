import SwiftUI
import SceneKit
import Combine

// MARK: - Graphics Quality
enum GraphicsQuality: String, CaseIterable, Identifiable {
    case battery, balanced, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .battery:  return "Hemat"
        case .balanced: return "Seimbang"
        case .high:     return "Tinggi"
        }
    }

    var detail: String {
        switch self {
        case .battery:  return "30 FPS, tanpa anti-aliasing. Baterai paling awet."
        case .balanced: return "60 FPS dengan anti-aliasing ringan."
        case .high:     return "Frame rate maksimal (hingga 120 FPS) dan grafis paling halus."
        }
    }

    var framesPerSecond: Int {
        switch self {
        case .battery:  return 30
        case .balanced: return 60
        case .high:     return 120
        }
    }

    var antialiasing: SCNAntialiasingMode {
        switch self {
        case .battery:  return .none
        case .balanced: return .multisampling2X
        case .high:     return .multisampling4X
        }
    }

    /// Pengali jumlah partikel hujan di luar jendela.
    var particleScale: CGFloat {
        switch self {
        case .battery:  return 0.4
        case .balanced: return 0.75
        case .high:     return 1.0
        }
    }
}

// MARK: - App Settings
/// Semua preferensi user, tersimpan di UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var musicVolume: Double     { didSet { defaults.set(musicVolume, forKey: Keys.musicVolume) } }
    @Published var sfxVolume: Double       { didSet { defaults.set(sfxVolume, forKey: Keys.sfxVolume) } }
    @Published var hapticsEnabled: Bool    { didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) } }
    @Published var graphicsQuality: GraphicsQuality {
        didSet { defaults.set(graphicsQuality.rawValue, forKey: Keys.graphics) }
    }
    @Published var focusMinutes: Int       { didSet { defaults.set(focusMinutes, forKey: Keys.focusMinutes) } }
    @Published var breakMinutes: Int       { didSet { defaults.set(breakMinutes, forKey: Keys.breakMinutes) } }
    @Published var autoLofiOnFocus: Bool   { didSet { defaults.set(autoLofiOnFocus, forKey: Keys.autoLofi) } }
    @Published var showNeedsHUD: Bool      { didSet { defaults.set(showNeedsHUD, forKey: Keys.needsHUD) } }
    @Published var useLocationWeather: Bool { didSet { defaults.set(useLocationWeather, forKey: Keys.locationWeather) } }
    @Published var hasOnboarded: Bool      { didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) } }

    private enum Keys {
        static let musicVolume     = "settings.musicVolume"
        static let sfxVolume       = "settings.sfxVolume"
        static let haptics         = "settings.haptics"
        static let graphics        = "settings.graphics"
        static let focusMinutes    = "settings.focusMinutes"
        static let breakMinutes    = "settings.breakMinutes"
        static let autoLofi        = "settings.autoLofi"
        static let needsHUD        = "settings.needsHUD"
        static let locationWeather = "settings.locationWeather"
        static let onboarded       = "settings.onboarded"
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            Keys.musicVolume:     0.8,
            Keys.sfxVolume:       0.8,
            Keys.haptics:         true,
            Keys.graphics:        GraphicsQuality.balanced.rawValue,
            Keys.focusMinutes:    25,
            Keys.breakMinutes:    5,
            Keys.autoLofi:        true,
            Keys.needsHUD:        true,
            Keys.locationWeather: false,
            Keys.onboarded:       false,
        ])
        musicVolume        = d.double(forKey: Keys.musicVolume)
        sfxVolume          = d.double(forKey: Keys.sfxVolume)
        hapticsEnabled     = d.bool(forKey: Keys.haptics)
        graphicsQuality    = GraphicsQuality(rawValue: d.string(forKey: Keys.graphics) ?? "") ?? .balanced
        focusMinutes       = d.integer(forKey: Keys.focusMinutes)
        breakMinutes       = d.integer(forKey: Keys.breakMinutes)
        autoLofiOnFocus    = d.bool(forKey: Keys.autoLofi)
        showNeedsHUD       = d.bool(forKey: Keys.needsHUD)
        useLocationWeather = d.bool(forKey: Keys.locationWeather)
        hasOnboarded       = d.bool(forKey: Keys.onboarded)
    }
}
