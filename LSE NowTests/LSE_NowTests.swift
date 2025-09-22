import Foundation
import Testing
@testable import LSE_Now

struct TokenStorageTests {

    enum TokenStorageTestError: Error {
        case unableToCreateDefaults(String)
    }

    final class MockSecureTokenStorage: SecureTokenStoring {
        private(set) var storage: [SecureTokenStorage.ItemKey: String] = [:]

        func loadValue(for key: SecureTokenStorage.ItemKey) throws -> String? {
            storage[key]
        }

        func save(_ value: String, for key: SecureTokenStorage.ItemKey) throws {
            storage[key] = value
        }

        func deleteValue(for key: SecureTokenStorage.ItemKey) throws {
            storage.removeValue(forKey: key)
        }
    }

    private func makeIsolatedDefaults(function: StaticString = #function) throws -> UserDefaults {
        let suiteName = "TokenStorageTests.\(function)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TokenStorageTestError.unableToCreateDefaults(suiteName)
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func credentialsPersistAcrossInstances() throws {
        let keychain = MockSecureTokenStorage()
        let defaults = try makeIsolatedDefaults()

        let firstInstance = TokenStorage(keychain: keychain, legacyUserDefaults: defaults)
        try firstInstance.save(token: "abc123", email: "student@lse.ac.uk")

        let secondInstance = TokenStorage(keychain: keychain, legacyUserDefaults: defaults)
        #expect(try secondInstance.loadToken() == "abc123")
        #expect(try secondInstance.loadEmail() == "student@lse.ac.uk")
    }

    @Test func clearRemovesCredentials() throws {
        let keychain = MockSecureTokenStorage()
        let defaults = try makeIsolatedDefaults()
        let storage = TokenStorage(keychain: keychain, legacyUserDefaults: defaults)

        try storage.save(token: "token-value", email: "user@lse.ac.uk")
        try storage.clear()

        #expect(try storage.loadToken() == nil)
        #expect(try storage.loadEmail() == nil)

        let newInstance = TokenStorage(keychain: keychain, legacyUserDefaults: defaults)
        #expect(try newInstance.loadToken() == nil)
        #expect(try newInstance.loadEmail() == nil)
    }

    @Test func migratesLegacyUserDefaultsValues() throws {
        let keychain = MockSecureTokenStorage()
        let defaults = try makeIsolatedDefaults()
        defaults.set("legacy-token", forKey: SecureTokenStorage.ItemKey.token.rawValue)
        defaults.set("legacy@lse.ac.uk", forKey: SecureTokenStorage.ItemKey.email.rawValue)

        let storage = TokenStorage(keychain: keychain, legacyUserDefaults: defaults)

        #expect(try storage.loadToken() == "legacy-token")
        #expect(try storage.loadEmail() == "legacy@lse.ac.uk")
        #expect(defaults.string(forKey: SecureTokenStorage.ItemKey.token.rawValue) == nil)
        #expect(defaults.string(forKey: SecureTokenStorage.ItemKey.email.rawValue) == nil)
    }
}
