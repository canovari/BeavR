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
            creator: creator,
            contact: contact
        )
    }
}
