import Foundation

struct WhiteboardPin: Identifiable, Codable, Equatable {
    let id: Int
    let emoji: String
    let text: String
    let author: String?
    let creatorEmail: String
    let gridRow: Int
    let gridCol: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case emoji
        case text
        case author
        case creatorEmail
        case gridRow
        case gridCol
        case createdAt
    }

    init(id: Int, emoji: String, text: String, author: String?, creatorEmail: String, gridRow: Int, gridCol: Int, createdAt: Date?) {
        self.id = id
        self.emoji = emoji
        self.text = text
        self.author = author
        self.creatorEmail = creatorEmail
        self.gridRow = gridRow
        self.gridCol = gridCol
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeLossyInt(forKey: .id)
        emoji = try container.decode(String.self, forKey: .emoji)
        text = try container.decode(String.self, forKey: .text)
        author = container.decodeTrimmedStringIfPresent(forKey: .author)

        let rawCreatorEmail = try container.decode(String.self, forKey: .creatorEmail)
        creatorEmail = rawCreatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        gridRow = try container.decodeLossyInt(forKey: .gridRow)
        gridCol = try container.decodeLossyInt(forKey: .gridCol)
        createdAt = container.decodeWhiteboardDateIfPresent(forKey: .createdAt)
    }
}

struct WhiteboardCoordinate: Identifiable, Hashable {
    let row: Int
    let column: Int

    var id: String {
        "\(row)-\(column)"
    }
}

extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) throws -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }

        if let stringValue = try? decode(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let intValue = Int(trimmed) {
                return intValue
            }
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected integer value for \(key.stringValue)."
        )
    }

    func decodeTrimmedStringIfPresent(forKey key: Key) -> String? {
        guard contains(key) else { return nil }

        if let stringValue = try? decode(String.self, forKey: key) {
            return WhiteboardDecoding.sanitized(stringValue)
        }

        return nil
    }

    func decodeWhiteboardDateIfPresent(forKey key: Key) -> Date? {
        guard contains(key) else { return nil }

        if let stringValue = try? decode(String.self, forKey: key) {
            return WhiteboardDecoding.parseDate(from: stringValue)
        }

        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: doubleValue)
        }

        if let intValue = try? decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(intValue))
        }

        return nil
    }
}

enum WhiteboardDecoding {
    static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func parseDate(from rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }

        if let date = iso8601WithFractional.date(from: trimmed) {
            return date
        }

        if let date = iso8601.date(from: trimmed) {
            return date
        }

        if let date = extendedFractional.date(from: trimmed) {
            return date
        }

        if let date = fallback.date(from: trimmed) {
            return date
        }

        return nil
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let extendedFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fallback: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
