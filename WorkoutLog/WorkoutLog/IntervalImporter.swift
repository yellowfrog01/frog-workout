import Foundation
import HealthKit
import WorkoutKit

/// 애플 운동 앱 "사용자 설정 세션"(인터벌)을 구간 단위로 읽는다.
/// 구간 = HKWorkoutActivity, 계획 = WorkoutKit WorkoutPlan, 워밍업 = 직전에 따로 뛴 러닝.
enum IntervalImporter {
    private static let store = HKHealthStore()
    /// 본운동 시작 전 이 시간 안에 끝난 러닝을 워밍업으로 묶는다
    static let warmupWindow: TimeInterval = 60 * 60

    static func isInterval(_ w: HKWorkout) -> Bool { w.workoutActivities.count > 1 }

    /// 인터벌이 아니면 nil
    static func load(_ w: HKWorkout, done: @escaping (IntervalDetail?) -> Void) {
        guard isInterval(w) else { done(nil); return }
        Task {
            var custom: CustomWorkout?
            if let plan = try? await w.workoutPlan, case .custom(let c) = plan.workout { custom = c }

            var d = IntervalDetail()
            d.planName = custom?.displayName
            if let b = custom?.blocks.first {
                d.plannedSets = b.iterations
                for st in b.steps {
                    let s = seconds(st.step.goal)
                    if st.purpose == .work { d.plannedWorkSeconds = d.plannedWorkSeconds ?? s }
                    else { d.plannedRecoverySeconds = d.plannedRecoverySeconds ?? s }
                }
            }
            d.segments = segments(w, plan: custom)
            d.warmup = await warmup(before: w)
            await MainActor.run { done(d) }
        }
    }

    // MARK: - 구간

    private static func segments(_ w: HKWorkout, plan: CustomWorkout?) -> [IntervalSegment] {
        let acts = w.workoutActivities.sorted { $0.startDate < $1.startDate }
        let kinds = acts.map { kind($0, plan: plan) }
        let fallback = kinds.contains(nil) ? speedKinds(acts) : []
        var round = 0
        return acts.enumerated().map { i, a in
            let k = kinds[i] ?? fallback[i]
            if k == .work { round += 1 }
            return segment(a, kind: k, round: k == .work || k == .recovery ? round : 0,
                           start: w.startDate)
        }
    }

    /// 메타데이터 WOIntervalStepKeyPath = "블록.반복.단계" (애플 비공개 키) 로 판별.
    /// 계획에 워밍업이 있으면 블록 0 이 워밍업이라고 가정한다 (실기록으로 확인 전).
    private static func kind(_ a: HKWorkoutActivity, plan: CustomWorkout?) -> IntervalSegment.Kind? {
        guard let plan, let raw = a.metadata?["WOIntervalStepKeyPath"] as? String else { return nil }
        let kp = raw.split(separator: ".").compactMap { Int($0) }
        guard kp.count == 3 else { return nil }
        let offset = plan.warmup == nil ? 0 : 1
        if offset == 1 && kp[0] == 0 { return .warmup }
        let b = kp[0] - offset
        guard b < plan.blocks.count else { return .cooldown }
        let steps = plan.blocks[b].steps
        guard kp[2] < steps.count else { return nil }
        return steps[kp[2]].purpose == .work ? .work : .recovery
    }

    /// 계획·메타데이터가 없을 때: 중앙값보다 빠른 구간 = 질주, 마지막 느린 구간 = 쿨다운
    private static func speedKinds(_ acts: [HKWorkoutActivity]) -> [IntervalSegment.Kind] {
        let sp = acts.map { speed($0) }
        let med = sp.sorted()[sp.count / 2]
        var ks: [IntervalSegment.Kind] = sp.map { $0 > med * 1.2 ? .work : .recovery }
        // 마지막 느린 구간의 길이가 다른 회복과 20% 넘게 다르면 쿨다운
        let recDur = acts.indices.filter { ks[$0] == .recovery }.dropLast().map { acts[$0].duration }.sorted()
        if let last = ks.indices.last, ks[last] == .recovery, !recDur.isEmpty {
            let m = recDur[recDur.count / 2]
            if abs(acts[last].duration - m) > m * 0.2 { ks[last] = .cooldown }
        }
        return ks
    }

    private static func speed(_ a: HKWorkoutActivity) -> Double {
        let m = sum(a, .distanceWalkingRunning, .meter())
        return a.duration > 0 ? m / a.duration : 0
    }

