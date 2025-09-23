import SwiftUI
import UserNotifications
import UIKit
import CoreLocation

struct PermissionsGateView: View {
    @Binding var isComplete: Bool
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var stage: Stage = .checking
    @State private var hasRequestedLocation = false
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var isRequestingNotifications = false
    @State private var isFetchingNotificationStatus = false
    @State private var hasRequestedNotifications = false

    private let pushManager = PushNotificationManager.shared

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                content

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear { evaluateState() }
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            evaluateState()
        }
        .onChange(of: locationManager.accuracyAuthorization) { _, _ in
            evaluateState()
        }
        .onChange(of: notificationStatus) { _, _ in
            evaluateState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                fetchNotificationStatus(force: true)
                evaluateState()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .checking:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
                .tint(Color("LSERed"))
            Text("Preparing your BeavR experience…")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        case .locationRequest:
            permissionHeader(
                systemImage: "location.fill",
                title: "Allow Location Access",
                message: "BeavR needs your precise location to suggest the most relevant campus events nearby."
            )
            permissionButton(title: "Allow Location Access") {
                hasRequestedLocation = true
                locationManager.requestPermission()
            }
        case .locationDenied:
            permissionHeader(
                systemImage: "location.slash.fill",
                title: "Turn On Location Services",
                message: "Location access is required to surface events happening around you. Open Settings > Privacy & Security > Location Services > BeavR and allow Precise While Using."
            )
            permissionButton(title: "Open Settings") {
                openSettings()
            }
            retryButton
        case .locationPreciseRequired:
            permissionHeader(
                systemImage: "scope",
                title: "Enable Precise Location",
                message: "Precise location keeps recommendations relevant. In Settings > BeavR > Location, choose While Using and switch on Precise Location."
            )
            permissionButton(title: "Open Settings") {
                openSettings()
            }
            retryButton
        case .notificationRequest:
            permissionHeader(
                systemImage: "bell.fill",
                title: "Stay in the Loop",
                message: "Allow notifications so we can alert you about important happenings and updates."
            )
            permissionButton(title: "Allow Notifications") {
                requestNotifications()
            }
        case .notificationDenied:
            permissionHeader(
                systemImage: "bell.slash.fill",
                title: "Enable Notifications",
                message: "Notifications keep you up to date with campus events. Turn them on in Settings > Notifications > BeavR."
            )
            permissionButton(title: "Open Settings") {
                openSettings()
            }
            retryButton
        case .completed:
            EmptyView()
        }
    }

    private var retryButton: some View {
        Button(action: refreshStatuses) {
            Text("Check Again")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundColor(Color("LSERed"))
        .padding(.top, 4)
    }

    private func permissionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if stage == .notificationRequest && isRequestingNotifications {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.white)
                    .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Color("LSERed"))
    }

    private func permissionHeader(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(Color("LSERed"))
                .padding(.bottom, 4)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func evaluateState() {
        guard !isComplete else { return }

        if !hasFullLocationAccess {
            handleLocationStage()
            return
        }

        handleNotificationStage()
    }

    private func handleLocationStage() {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            stage = .locationRequest
            if !hasRequestedLocation {
                hasRequestedLocation = true
                DispatchQueue.main.async {
                    locationManager.requestPermission()
                }
            }
        case .restricted, .denied:
            stage = .locationDenied
        case .authorizedWhenInUse, .authorizedAlways, .authorized:
            guard CLLocationManager.locationServicesEnabled() else {
                stage = .locationDenied
                return
            }

            if !locationManager.hasValidLocationPermission {
                stage = .locationPreciseRequired
                return
            }

            handleNotificationStage()
        @unknown default:
            stage = .locationDenied
        }
    }

    private func handleNotificationStage() {
        if let status = notificationStatus {
            switch status {
            case .authorized, .provisional, .ephemeral:
                completePermissions()
            case .denied:
                stage = .notificationDenied
            case .notDetermined:
                stage = .notificationRequest
                if !hasRequestedNotifications {
                    hasRequestedNotifications = true
                    requestNotifications()
                }
            default:
                stage = .notificationRequest
                if !hasRequestedNotifications {
                    hasRequestedNotifications = true
                    requestNotifications()
                }
            }
        } else {
            stage = .checking
            fetchNotificationStatus()
        }
    }

    private func requestNotifications() {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        pushManager.requestAuthorizationIfNeeded { status in
            DispatchQueue.main.async {
                self.notificationStatus = status
                self.isRequestingNotifications = false
            }
        }
    }

    private func fetchNotificationStatus(force: Bool = false) {
        guard force || (!isFetchingNotificationStatus && notificationStatus == nil) else { return }
        isFetchingNotificationStatus = true
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
                self.isFetchingNotificationStatus = false
            }
        }
    }

    private func refreshStatuses() {
        notificationStatus = nil
        hasRequestedNotifications = false
        fetchNotificationStatus(force: true)
        evaluateState()
    }

    private var hasFullLocationAccess: Bool {
        locationManager.hasValidLocationPermission
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func completePermissions() {
        guard !isComplete else { return }
        stage = .completed
        withAnimation(.easeInOut(duration: 0.3)) {
            isComplete = true
        }
    }

    private enum Stage {
        case checking
        case locationRequest
        case locationDenied
        case locationPreciseRequired
        case notificationRequest
        case notificationDenied
        case completed
    }

}
