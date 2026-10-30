import Foundation
import ActivityKit

/// 근력 운동 잠금화면 상황판. 초안(StrengthDraft)이 바뀔 때마다 맞춘다.
/// 운동 시작 전(준비 중)에는 띄우지 않는다.
enum StrengthLive {
    private static var activity: Activity<StrengthActivityAttributes>? {
        Activity<StrengthActivityAttributes>.activities.first
    }

    /// 앱 시작 시 한 번: 잠금화면 버튼 처리를 연결한다
    static func install() {
        CompleteSetIntent.handler = { completeNextSet() }
        StartNextLiftIntent.handler = { startNextLift() }
    }

    static func sync(_ d: StrengthDraft?) {
        guard let d, let start = d.start else { end(); return }
        let state = makeState(d, start: start)
        // 휴식 끝 시각을 staleDate 로 준다: 그 시각에 시스템이 위젯을 다시 그리고(isStale) "휴식 끝"으로 바뀐다
        let content = ActivityContent(state: state, staleDate: state.restEnd)
        if let a = activity {
            guard a.content.state != state else { return }
            Task { await a.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // 앱이 앞에 있을 때만 새로 띄울 수 있다 (실패는 무시)
            _ = try? Activity.request(attributes: StrengthActivityAttributes(), content: content)
        }
    }

    static func end() {
        for a in Activity<StrengthActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func makeState(_ d: StrengthDraft, start: Date) -> StrengthActivityAttributes.ContentState {
        let next = d.lifts.first { $0.done < $0.sets }
        let reps = next.map { l in l.repsList.indices.contains(l.done) ? l.repsList[l.done] : l.reps } ?? 0
        let rest = d.restEnd.flatMap { $0 > .now ? $0 : nil }
        let phase: String
        var since: Date?
        switch d.lifts.phase {
        case .sets: phase = "set"
        case .transition(let t, _): phase = "transition"; since = t
        case .warmup(let t, _): phase = "warmup"; since = t
        case .done: phase = "done"
        }
        return .init(startedAt: start,
                     lift: next?.name ?? "",
                     setNo: (next?.done ?? 0) + 1,
                     sets: next?.sets ?? 0,
                     load: next.map { "\($0.weightText(at: $0.done)) × \(reps)" } ?? "",
                     restEnd: rest,
                     doneSets: d.lifts.reduce(0) { $0 + $1.done },
                     totalSets: d.lifts.reduce(0) { $0 + $1.sets },
                     repsList: next?.repsList ?? [],
                     liftDone: next?.done ?? 0,
                     weight: next.map { $0.weightText(at: $0.done) } ?? "",
                     phase: phase,
                     phaseSince: since)
    }

    /// 잠금화면 "다음 운동 시작": 다음 종목 웜업 시작
    @MainActor static func startNextLift() {
        let store = StrengthDraftStore.shared
        guard var d = store.draft, d.start != nil,
              let i = d.lifts.firstIndex(where: { $0.done < $0.sets }),
              d.lifts[i].warmupAt == nil else { return }
        d.lifts[i].warmupAt = Date().timeIntervalSince1970
        store.save(d)
        store.externalRevision += 1
    }

    /// 잠금화면 "세트 완료": 순서상 다음 세트를 체크하고 그 종목 목표 휴식을 시작한다.
    /// 앱 화면에서 세트를 누른 것과 같은 기록(완료 시각 포함)이 남는다.
    @MainActor static func completeNextSet() {
        let store = StrengthDraftStore.shared
        guard var d = store.draft, d.start != nil,
              let i = d.lifts.firstIndex(where: { $0.done < $0.sets }) else { return }
        d.lifts[i].markSetDone()
        let lift = d.lifts[i]
        // 종목의 마지막 세트면 세트 휴식 대신 종목 간 휴식 ("다음 운동 시작"을 누를 때까지)
        if lift.done >= lift.sets {
            d.restEnd = nil
            d.restNext = nil
            store.save(d)
            store.externalRevision += 1
            RestAlert.shared.cancel()
            return
        }
        let total = lift.restSec ?? (UserDefaults.standard.object(forKey: "rest.seconds") as? Int ?? 120)
        let end = Date().addingTimeInterval(TimeInterval(total))
        let next: String
        if lift.done < lift.sets {
            let n = lift.repsList.indices.contains(lift.done) ? lift.repsList[lift.done] : lift.reps
            next = "다음: \(lift.name) \(lift.done + 1)세트 · \(lift.weightText(at: lift.done)) \(n)회"
        } else if let nx = d.lifts.first(where: { $0.done < $0.sets }) {
            next = "다음: \(nx.name) \(nx.done + 1)세트 · \(nx.weightText(at: nx.done))"
        } else {
            next = "\(lift.name) 완료"
        }
        d.restEnd = end
        d.restTotal = total
        d.restNext = next
        d.restLiftID = lift.id
        store.save(d)
        store.externalRevision += 1
        RestAlert.shared.schedule(at: end, body: next)
    }
}
