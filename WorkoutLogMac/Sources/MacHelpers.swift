import SwiftUI

extension Session {
    /// 목록·달력용 제목: 근력 / 러닝(일반) / 인터벌 / 기타 운동 이름
    var macTitle: String {
        switch kind {
        case .strength: return bodyPart?.label.appending(" 근력") ?? "근력"
        case .interval: return cardioMode == .steady ? "러닝" : "인터벌"
        case .activity: return activityName ?? WorkoutKind.activity.label
        }
    }
    var macSymbol: String {
        switch kind {
        case .strength: return WorkoutKind.strength.symbol
        case .interval: return cardioMode == .steady ? "figure.run" : "stopwatch.fill"
        case .activity: return ActivityPreset.symbol(for: activityName ?? "")
        }
    }
    var macTint: Color {
        switch kind {
        case .strength: Palette.strength
        case .interval: Palette.interval
        case .activity: Palette.activity
        }
    }
    /// 목록 한 줄 요약
    var macSummary: String {
        var parts: [String] = []
        switch kind {
        case .strength:
            if !lifts.isEmpty { parts.append("\(lifts.count)종목") }
            if totalVolume > 0 { parts.append("\(Int(totalVolume))kg") }
        case .interval, .activity:
            if distanceKm > 0.01 { parts.append(String(format: "%.2fkm", distanceKm)) }
            if let p = avgPace, distanceKm > 0.01 { parts.append("\(p.clockString)/km") }
        }
        if let d = durationSeconds, d > 0 { parts.append(d.hmsString) }
        return parts.joined(separator: " · ")
    }
}
