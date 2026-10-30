import Foundation
import Security

// MARK: - 설정

/// Supabase.plist (URL, AnonKey) 를 번들에서 읽는다. 없거나 자리표시값이면 nil → 동기화 꺼짐.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static let shared: SupabaseConfig? = load()

    private static func load() -> SupabaseConfig? {
        guard let path = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              var raw = (dict["URL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let key = (dict["AnonKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty, !key.isEmpty,
              !raw.contains("YOUR-"), !key.contains("YOUR-")
        else { return nil }
        while raw.hasSuffix("/") { raw.removeLast() }
        guard let url = URL(string: raw), url.host != nil else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }
}

// MARK: - 오류·세션

enum SupabaseError: LocalizedError {
    case notConfigured
    case notSignedIn
    case http(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Supabase 설정(Supabase.plist)이 없습니다"
        case .notSignedIn: "로그인이 필요합니다"
        case .http(let code, let msg): msg.isEmpty ? "서버 오류 (\(code))" : msg
        case .invalidResponse: "서버 응답을 해석할 수 없습니다"
        }
    }
}

/// 로그인 상태. Keychain 에 JSON 한 덩어리로 저장.
struct AuthSession: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var email: String
}

/// Keychain (kSecClassGenericPassword, service "workoutlog.supabase")
private enum SessionKeychain {
    static let service = "workoutlog.supabase"
    static let account = "session"

    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> AuthSession? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func save(_ s: AuthSession) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func clear() { SecItemDelete(base as CFDictionary) }
}

// MARK: - 클라이언트 (GoTrue + PostgREST, URLSession 직접 호출)

@MainActor
final class SupabaseClient {
    static let shared = SupabaseClient()

    private(set) var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    private let config = SupabaseConfig.shared
    private let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    var isConfigured: Bool { config != nil }

    private init() { session = SessionKeychain.load() }

    // MARK: 인증

    /// 이메일·비밀번호 로그인
    @discardableResult
    func signIn(email: String, password: String) async throws -> AuthSession {
        let obj = try await authCall("token?grant_type=password",
                                     body: ["email": email, "password": password])
        guard let s = Self.parseSession(obj, fallbackEmail: email) else { throw SupabaseError.invalidResponse }
        store(s)
        return s
    }

    /// 가입. 이메일 확인이 켜져 있으면 세션이 오지 않아 nil 을 돌려준다.
    func signUp(email: String, password: String) async throws -> AuthSession? {
        let obj = try await authCall("signup", body: ["email": email, "password": password])
        guard let s = Self.parseSession(obj, fallbackEmail: email) else { return nil }
        store(s)
        return s
    }

    func signOut() {
        refreshTask?.cancel()
        refreshTask = nil
        session = nil
        SessionKeychain.clear()
    }

    private func store(_ s: AuthSession) {
        session = s
        SessionKeychain.save(s)
    }

    /// 유효한 액세스 토큰. 만료 60초 전이면 먼저 갱신.
    private func validToken(forceRefresh: Bool = false) async throws -> String {
        guard let s = session else { throw SupabaseError.notSignedIn }
        if !forceRefresh, s.expiresAt.timeIntervalSinceNow > 60 { return s.accessToken }
        return try await refresh().accessToken
    }

    /// 갱신은 한 번에 하나만 (refresh token 은 일회용이라 중복 호출하면 실패한다)
    private func refresh() async throws -> AuthSession {
        if let t = refreshTask { return try await t.value }
        guard let old = session else { throw SupabaseError.notSignedIn }
        let task = Task { @MainActor () -> AuthSession in
            let obj = try await self.authCall("token?grant_type=refresh_token",
                                              body: ["refresh_token": old.refreshToken])
            guard let s = Self.parseSession(obj, fallbackEmail: old.email) else { throw SupabaseError.invalidResponse }
            return s
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let s = try await task.value
            store(s)
            return s
        } catch SupabaseError.http(let code, let msg) where code == 400 || code == 401 || code == 403 {
            // refresh token 이 거부됨 → 다시 로그인해야 한다
            signOut()
            throw SupabaseError.http(code, msg.isEmpty ? "로그인이 만료되었습니다. 다시 로그인하세요" : msg)
        }
    }

