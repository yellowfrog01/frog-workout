import Foundation
import SwiftData
import Network
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 동기화 대상 테이블
enum SyncTable: String, CaseIterable {
    case sessions, body_records, planned_workouts
}

/// 오프라인 우선 Supabase 양방향 동기화.
///
/// 순서: 풀(서버 변경분 반영) → 스캔 → 업로드. 풀은 테이블별 lastPull(서버 synced_at 최댓값)부터 받는다.
/// 충돌 판정은 클라이언트가 보낸 updated_at(변경 시각)으로, 받기 커서는 synced_at 으로 한다.
/// 충돌(로컬에 대기 변경이 있는 행): 서버 updated_at 과 로컬 dirtySince 를 비교해 최신이 이긴다.
///
/// 변경 감지: 행 내용 해시(SHA256, updated_at 제외)를 "마지막으로 올린 해시"와 비교한다.
/// 이 해시 사전(Application Support/sync-uploaded.json)이 곧 영속 대기열이다.
///  - 대기 = 해시가 다른 행(신규·수정) + 올린 적 있는데 로컬에 없는 id(삭제 → deleted=true)
///  - 앱을 꺼도 파일이 남아 있어, 연결이 돌아오면 이어서 올린다.
/// 진행 중인 근력 운동(StrengthDraft)은 SwiftData 가 아니라 올라가지 않는다.
@MainActor @Observable
final class SyncService {
    static let shared = SyncService()

    // MARK: 화면용 상태
    private(set) var isSignedIn = false
    private(set) var email: String?
    private(set) var lastUploadAt: Date?
    private(set) var lastPullAt: Date?
    private(set) var pendingCount = 0
    private(set) var lastError: String?
    private(set) var isSyncing = false
    private(set) var isOnline = false

    var isConfigured: Bool { client.isConfigured }

    /// 툴바 아이콘
    var statusSymbol: String {
        if !isConfigured || !isSignedIn { return "icloud.slash" }
        if isSyncing || pendingCount > 0 { return "arrow.triangle.2.circlepath.icloud" }
        return "icloud"
    }

    // MARK: 내부
    @ObservationIgnored private let client = SupabaseClient.shared
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var assigning = false          // syncID 발급 저장 중 (알림 무시)
    @ObservationIgnored private var suppressUntil = Date.distantPast   // 원격 반영 저장 직후 알림 무시
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var rerun = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryStep = 0
    @ObservationIgnored private var monitor: NWPathMonitor?
    /// "table:uuid" → 마지막으로 올린(또는 원격에서 받아 반영한) 해시
    @ObservationIgnored private var uploaded: [String: String] = [:]
    /// "table:uuid" → 로컬에서 바뀐 것을 처음 감지한 시각 (epoch 초). 업로드 성공 시 제거.
    @ObservationIgnored private var dirtySince: [String: Double] = [:]
    /// 테이블명 → 마지막으로 받은 서버 updated_at 문자열(원문)
    @ObservationIgnored private var lastPull: [String: String] = [:]

    private struct State: Codable {
        var uploaded: [String: String] = [:]
        var dirtySince: [String: Double] = [:]
        var lastPull: [String: String] = [:]
    }

    private static let retryDelays: [UInt64] = [5, 30, 120, 600]
    private let kLastSync = "sync.lastSyncAt"      // 마지막 업로드 시각
    private let kLastPull = "sync.lastPullAt"      // 마지막 받기 시각
    private let kRestore = "sync.restorePending"
    private let kAccount = "sync.account"

    private var restorePending: Bool {
        get { UserDefaults.standard.bool(forKey: kRestore) }
        set { UserDefaults.standard.set(newValue, forKey: kRestore) }
    }

    private static var dir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    private static var storeURL: URL { dir.appendingPathComponent("sync-state.json") }
    /// 단방향 시절 파일 (해시 사전만). 새 파일이 없을 때만 읽는다.
    private static var legacyURL: URL { dir.appendingPathComponent("sync-uploaded.json") }

    private init() {}

    // MARK: 시작

