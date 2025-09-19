import Foundation

struct WhiteboardMessage: Identifiable, Decodable, Equatable {
    let id: Int
    let message: String
    let author: String?
    let senderEmail: String
    let receiverEmail: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case message
        case author
        case senderEmail
        case receiverEmail
        case createdAt
    }

    var formattedTimestamp: String {
        guard let createdAt else { return "" }
        return WhiteboardMessage.dateFormatter.string(from: createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
