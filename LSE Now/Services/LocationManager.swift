import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var latestLocation: CLLocation?

    private let locationManager: CLLocationManager
    private let apiService: APIService
    private let userDefaults: UserDefaults

    private var uploadTimer: Timer?
    private var tokenProvider: (() -> String?)?
    private var shouldUploadWhenLocationAvailable = false
    private var isUploadingLocation = false
    private var isTrackingUser = false
    private var isAppActive = true

    private let permissionKey = "lse.now.locationPermissionPrompted"
    private let locationUploadInterval: TimeInterval = 30

    init(
        locationManager: CLLocationManager = CLLocationManager(),
        apiService: APIService = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        let manager = locationManager
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10

        self.locationManager = manager
        self.apiService = apiService
        self.userDefaults = userDefaults
        self.authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
    }

    deinit {
        stopUploadTimer()
    }

    func requestPermission() {
        hasPromptedForPermission = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        default:
            break
        }
    }

    func refreshLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    func handleLoginStateChange(isLoggedIn: Bool, tokenProvider: (() -> String?)?) {
        DispatchQueue.main.async {
            if isLoggedIn {
                self.isTrackingUser = true
                self.tokenProvider = tokenProvider

                if !self.hasPromptedForPermission {
                    self.requestPermission()
                } else {
                    self.startLocationUpdatesIfAuthorized()
                }

                self.startUploadTimerIfNeeded()

                if let location = self.latestLocation {
                    self.shouldUploadWhenLocationAvailable = false
                    self.sendLocationUpdate(using: location)
                } else {
                    self.shouldUploadWhenLocationAvailable = true
                    self.refreshLocation()
                }
            } else {
                self.isTrackingUser = false
                self.tokenProvider = nil
                self.shouldUploadWhenLocationAvailable = false
                self.stopUploadTimer()
                self.locationManager.stopUpdatingLocation()
            }
        }
    }

    func updateAppActivity(isActive: Bool) {
        DispatchQueue.main.async {
            self.isAppActive = isActive

            if isActive {
                if self.isTrackingUser {
                    self.handleUploadTimerFired()
                    self.startUploadTimerIfNeeded()
                }
            } else {
                self.stopUploadTimer()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        DispatchQueue.main.async {
            self.authorizationStatus = status

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
                if self.isTrackingUser {
                    self.locationManager.requestLocation()
                }
            default:
                self.locationManager.stopUpdatingLocation()
                self.latestLocation = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            self.latestLocation = location

            if self.shouldUploadWhenLocationAvailable {
                self.shouldUploadWhenLocationAvailable = false
                self.sendLocationUpdate(using: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    private var hasPromptedForPermission: Bool {
        get { userDefaults.bool(forKey: permissionKey) }
        set { userDefaults.set(newValue, forKey: permissionKey) }
    }

    private func startLocationUpdatesIfAuthorized() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    private func startUploadTimerIfNeeded() {
        guard uploadTimer == nil, isTrackingUser, isAppActive else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: locationUploadInterval, repeats: true) { [weak self] _ in
            self?.handleUploadTimerFired()
        }
        RunLoop.main.add(timer, forMode: .common)
        uploadTimer = timer
    }

    private func handleUploadTimerFired() {
        guard isTrackingUser else { return }

        if let location = latestLocation {
            sendLocationUpdate(using: location)
            locationManager.requestLocation()
        } else {
            shouldUploadWhenLocationAvailable = true
            refreshLocation()
        }
    }

    private func stopUploadTimer() {
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    private func sendLocationUpdate(using location: CLLocation) {
        guard let tokenClosure = tokenProvider, let token = tokenClosure() else { return }
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        guard !isUploadingLocation else { return }

        isUploadingLocation = true
        shouldUploadWhenLocationAvailable = false

        let coordinate = location.coordinate
        let timestamp = Date()

        Task {
            do {
                try await apiService.updateUserLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    timestamp: timestamp,
                    token: trimmedToken
                )
            } catch {
                print("Failed to update user location: \(error.localizedDescription)")
            }

            await MainActor.run {
                self.isUploadingLocation = false
            }
        }
    }
}
