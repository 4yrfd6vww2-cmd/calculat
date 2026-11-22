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
    var inviteCode: String?
    var pinnedMsg: Int?
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

struct ChatPref: Codable, Hashable {
    let key: String
    var muted: Bool?
    var pinned: Bool?
}

struct Sticker: Codable, Identifiable, Hashable {
    let id: Int
    let path: String
}

extension Message {
    var isSticker: Bool { kind == "image" && (fileName ?? "").hasPrefix("sticker.") }
}

/// Сообщение из 1–5 эмодзи показываем крупно (встроенный стикер).
func isBigEmoji(_ s: String?) -> Bool {
    guard let s = s, !s.isEmpty, s.count <= 24 else { return false }
    var n = 0
    for u in s.unicodeScalars {
        if u.value == 0x200D || u.value == 0xFE0F || u.properties.isWhitespace { continue }
        let v = u.value
        let ok: Bool = (v >= 0x1F000 && v <= 0x1FFFF) || (v >= 0x2190 && v <= 0x2BFF) || v == 0xA9 || v == 0xAE || (v >= 0x203C && v <= 0x3299)
        if !ok { return false }
        n += 1
    }
    return n >= 1 && n <= 5
}

struct HiddenRow: Codable { let messageId: Int }

struct PrivateProfile: Codable {
    let userId: String
    let recoveryEmail: String
}
