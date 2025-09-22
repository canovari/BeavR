import Foundation
import Security

protocol SecureTokenStoring {
    func loadValue(for key: SecureTokenStorage.ItemKey) throws -> String?
    func save(_ value: String, for key: SecureTokenStorage.ItemKey) throws
    func deleteValue(for key: SecureTokenStorage.ItemKey) throws
}

enum SecureTokenStorageError: LocalizedError {
    case unexpectedData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedData:
            return "The stored credentials are in an unexpected format."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Keychain operation failed with status: \(status)."
        }
    }
}

final class SecureTokenStorage: SecureTokenStoring {
    enum ItemKey: String, CaseIterable {
        case token = "lse.now.authToken"
        case email = "lse.now.authEmail"
    }

    private let service = "lse.now.auth.credentials"

    func loadValue(for key: ItemKey) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
                throw SecureTokenStorageError.unexpectedData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw SecureTokenStorageError.unhandledStatus(status)
        }
    }

    func save(_ value: String, for key: ItemKey) throws {
        let encoded = Data(value.utf8)
        var query = baseQuery(for: key)
        let attributes = [kSecValueData as String: encoded]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            query[kSecValueData as String] = encoded
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SecureTokenStorageError.unhandledStatus(addStatus)
            }
        default:
            throw SecureTokenStorageError.unhandledStatus(status)
        }
    }

    func deleteValue(for key: ItemKey) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)

        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw SecureTokenStorageError.unhandledStatus(status)
        }
    }

    private func baseQuery(for key: ItemKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}
