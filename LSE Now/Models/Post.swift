import Foundation

struct Post: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let startTime: Date
    let endTime: Date?
    let location: String?
    let description: String?
    let organization: String?
    let category: String?
    let imageUrl: String?
    let status: String?
    let latitude: Double?
    let longitude: Double?
    let creator: String?
    let contact: ContactInfo?   // ✅ Reference only, don’t redeclare

    // ✅ Hashable + Equatable by id
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func isExpired(referenceDate: Date = Date()) -> Bool {
        let expiryCutoff = startTime.addingTimeInterval(2 * 3600)
        if referenceDate >= expiryCutoff {
            return true
        }

        if let endTime, referenceDate >= endTime {
            return true
        }

        return false
    }

    func updatingStatusForExpiry(referenceDate: Date = Date()) -> Post {
        guard isExpired(referenceDate: referenceDate) else { return self }
        if status?.lowercased() == "expired" { return self }
        return Post(
            id: id,
            title: title,
            startTime: startTime,
            endTime: endTime,
            location: location,
            description: description,
            organization: organization,
            category: category,
            imageUrl: imageUrl,
            status: "expired",
            latitude: latitude,
            longitude: longitude,
            contact: contact,
            creator: creator
        )
    }

    var resolvedStatus: String {
        statusKind.displayKey
    }

    /// Returns a normalized representation of the server-provided status so that
    /// the UI can consistently reason about states such as approved/live/pending.
    var statusKind: StatusKind {
        if isExpired() { return .expired }

        guard let status = status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty else {
            return .pending
        }

        switch status {
        case "pending", "pending approval", "awaiting approval", "under review":
            return .pending
        case "live", "approved", "active", "published":
            return .live
        case "expired":
            return .expired
        case "cancelled", "canceled":
            return .cancelled
        default:
            return .other(status)
        }
    }

    /// Formats the event window as "MMM dd at h:mm - h:mm" (or with the end date when needed).
    func conciseScheduleString(calendar: Calendar = .current) -> String {
        let start = startTime
        let dayFormatter = Self.conciseDayFormatter
        let timeFormatter = Self.conciseTimeFormatter

        let startDay = dayFormatter.string(from: start)
        let startTimeString = timeFormatter.string(from: start)

        guard let end = endTime else {
            return "\(startDay) at \(startTimeString)"
        }

        if calendar.isDate(start, inSameDayAs: end) {
            let endTimeString = timeFormatter.string(from: end)
            return "\(startDay) at \(startTimeString) - \(endTimeString)"
        } else {
            let endDay = dayFormatter.string(from: end)
            let endTimeString = timeFormatter.string(from: end)
            return "\(startDay) at \(startTimeString) - \(endDay) \(endTimeString)"
        }
    }

    /// Attempts to trim the stored location down to a "number, street" format.
    var primaryLocationLine: String? {
        guard let rawLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines), !rawLocation.isEmpty else {
            return nil
        }

        let cleaned = rawLocation
            .components(separatedBy: CharacterSet.newlines)
            .joined(separator: ", ")

        let parts = cleaned
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return cleaned
        }

        let candidateWithDigits = parts.first(where: { $0.containsDigit && !$0.isCityComponent })
        let candidate = candidateWithDigits ?? parts.first(where: { !$0.isCityComponent }) ?? parts[0]
        let normalizedCandidate = candidate.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if normalizedCandidate.contains(",") {
            return normalizedCandidate
        }

        let components = normalizedCandidate.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if components.count == 2, components[0].containsDigit {
            let number = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let street = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(number), \(street)"
        }

        return normalizedCandidate
    }
}

extension Post {
    enum StatusKind: Equatable {
        case pending
        case live
        case expired
        case cancelled
        case other(String)

        fileprivate var displayKey: String {
            switch self {
            case .pending:
                return "pending"
            case .live:
                return "live"
            case .expired:
                return "expired"
            case .cancelled:
                return "cancelled"
            case .other(let raw):
                return raw
            }
        }
    }
}

private extension Post {
    static let conciseDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM dd")
        return formatter
    }()

    static let conciseTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension String {
    var containsDigit: Bool {
        rangeOfCharacter(from: .decimalDigits) != nil
    }

    var isCityComponent: Bool {
        let lower = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "london" || lower == "england" || lower == "united kingdom" || lower == "uk" {
            return true
        }
        if lower.hasPrefix("london ") {
            return true
        }
        return false
    }
}
