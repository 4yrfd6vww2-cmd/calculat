import SwiftUI
import AudioToolbox

@MainActor
final class Store: ObservableObject {
    static let shared = Store()

    @Published var me: Profile?
    @Published var friendships: [Friendship] = []
    @Published var profiles: [String: Profile] = [:]
    @Published var messages: [Message] = []
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
        API.shared.signOut()
        me = nil
        friendships = []
        profiles = [:]
        messages = []
        recoveryEmail = nil
        knownMessageIds = []
        firstLoadDone = false
        loggedIn = false
    }

    func start() async {
        guard API.shared.isLoggedIn else { return }
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

            let msgs: [Message] = try await API.shared.select("messages", [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1000")])
            notifyNew(msgs)
            messages = msgs.reversed()

            var ids = Set<String>()
            for f in fr { ids.insert(f.requester); ids.insert(f.addressee) }
            for m in msgs { ids.insert(m.sender); ids.insert(m.receiver) }
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
            let fresh = msgs.filter { !knownMessageIds.contains($0.id) && $0.receiver == myId }
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

    func thread(with id: String) -> [Message] {
        messages.filter { ($0.sender == id && $0.receiver == myId) || ($0.sender == myId && $0.receiver == id) }
    }

    func unread(from id: String) -> Int {
        messages.filter { $0.sender == id && $0.receiver == myId && $0.readAt == nil }.count
    }

    func sendText(_ text: String, to id: String) async throws {
        try await API.shared.insert("messages", ["sender": myId, "receiver": id, "kind": "text", "body": text])
        await refresh()
    }

    func sendMedia(data: Data, mime: String, fileName: String, kind: String, to id: String) async throws {
        let ext = (fileName as NSString).pathExtension
        let path = "\(myId)/\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
        try await API.shared.upload(bucket: "chat-media", path: path, data: data, mime: mime)
        try await API.shared.insert("messages", ["sender": myId, "receiver": id, "kind": kind,
                                                  "media_path": path, "file_name": fileName])
        await refresh()
    }

    func markRead(from id: String) async {
        guard unread(from: id) > 0 else { return }
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
