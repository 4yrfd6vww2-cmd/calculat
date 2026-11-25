import Foundation

struct Session: Codable {
    var accessToken: String
    var refreshToken: String
    var userId: String
    var expiresAt: Date
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum ISO {
    static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func parse(_ s: String) -> Date? { withFraction.date(from: s) ?? plain.date(from: s) }
    static func now() -> String { withFraction.string(from: Date()) }
    static func string(_ d: Date) -> String { withFraction.string(from: d) }
}

final class API {
    static let shared = API()
    private let base = Config.supabaseURL.absoluteString
    private let key = Config.supabasePublishableKey
    private let storeKey = "neirox.session"
    private(set) var session: Session?

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = ISO.parse(s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: s))
        }
        return d
    }()

    init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let s = try? JSONDecoder().decode(Session.self, from: data) {
            session = s
        }
    }

    var isLoggedIn: Bool { session != nil }
    var userId: String { session?.userId ?? "" }

    func setSession(_ s: Session?) {
        session = s
        if let s = s, let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: storeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storeKey)
        }
    }

    static func fakeEmail(_ nick: String) -> String { nick.lowercased() + "@neirox.app" }

    // MARK: Auth

    func signIn(nick: String, password: String) async throws {
        let body: [String: Any] = ["email": API.fakeEmail(nick), "password": password]
        let data = try await raw("POST", "/auth/v1/token",
                                 query: [URLQueryItem(name: "grant_type", value: "password")],
                                 json: body, auth: false)
        setSession(try parseSession(data))
    }

    func register(nick: String, password: String, email: String) async throws {
        var body: [String: Any] = ["nick": nick, "password": password]
        if !email.isEmpty { body["email"] = email }
        _ = try await raw("POST", "/functions/v1/register", json: body, auth: false)
    }

    func signOut() {
        setSession(nil)
    }

    private func parseSession(_ data: Data) throws -> Session {
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let at = o["access_token"] as? String,
              let rt = o["refresh_token"] as? String,
              let user = o["user"] as? [String: Any],
              let id = user["id"] as? String else {
            throw APIError(message: "Bad auth response")
        }
        let exp = (o["expires_in"] as? Double) ?? 3600
        return Session(accessToken: at, refreshToken: rt, userId: id,
                       expiresAt: Date().addingTimeInterval(exp))
    }

    private var refreshing = false
    private func refreshIfNeeded() async throws {
        guard let s = session, s.expiresAt.timeIntervalSinceNow < 60, !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let data = try await raw("POST", "/auth/v1/token",
                                     query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                     json: ["refresh_token": s.refreshToken], auth: false)
            setSession(try parseSession(data))
        } catch {
            // Если токен отозван — выходим из аккаунта
            if let e = error as? APIError, e.message.lowercased().contains("refresh") || e.message.lowercased().contains("invalid") {
                setSession(nil)
            }
            throw error
        }
    }

    // MARK: Low level

    func raw(_ method: String, _ path: String,
             query: [URLQueryItem] = [], json: Any? = nil,
             body: Data? = nil, contentType: String? = nil,
             headers: [String: String] = [:], auth: Bool = true) async throws -> Data {
        if auth { try await refreshIfNeeded() }
        var comps = URLComponents(string: base + path)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.timeoutInterval = 90
        req.setValue(key, forHTTPHeaderField: "apikey")
        if auth, let t = session?.accessToken {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let json = json {
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let body = body {
            req.httpBody = body
            req.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code >= 200 && code < 300 { return data }
        throw APIError(message: API.extractError(data, code))
    }

    static func extractError(_ data: Data, _ code: Int) -> String {
        if let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for k in ["error", "msg", "message", "error_description", "detail"] {
                if let s = o[k] as? String, !s.isEmpty { return s }
            }
        }
        return "HTTP \(code)"
    }

    // MARK: REST helpers

    func select<T: Decodable>(_ table: String, _ query: [URLQueryItem]) async throws -> [T] {
        let data = try await raw("GET", "/rest/v1/\(table)", query: query)
        return try API.decoder.decode([T].self, from: data)
    }

    func insert(_ table: String, _ row: [String: Any]) async throws {
        _ = try await raw("POST", "/rest/v1/\(table)", json: row, headers: ["Prefer": "return=minimal"])
    }

    func update(_ table: String, _ query: [URLQueryItem], _ values: [String: Any]) async throws {
        _ = try await raw("PATCH", "/rest/v1/\(table)", query: query, json: values, headers: ["Prefer": "return=minimal"])
    }

    func delete(_ table: String, _ query: [URLQueryItem]) async throws {
        _ = try await raw("DELETE", "/rest/v1/\(table)", query: query)
    }

    // MARK: Storage

    func upload(bucket: String, path: String, data: Data, mime: String, upsert: Bool = false) async throws {
        _ = try await raw("POST", "/storage/v1/object/\(bucket)/\(path)", body: data, contentType: mime,
                          headers: ["x-upsert": upsert ? "true" : "false"])
    }

    func signedURL(bucket: String, path: String) async throws -> URL {
        let data = try await raw("POST", "/storage/v1/object/sign/\(bucket)/\(path)", json: ["expiresIn": 3600])
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = o["signedURL"] as? String,
              let url = URL(string: base + "/storage/v1" + s) else {
            throw APIError(message: "Bad signed url")
        }
        return url
    }

    func publicURL(bucket: String, path: String) -> String {
        base + "/storage/v1/object/public/\(bucket)/\(path)"
    }

    // MARK: AI

    func aiText(_ messages: [[String: String]]) async throws -> String {
        let data = try await raw("POST", "/functions/v1/ai", json: ["type": "text", "messages": messages])
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = o["text"] as? String else { throw APIError(message: "Empty AI answer") }
        return t
    }

    func aiImage(_ prompt: String) async throws -> Data {
        let data = try await raw("POST", "/functions/v1/ai", json: ["type": "image", "prompt": prompt])
        guard let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let b64 = o["base64"] as? String,
              let img = Data(base64Encoded: b64) else { throw APIError(message: "Empty AI image") }
        return img
    }

    // MARK: Password recovery

    func recoverRequest(nick: String) async throws {
        _ = try await raw("POST", "/functions/v1/recover", json: ["action": "request", "nick": nick], auth: false)
    }

    func recoverConfirm(nick: String, code: String, newPassword: String) async throws {
        _ = try await raw("POST", "/functions/v1/recover",
                          json: ["action": "confirm", "nick": nick, "code": code, "new_password": newPassword],
                          auth: false)
    }
}
