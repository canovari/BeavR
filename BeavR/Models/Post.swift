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
    let contact: ContactInfo?   // ✅ Reference only, don’t redeclare

    // ✅ Hashable + Equatable by id
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func isExpired(referenceDate: Date = Date()) -> Bool {
        guard endTime == nil else { return false }
        let expiryCutoff = startTime.addingTimeInterval(2 * 3600)
        return referenceDate >= expiryCutoff
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
            contact: contact
        )
    }

    var resolvedStatus: String {
        if isExpired() { return "expired" }
        return status ?? "pending"
    }
}
