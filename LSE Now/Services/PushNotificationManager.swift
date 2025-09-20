import Foundation
import UIKit
import UserNotifications

final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()
    static let messageReplyReceivedNotification = Notification.Name("PushNotificationManager.didReceiveMessageReply")

    private let apiService: APIService
    private let tokenStorage: TokenStorage

    private var cachedAuthToken: String?
    private var cachedEmail: String?
    private var currentDeviceToken: String?
    private var isRegisteredOnServer = false

    private var registrationTask: Task<Void, Never>?
    private var unregistrationTask: Task<Void, Never>?

    private override init() {
        self.apiService = .shared
        self.tokenStorage = .shared
        super.init()

        cachedAuthToken = tokenStorage.loadToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        cachedEmail = tokenStorage.loadEmail()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func applicationDidFinishLaunching() {
        if cachedAuthToken != nil, cachedEmail != nil {
            requestAuthorizationIfNeeded()
            registerDeviceTokenIfPossible(force: true)
        }
    }

    func resumeSession(email: String, authToken: String, shouldRequestAuthorization: Bool = false) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)

        DispatchQueue.main.async {
            self.cachedEmail = normalizedEmail
            self.cachedAuthToken = normalizedToken
            self.isRegisteredOnServer = false

            if shouldRequestAuthorization {
                self.requestAuthorizationIfNeeded()
            }

            self.registerDeviceTokenIfPossible(force: shouldRequestAuthorization)
        }
    }

    func handleSuccessfulLogin(email: String, authToken: String) {
        resumeSession(email: email, authToken: authToken, shouldRequestAuthorization: true)
    }

    func handleLogout(email _: String, authToken: String) {
        let normalizedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else {
            clearCachedCredentials()
            return
        }

        DispatchQueue.main.async {
            let deviceToken = self.currentDeviceToken
            self.clearCachedCredentials()

            guard let token = deviceToken else { return }

            self.unregistrationTask?.cancel()
            self.unregistrationTask = Task { [weak self] in
                do {
                    try await self?.apiService.unregisterNotificationDevice(deviceToken: token, authToken: normalizedToken)
                } catch {
                    print("⚠️ [Push] Failed to unregister device token: \(error.localizedDescription)")
                }
            }
        }
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            self.currentDeviceToken = tokenString
            self.isRegisteredOnServer = false
            self.registerDeviceTokenIfPossible(force: true)
        }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("⚠️ [Push] Remote notification registration failed: \(error.localizedDescription)")
    }

    @discardableResult
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String else { return false }

        if type == "message.reply" {
            NotificationCenter.default.post(name: Self.messageReplyReceivedNotification, object: nil, userInfo: userInfo)
            return true
        }

        return false
    }

    func handleForegroundNotification(userInfo: [AnyHashable: Any]) {
        _ = handleRemoteNotification(userInfo: userInfo)
    }

    // MARK: - Private helpers

    private func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.registerDeviceTokenIfPossible(force: false)
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error {
                        print("⚠️ [Push] Authorization request failed: \(error.localizedDescription)")
                    }

                    guard granted else { return }
                    DispatchQueue.main.async { [weak self] in
                        UIApplication.shared.registerForRemoteNotifications()
                        self?.registerDeviceTokenIfPossible(force: true)
                    }
                }
            case .denied:
                print("⚠️ [Push] Notifications are disabled in Settings.")
            default:
                break
            }
        }
    }

    private func registerDeviceTokenIfPossible(force: Bool) {
        DispatchQueue.main.async {
            guard let deviceToken = self.currentDeviceToken,
                  let authToken = self.cachedAuthToken,
                  let email = self.cachedEmail,
                  !deviceToken.isEmpty,
                  !authToken.isEmpty,
                  !email.isEmpty else {
                return
            }

            if self.isRegisteredOnServer && !force {
                return
            }

            let appVersion = self.currentAppVersion()
            let osVersion = UIDevice.current.systemVersion
            let environment = Self.currentEnvironment

            self.registrationTask?.cancel()
            self.registrationTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.apiService.registerNotificationDevice(
                        token: deviceToken,
                        environment: environment,
                        appVersion: appVersion,
                        osVersion: osVersion,
                        authToken: authToken
                    )

                    await MainActor.run {
                        self.isRegisteredOnServer = true
                    }
                } catch {
                    await MainActor.run {
                        self.isRegisteredOnServer = false
                    }
                    print("⚠️ [Push] Failed to register device: \(error.localizedDescription)")
                }
            }
        }
    }

    private func clearCachedCredentials() {
        cachedEmail = nil
        cachedAuthToken = nil
        isRegisteredOnServer = false
        registrationTask?.cancel()
        registrationTask = nil
    }

    private func currentAppVersion() -> String? {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        default:
            return nil
        }
    }

    private static var currentEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}
