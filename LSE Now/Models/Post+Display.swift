import Foundation

extension Post {
    func conciseScheduleString(calendar: Calendar = .current) -> String {
        let startDay = Self.conciseDayFormatter.string(from: startTime)
        let startTimeString = Self.conciseTimeFormatter.string(from: startTime)

        guard let endTime else {
            return "\(startDay) at \(startTimeString)"
        }

        if calendar.isDate(startTime, inSameDayAs: endTime) {
            let endTimeString = Self.conciseTimeFormatter.string(from: endTime)
            return "\(startDay) at \(startTimeString) - \(endTimeString)"
        }

        let endDay = Self.conciseDayFormatter.string(from: endTime)
        let endTimeString = Self.conciseTimeFormatter.string(from: endTime)
        return "\(startDay) at \(startTimeString) - \(endDay) \(endTimeString)"
    }

    var primaryLocationLine: String? {
        let baseLocation = sanitizedPrimaryLocation
        let roomComponent = sanitizedRoom

        if let baseLocation, let roomComponent {
            return "\(baseLocation) – \(roomComponent)"
        }

        return baseLocation ?? roomComponent
    }

    private var sanitizedPrimaryLocation: String? {
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
        let normalized = candidate.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if normalized.contains(",") {
            return normalized
        }

        let components = normalized.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if components.count == 2, components[0].containsDigit {
            let number = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let street = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(number), \(street)"
        }

        return normalized
    }

    private var sanitizedRoom: String? {
        guard let rawRoom = room?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRoom.isEmpty else {
            return nil
        }
        return rawRoom
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

private extension Substring {
    var containsDigit: Bool {
        rangeOfCharacter(from: .decimalDigits) != nil
    }

    var isCityComponent: Bool {
        let lower = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower == "london" || lower == "england" || lower == "united kingdom" || lower == "uk" {
            return true
        }
        return lower.hasPrefix("london ")
    }
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
        return lower.hasPrefix("london ")
    }
}
