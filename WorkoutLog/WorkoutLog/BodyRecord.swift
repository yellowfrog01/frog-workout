import Foundation
import SwiftData

/// 체성분 측정 1회. 인바디 CSV 또는 HealthKit 에서 채운다.
@Model
final class BodyRecord {
    var date: Date = Date()
    var source: String = ""          // "InBody" / "HealthKit"
    var deviceCode: String?

    var weight: Double = 0           // kg
    var skeletalMuscle: Double?      // 골격근량 kg
    var bodyFatMass: Double?         // 체지방량 kg
    var bmi: Double?
    var bodyFatPercent: Double?
    var bmr: Double?                 // 기초대사량 kcal
    var score: Double?               // 인바디 점수
    var abdominalFatRatio: Double?   // 복부지방률
    var visceralLevel: Double?       // 내장지방레벨
    var totalWater: Double?          // 체수분 L
    var protein: Double?             // kg
    var mineral: Double?             // kg
    var smi: Double?                 // kg/m²

    /// 중복 방지용 (측정 시각 문자열)
    var key: String = ""

    init(date: Date, source: String, key: String) {
        self.date = date
        self.source = source
        self.key = key
    }

    var fatFreeMass: Double? {
        guard let f = bodyFatMass else { return nil }
        return weight - f
    }
}

// MARK: - 인바디 CSV 파서

enum InBodyCSV {
    /// 인바디 앱이 내보낸 CSV 를 파싱한다. 값이 "-" 이면 nil.
    static func parse(_ raw: String) -> [BodyRecord] {
        // BOM 제거 — 인바디 앱 CSV 는 UTF-8 BOM 으로 시작한다
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        var lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] }

        let header = split(lines.removeFirst())
        // 헤더에 단위·괄호가 붙으므로 포함 여부로 찾는다
        func idx(_ name: String) -> Int? { header.firstIndex { $0.contains(name) } }

        let iDate   = idx("날짜")
        let iDevice = idx("측정장비")
        let iW      = idx("체중")
        let iSM     = idx("골격근량")
        let iFM     = idx("체지방량")
        let iBMI    = idx("BMI")
        let iFP     = idx("체지방률")
        let iBMR    = idx("기초대사량")
        let iScore  = idx("인바디점수")
        let iAFR    = idx("복부지방률")
        let iVis    = idx("내장지방레벨")
        let iTW     = idx("체수분")
        let iPro    = idx("단백질")
        let iMin    = idx("무기질")
        let iSMI    = idx("SMI")

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMddHHmmss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current

        var out: [BodyRecord] = []
        for line in lines {
            let f = split(line)
            guard let di = iDate, di < f.count, let d = fmt.date(from: f[di]) else { continue }
            func num(_ i: Int?) -> Double? {
                guard let i, i < f.count else { return nil }
                let v = f[i]
                guard v != "-", !v.isEmpty else { return nil }
                return Double(v)
            }
            let r = BodyRecord(date: d, source: "InBody", key: f[di])
            r.deviceCode = iDevice.flatMap { $0 < f.count ? f[$0] : nil }
            r.weight            = num(iW) ?? 0
            r.skeletalMuscle    = num(iSM)
            r.bodyFatMass       = num(iFM)
            r.bmi               = num(iBMI)
            r.bodyFatPercent    = num(iFP)
            r.bmr               = num(iBMR)
            r.score             = num(iScore)
            r.abdominalFatRatio = num(iAFR)
            r.visceralLevel     = num(iVis)
            r.totalWater        = num(iTW)
            r.protein           = num(iPro)
            r.mineral           = num(iMin)
            r.smi               = num(iSMI)
            if r.weight > 0 { out.append(r) }
        }
        return out.sorted { $0.date < $1.date }
    }

    private static func split(_ line: String) -> [String] {
        var junk = CharacterSet.whitespacesAndNewlines
        junk.insert(charactersIn: "\"'\u{FEFF}\r")
        return line.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: junk)
        }
    }
}
