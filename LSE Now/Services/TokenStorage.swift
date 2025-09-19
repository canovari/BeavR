import Foundation

final class TokenStorage {
    static let shared = TokenStorage()

    private let tokenKey = "lse.now.authToken"
    private let emailKey = "lse.now.authEmail"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadToken() -> String? {
        userDefaults.string(forKey: tokenKey)
    }

    func loadEmail() -> String? {
        userDefaults.string(forKey: emailKey)
    }

    func save(token: String, email: String) {
        userDefaults.set(token, forKey: tokenKey)
        userDefaults.set(email, forKey: emailKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: emailKey)
    }
}