    private func authCall(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let cfg = config else { throw SupabaseError.notConfigured }
        guard let url = URL(string: cfg.url.absoluteString + "/auth/v1/" + path) else { throw SupabaseError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(cfg.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await urlSession.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw SupabaseError.http(code, Self.errorMessage(data)) }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    /// 로그인·갱신 응답 → 세션. access_token 이 없으면 nil (가입 확인 대기).
    private static func parseSession(_ o: [String: Any], fallbackEmail: String) -> AuthSession? {
        guard let access = o["access_token"] as? String,
              let refresh = o["refresh_token"] as? String else { return nil }
        let expiresIn = (o["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        let user = o["user"] as? [String: Any]
        let email = (user?["email"] as? String) ?? (o["email"] as? String) ?? fallbackEmail
        return AuthSession(accessToken: access, refreshToken: refresh,
                           expiresAt: Date().addingTimeInterval(expiresIn), email: email)
    }

    private static func errorMessage(_ data: Data) -> String {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return String(data: data, encoding: .utf8)?.prefix(200).description ?? ""
        }
        for k in ["error_description", "msg", "message", "hint", "error"] {
            if let s = o[k] as? String, !s.isEmpty { return s }
        }
        return ""
    }

    // MARK: REST (PostgREST)

    /// 인증 헤더를 붙여 호출. 401 이면 토큰을 갱신해 한 번 재시도.
    private func rest(method: String, table: String, query: String? = nil, body: Data? = nil,
                      headers: [String: String] = [:]) async throws -> Data {
        guard let cfg = config else { throw SupabaseError.notConfigured }
        var urlString = cfg.url.absoluteString + "/rest/v1/" + table
        if let q = query { urlString += "?" + q }
        guard let url = URL(string: urlString) else { throw SupabaseError.invalidResponse }

        func attempt(_ token: String) async throws -> (Data, Int) {
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.setValue(cfg.anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            req.httpBody = body
            let (data, resp) = try await urlSession.data(for: req)
            return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }

        var (data, code) = try await attempt(try await validToken())
        if code == 401 { (data, code) = try await attempt(try await validToken(forceRefresh: true)) }
        guard (200..<300).contains(code) else { throw SupabaseError.http(code, Self.errorMessage(data)) }
        return data
    }

    /// 업서트 (id 충돌 시 병합). user_id 는 보내지 않는다 — 새 행은 DB 기본값(auth.uid()),
    /// 기존 행은 그대로 유지된다. 한 번에 최대 50행.
    func upsert(table: String, rows: [[String: Any]]) async throws {
        for start in stride(from: 0, to: rows.count, by: 50) {
            let chunk = Array(rows[start..<min(start + 50, rows.count)])
            let body = try JSONSerialization.data(withJSONObject: chunk)
            _ = try await rest(method: "POST", table: table, body: body,
                               headers: ["Prefer": "resolution=merge-duplicates,return=minimal"])
        }
    }

    /// 소프트 삭제 표시
    func markDeleted(table: String, ids: [UUID]) async throws {
        for start in stride(from: 0, to: ids.count, by: 50) {
            let list = ids[start..<min(start + 50, ids.count)].map { $0.uuidString.lowercased() }.joined(separator: ",")
            let body = try JSONSerialization.data(withJSONObject: [
                "deleted": true, "updated_at": SyncMapper.iso(Date())
            ] as [String: Any])
            _ = try await rest(method: "PATCH", table: table, query: "id=in.(\(list))", body: body,
                               headers: ["Prefer": "return=minimal"])
        }
    }

    /// 복원용 전체 조회 (deleted=false). Range 헤더로 1000행씩.
    func fetchAll(table: String) async throws -> [[String: Any]] {
        var out: [[String: Any]] = []
        var from = 0
        while true {
            let data = try await rest(method: "GET", table: table,
                                      query: "select=*&deleted=eq.false&order=date.asc,id.asc",
                                      headers: ["Range-Unit": "items", "Range": "\(from)-\(from + 999)"])
            guard let page = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
                throw SupabaseError.invalidResponse
            }
            out += page
            if page.count < 1000 { break }
            from += 1000
        }
        return out
    }

    /// 풀용 변경분 조회. `synced_at > since` (deleted 포함), 오래된 것부터. Range 헤더로 1000행씩.
    /// synced_at = 서버에 쓰인 시각(트리거). 오프라인 변경이 과거 updated_at 으로 늦게 올라와도 놓치지 않는다.
    /// since 가 nil 이면 전체. `synced_at` 문자열은 서버 값 그대로 돌려준다.
    func fetchChanges(table: String, since: String?) async throws -> [[String: Any]] {
        var out: [[String: Any]] = []
        var from = 0
        var query = "select=*&order=synced_at.asc,id.asc"
        if let since {
            // '+' 가 공백으로 해석되지 않게 인코딩
            let enc = since.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "0123456789-:.TZ")) ?? since
            query = "select=*&synced_at=gt.\(enc)&order=synced_at.asc,id.asc"
        }
        while true {
            let data = try await rest(method: "GET", table: table, query: query,
                                      headers: ["Range-Unit": "items", "Range": "\(from)-\(from + 999)"])
            guard let page = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
                throw SupabaseError.invalidResponse
            }
            out += page
            if page.count < 1000 { break }
            from += 1000
        }
        return out
    }
}
