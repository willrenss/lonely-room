import Foundation
@preconcurrency import CoreLocation
import Combine

// MARK: - Open-Meteo Weather Service
/// Cuaca dari Open-Meteo (gratis, tanpa API key). Lokasi hanya dipakai bila user
/// mengaktifkan "Cuaca sesuai lokasi"; selain itu memakai lokasi default (Tangerang Selatan).
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var condition: WeatherCondition?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true
    @Published var placeName: String = WeatherService.fallbackName

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // Tangerang Selatan, Banten
    private static let fallbackName = "Tangsel"
    private let fallbackLat = -6.3297
    private let fallbackLon = 106.7010

    private var refreshTimer: Timer?
    private var lastFetch: Date?
    private var lastGeocoded: CLLocation?
    private let refreshInterval: TimeInterval = 10 * 60

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
        locationManager.distanceFilter  = 1000
    }

    // MARK: - Public

    func fetch() {
        lastFetch = Date()
        if AppSettings.shared.useLocationWeather {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            default:
                useFallbackLocation()
            }
        } else {
            useFallbackLocation()
        }
        scheduleRefresh()
    }

    /// Dipanggil saat app kembali aktif — hanya fetch kalau data sudah basi.
    func refreshIfStale() {
        guard let last = lastFetch else { fetch(); return }
        if Date().timeIntervalSince(last) > refreshInterval { fetch() }
    }

    func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Private

    private func useFallbackLocation() {
        placeName = Self.fallbackName
        fetchOpenMeteo(lat: fallbackLat, lon: fallbackLon)
    }

    private func scheduleRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
        refreshTimer?.tolerance = 30
    }

    private func reverseGeocode(_ loc: CLLocation) {
        if let last = lastGeocoded, last.distance(from: loc) < 2000 { return }
        lastGeocoded = loc
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let p = placemarks?.first
            let name = p?.locality ?? p?.subAdministrativeArea ?? p?.administrativeArea
            DispatchQueue.main.async {
                if let name, !name.isEmpty { self?.placeName = name }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.reverseGeocode(loc)
            self.fetchOpenMeteo(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        DispatchQueue.main.async { self.useFallbackLocation() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            guard AppSettings.shared.useLocationWeather else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.useFallbackLocation()
            default:
                break
            }
        }
    }

    // MARK: - Open-Meteo API

    nonisolated private struct Response: Decodable {
        nonisolated struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    private func fetchOpenMeteo(lat: Double, lon: Double) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",  value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current",   value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "timezone",  value: "auto"),
        ]
        guard let url = comps.url else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let decoded = data.flatMap { try? JSONDecoder().decode(Response.self, from: $0) }
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.isLoading = false }
                guard error == nil, let c = decoded?.current else {
                    self.errorMessage = error?.localizedDescription ?? "Gagal memuat cuaca"
                    return
                }
                let new = WeatherCondition(code: c.weather_code, isDay: c.is_day == 1, tempC: c.temperature_2m)
                // Hindari re-render & re-draw tekstur bila cuaca tidak berubah.
                if self.condition?.code != new.code || self.condition?.isDay != new.isDay
                    || Int(self.condition?.tempC ?? -999) != Int(new.tempC) {
                    self.condition = new
                }
                self.errorMessage = nil
            }
        }.resume()
    }
}
