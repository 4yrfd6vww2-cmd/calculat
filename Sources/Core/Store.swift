import SwiftUI
import AudioToolbox
import UniformTypeIdentifiers

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var me: Profile?
    @Published var friendships: [Friendship] = []
    @Published var profiles: [String: Profile] = [:]
    @Published var messages: [Message] = []
    @Published var hidden: Set<Int> = []
    @Published var chats: [Chat] = []
    @Published var members: [Member] = []
    @Published var reactions: [Reaction] = []
    @Published var prefs: [String: ChatPref] = [:]
    @Published var stickers: [Sticker] = []
    @Published var jumpTo: Int?
    private var stkLoaded = false
    @Published var recoveryEmail: String?
    @Published var loggedIn: Bool = API.shared.isLoggedIn
    @Published var selectedTab = 0

    private var timer: Timer?
    private var knownMessageIds = Set<Int>()
    private var firstLoadDone = false

    var myId: String { API.shared.userId }

    // MARK: Session

    func login(nick: String, password: String) async throws {
        try await API.shared.signIn(nick: nick, password: password)
        loggedIn = true
        await start()
    }

    func logout() {
        timer?.invalidate()
        timer = nil
        Calls.shared.reset()
        API.shared.signOut()
        me = nil
        friendships = []
        profiles = [:]
        messages = []
        hidden = []
        chats = []
        members = []
        reactions = []
        prefs = [:]
        stickers = []
        stkLoaded = false
        recoveryEmail = nil
        knownMessageIds = []
        firstLoadDone = false
        loggedIn = false
    }

    func start() async {
        guard API.shared.isLoggedIn else { return }
        Calls.shared.startPolling()
        await refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            Task { @MainActor in await Store.shared.refresh() }
        }
    }

    // MARK: Data

    func refresh() async {
        guard API.shared.isLoggedIn else { return }
        do {
            let mine: [Profile] = try await API.shared.select("profiles", [
                URLQueryItem(name: "id", value: "eq.\(myId)"), URLQueryItem(name: "select", value: "*")])
            me = mine.first

            let fr: [Friendship] = try await API.shared.select("friendships", [URLQueryItem(name: "select", value: "*")])
            friendships = fr

            if let mm: [Member] = try? await API.shared.select("chat_members", [URLQueryItem(name: "select", value: "*")]) {
                members = mm
                let ck = Set(mm.map { $0.chatId })
                if ck.isEmpty { chats = [] }
                else if let cc: [Chat] = try? await API.shared.select("chats", [
                    URLQueryItem(name: "id", value: "in.(\(ck.joined(separator: ",")))"), URLQueryItem(name: "select", value: "*")]) {
                    chats = cc
                }
            }
            if let pr: [ChatPref] = try? await API.shared.select("chat_prefs", [URLQueryItem(name: "select", value: "*")]) {
                var d: [String: ChatPref] = [:]
                for x in pr { d[x.key] = x }
                prefs = d
            }
            if !stkLoaded, let st: [Sticker] = try? await API.shared.select("my_stickers", [
                URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "order", value: "id.desc")]) {
                stickers = st
                stkLoaded = true
            }
            let msgs: [Message] = try await API.shared.select("messages", [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1000")])
            let hid: [HiddenRow] = (try? await API.shared.select("message_hidden", [URLQueryItem(name: "select", value: "message_id")])) ?? []
            hidden = Set(hid.map { $0.messageId })
            notifyNew(msgs)
            messages = msgs.filter { !hidden.contains($0.id) }.reversed()
            if let rr: [Reaction] = try? await API.shared.select("message_reactions", [
                URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "limit", value: "3000")]) {
                reactions = rr
            }

            var ids = Set<String>()
            for f in fr { ids.insert(f.requester); ids.insert(f.addressee) }
            for m in msgs { ids.insert(m.sender); if let r = m.receiver { ids.insert(r) } }
            for mb in members { ids.insert(mb.userId) }
            ids.remove(myId)
            if !ids.isEmpty {
                let list = ids.joined(separator: ",")
                let ps: [Profile] = try await API.shared.select("profiles", [
                    URLQueryItem(name: "id", value: "in.(\(list))"), URLQueryItem(name: "select", value: "*")])
                for p in ps { profiles[p.id] = p }
            }
            if let m = me { profiles[m.id] = m }

        } catch {
            if !API.shared.isLoggedIn { logout() }
        }

        if recoveryEmail == nil { try? await reloadRecoveryEmail() }
        try? await API.shared.update("profiles", [URLQueryItem(name: "id", value: "eq.\(myId)")],
                                     ["last_seen": ISO.now()])
    }

    func reloadRecoveryEmail() async throws {
        let pp: [PrivateProfile] = try await API.shared.select("private_profiles", [
            URLQueryItem(name: "user_id", value: "eq.\(myId)"), URLQueryItem(name: "select", value: "*")])
        recoveryEmail = pp.first?.recoveryEmail
    }

    func changeNick(_ nick: String) async throws {
        _ = try await API.shared.raw("POST", "/functions/v1/account", json: ["action": "change_nick", "nick": nick])
        await refresh()
    }

    private func notifyNew(_ msgs: [Message]) {
        let ids = Set(msgs.map { $0.id })
        if firstLoadDone {
            let fresh = msgs.filter { m in
                if knownMessageIds.contains(m.id) || m.sender == myId { return false }
                let key: String = m.chatId.map { "c:" + $0 } ?? m.sender
                if isMuted(key) { return false }
                return m.receiver == myId || (m.chatId.map { isMember($0) } ?? false)
            }
            if !fresh.isEmpty && Settings.shared.messageSound {
                AudioServicesPlaySystemSound(1007)
            }
        }
        knownMessageIds = ids
        firstLoadDone = true
    }

    // MARK: Friends

    var friendIds: [String] {
        friendships.filter { $0.status == "accepted" }.map { $0.requester == myId ? $0.addressee : $0.requester }
    }
    var incoming: [Friendship] { friendships.filter { $0.status == "pending" && $0.addressee == myId } }
    var outgoing: [Friendship] { friendships.filter { $0.status == "pending" && $0.requester == myId } }

    func friendship(with id: String) -> Friendship? {
        friendships.first { ($0.requester == id && $0.addressee == myId) || ($0.requester == myId && $0.addressee == id) }
    }

    func search(_ q: String) async -> [Profile] {
        let clean = q.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        guard clean.count >= 2 else { return [] }
        let r: [Profile]? = try? await API.shared.select("profiles", [
            URLQueryItem(name: "nick", value: "ilike.*\(clean)*"),
            URLQueryItem(name: "id", value: "neq.\(myId)"),
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "20")])
        return r ?? []
    }

    func sendRequest(to id: String) async throws {
        try await API.shared.insert("friendships", ["requester": myId, "addressee": id, "status": "pending"])
        await refresh()
    }

    func accept(_ f: Friendship) async throws {
        try await API.shared.update("friendships", [URLQueryItem(name: "id", value: "eq.\(f.id)")], ["status": "accepted"])
        await refresh()
    }

    func removeFriendship(_ f: Friendship) async throws {
        try await API.shared.delete("friendships", [URLQueryItem(name: "id", value: "eq.\(f.id)")])
        await refresh()
    }

    // MARK: Messages

    func isKey(_ k: String) -> Bool { k.hasPrefix("c:") }
    func cidOf(_ k: String) -> String { String(k.dropFirst(2)) }
    func chatByKey(_ k: String) -> Chat? { isKey(k) ? chats.first { $0.id == cidOf(k) } : nil }
    func isMember(_ cid: String) -> Bool { members.contains { $0.chatId == cid && $0.userId == myId } }
    func myMember(_ k: String) -> Member? { members.first { $0.chatId == cidOf(k) && $0.userId == myId } }
    func memberCount(_ k: String) -> Int { members.filter { $0.chatId == cidOf(k) }.count }

    func canPost(_ k: String) -> Bool {
        guard let c = chatByKey(k) else { return true }
        if c.kind != "channel" { return myMember(k) != nil }
        let r = myMember(k)?.role
        return r == "owner" || r == "admin"
    }

    private func tgt(_ to: String, _ o: [String: Any]) -> [String: Any] {
        var r = o
        if isKey(to) { r["chat_id"] = cidOf(to) } else { r["receiver"] = to }
        return r
    }

    func thread(with id: String) -> [Message] {
        if isKey(id) { return messages.filter { $0.chatId == cidOf(id) } }
        return messages.filter { ($0.sender == id && $0.receiver == myId) || ($0.sender == myId && $0.receiver == id) }
    }

    func unread(from id: String) -> Int {
        if isKey(id) {
            let lr = myMember(id)?.lastRead ?? 0
            return messages.filter { $0.chatId == cidOf(id) && $0.sender != myId && $0.id > lr }.count
        }
        return messages.filter { $0.sender == id && $0.receiver == myId && $0.readAt == nil }.count
    }

    var totalUnread: Int {
        messages.filter { $0.receiver == myId && $0.readAt == nil }.count + chats.reduce(0) { $0 + unread(from: "c:" + $1.id) }
    }

    func reactions(of id: Int) -> [Reaction] { reactions.filter { $0.messageId == id } }

    func react(_ id: Int, _ emoji: String) async {
        let mine = reactions.first { $0.messageId == id && $0.userId == myId }
        if mine != nil {
            try? await API.shared.delete("message_reactions", [
                URLQueryItem(name: "message_id", value: "eq.\(id)"), URLQueryItem(name: "user_id", value: "eq.\(myId)")])
        }
        if mine == nil || mine?.emoji != emoji {
            try? await API.shared.insert("message_reactions", ["message_id": id, "user_id": myId, "emoji": emoji])
        }
        await refresh()
    }

    // MARK: Prefs / pins / codes / stickers

    func isMuted(_ k: String) -> Bool { prefs[k]?.muted ?? false }
    func isPinned(_ k: String) -> Bool { prefs[k]?.pinned ?? false }

    func setPref(_ k: String, _ field: String, _ v: Bool) async {
        let cur = prefs[k]
        do {
            if cur != nil {
                try await API.shared.update("chat_prefs", [
                    URLQueryItem(name: "user_id", value: "eq.\(myId)"), URLQueryItem(name: "key", value: "eq.\(k)")], [field: v])
            } else {
                var row: [String: Any] = ["user_id": myId, "key": k]
                row[field] = v
                try await API.shared.insert("chat_prefs", row)
            }
            let m: Bool = field == "muted" ? v : (cur?.muted ?? false)
            let p: Bool = field == "pinned" ? v : (cur?.pinned ?? false)
            prefs[k] = ChatPref(key: k, muted: m, pinned: p)
        } catch {
        }
    }

    func pinMessage(_ cid: String, _ mid: Int?) async {
        var v: [String: Any] = [:]
        if let mid = mid { v["pinned_msg"] = mid } else { v["pinned_msg"] = NSNull() }
        try? await API.shared.update("chats", [URLQueryItem(name: "id", value: "eq.\(cid)")], v)
        await refresh()
    }

    func setDescription(_ cid: String, _ d: String) async throws {
        var v: [String: Any] = [:]
        let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { v["description"] = NSNull() } else { v["description"] = t }
        try await API.shared.update("chats", [URLQueryItem(name: "id", value: "eq.\(cid)")], v)
        await refresh()
    }

    func joinByCode(_ code: String) async throws -> String {
        let data = try await API.shared.raw("POST", "/rest/v1/rpc/join_by_code", json: ["code": code.trimmingCharacters(in: .whitespaces)])
        await refresh()
        let s = String(data: data, encoding: .utf8) ?? ""
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n"))
    }

    func channelCounts(_ ids: [String]) async -> [String: Int] {
        guard !ids.isEmpty else { return [:] }
        guard let data = try? await API.shared.raw("POST", "/rest/v1/rpc/channel_counts", json: ["ids": ids]),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [:] }
        var out: [String: Int] = [:]
        for o in arr {
            if let c = o["chat_id"] as? String, let n = o["n"] as? Int { out[c] = n }
        }
        return out
    }

    func addSticker(_ data: Data, mime: String, ext: String) async throws {
        let path = "\(myId)/stickers/\(UUID().uuidString.lowercased()).\(ext)"
        try await API.shared.upload(bucket: "chat-media", path: path, data: data, mime: mime)
        try await API.shared.insert("my_stickers", ["path": path])
        stkLoaded = false
        await refresh()
    }

    func deleteSticker(_ id: Int) async {
        try? await API.shared.delete("my_stickers", [URLQueryItem(name: "id", value: "eq.\(id)")])
        stickers = stickers.filter { $0.id != id }
    }

    func sendSticker(_ path: String, to id: String, reply: Int? = nil) async throws {
        let ext = (path as NSString).pathExtension
        var row = tgt(id, ["sender": myId, "kind": "image", "media_path": path, "file_name": "sticker." + (ext.isEmpty ? "png" : ext)])
        if let r = reply { row["reply_to"] = r }
        try await API.shared.insert("messages", row)
        await refresh()
    }

    // MARK: Groups & channels

    func createChat(kind: String, title: String, friends: [String], desc: String = "") async throws -> String {
        let id = UUID().uuidString.lowercased()
        var row: [String: Any] = ["id": id, "kind": kind, "title": title, "owner": myId]
        let d = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty { row["description"] = d }
        try await API.shared.insert("chats", row)
        for f in friends {
            try? await API.shared.insert("chat_members", ["chat_id": id, "user_id": f, "role": "member"])
        }
        await refresh()
        return "c:" + id
    }

    func findChannels(_ q: String) async -> [Chat] {
        let clean = q.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        guard !clean.isEmpty else { return [] }
        let r: [Chat]? = try? await API.shared.select("chats", [
            URLQueryItem(name: "kind", value: "eq.channel"),
            URLQueryItem(name: "title", value: "ilike.*\(clean)*"),
            URLQueryItem(name: "select", value: "*"), URLQueryItem(name: "limit", value: "20")])
        return r ?? []
    }

    func joinChat(_ cid: String) async throws {
        try await API.shared.insert("chat_members", ["chat_id": cid, "user_id": myId, "role": "member"])
        await refresh()
    }

    func leaveChat(_ cid: String) async throws {
        try await API.shared.delete("chat_members", [
            URLQueryItem(name: "chat_id", value: "eq.\(cid)"), URLQueryItem(name: "user_id", value: "eq.\(myId)")])
        await refresh()
    }

    func addMember(_ cid: String, _ uid: String) async throws {
        try await API.shared.insert("chat_members", ["chat_id": cid, "user_id": uid, "role": "member"])
        await refresh()
    }

    func kickMember(_ cid: String, _ uid: String) async throws {
        try await API.shared.delete("chat_members", [
            URLQueryItem(name: "chat_id", value: "eq.\(cid)"), URLQueryItem(name: "user_id", value: "eq.\(uid)")])
        await refresh()
    }

    func setRole(_ cid: String, _ uid: String, _ role: String) async {
        try? await API.shared.update("chat_members", [
            URLQueryItem(name: "chat_id", value: "eq.\(cid)"), URLQueryItem(name: "user_id", value: "eq.\(uid)")], ["role": role])
        await refresh()
    }

    func setChatAvatar(_ cid: String, _ data: Data) async throws {
        let path = "\(myId)/chat-\(cid).jpg"
        try await API.shared.upload(bucket: "avatars", path: path, data: data, mime: "image/jpeg", upsert: true)
        let url = API.shared.publicURL(bucket: "avatars", path: path) + "?v=\(Int(Date().timeIntervalSince1970))"
        try await API.shared.update("chats", [URLQueryItem(name: "id", value: "eq.\(cid)")], ["avatar_url": url])
        await refresh()
    }

    func deleteChat(_ cid: String) async throws {
        try await API.shared.delete("chats", [URLQueryItem(name: "id", value: "eq.\(cid)")])
        await refresh()
    }

    // MARK: Typing / online

    private var lastTyping = Date.distantPast

    func sendTyping(to key: String) {
        guard Date().timeIntervalSince(lastTyping) >= 3 else { return }
        lastTyping = Date()
        Task {
            try? await API.shared.update("profiles", [URLQueryItem(name: "id", value: "eq.\(myId)")],
                                         ["typing_to": key, "typing_at": ISO.now()])
        }
    }

    func isOnline(_ p: Profile?) -> Bool {
        guard let d = p?.lastSeen else { return false }
        return Date().timeIntervalSince(d) < 15
    }

    func typingIn(_ key: String) -> [Profile] {
        let want = isKey(key) ? key : myId
        return profiles.values.filter {
            $0.id != myId && $0.typingTo == want && ($0.typingAt.map { Date().timeIntervalSince($0) < 6 } ?? false)
                && (isKey(key) || $0.id == key)
        }
    }

    func sendText(_ text: String, to id: String, reply: Int? = nil) async throws {
        var row = tgt(id, ["sender": myId, "kind": "text", "body": text])
        if let r = reply { row["reply_to"] = r }
        try await API.shared.insert("messages", row)
        await refresh()
    }

    func sendMedia(data: Data, mime: String, fileName: String, kind: String, to id: String, reply: Int? = nil) async throws {
        let ext = (fileName as NSString).pathExtension
        let path = "\(myId)/\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
        try await API.shared.upload(bucket: "chat-media", path: path, data: data, mime: mime)
        var row = tgt(id, ["sender": myId, "kind": kind, "media_path": path, "file_name": fileName])
        if let r = reply { row["reply_to"] = r }
        try await API.shared.insert("messages", row)
        await refresh()
    }

    func sendAlbum(_ items: [OutItem], caption: String, to id: String, reply: Int? = nil) async throws {
        var atts: [[String: Any]] = []
        for it in items {
            let ext = (it.name as NSString).pathExtension
            let path = "\(myId)/\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
            try await API.shared.upload(bucket: "chat-media", path: path, data: it.data, mime: it.mime)
            atts.append(["path": path, "name": it.name, "type": it.kind, "mime": it.mime, "size": it.data.count])
        }
        var row = tgt(id, ["sender": myId, "kind": "album", "attachments": atts])
        if !caption.isEmpty { row["body"] = caption }
        if let r = reply { row["reply_to"] = r }
        try await API.shared.insert("messages", row)
        await refresh()
    }

    func editMessage(_ id: Int, text: String) async throws {
        try await API.shared.update("messages", [URLQueryItem(name: "id", value: "eq.\(id)")],
                                    ["body": text, "edited_at": ISO.now()])
        await refresh()
    }

    func deleteForAll(_ list: [Message]) async throws {
        for m in list where m.sender == myId {
            try await API.shared.delete("messages", [URLQueryItem(name: "id", value: "eq.\(m.id)")])
            var paths = (m.attachments ?? []).map { $0.path }
            if let p = m.mediaPath, !m.isSticker { paths.append(p) }
            for p in paths {
                _ = try? await API.shared.raw("DELETE", "/storage/v1/object/chat-media/\(p)")
            }
        }
        await refresh()
    }

    func deleteForMe(_ list: [Message]) async throws {
        for m in list {
            try await API.shared.insert("message_hidden", ["message_id": m.id])
            hidden.insert(m.id)
        }
        messages = messages.filter { !hidden.contains($0.id) }
        await refresh()
    }

    func forward(_ m: Message, to id: String) async throws {
        if m.kind == "text" {
            try await sendText(m.body ?? "", to: id)
        } else if m.kind == "album" {
            var out: [OutItem] = []
            for a in m.attachments ?? [] {
                let url = try await API.shared.signedURL(bucket: "chat-media", path: a.path)
                let (data, _) = try await URLSession.shared.data(from: url)
                out.append(OutItem(data: data, mime: a.mime ?? "application/octet-stream", name: a.name, kind: a.type))
            }
            try await sendAlbum(out, caption: m.body ?? "", to: id)
        } else if let p = m.mediaPath {
            let url = try await API.shared.signedURL(bucket: "chat-media", path: p)
            let (data, _) = try await URLSession.shared.data(from: url)
            let name = m.fileName ?? (m.kind == "image" ? "photo.jpg" : "file")
            let ext = (name as NSString).pathExtension
            let mime = m.kind == "image" ? "image/jpeg"
                : (UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream")
            try await sendMedia(data: data, mime: mime, fileName: name, kind: m.kind, to: id)
        }
    }

    func markRead(from id: String) async {
        guard unread(from: id) > 0 else { return }
        if isKey(id) {
            if let last = thread(with: id).map({ $0.id }).max() {
                try? await API.shared.update("chat_members", [
                    URLQueryItem(name: "chat_id", value: "eq.\(cidOf(id))"),
                    URLQueryItem(name: "user_id", value: "eq.\(myId)")], ["last_read": last])
                await refresh()
            }
            return
        }
        try? await API.shared.update("messages", [
            URLQueryItem(name: "sender", value: "eq.\(id)"),
            URLQueryItem(name: "receiver", value: "eq.\(myId)"),
            URLQueryItem(name: "read_at", value: "is.null")], ["read_at": ISO.now()])
        await refresh()
    }

    // MARK: Profile

    func bindEmail(_ email: String) async throws {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        try await API.shared.insert("private_profiles", ["user_id": myId, "recovery_email": e])
        recoveryEmail = e
    }

    func uploadAvatar(_ data: Data) async throws {
        let path = "\(myId)/avatar.jpg"
        try await API.shared.upload(bucket: "avatars", path: path, data: data, mime: "image/jpeg", upsert: true)
        let url = API.shared.publicURL(bucket: "avatars", path: path) + "?v=\(Int(Date().timeIntervalSince1970))"
        try await API.shared.update("profiles", [URLQueryItem(name: "id", value: "eq.\(myId)")], ["avatar_url": url])
        await refresh()
    }
}
