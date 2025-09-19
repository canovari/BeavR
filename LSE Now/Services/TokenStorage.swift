import Foundation

final class TokenStorage {
    static let shared = TokenStorage()

    private let tokenKey = "lse.now.authToken"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadToken() -> String? {
        userDefaults.string(forKey: tokenKey)
    }

    func save(token: String) {
        userDefaults.set(token, forKey: tokenKey)
    }

    func clear() {
        userDefaults.removeObject(forKey: tokenKey)
    }
}
