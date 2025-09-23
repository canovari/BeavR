import Foundation

struct Post: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let startTime: Date
    let endTime: Date?
    let location: String?
    let room: String?
    let description: String?
    let organization: String?
    let category: String?
    let imageUrl: String?
    let status: String?
    let latitude: Double?
    let longitude: Double?
    let creator: String?
    let contact: ContactInfo?   // ✅ Reference only, don’t redeclare
    let likesCount: Int
    let likedByMe: Bool

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
            room: room,
            description: description,
            organization: organization,
            category: category,
            imageUrl: imageUrl,
            status: "expired",
            latitude: latitude,
            longitude: longitude,
            creator: creator,
            contact: contact,
            likesCount: likesCount,
            likedByMe: likedByMe
        )
    }
}

extension Post {
    func updatingLikeState(likesCount: Int, likedByMe: Bool) -> Post {
        Post(
            id: id,
            title: title,
            startTime: startTime,
            endTime: endTime,
            location: location,
            room: room,
            description: description,
            organization: organization,
            category: category,
            imageUrl: imageUrl,
            status: status,
            latitude: latitude,
            longitude: longitude,
            creator: creator,
            contact: contact,
            likesCount: likesCount,
            likedByMe: likedByMe
        )
    }
}

extension Notification.Name {
    static let eventLikeStatusDidChange = Notification.Name("EventLikeStatusDidChangeNotification")
}

struct EventLikeChange {
    let eventID: Int
    let isLiked: Bool
    let likeCount: Int
    let post: Post?

    static func post(from sender: AnyObject?, eventID: Int, isLiked: Bool, likeCount: Int, post: Post?) {
        NotificationCenter.default.post(
            name: .eventLikeStatusDidChange,
            object: sender,
            userInfo: [
                "eventID": eventID,
                "isLiked": isLiked,
                "likeCount": likeCount,
                "post": post as Any
            ]
        )
    }

    static func from(_ notification: Notification) -> EventLikeChange? {
        guard
            let userInfo = notification.userInfo,
            let eventID = userInfo["eventID"] as? Int,
            let isLiked = userInfo["isLiked"] as? Bool,
            let likeCount = userInfo["likeCount"] as? Int
        else {
            return nil
        }

        let post = userInfo["post"] as? Post
        return EventLikeChange(eventID: eventID, isLiked: isLiked, likeCount: likeCount, post: post)
    }
}
