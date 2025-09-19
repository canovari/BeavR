import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?

    var coordinate: CLLocationCoordinate2D? {
        location?.coordinate
    }

    private let manager: CLLocationManager
    private let apiService: APIService
    private let tokenStorage: TokenStorage
    private var updateTimer: Timer?
    private var hasSentInitialLocation = false

    private let updateInterval: TimeInterval = 30

    override init() {
        let locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        self.manager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        self.apiService = .shared
        self.tokenStorage = .shared

        super.init()

        self.manager.delegate = self
    }

    deinit {
        invalidateTimer()
    }

    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        case .restricted, .denied:
            stopUpdatingLocation()
        @unknown default:
            stopUpdatingLocation()
        }
    }

    private func startUpdatingLocation() {
        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    private func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        invalidateTimer()
    }

    private func scheduleTimerIfNeeded() {
        guard updateTimer == nil else { return }

        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.sendLocation()
        }

        if !hasSentInitialLocation {
            sendLocation(initial: true)
        }
    }

    private func invalidateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        hasSentInitialLocation = false
    }

    private func sendLocation(initial: Bool = false) {
        guard let coordinate = coordinate else { return }
        guard let token = tokenStorage.loadToken(), !token.isEmpty else { return }

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        let authToken = token

        Task.detached { [apiService] in
            do {
                try await apiService.updateUserLocation(latitude: latitude, longitude: longitude, token: authToken)
            } catch {
                print("⚠️ Failed to update user location:", error.localizedDescription)
            }
        }

        if initial {
            DispatchQueue.main.async {
                self.hasSentInitialLocation = true
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation()
        case .notDetermined:
            break
        case .restricted, .denied:
            stopUpdatingLocation()
        @unknown default:
            stopUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        DispatchQueue.main.async {
            self.location = latest
            self.scheduleTimerIfNeeded()

            if !self.hasSentInitialLocation {
                self.sendLocation(initial: true)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location manager error:", error.localizedDescription)
    }
}
