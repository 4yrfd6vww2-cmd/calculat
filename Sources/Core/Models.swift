import Foundation

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    let nick: String
    var avatarUrl: String?
    var lastSeen: Date?
    var createdAt: Date?
    var typingTo: String?
    var typingAt: Date?
}

struct Friendship: Codable, Identifiable, Hashable {
    let id: Int
    let requester: String
    let addressee: String
    var status: String
    var createdAt: Date?
}

struct Attachment: Codable, Hashable {
    let path: String
    var name: String
    var type: String      // image / video / file / voice
    var mime: String?
}

struct OutItem {
    let data: Data
    let mime: String
    let name: String
    let kind: String
}

struct Message: Codable, Identifiable, Hashable {
    let id: Int
    let sender: String
    let receiver: String?
    let kind: String
    var body: String?
    var mediaPath: String?
    var fileName: String?
    let createdAt: Date
    var readAt: Date?
    var editedAt: Date?
    var attachments: [Attachment]?
    var chatId: String?
    var replyTo: Int?
}

struct Chat: Codable, Identifiable, Hashable {
    let id: String
    let kind: String      // group / channel
    var title: String
    var description: String?
    let owner: String
    var avatarUrl: String?
}

struct Member: Codable, Hashable {
    let chatId: String
    let userId: String
    var role: String
    var lastRead: Int?
}

struct Reaction: Codable, Hashable {
    let messageId: Int
    let userId: String
    var emoji: String
}

struct HiddenRow: Codable { let messageId: Int }

struct PrivateProfile: Codable {
    let userId: String
    let recoveryEmail: String
}
