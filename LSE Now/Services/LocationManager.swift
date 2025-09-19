import Foundation
import CoreLocation

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestLocation: CLLocation?

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
        self.authorizationStatus = LocationManager.currentAuthorizationStatus(for: manager)

        super.init()

        manager.delegate = self
    }

    deinit {
        stopUploadTimer()
    }

    func requestPermission() {
        hasPromptedForPermission = true

        let status = currentAuthorizationStatus()
        log("Permission request invoked. Current status: \(describeAuthorizationStatus(status))")

        switch status {
        case .notDetermined:
            log("Asking user for when-in-use authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            log("Permission already granted; starting location updates")
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        default:
            log("Permission request not performed because status is \(describeAuthorizationStatus(status))")
        }
    }

    func refreshLocation() {
        let status = currentAuthorizationStatus()
        log("Refreshing location with authorization status \(describeAuthorizationStatus(status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            log("Requesting a one-time location update")
            locationManager.requestLocation()
        case .notDetermined:
            log("Authorization not determined; requesting permission before refreshing location")
            locationManager.requestWhenInUseAuthorization()
        default:
            log("Skipping location refresh because authorization is \(describeAuthorizationStatus(status))")
        }
    }

    func handleLoginStateChange(isLoggedIn: Bool, tokenProvider: (() -> String?)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.log("Login state changed. isLoggedIn: \(isLoggedIn)")

            if isLoggedIn {
                self.isTrackingUser = true
                self.tokenProvider = tokenProvider

                if !self.hasPromptedForPermission {
                    self.log("Location permission has not been requested yet; prompting user")
                    self.requestPermission()
                } else {
                    self.log("Location permission already handled; ensuring updates are active")
                    self.startLocationUpdatesIfAuthorized()
                }

                if let location = self.latestLocation {
                    self.log("Sending immediate location update using cached coordinates")
                    self.shouldUploadWhenLocationAvailable = false
                    self.sendLocationUpdate(using: location)
                } else {
                    self.log("Waiting for first location fix before uploading to server")
                    self.shouldUploadWhenLocationAvailable = true
                    self.refreshLocation()
                }
            } else {
                self.log("Stopping user location tracking and clearing resources")
                self.isTrackingUser = false
                self.tokenProvider = nil
                self.shouldUploadWhenLocationAvailable = false
                self.isUploadingLocation = false
                self.locationManager.stopUpdatingLocation()
                self.latestLocation = nil
            }

            self.updateUploadTimerState()
        }
    }

    func updateAppActivity(isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isAppActive = isActive
            self.log("App activity updated. isActive: \(isActive)")

            if isActive {
                if self.isTrackingUser {
                    self.log("App became active while tracking is enabled; triggering immediate upload")
                    self.handleUploadTimerFired()
                }
            } else {
                self.log("App moved to background; stopping upload timer")
            }

            self.updateUploadTimerState()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.latestLocation = location
            let coordinate = location.coordinate
            let latitudeString = String(format: "%.6f", coordinate.latitude)
            let longitudeString = String(format: "%.6f", coordinate.longitude)
            self.log("Received location update (lat: \(latitudeString), lon: \(longitudeString)) at \(location.timestamp)")

            if self.shouldUploadWhenLocationAvailable {
                self.log("Uploading deferred location update now that a location is available")
                self.shouldUploadWhenLocationAvailable = false
                self.sendLocationUpdate(using: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("Location manager error: \(error.localizedDescription)")
    }

    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange(to: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange(to: status)
    }

    private func handleAuthorizationChange(to status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.authorizationStatus = status
            self.log("Authorization status changed to \(self.describeAuthorizationStatus(status))")

            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.log("Permission granted; starting location updates")
                self.locationManager.startUpdatingLocation()
                if self.isTrackingUser {
                    self.log("Requesting location immediately after authorization granted")
                    self.locationManager.requestLocation()
                }
            default:
                self.log("Authorization not sufficient; stopping location updates")
                self.locationManager.stopUpdatingLocation()
                self.latestLocation = nil
            }

            self.updateUploadTimerState()
        }
    }

    private var hasPromptedForPermission: Bool {
        get { userDefaults.bool(forKey: permissionKey) }
        set { userDefaults.set(newValue, forKey: permissionKey) }
    }

    private var isAuthorizedForLocationUpdates: Bool {
        switch currentAuthorizationStatus() {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    private func currentAuthorizationStatus() -> CLAuthorizationStatus {
        LocationManager.currentAuthorizationStatus(for: locationManager)
    }

    private static func currentAuthorizationStatus(for manager: CLLocationManager) -> CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        } else {
            return CLLocationManager.authorizationStatus()
        }
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = currentAuthorizationStatus()
        log("Evaluating whether to start location updates with status \(describeAuthorizationStatus(status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            log("Starting continuous location updates")
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        case .notDetermined:
            log("Authorization not determined; requesting permission before starting updates")
            locationManager.requestWhenInUseAuthorization()
        default:
            log("Location updates not started because authorization is \(describeAuthorizationStatus(status))")
        }
    }

    private func updateUploadTimerState() {
        if isTrackingUser && isAppActive && isAuthorizedForLocationUpdates {
            startUploadTimerIfNeeded()
        } else {
            stopUploadTimer()
        }
    }

    private func startUploadTimerIfNeeded() {
        guard uploadTimer == nil else {
            log("Upload timer already running; skipping start request")
            return
        }

        guard isTrackingUser else {
            log("Skipping upload timer start because tracking is disabled")
            return
        }

        guard isAppActive else {
            log("Skipping upload timer start because app is not active")
            return
        }

        guard isAuthorizedForLocationUpdates else {
            log("Skipping upload timer start because authorization is \(describeAuthorizationStatus(currentAuthorizationStatus()))")
            return
        }

        log("Starting upload timer with interval \(locationUploadInterval) seconds")

        let timer = Timer.scheduledTimer(withTimeInterval: locationUploadInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleUploadTimerFired()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        uploadTimer = timer
    }

    private func handleUploadTimerFired() {
        guard isTrackingUser else {
            log("Upload timer fired but tracking is disabled; ignoring")
            return
        }

        guard isAuthorizedForLocationUpdates else {
            log("Upload timer fired but authorization is \(describeAuthorizationStatus(currentAuthorizationStatus()))")
            return
        }

        log("Upload timer fired")

        if let location = latestLocation {
            log("Uploading periodic location update using latest coordinates")
            sendLocationUpdate(using: location)
            locationManager.requestLocation()
        } else {
            log("No location available when timer fired; requesting new location")
            shouldUploadWhenLocationAvailable = true
            refreshLocation()
        }
    }

    private func stopUploadTimer() {
        guard let timer = uploadTimer else { return }

        log("Stopping upload timer")
        timer.invalidate()
        uploadTimer = nil
    }

    private func sendLocationUpdate(using location: CLLocation) {
        guard isTrackingUser else {
            log("Skipping location upload because tracking is disabled")
            return
        }

        guard let tokenClosure = tokenProvider else {
            log("Cannot send location update because token provider is unavailable")
            shouldUploadWhenLocationAvailable = true
            return
        }

        guard let token = tokenClosure() else {
            log("Cannot send location update because token is unavailable")
            shouldUploadWhenLocationAvailable = true
            return
        }

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty else {
            log("Cannot send location update because token is empty after trimming")
            shouldUploadWhenLocationAvailable = true
            return
        }

        guard !isUploadingLocation else {
            log("A location upload is already in progress; skipping new request")
            return
        }

        isUploadingLocation = true
        shouldUploadWhenLocationAvailable = false

        let coordinate = location.coordinate
        let latitudeString = String(format: "%.6f", coordinate.latitude)
        let longitudeString = String(format: "%.6f", coordinate.longitude)
        let timestamp = Date()

        log("Sending location update to server (lat: \(latitudeString), lon: \(longitudeString)) at \(timestamp)")

        Task { [weak self] in
            guard let self = self else { return }

            do {
                try await self.apiService.updateUserLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    timestamp: timestamp,
                    token: trimmedToken
                )
                DispatchQueue.main.async {
                    self.log("Successfully sent location update at \(timestamp)")
                    self.isUploadingLocation = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.log("Failed to update user location: \(error.localizedDescription)")
                    self.shouldUploadWhenLocationAvailable = true
                    self.isUploadingLocation = false
                }
            }
        }
    }

    private func log(_ message: String) {
        print("[LocationManager] \(message)")
    }

    private func describeAuthorizationStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "not determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorized always"
        case .authorizedWhenInUse:
            return "authorized when in use"
        @unknown default:
            return "unknown (\(status.rawValue))"
        }
    }
}
