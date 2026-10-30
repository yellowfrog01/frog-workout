import Foundation
import ActivityKit

/// 잠금화면 상황판 제어.
@Observable
final class LiveRunStatus {
    static let shared = LiveRunStatus()
    var note: String = ""
    private init() {}
}

enum LiveRun {
    private static var activity: Activity<RunActivityAttributes>?

    static var enabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// 앱이 죽었다 켜지면 시스템에 액티비티가 남아 있어도 참조는 사라진다.
    /// 남은 것을 찾아 현재 상태에 맞게 붙이거나 정리한다.
    static func reconcile(running: Bool, startedAt: Date?, mode: CardioMode) {
        let live = Activity<RunActivityAttributes>.activities
        guard !live.isEmpty else {
            if running, let s = startedAt { start(mode: mode, at: s) }
            return
        }
        if running {
            // 하나만 남기고 나머지는 종료
            activity = live.first
            for extra in live.dropFirst() {
                Task { await extra.end(nil, dismissalPolicy: .immediate) }
            }
            // 시작 시각이 어긋나 있으면 바로잡는다
            if let s = startedAt, let a = activity, a.content.state.startedAt != s {
                let st = a.content.state
                let fixed = RunActivityAttributes.ContentState(
                    startedAt: s, bpm: st.bpm, distanceKm: st.distanceKm,
                    paceSeconds: st.paceSeconds, kcal: st.kcal, watchLive: st.watchLive)
                lastPush = .distantPast
                Task { await a.update(.init(state: fixed, staleDate: nil)) }
            }
        } else {
            // 운동이 안 돌고 있는데 상황판이 살아있으면 전부 정리
            activity = nil
            lastState = nil
            for a in live { Task { await a.end(nil, dismissalPolicy: .immediate) } }
            LiveRunStatus.shared.note = ""
        }
    }

    static func start(mode: CardioMode, at: Date) {
        let st = LiveRunStatus.shared
        guard activity == nil else { return }
        // 이전 실행에서 남은 것이 있으면 먼저 치운다
        let stale = Activity<RunActivityAttributes>.activities
        if !stale.isEmpty {
            for a in stale { Task { await a.end(nil, dismissalPolicy: .immediate) } }
        }
        guard enabled else {
            st.note = "설정 → 운동로그 → 실시간 액티비티를 켜주세요"
            return
        }
        let attrs = RunActivityAttributes(mode: mode.label)
        let state = RunActivityAttributes.ContentState(
            startedAt: at, bpm: 0, distanceKm: 0, paceSeconds: 0, kcal: 0, watchLive: false)
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil))
            st.note = "잠금화면 상황판 켜짐"
        } catch let e as ActivityAuthorizationError {
            st.note = e == .visibility
                ? "잠금 상태에선 상황판을 띄울 수 없습니다 (앱을 열면 표시)"
                : "상황판 실패: \(e.localizedDescription)"
        } catch {
            st.note = "상황판 실패: \(error.localizedDescription)"
        }
    }

    private static var lastPush = Date.distantPast
    private static var lastState: RunActivityAttributes.ContentState?

    /// ActivityKit 은 갱신 예산이 있어 과도하게 호출하면 시스템이 액티비티를 끊는다.
    /// 2초에 한 번, 값이 실제로 바뀐 경우에만 보낸다.
    static func update(startedAt: Date, bpm: Int, km: Double, pace: Int, kcal: Int, watchLive: Bool) {
        guard let a = activity else { return }
        let state = RunActivityAttributes.ContentState(
            startedAt: startedAt, bpm: bpm, distanceKm: km,
            paceSeconds: pace, kcal: kcal, watchLive: watchLive)
        guard state != lastState else { return }
        guard Date().timeIntervalSince(lastPush) >= 2 else { return }
        lastPush = Date()
        lastState = state
        Task { await a.update(.init(state: state, staleDate: nil)) }
    }

    /// 참조가 없어도 시스템에 남은 것까지 전부 종료한다.
    static func end() {
        activity = nil
        lastState = nil
        lastPush = .distantPast
        LiveRunStatus.shared.note = ""
        let live = Activity<RunActivityAttributes>.activities
        for a in live { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
