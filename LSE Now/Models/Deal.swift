import Foundation

enum DealKind: String, Codable, CaseIterable, Identifiable {
    case service
    case good

    var id: String { rawValue }

    var title: String {
        switch self {
        case .service:
            return "Service"
        case .good:
            return "Good"
        }
    }

    var symbol: String {
        switch self {
        case .service:
            return "💼"
        case .good:
            return "🛍️"
        }
    }
}

struct Deal: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let kind: DealKind
    let discount: String
    let description: String?
    let location: String?
    let startDate: Date
    let endDate: Date?
    let status: String?
    let creator: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind = "type"
        case discount
        case description
        case location
        case startDate
        case endDate
        case status
        case creator
        case createdAt
        case updatedAt
    }

    var isActive: Bool {
        let now = Date()
        guard status?.lowercased() == "approved" else { return false }
        guard startDate <= now else { return false }
        if let endDate, endDate < now {
            return false
        }
        return true
    }

    var validitySummary: String {
        let formatter = Deal.displayFormatter
        let startString = formatter.string(from: startDate)

        if let endDate {
            let endString = formatter.string(from: endDate)
            return "Valid \(startString) – \(endString)"
        }

        return "Valid from \(startString)"
    }

    static func == (lhs: Deal, rhs: Deal) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
