import Foundation

struct ContactInfo: Codable, Hashable {
    var type: String
    var value: String

    var displayValue: String {
        ContactInfo.displayValue(for: type, storedValue: value)
    }

    static func sanitizedValue(for type: String, rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type.lowercased() {
        case "instagram":
            return instagramHandle(from: trimmed)
        default:
            return trimmed
        }
    }

    static func displayValue(for type: String, storedValue: String) -> String {
        let trimmed = storedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch type.lowercased() {
        case "instagram":
            guard !trimmed.isEmpty else { return "" }
            let handle = instagramHandle(from: trimmed)
            if handle.isEmpty { return trimmed }
            return "@\(handle)"
        default:
            return trimmed
        }
    }

    static func instagramHandle(from rawValue: String) -> String {
        var handle = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty else { return "" }

        if let schemeRange = handle.range(of: "://") {
            handle = String(handle[schemeRange.upperBound...])
        }

        let lowercase = handle.lowercased()
        if lowercase.hasPrefix("www.") {
            handle = String(handle.dropFirst(4))
        } else if lowercase.hasPrefix("m.") {
            handle = String(handle.dropFirst(2))
        }

        let instagramDomain = "instagram.com"
        let shortDomain = "instagr.am"
        let loweredAfterPrefix = handle.lowercased()
        if loweredAfterPrefix.hasPrefix(instagramDomain) {
            handle = String(handle.dropFirst(instagramDomain.count))
        } else if loweredAfterPrefix.hasPrefix(shortDomain) {
            handle = String(handle.dropFirst(shortDomain.count))
        }

        handle = handle.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if let queryIndex = handle.firstIndex(of: "?") {
            handle = String(handle[..<queryIndex])
        }

        if let fragmentIndex = handle.firstIndex(of: "#") {
            handle = String(handle[..<fragmentIndex])
        }

        if handle.hasPrefix("@") {
            handle.removeFirst()
        }

        return handle.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
