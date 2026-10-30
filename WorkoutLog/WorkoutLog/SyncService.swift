import Foundation
import SwiftData
import Network
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// 동기화 대상 테이블
enum SyncTable: String, CaseIterable {
    case sessions, body_records, planned_workouts
}

/// 오프라인 우선 Supabase 동기화.
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
    private(set) var lastSyncAt: Date?
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
    @ObservationIgnored private var rerun = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var retryStep = 0
    @ObservationIgnored private var monitor: NWPathMonitor?
    /// "table:uuid" → 마지막으로 올린 해시
    @ObservationIgnored private var uploaded: [String: String] = [:]

    private static let retryDelays: [UInt64] = [5, 30, 120, 600]
    private let kLastSync = "sync.lastSyncAt"
    private let kRestore = "sync.restorePending"
    private let kAccount = "sync.account"

    private var restorePending: Bool {
        get { UserDefaults.standard.bool(forKey: kRestore) }
        set { UserDefaults.standard.set(newValue, forKey: kRestore) }
    }

    private static var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("sync-uploaded.json")
    }

    private init() {}

    // MARK: 시작

    /// 앱 시작 때 한 번. ModelContainer 의 mainContext 를 쓴다. 설정이 없으면 아무것도 하지 않는다.
    func start(container: ModelContainer) {
        guard !started else { return }
        started = true
        self.container = container
        loadUploaded()
        lastSyncAt = UserDefaults.standard.object(forKey: kLastSync) as? Date
        refreshAuth()
        guard isConfigured else { return }

        // 저장될 때마다
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            Task { @MainActor in SyncService.shared.contextDidSave() }
        }
        #if canImport(UIKit)
        // 앱이 활성화될 때
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in SyncService.shared.kick() }
        }
        #endif
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
        guard !assigning else { return }
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
        /// 로컬 세션이 비었는데 올린 세션이 2건 이상 → 저장소 초기화로 의심, 삭제 대신 복원
        var suspectWipe = false
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
            var plan = scan(ctx, allowWipe: false)
            pendingCount = plan.count
            guard isOnline else { return }

            var didWork = manual
            if restorePending || plan.suspectWipe {
                try await restore(ctx)
                plan = scan(ctx, allowWipe: true)
                pendingCount = plan.count
                didWork = true
            }
            if plan.count > 0 { didWork = true }
            try await push(plan)
            pendingCount = 0
            lastError = nil
            retryStep = 0
            if didWork {
                lastSyncAt = Date()
                UserDefaults.standard.set(lastSyncAt, forKey: kLastSync)
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

    /// 로컬 전체를 행으로 만들어 마지막 업로드 해시와 비교. 없는 syncID 는 여기서 발급한다.
    private func scan(_ ctx: ModelContext, allowWipe: Bool) -> Plan {
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
        for it in items {
            localKeys.insert(it.key)
            if uploaded[it.key] != it.hash { plan.upserts.append(it) }
        }
        let gone = uploaded.keys.filter { !localKeys.contains($0) }
        if !allowWipe, sessions.isEmpty, gone.filter({ $0.hasPrefix("sessions:") }).count >= 2 {
            plan.suspectWipe = true
            return plan
        }
        for k in gone {
            let parts = k.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2, let t = SyncTable(rawValue: parts[0]), let id = UUID(uuidString: parts[1]) {
                plan.deletes.append((t, id))
            }
        }
        return plan
    }

    // MARK: 업로드

    private func push(_ plan: Plan) async throws {
        guard plan.count > 0, !plan.suspectWipe else { return }
        let now = SyncMapper.iso(Date())
        for table in SyncTable.allCases {
            let items = plan.upserts.filter { $0.table == table }
            for start in stride(from: 0, to: items.count, by: 50) {
                let chunk = Array(items[start..<min(start + 50, items.count)])
                let rows = chunk.map { it -> [String: Any] in
                    var r = it.row
                    r["updated_at"] = now
                    return r
                }
                try await client.upsert(table: table.rawValue, rows: rows)
                for it in chunk { uploaded[it.key] = it.hash }
                saveUploaded()
            }
        }
        for table in SyncTable.allCases {
            let ids = plan.deletes.filter { $0.table == table }.map(\.id)
            for start in stride(from: 0, to: ids.count, by: 50) {
                let chunk = Array(ids[start..<min(start + 50, ids.count)])
                try await client.markDeleted(table: table.rawValue, ids: chunk)
                for id in chunk { uploaded.removeValue(forKey: "\(table.rawValue):\(id.uuidString.lowercased())") }
                saveUploaded()
            }
        }
    }

    // MARK: 복원

    /// 로컬 세션이 0건이면 서버의 세 테이블을 내려받아 넣는다. 받은 행의 해시는 "올림"으로 기록.
    private func restore(_ ctx: ModelContext) async throws {
        guard ((try? ctx.fetchCount(FetchDescriptor<Session>())) ?? 0) == 0 else {
            restorePending = false
            return
        }
        // 세 테이블을 모두 받은 뒤에 넣는다 (중간 실패 시 일부만 들어가지 않게)
        let sRows = try await client.fetchAll(table: SyncTable.sessions.rawValue)
        let bRows = try await client.fetchAll(table: SyncTable.body_records.rawValue)
        let pRows = try await client.fetchAll(table: SyncTable.planned_workouts.rawValue)
        guard ((try? ctx.fetchCount(FetchDescriptor<Session>())) ?? 0) == 0 else { return }

        let haveBody = Set(((try? ctx.fetch(FetchDescriptor<BodyRecord>())) ?? []).compactMap(\.syncID))
        let havePlan = Set(((try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []).compactMap(\.syncID))
        var hashes: [String: String] = [:]

        for r in sRows {
            guard let m = SyncMapper.session(from: r), let id = m.syncID,
                  let h = SyncMapper.hash(SyncMapper.sessionRow(m, id: id)) else { continue }
            ctx.insert(m)
            hashes["\(SyncTable.sessions.rawValue):\(id.uuidString.lowercased())"] = h
        }
        for r in bRows {
            guard let m = SyncMapper.body(from: r), let id = m.syncID, !haveBody.contains(id),
                  let h = SyncMapper.hash(SyncMapper.bodyRow(m, id: id)) else { continue }
            ctx.insert(m)
            hashes["\(SyncTable.body_records.rawValue):\(id.uuidString.lowercased())"] = h
        }
        for r in pRows {
            guard let m = SyncMapper.planned(from: r), let id = m.syncID, !havePlan.contains(id),
                  let h = SyncMapper.hash(SyncMapper.plannedRow(m, id: id)) else { continue }
            ctx.insert(m)
            hashes["\(SyncTable.planned_workouts.rawValue):\(id.uuidString.lowercased())"] = h
        }
        assigning = true
        defer { assigning = false }
        try ctx.save()
        uploaded.merge(hashes) { _, new in new }
        saveUploaded()
        restorePending = false
    }

    // MARK: 대기열 파일

    private func loadUploaded() {
        guard let d = try? Data(contentsOf: Self.storeURL),
              let m = try? JSONDecoder().decode([String: String].self, from: d) else { return }
        uploaded = m
    }

    private func saveUploaded() {
        guard let d = try? JSONEncoder().encode(uploaded) else { return }
        let url = Self.storeURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? d.write(to: url, options: .atomic)
    }
}
