import Foundation
import HealthKit
import WatchConnectivity
import Combine

/// 워치에서 HKWorkoutSession 을 직접 돌려 고빈도 심박을 받는다.
/// NSObject + 델리게이트 조합이라 @Observable 대신 ObservableObject 를 쓴다.
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var running = false
    @Published var startedAt: Date?
    @Published var heartRate: Int = 0
    @Published var activeKcal: Int = 0
    @Published var distanceMeters: Double = 0
    @Published var message: String = ""
    @Published var authorized = false
    @Published var sessionID: String = ""
    @Published var outdoor = true
    @Published var phoneReachable = false
    @Published var records: [WatchRecord] = []
    @Published var cardio = "steady"

    private var store: HKHealthStore?
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var lastSent = Date.distantPast
    private let hrUnit = HKUnit.count().unitDivided(by: .minute())

    /// 세션 동안 모으는 전체 시계열. 종료 시 아이폰으로 통째 전송한다.
    private var series: [String: [[Double]]] = [:]   // key -> [[t, v], ...]
    private var totals: [String: Double] = [:]

    private func record(_ key: String, _ v: Double) {
        guard let s = startedAt, v.isFinite, v > 0 else { return }
        let t = Date().timeIntervalSince(s)
        series[key, default: []].append([t, v])
    }

    // init 에서는 아무것도 건드리지 않는다. 크래시 방지.
    override init() { super.init() }

    /// 화면이 뜬 뒤 한 번 호출
    func prepare() {
        guard store == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "건강 데이터를 지원하지 않는 기기입니다"
            return
        }
        store = HKHealthStore()

        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            if s.activationState != .activated { s.activate() }
        }
        requestAuth()
    }

    private func requestAuth() {
        guard let store else { return }
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount),
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningGroundContactTime),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]
        let share: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
        store.requestAuthorization(toShare: share, read: read) { [weak self] ok, err in
            DispatchQueue.main.async {
                self?.authorized = ok
                if let err { self?.message = err.localizedDescription }
                else if !ok { self?.message = "건강 권한이 필요합니다" }
            }
        }
    }

    // MARK: - 세션

    /// sid·at 을 주면 아이폰이 시작한 세션에 합류한다.
    func start(outdoor: Bool, cardio: String = "steady", sid: String? = nil, at: Date? = nil) {
        guard let store, !running else { return }
        self.outdoor = outdoor
        self.cardio = cardio
        message = ""
        let id = sid ?? UUID().uuidString
        sessionID = id
        // 이전 세션 잔여 데이터가 남으면 t 가 뒤섞인다
        series.removeAll()
        totals.removeAll()
        heartRate = 0; activeKcal = 0; distanceMeters = 0
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .running
        cfg.locationType = outdoor ? .outdoor : .indoor

        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: cfg)
            let b = s.associatedWorkoutBuilder()
            let ds = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: cfg)
            // 러닝 다이내믹스까지 전부 수집
            for id: HKQuantityTypeIdentifier in [
                .heartRate, .activeEnergyBurned, .basalEnergyBurned,
                .distanceWalkingRunning, .stepCount,
                .runningSpeed, .runningPower, .runningStrideLength,
                .runningVerticalOscillation, .runningGroundContactTime
            ] {
                ds.enableCollection(for: HKQuantityType(id), predicate: nil)
            }
            b.dataSource = ds
            s.delegate = self
            b.delegate = self
            session = s; builder = b

            let now = at ?? Date()
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { [weak self] ok, err in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if ok {
                        self.running = true
                        self.startedAt = now
                        self.send(["cmd": "state", "running": true, "sid": id,
                                   "t": now.timeIntervalSince1970,
                                   "mode": outdoor ? "outdoor" : "indoor",
                                   "cardio": cardio])
                    } else {
                        self.message = err.map { self.text($0) } ?? "시작 실패"
                        self.cleanup()
                    }
                }
            }
        } catch {
            message = text(error)
            cleanup()
        }
    }

    func stop() {
        guard let s = session, let b = builder else { cleanup(); return }
        let now = Date()
        s.end()
        b.endCollection(withEnd: now) { [weak self] _, _ in
            b.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    self?.sendTelemetry()
                    self?.send(["cmd": "state", "running": false,
                                "sid": self?.sessionID ?? "",
                                "t": now.timeIntervalSince1970])
                    self?.cleanup()
                }
            }
        }
    }

    private func cleanup() {
        running = false
        startedAt = nil
        session = nil
        builder = nil
    }

    private func text(_ e: Error) -> String {
        let ns = e as NSError
        if ns.domain == HKError.errorDomain,
           ns.code == HKError.Code.errorAnotherWorkoutSessionStarted.rawValue {
            return "다른 앱이 운동 중입니다. 먼저 종료하세요."
        }
        return ns.localizedDescription
    }

    // MARK: - 기록 목록

    /// 아이폰에 최근 기록을 요청한다. 캐시가 있으면 먼저 보여준다.
    func requestRecords() {
        if records.isEmpty,
           let data = UserDefaults.standard.data(forKey: "records.cache"),
           let list = try? JSONDecoder().decode([WatchRecord].self, from: data) {
            records = list
        }
        send(["cmd": "records"])
    }

    private func absorbRecords(_ raw: [[String: Any]]) {
        let list = raw.compactMap(WatchRecord.init)
        records = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "records.cache")
        }
    }

    // MARK: - 아이폰 전송

    private func send(_ payload: [String: Any]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    /// 세션 전체 시계열을 JSON 으로 아이폰에 넘긴다.
    private func sendTelemetry() {
        let sorted = series.mapValues { $0.sorted { $0[0] < $1[0] } }
        var payload: [String: Any] = ["series": sorted, "totals": totals]
        payload["sid"] = sessionID
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        // 용량이 크므로 파일/유저인포 경로로 보낸다
        WCSession.default.transferUserInfo(["telemetry": data])
        series.removeAll(); totals.removeAll()
    }

    private func pushLive() {
        guard Date().timeIntervalSince(lastSent) > 1 else { return }
        lastSent = Date()
        send(["event": "live", "bpm": heartRate, "kcal": activeKcal,
              "meters": distanceMeters, "sid": sessionID,
              "t": Date().timeIntervalSince1970])
    }
}

