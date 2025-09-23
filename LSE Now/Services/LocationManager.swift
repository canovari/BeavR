import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization

    private let locationManager: CLLocationManager
    private let apiService: APIService
    private let userDefaults: UserDefaults

    private var uploadTimer: Timer?
    private var emailProvider: (() -> String?)?   // ✅ closure that returns latest email
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
        if #available(iOS 14.0, *) {
            self.accuracyAuthorization = manager.accuracyAuthorization
        } else {
            self.accuracyAuthorization = .fullAccuracy
        }

        super.init()
        manager.delegate = self

        log("Initialized LocationManager with status: \(describeAuthorizationStatus(manager.authorizationStatus))")
    }

    deinit {
        stopUploadTimer()
    }

    // MARK: - Permissions
    func requestPermission() {
        hasPromptedForPermission = true
        let status = locationManager.authorizationStatus
        log("requestPermission() → current status: \(describeAuthorizationStatus(status))")

        switch status {
        case .notDetermined:
            log("Requesting when-in-use authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            log("Already authorized, starting updates")
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        default:
            log("Permission not requested because status = \(describeAuthorizationStatus(status))")
        }
    }

    func refreshLocation() {
        let status = locationManager.authorizationStatus
        log("refreshLocation() → status = \(describeAuthorizationStatus(status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            log("Requesting one-time location update")
            locationManager.requestLocation()
        case .notDetermined:
            log("Status not determined, requesting permission again")
            locationManager.requestWhenInUseAuthorization()
        default:
            log("Skipping refresh, not authorized")
        }
    }

    // MARK: - Login / Activity
    func handleLoginStateChange(isLoggedIn: Bool, emailProvider: (() -> String?)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.log("handleLoginStateChange() → isLoggedIn: \(isLoggedIn)")

            if isLoggedIn {
                self.isTrackingUser = true
                self.emailProvider = emailProvider
                self.log("Tracking enabled, email provider wired")

                if !self.hasPromptedForPermission {
                    self.log("Permission never prompted → requestPermission()")
                    self.requestPermission()
                } else {
                    self.startLocationUpdatesIfAuthorized()
                }

                if let location = self.latestLocation {
                    self.log("Cached location found, sending immediately")
                    self.sendLocationUpdate(using: location)
                } else {
                    self.log("No cached location, refreshing location")
                    self.shouldUploadWhenLocationAvailable = true
                    self.refreshLocation()
                }

                self.startUploadTimerIfNeeded()
            } else {
                self.log("Logging out → stopping tracking and timers")
                self.isTrackingUser = false
                self.emailProvider = nil
                self.shouldUploadWhenLocationAvailable = false
                self.isUploadingLocation = false
                self.stopUploadTimer()
                self.locationManager.stopUpdatingLocation()
                self.latestLocation = nil
            }
        }
    }

    func updateAppActivity(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isAppActive = isActive
            self.log("updateAppActivity() → isActive: \(isActive)")

            if isActive {
                if self.isTrackingUser {
                    self.handleUploadTimerFired()
                }
                self.startUploadTimerIfNeeded()
            } else {
                self.stopUploadTimer()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        log("didUpdateLocations → \(locations.count) locations")
        guard let location = locations.last else {
            log("No valid location received")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestLocation = location
            self.log("Latest location set → lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")

            if self.shouldUploadWhenLocationAvailable {
                self.log("Uploading deferred location update now")
                self.shouldUploadWhenLocationAvailable = false
                self.sendLocationUpdate(using: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("didFailWithError → \(error.localizedDescription)")
    }

    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        log("locationManagerDidChangeAuthorization → \(describeAuthorizationStatus(manager.authorizationStatus))")
        updateAccuracyAuthorization(from: manager)
        handleAuthorizationChange(to: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        log("didChangeAuthorization (legacy) → \(describeAuthorizationStatus(status))")
        updateAccuracyAuthorization(from: manager)
        handleAuthorizationChange(to: status)
    }

    private func handleAuthorizationChange(to status: CLAuthorizationStatus) {
        log("handleAuthorizationChange() → \(describeAuthorizationStatus(status))")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            if #available(iOS 14.0, *) {
                let newAccuracy = self.locationManager.accuracyAuthorization
                if newAccuracy != self.accuracyAuthorization {
                    self.accuracyAuthorization = newAccuracy
                    self.log("Accuracy authorization updated → \(self.describeAccuracyAuthorization(newAccuracy))")
                }
            }

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

    // MARK: - Location Updates
    private var hasPromptedForPermission: Bool {
        get { userDefaults.bool(forKey: permissionKey) }
        set {
            log("hasPromptedForPermission set = \(newValue)")
            userDefaults.set(newValue, forKey: permissionKey)
        }
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = locationManager.authorizationStatus
        log("startLocationUpdatesIfAuthorized() → \(describeAuthorizationStatus(status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            log("Not authorized, not starting updates")
        }
    }

    // MARK: - Upload Timer
    private func startUploadTimerIfNeeded() {
        guard uploadTimer == nil, isTrackingUser, isAppActive else {
            log("startUploadTimerIfNeeded() skipped")
            return
        }

        log("Starting upload timer, interval = \(locationUploadInterval) sec")
        uploadTimer = Timer.scheduledTimer(withTimeInterval: locationUploadInterval, repeats: true) { [weak self] _ in
            self?.handleUploadTimerFired()
        }
        RunLoop.main.add(uploadTimer!, forMode: .common)
    }

    private func handleUploadTimerFired() {
        log("Upload timer fired")
        guard isTrackingUser else {
            log("Tracking disabled, skipping upload")
            return
        }

        if let location = latestLocation {
            sendLocationUpdate(using: location)
            locationManager.requestLocation()
        } else {
            shouldUploadWhenLocationAvailable = true
            refreshLocation()
        }
    }

    private func stopUploadTimer() {
        if uploadTimer != nil { log("Stopping upload timer") }
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    // MARK: - Upload
    private func sendLocationUpdate(using location: CLLocation) {
        guard let emailClosure = emailProvider else {
            log("No emailProvider wired → skipping upload")
            return
        }

        guard let email = emailClosure()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            log("Email missing or empty → skipping upload")
            return
        }

        guard !isUploadingLocation else {
            log("Upload already in progress → skipping")
            return
        }

        isUploadingLocation = true
        shouldUploadWhenLocationAvailable = false

        log("Sending location update for \(email) at lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.apiService.updateUserLocation(
                    email: email,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: Date()
                )
                self.log("Upload succeeded")
            } catch {
                self.log("Upload failed: \(error.localizedDescription)")
            }
            await MainActor.run { self.isUploadingLocation = false }
        }
    }

    // MARK: - Helpers
    private func log(_ message: String) {
        print("[LocationManager] \(message)")
    }

    private func updateAccuracyAuthorization(from manager: CLLocationManager) {
        guard #available(iOS 14.0, *) else { return }
        let newAccuracy = manager.accuracyAuthorization
        if newAccuracy != accuracyAuthorization {
            accuracyAuthorization = newAccuracy
            log("Accuracy authorization updated → \(describeAccuracyAuthorization(newAccuracy))")
        }
    }

    @available(iOS 14.0, *)
    private func describeAccuracyAuthorization(_ accuracy: CLAccuracyAuthorization) -> String {
        switch accuracy {
        case .fullAccuracy: return "full accuracy"
        case .reducedAccuracy: return "reduced accuracy"
        @unknown default: return "unknown (\(accuracy.rawValue))"
        }
    }

    private func describeAuthorizationStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "not determined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorized always"
        case .authorizedWhenInUse: return "authorized when in use"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }
}
