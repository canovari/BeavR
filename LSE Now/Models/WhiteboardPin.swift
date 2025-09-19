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
}

struct WhiteboardCoordinate: Identifiable, Hashable {
    let row: Int
    let column: Int

    var id: String {
        "\(row)-\(column)"
    }
}
