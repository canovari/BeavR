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
        self.authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
    }

    deinit {
        stopUploadTimer()
    }

    // MARK: - Permissions
    func requestPermission() {
        hasPromptedForPermission = true
        switch locationManager.authorizationStatus {
        case .notDetermined:
            log("Asking user for when-in-use authorization")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            log("Permission already granted; starting location updates")
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        default:
            log("Permission request not performed because status is \(describeAuthorizationStatus(status: locationManager.authorizationStatus))")
        }
    }

    func refreshLocation() {
        let status = locationManager.authorizationStatus
        log("Refreshing location with authorization status \(describeAuthorizationStatus(status: status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            log("Requesting a one-time location update")
            locationManager.requestLocation()
        case .notDetermined:
            log("Authorization not determined; requesting permission")
            locationManager.requestWhenInUseAuthorization()
        default:
            log("Skipping location refresh (status = \(describeAuthorizationStatus(status: status)))")
        }
    }

    // MARK: - Login & Activity
    func handleLoginStateChange(isLoggedIn: Bool, tokenProvider: (() -> String?)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.log("Login state changed. isLoggedIn: \(isLoggedIn)")

            if isLoggedIn {
                self.isTrackingUser = true
                self.tokenProvider = tokenProvider

                if !self.hasPromptedForPermission {
                    self.log("Prompting user for location permission")
                    self.requestPermission()
                } else {
                    self.startLocationUpdatesIfAuthorized()
                }

                if let location = self.latestLocation {
                    self.log("Sending immediate location update with cached coordinates")
                    self.shouldUploadWhenLocationAvailable = false
                    self.sendLocationUpdate(using: location)
                } else {
                    let status = self.locationManager.authorizationStatus
                    self.shouldUploadWhenLocationAvailable = true

                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        self.log("Requesting location update now that user is logged in")
                        self.refreshLocation()
                    case .notDetermined:
                        self.log("Waiting for user to grant permission before refreshing location")
                    default:
                        self.log("Cannot refresh location because authorization is \(self.describeAuthorizationStatus(status: status))")
                    }
                }

                self.startUploadTimerIfNeeded()
            } else {
                self.log("Stopping tracking due to logout")
                self.isTrackingUser = false
                self.tokenProvider = nil
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
            guard let self = self else { return }

            self.isAppActive = isActive
            self.log("App activity updated. isActive: \(isActive)")

            if isActive {
                if self.isTrackingUser {
                    self.log("App active while tracking; trigger upload")
                    self.handleUploadTimerFired()
                }
                self.startUploadTimerIfNeeded()
            } else {
                self.log("App moved to background; stopping upload timer")
                self.stopUploadTimer()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.latestLocation = location
            self.log("Received location update at \(location.timestamp)")

            if self.shouldUploadWhenLocationAvailable {
                self.log("Uploading deferred location update")
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
            self.log("Authorization status changed to \(self.describeAuthorizationStatus(status: status))")

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
        set { userDefaults.set(newValue, forKey: permissionKey) }
    }

    private func startLocationUpdatesIfAuthorized() {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // MARK: - Upload Timer
    private func startUploadTimerIfNeeded() {
        guard uploadTimer == nil, isTrackingUser, isAppActive else { return }

        log("Starting upload timer every \(locationUploadInterval) seconds")
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
            let status = locationManager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                refreshLocation()
            } else {
                log("Upload timer fired but authorization is \(describeAuthorizationStatus(status: status)); awaiting permission")
            }
        }
    }

    private func stopUploadTimer() {
        if uploadTimer != nil {
            log("Stopping upload timer")
        }
        uploadTimer?.invalidate()
        uploadTimer = nil
    }

    // MARK: - Send Location
    private func sendLocationUpdate(using location: CLLocation) {
        guard let tokenClosure = tokenProvider, let token = tokenClosure() else {
            log("No token available for location update")
            return
        }

        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            log("Token is empty after trimming")
            return
        }

        guard !isUploadingLocation else {
            log("Upload already in progress")
            return
        }

        isUploadingLocation = true
        shouldUploadWhenLocationAvailable = false

        let coordinate = location.coordinate
        let timestamp = Date()
        log("Sending location update to server (lat: \(coordinate.latitude), lon: \(coordinate.longitude)) at \(timestamp)")

        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.apiService.updateUserLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    timestamp: timestamp,
                    token: trimmedToken
                )
                self.log("Successfully sent location update")
            } catch {
                self.log("Failed to send location: \(error.localizedDescription)")
            }
            await MainActor.run { self.isUploadingLocation = false }
        }
    }

    // MARK: - Helpers
    private func log(_ message: String) {
        print("[LocationManager] \(message)")
    }

    private func describeAuthorizationStatus(status: CLAuthorizationStatus) -> String {
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
