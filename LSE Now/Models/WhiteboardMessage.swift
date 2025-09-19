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

    init(id: Int, message: String, author: String?, senderEmail: String, receiverEmail: String, createdAt: Date?) {
        self.id = id
        self.message = message
        self.author = author
        self.senderEmail = senderEmail
        self.receiverEmail = receiverEmail
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeLossyInt(forKey: .id)
        message = try container.decode(String.self, forKey: .message)
        author = container.decodeTrimmedStringIfPresent(forKey: .author)

        let rawSender = try container.decode(String.self, forKey: .senderEmail)
        senderEmail = rawSender.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let rawReceiver = try container.decode(String.self, forKey: .receiverEmail)
        receiverEmail = rawReceiver.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        createdAt = container.decodeWhiteboardDateIfPresent(forKey: .createdAt)
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
