import Foundation
@preconcurrency import CoreLocation
import Combine

// MARK: - Open-Meteo Weather Service
// WeatherKit backup ada di WeatherService.weatherkit.backup.swift
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var condition: WeatherCondition?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true

    private let locationManager = CLLocationManager()

    // Tangerang Selatan, Banten
    private let fallbackLat = -6.3297
    private let fallbackLon = 106.7010

    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5 * 60  // 5 menit

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
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            fetchOpenMeteo(lat: fallbackLat, lon: fallbackLon)
        }
        scheduleRefresh()
    }

    func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Auto Refresh

    private func scheduleRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval,
                                            repeats: true) { [weak self] _ in
            print("🔄 Auto-refresh cuaca (5 menit)...")
            self?.fetch()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        print("📍 Location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        DispatchQueue.main.async {
            self.fetchOpenMeteo(lat: loc.coordinate.latitude,
                                lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("📍 Location error — fallback ke Tangerang Selatan: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.fetchOpenMeteo(lat: self.fallbackLat, lon: self.fallbackLon)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🌍 Auth changed → \(status.rawValue)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.async { manager.requestLocation() }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.fetchOpenMeteo(lat: self.fallbackLat, lon: self.fallbackLon)
            }
        default:
            break
        }
    }

    // MARK: - Open-Meteo API

    private func fetchOpenMeteo(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code,is_day"
            + "&timezone=auto"
        guard let url = URL(string: urlStr) else { return }

        print("🌤 Open-Meteo fetching: \(lat), \(lon)")
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error = error {
                    print("❌ Open-Meteo error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                guard let data,
                      let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current"] as? [String: Any],
                      let code    = current["weather_code"] as? Int,
                      let isDay   = current["is_day"] as? Int,
                      let temp    = current["temperature_2m"] as? Double
                else {
                    print("❌ Open-Meteo parse error")
                    self.errorMessage = "Parse gagal"
                    self.isLoading = false
                    return
                }
                print("✅ Open-Meteo: code=\(code), isDay=\(isDay), temp=\(temp)°C")
                self.condition    = WeatherCondition(code: code, isDay: isDay == 1, tempC: temp)
                self.errorMessage = nil
                self.isLoading    = false
            }
        }.resume()
    }
}
