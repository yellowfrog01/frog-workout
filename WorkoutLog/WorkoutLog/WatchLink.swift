import Foundation
import WatchConnectivity
import Observation

/// 아이폰 ↔ 워치 러닝 세션 공유 상태.
/// 세션 실체(HKWorkoutSession)는 워치가 소유하고, 양쪽 어디서든 시작·종료할 수 있다.
@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    // 공유 세션 상태
    var running = false
    var sessionID: String = ""
    var startedAt: Date?
    var mode: CardioMode = .steady

    // 워치가 보내는 실시간 지표
    var bpm: Int = 0
    var kcal: Int = 0
    var meters: Double = 0
    var lastUpdate: Date?
    var samples: [HRPoint] = []

    /// 아이폰이 시작을 눌렀지만 워치가 아직 안 받은 상태
    var pendingStart = false
    /// 워치가 종료 시 넘겨준 전체 시계열
    var telemetry = Telemetry()
    /// 뒤늦게 도착한 시계열을 세션에 반영하기 위한 신호
    var arrivedTelemetry: Telemetry?
    var arrivedSID: String = ""
    /// 마지막으로 워치에서 받은 메시지 (진단용)
    var lastEvent: String = ""
    /// 워치 기록 화면에 보낼 요약을 만드는 클로저. 앱 진입점에서 채운다.
    var recordsProvider: (() -> [[String: Any]])?

    var isLive: Bool {
        guard let l = lastUpdate else { return false }
        return Date().timeIntervalSince(l) < 15
    }
    var paired: Bool { WCSession.isSupported() && WCSession.default.isPaired }
    var watchAppInstalled: Bool { WCSession.isSupported() && WCSession.default.isWatchAppInstalled }
    var reachable: Bool { WCSession.isSupported() && WCSession.default.isReachable }

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    /// 앱이 포그라운드로 올라왔을 때 놓친 상황판을 다시 띄운다
    @MainActor
    func retryLiveActivityIfNeeded() {
        // 남은 액티비티를 현재 상태에 맞춘다 (없으면 시작, 운동 중 아니면 정리)
        LiveRun.reconcile(running: running, startedAt: startedAt, mode: mode)
        if running { pushToLiveActivity() }
    }

    func activateIfNeeded() {
        guard WCSession.isSupported() else { return }
        if WCSession.default.activationState != .activated { WCSession.default.activate() }
        else { send(["cmd": "query"]) }
    }

    // MARK: - 제어

    func startWorkout(mode: CardioMode) {
        let id = UUID().uuidString
        let now = Date()
        self.mode = mode
        sessionID = id
        startedAt = now
        running = true
        samples = []; bpm = 0; kcal = 0; meters = 0; lastUpdate = nil
        pendingStart = !reachable
        RunRecorder.shared.begin(at: now)
        LiveRun.start(mode: mode, at: now)
        send(["cmd": "start", "sid": id, "t": now.timeIntervalSince1970,
              "mode": "outdoor", "cardio": mode.rawValue])
    }

    /// 잠금화면 상황판 갱신
    @MainActor
    func pushToLiveActivity() {
        guard let s = startedAt else { return }
        let km = meters / 1000
        let pace = km > 0.05 ? Int(Date().timeIntervalSince(s) / km) : 0
        LiveRun.update(startedAt: s, bpm: bpm, km: km,
                       pace: pace, kcal: kcal, watchLive: isLive)
    }

    /// 워치가 요청한 기록 목록을 보낸다
    @MainActor
    func sendRecords() {
        guard let items = recordsProvider?() else { return }
        send(["event": "records", "items": items])
    }

    func stopWorkout() {
        running = false
        pendingStart = false
        RunRecorder.shared.end()
        LiveRun.end()
        send(["cmd": "stop", "sid": sessionID, "t": Date().timeIntervalSince1970])
    }

    // MARK: - 전송

    private func send(_ payload: [String: Any]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                try? WCSession.default.updateApplicationContext(payload)
            })
        } else {
            // 워치 앱이 꺼져 있으면 다음에 열릴 때 이어받게 남겨둔다
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in if state == .activated { self.send(["cmd": "query"]) } }
    }
    func sessionDidBecomeInactive(_ s: WCSession) { }
    func sessionDidDeactivate(_ s: WCSession) { WCSession.default.activate() }
    func sessionReachabilityDidChange(_ s: WCSession) {
        Task { @MainActor in
            if s.isReachable && self.pendingStart {
                // 워치가 이제 깨어났으니 시작 명령을 다시 보낸다
                self.send(["cmd": "start", "sid": self.sessionID,
                           "t": (self.startedAt ?? Date()).timeIntervalSince1970,
                           "mode": "outdoor"])
            }
        }
    }
    func session(_ s: WCSession, didReceiveMessage m: [String: Any]) {
        Task { @MainActor in self.apply(m) }
    }
    func session(_ s: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        Task { @MainActor in self.apply(ctx) }
    }
    func session(_ s: WCSession, didReceiveUserInfo info: [String: Any]) {
        guard let data = info["telemetry"] as? Data else { return }
        Task { @MainActor in self.ingestTelemetry(data) }
    }

    /// 워치가 보낸 JSON 시계열을 Telemetry 로 복원
    @MainActor
    private func ingestTelemetry(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let series = obj["series"] as? [String: [[Double]]] ?? [:]
        let totals = obj["totals"] as? [String: Double] ?? [:]
        func pts(_ k: String) -> [MetricPoint] {
            var out = (series[k] ?? []).compactMap { p -> MetricPoint? in
                guard p.count == 2, p[0].isFinite, p[1].isFinite else { return nil }
                return MetricPoint(t: p[0], v: p[1])
            }
            out.sort { $0.t < $1.t }
            // 같은 시각이 여럿이면 하나만
            var seen = Set<Int>()
            return out.filter { seen.insert(Int($0.t * 10)).inserted }
        }
        var t = telemetry
        t.hr                  = pts("hr")
        t.speed               = pts("speed")
        t.power               = pts("power")
        t.strideLength        = pts("stride")
        t.verticalOscillation = pts("vertOsc")
        t.groundContactTime   = pts("gct")
        t.activeKcal    = totals["activeKcal"]    ?? t.activeKcal
        t.basalKcal     = totals["basalKcal"]     ?? t.basalKcal
        t.steps         = Int(totals["steps"]     ?? Double(t.steps))
        t.watchDistance = totals["watchDistance"] ?? t.watchDistance
        telemetry = t
        arrivedSID = obj["sid"] as? String ?? ""
        arrivedTelemetry = t          // 저장된 세션에 병합하라는 신호
    }

    @MainActor
    private func apply(_ m: [String: Any]) {
        // 워치가 기록 목록을 요청
        if m["cmd"] as? String == "records" { sendRecords(); return }
        // 워치가 알려주는 세션 상태
        if m["cmd"] as? String == "state" {
            lastEvent = "state running=\(m["running"] as? Bool ?? false) \(Date().hmShort)"
            let r = m["running"] as? Bool ?? false
            if let sid = m["sid"] as? String, !sid.isEmpty { sessionID = sid }
            if let c = m["cardio"] as? String, let cm = CardioMode(rawValue: c) { mode = cm }
            // 종료 메시지의 t 는 "끝난 시각"이라 시작 시각으로 쓰면 타이머가 리셋된다
            if r, let t = m["t"] as? Double { startedAt = Date(timeIntervalSince1970: t) }
            if r { pendingStart = false }
            if r != running {
                running = r
                if r {
                    samples = []; bpm = 0; kcal = 0; meters = 0
                    // 아이폰 쪽 수집도 즉시 시작 (세션 화면이 없어도)
                    RunRecorder.shared.begin(at: startedAt ?? Date())
                    LiveRun.start(mode: mode, at: startedAt ?? Date())
                } else {
                    RunRecorder.shared.end()
                    LiveRun.end()
                }
            }
            return
        }
        // 실시간 지표
        guard m["event"] as? String == "live" else { return }
        lastEvent = "live bpm=\(m["bpm"] as? Int ?? 0) \(Date().hmShort)"
        if !running {
            RunRecorder.shared.begin(at: startedAt ?? Date())
            LiveRun.start(mode: mode, at: startedAt ?? Date())
        }
        running = true
        pendingStart = false
        if let b = m["bpm"] as? Int, b > 0 {
            bpm = b
            // 시작 시각을 아직 못 받았으면 지금을 기준으로 잡는다 (t 가 전부 0 이 되는 것 방지)
            if startedAt == nil { startedAt = Date() }
            let t = Date().timeIntervalSince(startedAt!)
            samples.append(HRPoint(bpm: Double(b), t: max(0, t)))
        }
        if let k = m["kcal"] as? Int { kcal = k }
        if let d = m["meters"] as? Double { meters = d }
        lastUpdate = Date()
        pushToLiveActivity()
    }
}
