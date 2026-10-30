import Foundation
import SwiftData
import HealthKit

/// 애플이 계산해둔 파생 지표. HealthKit 에서 읽어온다.
@Model
final class Vital {
    var date: Date = Date()
    var kindRaw: String = ""
    var value: Double = 0
    var source: String = ""
    var key: String = ""

    init(date: Date, kind: VitalKind, value: Double, source: String, key: String) {
        self.date = date
        self.kindRaw = kind.rawValue
        self.value = value
        self.source = source
        self.key = key
    }
    var kind: VitalKind { VitalKind(rawValue: kindRaw) ?? .vo2Max }
}

enum VitalKind: String, CaseIterable, Identifiable {
    case vo2Max, restingHR, hrv, hrRecovery, walkingHR, respiratory, oxygen, wristTemp

    var id: String { rawValue }
    var label: String {
        switch self {
        case .vo2Max:      "심폐 체력"
        case .restingHR:   "안정시 심박"
        case .hrv:         "심박 변이도"
        case .hrRecovery:  "심박 회복"
        case .walkingHR:   "보행 심박"
        case .respiratory: "호흡수"
        case .oxygen:      "혈중 산소"
        case .wristTemp:   "손목 온도"
        }
    }
    var unit: String {
        switch self {
        case .vo2Max:      "ml/kg·min"
        case .restingHR, .hrRecovery, .walkingHR: "bpm"
        case .hrv:         "ms"
        case .respiratory: "회/분"
        case .oxygen:      "%"
        case .wristTemp:   "℃"
        }
    }
    var identifier: HKQuantityTypeIdentifier {
        switch self {
        case .vo2Max:      .vo2Max
        case .restingHR:   .restingHeartRate
        case .hrv:         .heartRateVariabilitySDNN
        case .hrRecovery:  .heartRateRecoveryOneMinute
        case .walkingHR:   .walkingHeartRateAverage
        case .respiratory: .respiratoryRate
        case .oxygen:      .oxygenSaturation
        case .wristTemp:   .appleSleepingWristTemperature
        }
    }
    var hkUnit: HKUnit {
        switch self {
        case .vo2Max:
            HKUnit(from: "ml/kg*min")
        case .restingHR, .hrRecovery, .walkingHR, .respiratory:
            HKUnit.count().unitDivided(by: .minute())
        case .hrv:
            HKUnit.secondUnit(with: .milli)
        case .oxygen:
            HKUnit.percent()
        case .wristTemp:
            HKUnit.degreeCelsius()
        }
    }
    /// 높을수록 좋은 지표인가
    var higherIsBetter: Bool {
        switch self {
        case .vo2Max, .hrv, .hrRecovery, .oxygen: true
        default: false
        }
    }
}

enum VitalsImporter {
    /// 전 지표를 HealthKit 에서 읽는다. done(가져온 건수, 발견된 종류)
    static func importAll(existing: Set<String>,
                          insert: @escaping (Vital) -> Void,
                          done: @escaping (Int, [String]) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { done(0, []); return }
        let store = HKHealthStore()
        let types = Set(VitalKind.allCases.map { HKQuantityType($0.identifier) as HKObjectType })
        store.requestAuthorization(toShare: [], read: types) { ok, _ in
            guard ok else { DispatchQueue.main.async { done(0, []) }; return }
            var n = 0
            var kinds: [String] = []
            let group = DispatchGroup()
            for k in VitalKind.allCases {
                group.enter()
                let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let q = HKSampleQuery(sampleType: HKQuantityType(k.identifier), predicate: nil,
                                      limit: 400, sortDescriptors: [sort]) { _, samples, _ in
                    let ss = (samples as? [HKQuantitySample]) ?? []
                    DispatchQueue.main.async {
                        if !ss.isEmpty { kinds.append("\(k.label) \(ss.count)") }
                        for s in ss {
                            let key = "\(k.rawValue)-\(s.uuid.uuidString)"
                            guard !existing.contains(key) else { continue }
                            var v = s.quantity.doubleValue(for: k.hkUnit)
                            if k == .oxygen { v *= 100 }
                            insert(Vital(date: s.startDate, kind: k, value: v,
                                         source: s.sourceRevision.source.name, key: key))
                            n += 1
                        }
                        group.leave()
                    }
                }
                store.execute(q)
            }
            group.notify(queue: .main) { done(n, kinds.sorted()) }
        }
    }
}
