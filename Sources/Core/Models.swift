import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    let nick: String
    var avatarUrl: String?
    var lastSeen: Date?
    var createdAt: Date?
}

struct Friendship: Codable, Identifiable, Hashable {
    let id: Int
    let requester: String
    let addressee: String
    var status: String
    var createdAt: Date?
}

struct Message: Codable, Identifiable, Hashable {
    let id: Int
    let sender: String
    let receiver: String
    let kind: String
    var body: String?
    var mediaPath: String?
    var fileName: String?
    let createdAt: Date
    var readAt: Date?
    var editedAt: Date?
}

struct HiddenRow: Codable { let messageId: Int }

struct PrivateProfile: Codable {
    let userId: String
    let recoveryEmail: String
}
