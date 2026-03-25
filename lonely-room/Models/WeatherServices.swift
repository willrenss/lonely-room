import Foundation
@preconcurrency import CoreLocation
import Combine
import WeatherKit

// MARK: - WeatherKit Service
class WeatherServices: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var condition: WeatherCondition?
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter  = 500
    }

    // MARK: - Public

    func fetch() {
        let status = locationManager.authorizationStatus
        print("🌍 fetch() — auth status: \(status.rawValue)")
        switch status {
        case .notDetermined:
            print("🌍 Requesting authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("🌍 Authorized — requesting location...")
            locationManager.requestLocation()
        default:
            print("🌍 Denied")
            DispatchQueue.main.async { self.errorMessage = "Izin lokasi ditolak" }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        print("📍 Location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        Task { await self.fetchWeather(for: loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🌍 Auth changed → \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("🌍 Authorized — requesting location...")
            DispatchQueue.main.async { manager.requestLocation() }
        case .denied, .restricted:
            print("🌍 Denied")
            DispatchQueue.main.async { self.errorMessage = "Izin lokasi ditolak" }
        default:
            print("🌍 Waiting for auth: \(status.rawValue)")
        }
    }

    // MARK: - WeatherKit

    @MainActor
    private func fetchWeather(for location: CLLocation) async {
        print("🌤 WeatherKit fetching...")
        do {
            let result  = try await WeatherKit.WeatherService.shared.weather(for: location)
            let current = result.currentWeather
            let wmo     = mapToWMO(current.condition)
            print("✅ WeatherKit: \(current.condition) → WMO \(wmo), \(current.temperature.converted(to: .celsius).value)°C, isDay=\(current.isDaylight)")
            condition    = WeatherCondition(code: wmo, isDay: current.isDaylight,
                                            tempC: current.temperature.converted(to: .celsius).value)
            errorMessage = nil
        } catch {
            print("❌ WeatherKit error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - WMO mapping

    private func mapToWMO(_ condition: WeatherKit.WeatherCondition) -> Int {
        switch condition {
        case .clear, .mostlyClear:                              return 0
        case .partlyCloudy:                                     return 1
        case .mostlyCloudy:                                     return 2
        case .cloudy, .foggy, .smoky, .haze:                   return 3
        case .drizzle, .freezingDrizzle:                        return 51
        case .rain, .sunShowers:                                return 61
        case .heavyRain:                                        return 65
        case .isolatedThunderstorms, .scatteredThunderstorms,
             .thunderstorms:                                    return 95
        case .strongStorms, .tropicalStorm, .hurricane:         return 99
        case .sleet, .freezingRain, .wintryMix:                return 77
        case .snow, .flurries, .sunFlurries:                   return 71
        case .heavySnow, .blizzard, .blowingSnow:              return 75
        case .blowingDust, .hail:                              return 95
        default:                                                return 0
        }
    }
}