    private static func segment(_ a: HKWorkoutActivity, kind: IntervalSegment.Kind,
                                round: Int, start: Date) -> IntervalSegment {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let mps = HKUnit.meter().unitDivided(by: .second())
        let ok = a.metadata?["WOIntervalStepSuccessful"]
        let completed = (ok as? NSNumber)?.boolValue ?? (ok as? String).map { $0 == "1" } ?? (kind != .cooldown)
        return IntervalSegment(
            kindRaw: kind.rawValue, round: round,
            start: a.startDate.timeIntervalSince(start), seconds: a.duration,
            completed: completed,
            meters: sum(a, .distanceWalkingRunning, .meter()),
            avgHR: avg(a, .heartRate, bpm), maxHR: max(a, .heartRate, bpm),
            avgPower: avg(a, .runningPower, .watt()), maxPower: max(a, .runningPower, .watt()),
            avgSpeed: avg(a, .runningSpeed, mps), maxSpeed: max(a, .runningSpeed, mps),
            steps: sum(a, .stepCount, .count()),
            avgStride: avg(a, .runningStrideLength, .meter()),
            avgGCT: avg(a, .runningGroundContactTime, .secondUnit(with: .milli)),
            avgVertOsc: avg(a, .runningVerticalOscillation, .meterUnit(with: .centi)))
    }

    private static func stat(_ a: HKWorkoutActivity, _ id: HKQuantityTypeIdentifier) -> HKStatistics? {
        a.statistics(for: HKQuantityType(id))
    }
    private static func sum(_ a: HKWorkoutActivity, _ id: HKQuantityTypeIdentifier, _ u: HKUnit) -> Double {
        stat(a, id)?.sumQuantity()?.doubleValue(for: u) ?? 0
    }
    private static func avg(_ a: HKWorkoutActivity, _ id: HKQuantityTypeIdentifier, _ u: HKUnit) -> Double {
        stat(a, id)?.averageQuantity()?.doubleValue(for: u) ?? 0
    }
    private static func max(_ a: HKWorkoutActivity, _ id: HKQuantityTypeIdentifier, _ u: HKUnit) -> Double {
        stat(a, id)?.maximumQuantity()?.doubleValue(for: u) ?? 0
    }

    private static func seconds(_ g: WorkoutGoal) -> Double? {
        if case .time(let v, let u) = g {
            return Measurement(value: v, unit: u).converted(to: .seconds).value
        }
        return nil
    }

    // MARK: - 워밍업

    /// 본운동 직전(60분 안)에 끝난 단일 러닝을 찾는다.
    private static func warmup(before w: HKWorkout) async -> WarmupRun? {
        let pred = HKQuery.predicateForSamples(withStart: w.startDate.addingTimeInterval(-3 * 3600),
                                               end: w.startDate, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let found: [HKWorkout] = await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred,
                                  limit: 20, sortDescriptors: [sort]) { _, s, _ in
                c.resume(returning: (s as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        guard let ww = found.first(where: {
            $0.uuid != w.uuid && $0.workoutActivityType == .running && !isInterval($0)
                && $0.endDate <= w.startDate.addingTimeInterval(60)
                && w.startDate.timeIntervalSince($0.endDate) <= warmupWindow
        }) else { return nil }

        let tele: Telemetry = await withCheckedContinuation { c in
            DispatchQueue.main.async {
                HealthImporter.shared.load(ww) { t, _ in c.resume(returning: t) }
            }
        }
        var pauses: [WarmupRun.Pause] = []
        var from: Double?
        for e in (ww.workoutEvents ?? []).sorted(by: { $0.dateInterval.start < $1.dateInterval.start }) {
            let t = e.dateInterval.start.timeIntervalSince(ww.startDate)
            switch e.type {
            case .pause, .motionPaused: if from == nil { from = t }
            case .resume, .motionResumed:
                if let f = from { pauses.append(.init(from: f, to: t)); from = nil }
            default: break
            }
        }
        if let f = from { pauses.append(.init(from: f, to: ww.endDate.timeIntervalSince(ww.startDate))) }

        return WarmupRun(healthKitUUID: ww.uuid.uuidString,
                         startAt: ww.startDate, endAt: ww.endDate,
                         seconds: ww.duration,
                         meters: tele.watchDistance, activeKcal: tele.activeKcal,
                         pauses: pauses, hr: tele.hr, speed: tele.speed, power: tele.power)
    }
}
