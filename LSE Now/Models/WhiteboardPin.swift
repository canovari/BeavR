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
    private static let serverTimeZone: TimeZone = {
        if let rome = TimeZone(identifier: "Europe/Rome") {
            return rome
        }
        if let offset = TimeZone(secondsFromGMT: 3600) {
            return offset
        }
        return TimeZone(secondsFromGMT: 0) ?? .current
    }()

    static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func parseDate(from rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }

        let hasExplicitTimeZone = containsExplicitTimeZone(in: trimmed)

        if let date = iso8601WithFractional.date(from: trimmed) {
            return hasExplicitTimeZone ? date : adjustForServerTimeZone(date)
        }

        if let date = iso8601.date(from: trimmed) {
            return hasExplicitTimeZone ? date : adjustForServerTimeZone(date)
        }

        if !hasExplicitTimeZone {
            if let date = iso8601FractionalWithoutTimeZone.date(from: trimmed) {
                return date
            }

            if let date = iso8601WithoutTimeZone.date(from: trimmed) {
                return date
            }
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

    private static let iso8601WithoutTimeZone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = serverTimeZone
        return formatter
    }()

    private static let iso8601FractionalWithoutTimeZone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = serverTimeZone
        return formatter
    }()

    private static let extendedFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = serverTimeZone
        return formatter
    }()

    private static let fallback: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = serverTimeZone
        return formatter
    }()

    private static func containsExplicitTimeZone(in value: String) -> Bool {
        guard let tIndex = value.firstIndex(of: "T") else { return false }
        let nextIndex = value.index(after: tIndex)
        guard nextIndex < value.endIndex else { return false }
        let timePortion = value[nextIndex...]
        return timePortion.contains("Z") || timePortion.contains("+") || timePortion.contains("-")
    }

    private static func adjustForServerTimeZone(_ date: Date) -> Date {
        let offset = serverTimeZone.secondsFromGMT(for: date)
        return date - TimeInterval(offset)
    }
}

extension WhiteboardPin {
    private static let lifetime: TimeInterval = 8 * 60 * 60

    var expirationDate: Date? {
        guard let createdAt else { return nil }
        return createdAt.addingTimeInterval(Self.lifetime)
    }

    func isExpired(referenceDate: Date = Date()) -> Bool {
        guard let expirationDate else { return false }
        return expirationDate <= referenceDate
    }

    func remainingLifetimeFraction(referenceDate: Date = Date()) -> Double {
        guard let createdAt else { return 0 }
        let elapsed = referenceDate.timeIntervalSince(createdAt)
        if elapsed <= 0 {
            return 1
        }

        let remaining = max(0, Self.lifetime - elapsed)
        return max(0, min(1, remaining / Self.lifetime))
    }

    var formattedTimestamp: String {
        guard let createdAt else { return "" }
        return WhiteboardPin.timestampFormatter.string(from: createdAt)
    }

    func formattedTimeRemaining(referenceDate: Date = Date()) -> String? {
        guard let expirationDate else { return nil }

        let remaining = expirationDate.timeIntervalSince(referenceDate)
        if remaining <= 0 {
            return nil
        }

        if remaining < 60 {
            return "Less than 1m"
        }

        return WhiteboardPin.remainingFormatter.string(from: remaining)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let remainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
