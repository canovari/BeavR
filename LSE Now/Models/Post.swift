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
}
