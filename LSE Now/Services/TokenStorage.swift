import Foundation

final class TokenStorage {
    static let shared = TokenStorage()

    private let keychain: any SecureTokenStoring
    private let legacyUserDefaults: UserDefaults

    private let legacyTokenKey = SecureTokenStorage.ItemKey.token.rawValue
    private let legacyEmailKey = SecureTokenStorage.ItemKey.email.rawValue

    init(
        keychain: any SecureTokenStoring = SecureTokenStorage(),
        legacyUserDefaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.legacyUserDefaults = legacyUserDefaults

        migrateLegacyCredentialsIfNeeded()
    }

    func loadToken() throws -> String? {
        try keychain.loadValue(for: .token)
    }

    func loadEmail() throws -> String? {
        try keychain.loadValue(for: .email)
    }

    func save(token: String, email: String) throws {
        do {
            try keychain.save(token, for: .token)
            try keychain.save(email, for: .email)
        } catch {
            try? keychain.deleteValue(for: .token)
            try? keychain.deleteValue(for: .email)
            throw error
        }
    }

    func clear() throws {
        try keychain.deleteValue(for: .token)
        try keychain.deleteValue(for: .email)
    }

    private func migrateLegacyCredentialsIfNeeded() {
        let legacyToken = legacyUserDefaults.string(forKey: legacyTokenKey)
        let legacyEmail = legacyUserDefaults.string(forKey: legacyEmailKey)

        guard legacyToken != nil || legacyEmail != nil else {
            return
        }

        var didPersistToken = false

        do {
            if let legacyToken {
                try keychain.save(legacyToken, for: .token)
                didPersistToken = true
            }

            if let legacyEmail {
                try keychain.save(legacyEmail, for: .email)
            }
        } catch {
            if didPersistToken {
                try? keychain.deleteValue(for: .token)
            }

            if legacyEmail != nil {
                try? keychain.deleteValue(for: .email)
            }

            print("⚠️ [TokenStorage] Failed to migrate credentials from UserDefaults: \(error.localizedDescription)")
            return
        }

        if legacyToken != nil {
            legacyUserDefaults.removeObject(forKey: legacyTokenKey)
        }

        if legacyEmail != nil {
            legacyUserDefaults.removeObject(forKey: legacyEmailKey)
        }
    }
}
