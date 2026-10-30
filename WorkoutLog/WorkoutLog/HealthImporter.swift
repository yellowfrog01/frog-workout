import Foundation
import HealthKit
import CoreLocation
import Observation

/// 애플 "운동" 앱 등이 HealthKit 에 저장한 워크아웃을 우리 앱으로 가져온다.
@Observable
final class HealthImporter {
    static let shared = HealthImporter()
    private let store = HKHealthStore()

    var available = HKHealthStore.isHealthDataAvailable()
    var busy = false
    var note: String = ""
    var found: [Candidate] = []

    struct Candidate: Identifiable {
        let id: UUID
        let workout: HKWorkout
        var start: Date { workout.startDate }
        var seconds: Int { Int(workout.duration) }
        var activity: String { HealthImporter.label(workout.workoutActivityType) }
        var sourceName: String { workout.sourceRevision.source.name }
        var distanceKm: Double {
            (workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0) / 1000
        }
        var kcal: Int {
            Int(workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
        }
    }

    private init() {}

    private var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        for id: HKQuantityTypeIdentifier in [
            .heartRate, .activeEnergyBurned, .basalEnergyBurned,
            .distanceWalkingRunning, .stepCount,
            .runningSpeed, .runningPower, .runningStrideLength,
            .runningVerticalOscillation, .runningGroundContactTime
        ] { s.insert(HKQuantityType(id)) }
        return s
    }

    func authorize(_ done: @escaping (Bool) -> Void) {
        guard available else { note = "건강 데이터를 지원하지 않습니다"; done(false); return }
        store.requestAuthorization(toShare: [], read: readTypes) { ok, err in
            DispatchQueue.main.async {
                if let err { self.note = err.localizedDescription }
                done(ok)
            }
        }
    }

    /// 최근 N일 워크아웃 조회
    func scan(days: Int = 14) {
        busy = true; note = ""
        authorize { ok in
            guard ok else { self.busy = false; self.note = "건강 접근 권한이 필요합니다"; return }
            let from = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
            let pred = HKQuery.predicateForSamples(withStart: from, end: .now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let q = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: pred,
                                  limit: 50, sortDescriptors: [sort]) { _, samples, err in
                DispatchQueue.main.async {
                    self.busy = false
                    if let err { self.note = err.localizedDescription; return }
                    let ws = (samples as? [HKWorkout]) ?? []
                    self.found = ws.map { Candidate(id: $0.uuid, workout: $0) }
                    if self.found.isEmpty { self.note = "최근 \(days)일 워크아웃이 없습니다" }
                }
            }
            self.store.execute(q)
        }
    }

    // MARK: - 상세 수집

    /// 워크아웃 하나를 Telemetry + 경로로 변환
    func load(_ w: HKWorkout, done: @escaping (Telemetry, [RoutePoint]) -> Void) {
        var tele = Telemetry()
        let start = w.startDate
        let group = DispatchGroup()

        func series(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit,
                    _ assign: @escaping ([MetricPoint]) -> Void) {
            group.enter()
            let type = HKQuantityType(id)
            let pred = HKQuery.predicateForObjects(from: w)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: type, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, s, _ in
                let pts = (s as? [HKQuantitySample] ?? []).map {
                    MetricPoint(t: $0.startDate.timeIntervalSince(start),
                                v: $0.quantity.doubleValue(for: unit))
                }
                DispatchQueue.main.async { assign(pts); group.leave() }
            }
            store.execute(q)
        }

        let bpm = HKUnit.count().unitDivided(by: .minute())
        series(.heartRate, bpm) { tele.hr = $0 }
        series(.runningSpeed, .meter().unitDivided(by: .second())) { tele.speed = $0 }
        series(.runningPower, .watt()) { tele.power = $0 }
        series(.runningStrideLength, .meter()) { tele.strideLength = $0 }
        series(.runningVerticalOscillation, .meterUnit(with: .centi)) { tele.verticalOscillation = $0 }
        series(.runningGroundContactTime, .secondUnit(with: .milli)) { tele.groundContactTime = $0 }

        // 누적값
        tele.activeKcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        tele.basalKcal = w.statistics(for: HKQuantityType(.basalEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        tele.watchDistance = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?.doubleValue(for: .meter()) ?? 0
        tele.steps = Int(w.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?.doubleValue(for: .count()) ?? 0)

        // 경로
        var route: [RoutePoint] = []
        group.enter()
        let rq = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(),
                                       predicate: HKQuery.predicateForObjects(from: w),
                                       anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            guard let self, let routes = samples as? [HKWorkoutRoute], let first = routes.first else {
                DispatchQueue.main.async { group.leave() }; return
            }
            var locs: [CLLocation] = []
            let lq = HKWorkoutRouteQuery(route: first) { _, batch, finished, _ in
                if let batch { locs.append(contentsOf: batch) }
                guard finished else { return }
                let pts = locs.map {
                    RoutePoint(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude,
                               t: $0.timestamp.timeIntervalSince(start))
                }
                DispatchQueue.main.async { route = pts; group.leave() }
            }
            self.store.execute(lq)
        }
        store.execute(rq)

        group.notify(queue: .main) {
            // 고도는 경로에서
            tele.altitude = route.enumerated().map { MetricPoint(t: $1.t, v: 0) }
            tele.gpsDistance = RouteAnalysis.routeDistance(route)
            let e = RouteAnalysis.elevation(tele.altitude)
            tele.elevationGain = e.gain; tele.elevationLoss = e.loss
            tele.splits = RouteAnalysis.splits(route: route, hr: tele.hr,
                                               totalMeters: tele.distance)
            done(tele, route)
        }
    }

    static func label(_ t: HKWorkoutActivityType) -> String {
        switch t {
        case .running: "달리기"
        case .walking: "걷기"
        case .cycling: "자전거"
        case .hiking: "하이킹"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "근력"
        case .highIntensityIntervalTraining: "HIIT"
        case .swimming: "수영"
        case .elliptical: "일립티컬"
        case .rowing: "로잉"
        default: "운동"
        }
    }
}
