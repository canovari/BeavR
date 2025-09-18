import Foundation

struct User: Codable {
    let id: String
    let name: String
    let email: String
    var savedPostIDs: [String]
    // other profile info
}