// MARK: - 세션 상태

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ s: HKWorkoutSession, didChangeTo to: HKWorkoutSessionState,
                        from: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { self.running = (to == .running) }
    }
    func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.message = self.text(error)
            self.cleanup()
        }
    }
}

// MARK: - 실시간 지표

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) { }

    func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        var hr: Int?, kcal: Double?, meters: Double?
        var collected: [(String, Double)] = []

        for type in types {
            guard let qt = type as? HKQuantityType, let st = b.statistics(for: qt) else { continue }
            switch qt {
            case HKQuantityType(.heartRate):
                if let v = st.mostRecentQuantity()?.doubleValue(for: hrUnit) {
                    hr = Int(v); collected.append(("hr", v))
                }
            case HKQuantityType(.activeEnergyBurned):
                if let v = st.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    kcal = v; self.totals["activeKcal"] = v
                }
            case HKQuantityType(.basalEnergyBurned):
                if let v = st.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    self.totals["basalKcal"] = v
                }
            case HKQuantityType(.distanceWalkingRunning):
                if let v = st.sumQuantity()?.doubleValue(for: .meter()) {
                    meters = v; self.totals["watchDistance"] = v
                }
            case HKQuantityType(.stepCount):
                if let v = st.sumQuantity()?.doubleValue(for: .count()) {
                    self.totals["steps"] = v
                }
            case HKQuantityType(.runningSpeed):
                if let v = st.mostRecentQuantity()?.doubleValue(
                    for: .meter().unitDivided(by: .second())) { collected.append(("speed", v)) }
            case HKQuantityType(.runningPower):
                if let v = st.mostRecentQuantity()?.doubleValue(for: .watt()) {
                    collected.append(("power", v))
                }
            case HKQuantityType(.runningStrideLength):
                if let v = st.mostRecentQuantity()?.doubleValue(for: .meter()) {
                    collected.append(("stride", v))
                }
            case HKQuantityType(.runningVerticalOscillation):
                if let v = st.mostRecentQuantity()?.doubleValue(for: .meterUnit(with: .centi)) {
                    collected.append(("vertOsc", v))
                }
            case HKQuantityType(.runningGroundContactTime):
                if let v = st.mostRecentQuantity()?.doubleValue(for: .secondUnit(with: .milli)) {
                    collected.append(("gct", v))
                }
            default: break
            }
        }

        DispatchQueue.main.async {
            for (k, v) in collected { self.record(k, v) }
            if let hr { self.heartRate = hr }
            if let kcal { self.activeKcal = Int(kcal) }
            if let meters { self.distanceMeters = meters }
            self.pushLive()
        }
    }
}

// MARK: - WatchConnectivity

extension WatchWorkoutManager: WCSessionDelegate {
    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.phoneReachable = s.isReachable
            // 켜지자마자 아이폰에 현재 상태를 알린다
            self.broadcastState()
            // 아이폰이 남겨둔 명령이 있으면 이어받는다
            self.handle(s.receivedApplicationContext)
        }
    }
    func sessionReachabilityDidChange(_ s: WCSession) {
        DispatchQueue.main.async {
            self.phoneReachable = s.isReachable
            if s.isReachable && self.records.isEmpty { self.send(["cmd": "records"]) }
        }
    }
    func session(_ s: WCSession, didReceiveMessage m: [String: Any]) {
        DispatchQueue.main.async { self.handle(m) }
    }
    func session(_ s: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        DispatchQueue.main.async { self.handle(ctx) }
    }

    func broadcastState() {
        var m: [String: Any] = ["cmd": "state", "running": running, "sid": sessionID]
        if let s = startedAt { m["t"] = s.timeIntervalSince1970 }
        send(m)
    }

    private func handle(_ m: [String: Any]) {
        if m["event"] as? String == "records", let raw = m["items"] as? [[String: Any]] {
            absorbRecords(raw)
            return
        }
        switch m["cmd"] as? String {
        case "start":
            guard !running else { broadcastState(); return }
            let sid = m["sid"] as? String
            let at = (m["t"] as? Double).map { Date(timeIntervalSince1970: $0) }
            let out = (m["mode"] as? String) != "indoor"
            let cd = m["cardio"] as? String ?? "steady"
            start(outdoor: out, cardio: cd, sid: sid, at: at)
        case "stop":
            if running { stop() } else { broadcastState() }
        case "query":
            broadcastState()
        default: break
        }
    }
}