    /// 앱 시작 때 한 번. ModelContainer 의 mainContext 를 쓴다. 설정이 없으면 아무것도 하지 않는다.
    func start(container: ModelContainer) {
        guard !started else { return }
        started = true
        self.container = container
        loadUploaded()
        lastUploadAt = UserDefaults.standard.object(forKey: kLastSync) as? Date
        lastPullAt = UserDefaults.standard.object(forKey: kLastPull) as? Date
        refreshAuth()
        guard isConfigured else { return }

        // 저장될 때마다
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            Task { @MainActor in SyncService.shared.contextDidSave() }
        }
        // 앱 활성/비활성: 활성일 때만 60초 주기로 받는다
        #if os(iOS)
        let activeName = UIApplication.didBecomeActiveNotification
        let inactiveName = UIApplication.willResignActiveNotification
        #elseif os(macOS)
        let activeName = NSApplication.didBecomeActiveNotification
        let inactiveName = NSApplication.didResignActiveNotification
        #endif
        #if os(iOS) || os(macOS)
        NotificationCenter.default.addObserver(forName: activeName, object: nil, queue: .main) { _ in
            Task { @MainActor in SyncService.shared.becameActive() }
        }
        NotificationCenter.default.addObserver(forName: inactiveName, object: nil, queue: .main) { _ in
            Task { @MainActor in SyncService.shared.stopPolling() }
        }
        #endif
        startPolling()
        // 네트워크 상태
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            let ok = path.status == .satisfied
            Task { @MainActor in SyncService.shared.networkChanged(ok) }
        }
        m.start(queue: DispatchQueue(label: "workoutlog.sync.path"))
        monitor = m

        kick()
    }

    // MARK: 주기 받기

    private func becameActive() {
        startPolling()
        kick()
    }

    /// 60초마다 kick (메인 런루프 타이머)
    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in SyncService.shared.kick() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: 인증

    func signIn(email: String, password: String) async throws {
        try await client.signIn(email: email, password: password)
        didSignIn()
    }

    /// true = 바로 로그인됨, false = 가입 확인 메일 대기
    func signUp(email: String, password: String) async throws -> Bool {
        guard try await client.signUp(email: email, password: password) != nil else { return false }
        didSignIn()
        return true
    }

    func signOut() {
        client.signOut()
        debounceTask?.cancel(); debounceTask = nil
        retryTask?.cancel(); retryTask = nil
        pendingCount = 0
        lastError = nil
        refreshAuth()
    }

    private func didSignIn() {
        let account = client.session?.email.lowercased() ?? ""
        // 다른 계정이면 올린 기록을 버린다 (새 계정에는 전부 새로 올려야 한다)
        if UserDefaults.standard.string(forKey: kAccount) != account {
            uploaded = [:]
            dirtySince = [:]
            lastPull = [:]
            saveUploaded()
            UserDefaults.standard.set(account, forKey: kAccount)
        }
        restorePending = true
        lastError = nil
        retryStep = 0
        refreshAuth()
        kick()
    }

    private func refreshAuth() {
        isSignedIn = client.session != nil
        email = client.session?.email
    }

    // MARK: 트리거

    private func contextDidSave() {
        guard !assigning, Date() >= suppressUntil else { return }
        kick()
    }

    private func networkChanged(_ ok: Bool) {
        let was = isOnline
        isOnline = ok
        if ok && !was { retryStep = 0; kick() }
    }

    /// 약 2초 디바운스 후 동기화. 연속 호출은 하나로 합쳐진다.
    func kick() {
        guard isConfigured, isSignedIn else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.debounceTask = nil
            await self.runSync()
        }
    }

    /// "지금 동기화"
    func syncNow() async {
        guard isConfigured, isSignedIn else { return }
        debounceTask?.cancel(); debounceTask = nil
        guard isOnline else {
            lastError = "오프라인입니다. 연결되면 자동으로 올립니다"
            return
        }
        await runSync(manual: true)
    }

    // MARK: 본체 (한 번에 하나만)

    private struct Item {
        let table: SyncTable
        let id: UUID
        let row: [String: Any]
        let hash: String
        var key: String { "\(table.rawValue):\(id.uuidString.lowercased())" }
    }
    private struct Plan {
        var upserts: [Item] = []
        var deletes: [(table: SyncTable, id: UUID)] = []
        var count: Int { upserts.count + deletes.count }
    }

    private func runSync(manual: Bool = false) async {
        guard isConfigured, client.session != nil, let ctx = container?.mainContext else { return }
        guard !isSyncing else { rerun = true; return }
        retryTask?.cancel(); retryTask = nil
        isSyncing = true
        defer {
            isSyncing = false
            refreshAuth()
            if rerun { rerun = false; kick() }
        }
        do {
            var plan = scan(ctx)
            pendingCount = plan.count
            guard isOnline else { return }

            // 1) 서버 변경분 받기 (충돌은 여기서 해소) → 2) 다시 스캔 → 3) 올리기
            try await pull(ctx)
            plan = scan(ctx)
            pendingCount = plan.count
            let hadWork = plan.count > 0
            try await push(plan)
            pendingCount = 0
            lastError = nil
            retryStep = 0
            if hadWork {
                lastUploadAt = Date()
                UserDefaults.standard.set(lastUploadAt, forKey: kLastSync)
            }
        } catch {
            lastError = Self.message(error)
            refreshAuth()
            if isSignedIn { scheduleRetry() }
        }
    }

    private func scheduleRetry() {
        let delay = Self.retryDelays[min(retryStep, Self.retryDelays.count - 1)]
        retryStep += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.retryTask = nil
            await self.runSync()
        }
    }

    private static func message(_ error: Error) -> String {
        if let u = error as? URLError {
            switch u.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                return "네트워크에 연결할 수 없습니다. 연결되면 다시 시도합니다"
            default: break
            }
        }
        return error.localizedDescription
    }

    // MARK: 변경 감지

    private static func key(_ table: SyncTable, _ id: UUID) -> String { "\(table.rawValue):\(id.uuidString.lowercased())" }

    /// 로컬 전체를 행으로 만들어 마지막 업로드 해시와 비교. 없는 syncID 는 여기서 발급한다.
    /// 해시가 다른 행·로컬에서 사라진 행은 처음 본 시각을 dirtySince 에 기록한다.
    private func scan(_ ctx: ModelContext) -> Plan {
        let sessions = (try? ctx.fetch(FetchDescriptor<Session>())) ?? []
        let bodies = (try? ctx.fetch(FetchDescriptor<BodyRecord>())) ?? []
        let plans = (try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []

        // syncID 발급 (저장 알림이 다시 kick 하지 않도록 플래그)
        var assigned = false
        var seen = Set<UUID>()
        for s in sessions { if s.syncID == nil || !seen.insert(s.syncID!).inserted { s.syncID = UUID(); seen.insert(s.syncID!); assigned = true } }
        for b in bodies { if b.syncID == nil || !seen.insert(b.syncID!).inserted { b.syncID = UUID(); seen.insert(b.syncID!); assigned = true } }
        for p in plans { if p.syncID == nil || !seen.insert(p.syncID!).inserted { p.syncID = UUID(); seen.insert(p.syncID!); assigned = true } }
        if assigned {
            assigning = true
            try? ctx.save()
            assigning = false
        }

        var items: [Item] = []
        func add(_ table: SyncTable, _ id: UUID, _ row: [String: Any]) {
            if let h = SyncMapper.hash(row) { items.append(Item(table: table, id: id, row: row, hash: h)) }
        }
        for s in sessions { if let id = s.syncID { add(.sessions, id, SyncMapper.sessionRow(s, id: id)) } }
        for b in bodies { if let id = b.syncID { add(.body_records, id, SyncMapper.bodyRow(b, id: id)) } }
        for p in plans { if let id = p.syncID { add(.planned_workouts, id, SyncMapper.plannedRow(p, id: id)) } }

        var plan = Plan()
        var localKeys = Set<String>()
        let now = Date().timeIntervalSince1970
        var dirtyChanged = false
        for it in items {
            localKeys.insert(it.key)
            if uploaded[it.key] != it.hash {
                plan.upserts.append(it)
                if dirtySince[it.key] == nil { dirtySince[it.key] = now; dirtyChanged = true }
            } else if dirtySince.removeValue(forKey: it.key) != nil {
                dirtyChanged = true
            }
        }
        let gone = uploaded.keys.filter { !localKeys.contains($0) }
        for k in gone {
            let parts = k.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2, let t = SyncTable(rawValue: parts[0]), let id = UUID(uuidString: parts[1]) {
                plan.deletes.append((t, id))
                if dirtySince[k] == nil { dirtySince[k] = now; dirtyChanged = true }
            }
        }
        // 올린 적 없이 만들었다 지운 행의 흔적 정리
        for k in dirtySince.keys where !localKeys.contains(k) && uploaded[k] == nil {
            dirtySince.removeValue(forKey: k); dirtyChanged = true
        }
        if dirtyChanged { saveUploaded() }
        return plan
    }

    // MARK: 업로드

    private func push(_ plan: Plan) async throws {
        guard plan.count > 0 else { return }
        let now = SyncMapper.iso(Date())
        for table in SyncTable.allCases {
            let items = plan.upserts.filter { $0.table == table }
            for start in stride(from: 0, to: items.count, by: 50) {
                let chunk = Array(items[start..<min(start + 50, items.count)])
                let rows = chunk.map { it -> [String: Any] in
                    var r = it.row
                    // 변경을 처음 감지한 시각을 updated_at 으로 (충돌 비교 기준)
                    r["updated_at"] = dirtySince[it.key].map { SyncMapper.iso(Date(timeIntervalSince1970: $0)) } ?? now
                    return r
                }
                try await client.upsert(table: table.rawValue, rows: rows)
                for it in chunk { uploaded[it.key] = it.hash; dirtySince.removeValue(forKey: it.key) }
                saveUploaded()
            }
        }
        for table in SyncTable.allCases {
            let ids = plan.deletes.filter { $0.table == table }.map(\.id)
            for start in stride(from: 0, to: ids.count, by: 50) {
                let chunk = Array(ids[start..<min(start + 50, ids.count)])
                try await client.markDeleted(table: table.rawValue, ids: chunk)
                for id in chunk {
                    let k = Self.key(table, id)
                    uploaded.removeValue(forKey: k)
                    dirtySince.removeValue(forKey: k)
                }
                saveUploaded()
            }
        }
    }

    // MARK: 풀 (서버 → 로컬)

    /// 서버 변경분을 받아 로컬에 반영한다. 세 테이블을 모두 받은 뒤에 적용한다(중간 실패 시 일부만 들어가지 않게).
    ///
    /// 로컬이 비었거나(재설치·기기 교체) 세션이 비었는데 올린 세션이 2건 이상(저장소 초기화 의심)이면
    /// 상태를 비우고 lastPull 없이(= 전체) 받는다.
    private func pull(_ ctx: ModelContext) async throws {
        let sCount = (try? ctx.fetchCount(FetchDescriptor<Session>())) ?? 0
        let bCount = (try? ctx.fetchCount(FetchDescriptor<BodyRecord>())) ?? 0
        let pCount = (try? ctx.fetchCount(FetchDescriptor<PlannedWorkout>())) ?? 0
        let uploadedSessions = uploaded.keys.filter { $0.hasPrefix("sessions:") }.count
        if (sCount + bCount + pCount == 0) || (sCount == 0 && (restorePending || uploadedSessions >= 2)) {
            uploaded = [:]; dirtySince = [:]; lastPull = [:]
            saveUploaded()
        }

        var fetched: [SyncTable: [[String: Any]]] = [:]
        for table in SyncTable.allCases {
            fetched[table] = try await client.fetchChanges(table: table.rawValue, since: lastPull[table.rawValue])
        }

        var changed = false
        var newPull = lastPull

        // 현재 로컬 객체 (syncID → 모델)
        func index<M>(_ list: [M], _ id: (M) -> UUID?) -> [UUID: M] {
            var d: [UUID: M] = [:]
            for m in list { if let i = id(m), d[i] == nil { d[i] = m } }
            return d
        }
        var sMap = index((try? ctx.fetch(FetchDescriptor<Session>())) ?? []) { $0.syncID }
        var bMap = index((try? ctx.fetch(FetchDescriptor<BodyRecord>())) ?? []) { $0.syncID }
        var pMap = index((try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []) { $0.syncID }

        changed = applyRows(.sessions, fetched[.sessions] ?? [], &sMap, ctx,
                            make: { SyncMapper.session(from: $0) },
                            update: { SyncMapper.applySession($0, to: $1) },
                            rowOf: { SyncMapper.sessionRow($0, id: $1) }) || changed
        changed = applyRows(.body_records, fetched[.body_records] ?? [], &bMap, ctx,
                            make: { SyncMapper.body(from: $0) },
                            update: { SyncMapper.applyBody($0, to: $1) },
                            rowOf: { SyncMapper.bodyRow($0, id: $1) }) || changed
        changed = applyRows(.planned_workouts, fetched[.planned_workouts] ?? [], &pMap, ctx,
                            make: { SyncMapper.planned(from: $0) },
                            update: { SyncMapper.applyPlanned($0, to: $1) },
                            rowOf: { SyncMapper.plannedRow($0, id: $1) }) || changed

        if changed {
            // 반영 저장이 다시 업로드를 부르지 않게 알림을 잠시 무시
            suppressUntil = Date().addingTimeInterval(2)
            assigning = true
            defer { assigning = false }
            try ctx.save()
        }
        // lastPull = 받은 행의 최대 synced_at (서버가 쓴 시각, 원문 유지)
        for (table, rows) in fetched {
            var best: (Date, String)?
            for r in rows {
                guard let s = r["synced_at"] as? String, let d = SyncMapper.date(s) else { continue }
                if best == nil || d >= best!.0 { best = (d, s) }
            }
            if let best { newPull[table.rawValue] = best.1 }
        }
        lastPull = newPull
        restorePending = false
        saveUploaded()
        lastPullAt = Date()
        UserDefaults.standard.set(lastPullAt, forKey: kLastPull)
    }

    /// 한 테이블의 받은 행을 적용. 반환값 = 로컬 객체가 바뀌었는지.
    private func applyRows<M: PersistentModel>(
        _ table: SyncTable, _ rows: [[String: Any]], _ local: inout [UUID: M], _ ctx: ModelContext,
        make: ([String: Any]) -> M?,
        update: ([String: Any], M) -> Void,
        rowOf: (M, UUID) -> [String: Any]
    ) -> Bool {
        var changed = false
        for r in rows {
            guard let id = SyncMapper.uuid(r["id"]) else { continue }
            let key = Self.key(table, id)
            let remoteAt = SyncMapper.date(r["updated_at"]) ?? .distantPast
            let remoteDeleted = (r["deleted"] as? Bool) == true

            if let obj = local[id] {
                guard let localHash = SyncMapper.hash(rowOf(obj, id)) else { continue }
                if uploaded[key] != localHash {
                    // 충돌: 로컬 대기 변경 vs 원격. 원격이 더 새로울 때만 원격 승리, 아니면 로컬을 올린다.
                    let localAt = Date(timeIntervalSince1970: dirtySince[key] ?? Date().timeIntervalSince1970)
                    if !(remoteAt > localAt) { continue }
                }
                if remoteDeleted {
                    ctx.delete(obj)
                    local.removeValue(forKey: id)
                    changed = true
                } else if let tmp = make(r), let newHash = SyncMapper.hash(rowOf(tmp, id)) {
                    if newHash != localHash { update(r, obj); changed = true }
                    uploaded[key] = newHash
                } else { continue }
                if remoteDeleted { uploaded.removeValue(forKey: key) }
                dirtySince.removeValue(forKey: key)
            } else {
                // 로컬에 없음: 새 행이거나, 로컬에서 지운 뒤 아직 못 올린 행
                if uploaded[key] != nil {
                    if remoteDeleted { uploaded.removeValue(forKey: key); dirtySince.removeValue(forKey: key); continue }
                    let delAt = Date(timeIntervalSince1970: dirtySince[key] ?? Date().timeIntervalSince1970)
                    if !(remoteAt > delAt) { continue }   // 로컬 삭제가 최신 → 삭제 표시를 올린다
                }
                if remoteDeleted { continue }
                guard let m = make(r), let h = SyncMapper.hash(rowOf(m, id)) else { continue }
                ctx.insert(m)
                local[id] = m
                uploaded[key] = h
                dirtySince.removeValue(forKey: key)
                changed = true
            }
        }
        return changed
    }

    // MARK: 상태 파일

    private func loadUploaded() {
        if let d = try? Data(contentsOf: Self.storeURL), let s = try? JSONDecoder().decode(State.self, from: d) {
            uploaded = s.uploaded; dirtySince = s.dirtySince; lastPull = s.lastPull
        } else if let d = try? Data(contentsOf: Self.legacyURL),
                  let m = try? JSONDecoder().decode([String: String].self, from: d) {
            uploaded = m
        }
    }

    private func saveUploaded() {
        let s = State(uploaded: uploaded, dirtySince: dirtySince, lastPull: lastPull)
        guard let d = try? JSONEncoder().encode(s) else { return }
        let url = Self.storeURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? d.write(to: url, options: .atomic)
    }
}
