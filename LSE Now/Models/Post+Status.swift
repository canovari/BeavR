import Foundation

extension Post {
    enum StatusKind: Equatable {
        case pending
        case live
        case expired
        case cancelled
        case other(String)

        var displayKey: String {
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

        var badgeTitle: String {
            switch self {
            case .pending:
                return "Pending Approval"
            case .live:
                return "LIVE"
            case .expired:
                return "Expired"
            case .cancelled:
                return "Cancelled"
            case .other(let raw):
                return raw.capitalized
            }
        }
    }

    var statusKind: StatusKind {
        if isExpired() {
            return .expired
        }

        guard let status = status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty else {
            return .pending
        }

        switch status.lowercased() {
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

    var resolvedStatus: String {
        statusKind.displayKey
    }
}
