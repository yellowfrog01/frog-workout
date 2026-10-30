import Foundation
import CryptoKit

/// SwiftData 모델 ↔ Supabase 행(JSON 딕셔너리) 변환.
///
/// 행에는 `updated_at` 을 넣지 않는다 (해시 계산용). 업로드 직전에 SyncService 가 붙인다.
/// `user_id` 도 보내지 않는다 (DB 기본값 auth.uid()).
///
/// telemetry 컬럼 선택: 스키마에 경로·심박(routeData/hrData)·watchSessionID 컬럼이 없으므로
/// telemetry jsonb 에 봉투 객체 `{"telemetry": Telemetry, "route": [RoutePoint],
/// "hr": [HRPoint], "watchSessionID": String}` 를 넣는다 (값이 있는 키만). 모두 없으면 null.
/// 복원은 이 봉투를 그대로 풀어 각 속성에 되돌린다.
@MainActor
enum SyncMapper {
    // MARK: 날짜

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 밀리초 단위 ISO8601 (UTC)
    static func iso(_ d: Date) -> String { isoFrac.string(from: d) }

    /// 서버 timestamptz 문자열 → Date. 소수 자릿수(없음~6자리)를 3자리로 맞춘 뒤 해석.
    static func date(_ any: Any?) -> Date? {
        guard var s = any as? String else { return nil }
        if let r = s.range(of: #"\.\d+"#, options: .regularExpression) {
            let digits = s[r].dropFirst()
            let fixed = String((digits + "000").prefix(3))
            s.replaceSubrange(r, with: "." + fixed)
        } else if let r = s.range(of: #"(Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) {
            s.replaceSubrange(r, with: ".000" + s[r])
        }
        return isoFrac.date(from: s)
    }

    // MARK: 해시

    /// 행(updated_at 제외) 내용 해시. 키 정렬로 항상 같은 바이트.
    static func hash(_ row: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: 값 도우미

    private static func null(_ v: Any?) -> Any { v ?? NSNull() }
    private static func finite(_ d: Double) -> Double { d.isFinite ? d : 0 }
    private static func finite(_ d: Double?) -> Any { d.map { $0.isFinite ? $0 : 0 } ?? NSNull() }

    /// Codable → JSON 객체 (키 정렬). 실패하면 nil.
    private static func obj<T: Encodable>(_ v: T) -> Any? {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        guard let d = try? e.encode(v) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }

    /// JSON 객체 → Codable. null/형식 불일치면 nil.
    private static func decode<T: Decodable>(_ any: Any?) -> T? {
        guard let any, !(any is NSNull), JSONSerialization.isValidJSONObject(any),
              let d = try? JSONSerialization.data(withJSONObject: any) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    private static func str(_ any: Any?) -> String? { any as? String }
    private static func dbl(_ any: Any?) -> Double? { (any as? NSNumber)?.doubleValue }
    private static func int(_ any: Any?) -> Int? { (any as? NSNumber)?.intValue }
    static func uuid(_ any: Any?) -> UUID? { (any as? String).flatMap(UUID.init(uuidString:)) }

    private static func put(_ d: inout [String: Any], _ k: String, _ v: Any?) {
        if let v { d[k] = v }
    }

    // MARK: Session

    static func sessionRow(_ s: Session, id: UUID) -> [String: Any] {
        [
            "id": id.uuidString.lowercased(),
            "date": iso(s.date),
            "kind": s.kindRaw,
            "condition": s.conditionRaw,
            "body_part": null(s.bodyPartRaw),
            "note": s.note,
            "start_at": null(s.startAt.map { iso($0) }),
            "end_at": null(s.endAt.map { iso($0) }),
            "cardio_mode": null(s.cardioModeRaw),
            "activity_name": null(s.activityName),
            "distance_m": finite(s.distanceMeters),
            "lifts": null((s.liftsData?.isEmpty ?? true) ? nil : obj(s.liftsData)),
            "interval": null(s.interval.flatMap { obj($0) }),
            "interval_detail": null(s.intervalDetailData.flatMap { try? JSONSerialization.jsonObject(with: $0) }),
            "telemetry": null(telemetryEnvelope(s)),
            "health_kit_uuid": null(s.healthKitUUID),
            "deleted": false,
        ]
    }

    private static func telemetryEnvelope(_ s: Session) -> Any? {
        var e: [String: Any] = [:]
        put(&e, "telemetry", s.telemetryData.flatMap { obj($0) })
        put(&e, "route", s.routeData.flatMap { obj($0) })
        put(&e, "hr", s.hrData.flatMap { obj($0) })
        put(&e, "watchSessionID", s.watchSessionID)
        return e.isEmpty ? nil : e
    }

    /// 서버 행 → Session (sessionRow 의 역변환)
    static func session(from r: [String: Any]) -> Session? {
        guard let id = uuid(r["id"]), let d = date(r["date"]) else { return nil }
        let s = Session(date: d)
        s.syncID = id
        applySession(r, to: s)
        return s
    }

    /// 서버 행 값을 기존 Session 에 그대로 덮어쓴다 (SwiftData 객체 동일성 유지용).
    static func applySession(_ r: [String: Any], to s: Session) {
        if let d = date(r["date"]) { s.date = d }
        s.kindRaw = str(r["kind"]) ?? WorkoutKind.strength.rawValue
        s.conditionRaw = str(r["condition"]) ?? Condition.normal.rawValue
        s.bodyPartRaw = str(r["body_part"])
        s.note = str(r["note"]) ?? ""
        s.startAt = date(r["start_at"])
        s.endAt = date(r["end_at"])
        s.cardioModeRaw = str(r["cardio_mode"])
        s.activityName = str(r["activity_name"])
        s.distanceMeters = dbl(r["distance_m"]) ?? 0
        s.liftsData = decode(r["lifts"]) as [LiftEntry]?
        s.interval = decode(r["interval"]) as IntervalEntry?
        if let detail = r["interval_detail"], !(detail is NSNull), JSONSerialization.isValidJSONObject(detail) {
            s.intervalDetailData = try? JSONSerialization.data(withJSONObject: detail)
        } else {
            s.intervalDetailData = nil
        }
        s.healthKitUUID = str(r["health_kit_uuid"])
        let env = r["telemetry"] as? [String: Any]
        s.telemetryData = decode(env?["telemetry"]) as Telemetry?
        s.routeData = decode(env?["route"]) as [RoutePoint]?
        s.hrData = decode(env?["hr"]) as [HRPoint]?
        s.watchSessionID = str(env?["watchSessionID"])
    }

    // MARK: BodyRecord

    static func bodyRow(_ b: BodyRecord, id: UUID) -> [String: Any] {
        var data: [String: Any] = [
            "source": b.source,
            "key": b.key,
            "weight": finite(b.weight),
        ]
        put(&data, "deviceCode", b.deviceCode)
        let optionals: [(String, Double?)] = [
            ("skeletalMuscle", b.skeletalMuscle), ("bodyFatMass", b.bodyFatMass), ("bmi", b.bmi),
            ("bodyFatPercent", b.bodyFatPercent), ("bmr", b.bmr), ("score", b.score),
            ("abdominalFatRatio", b.abdominalFatRatio), ("visceralLevel", b.visceralLevel),
            ("totalWater", b.totalWater), ("protein", b.protein), ("mineral", b.mineral), ("smi", b.smi),
        ]
        for (k, v) in optionals { if let v { data[k] = finite(v) } }
        return ["id": id.uuidString.lowercased(), "date": iso(b.date), "data": data, "deleted": false]
    }

    static func body(from r: [String: Any]) -> BodyRecord? {
        guard let id = uuid(r["id"]), let d = date(r["date"]), let data = r["data"] as? [String: Any] else { return nil }
        let b = BodyRecord(date: d, source: str(data["source"]) ?? "", key: str(data["key"]) ?? "")
        b.syncID = id
        applyBody(r, to: b)
        return b
    }

    /// 서버 행 값을 기존 BodyRecord 에 그대로 덮어쓴다.
    static func applyBody(_ r: [String: Any], to b: BodyRecord) {
        guard let data = r["data"] as? [String: Any] else { return }
        if let d = date(r["date"]) { b.date = d }
        b.source = str(data["source"]) ?? ""
        b.key = str(data["key"]) ?? ""
        b.deviceCode = str(data["deviceCode"])
        b.weight = dbl(data["weight"]) ?? 0
        b.skeletalMuscle = dbl(data["skeletalMuscle"])
        b.bodyFatMass = dbl(data["bodyFatMass"])
        b.bmi = dbl(data["bmi"])
        b.bodyFatPercent = dbl(data["bodyFatPercent"])
        b.bmr = dbl(data["bmr"])
        b.score = dbl(data["score"])
        b.abdominalFatRatio = dbl(data["abdominalFatRatio"])
        b.visceralLevel = dbl(data["visceralLevel"])
        b.totalWater = dbl(data["totalWater"])
        b.protein = dbl(data["protein"])
        b.mineral = dbl(data["mineral"])
        b.smi = dbl(data["smi"])
    }

    // MARK: PlannedWorkout

    static func plannedRow(_ p: PlannedWorkout, id: UUID) -> [String: Any] {
        var data: [String: Any] = [
            "kind": p.kindRaw,
            "title": p.title,
            "week": p.week,
            "note": p.note,
            "createdAt": iso(p.createdAt),
        ]
        put(&data, "programID", p.programID)
        put(&data, "programTitle", p.programTitle)
        put(&data, "lifts", (p.liftsData?.isEmpty ?? true) ? nil : obj(p.liftsData))
        put(&data, "interval", p.interval.flatMap { obj($0) })
        put(&data, "cardioMode", p.cardioModeRaw)
        put(&data, "cardioMinutes", p.cardioMinutes)
        put(&data, "intensityPct", p.intensityPct)
        put(&data, "startedAt", p.startedAt.map { iso($0) })
        return ["id": id.uuidString.lowercased(), "date": iso(p.date), "data": data, "deleted": false]
    }

    static func planned(from r: [String: Any]) -> PlannedWorkout? {
        guard let id = uuid(r["id"]), let d = date(r["date"]), let data = r["data"] as? [String: Any] else { return nil }
        let kind = str(data["kind"]).flatMap(WorkoutKind.init(rawValue:)) ?? .strength
        let p = PlannedWorkout(date: d, kind: kind, title: str(data["title"]) ?? "")
        p.syncID = id
        applyPlanned(r, to: p)
        return p
    }

    /// 서버 행 값을 기존 PlannedWorkout 에 그대로 덮어쓴다.
    static func applyPlanned(_ r: [String: Any], to p: PlannedWorkout) {
        guard let data = r["data"] as? [String: Any] else { return }
        if let d = date(r["date"]) { p.date = d }    // init 이 자정으로 맞추므로 서버 값을 그대로 복원
        p.kindRaw = str(data["kind"]) ?? WorkoutKind.strength.rawValue
        p.title = str(data["title"]) ?? ""
        p.programID = str(data["programID"])
        p.programTitle = str(data["programTitle"])
        p.week = int(data["week"]) ?? 1
        p.liftsData = decode(data["lifts"]) as [LiftEntry]?
        p.interval = decode(data["interval"]) as IntervalEntry?
        p.cardioModeRaw = str(data["cardioMode"])
        p.cardioMinutes = int(data["cardioMinutes"])
        p.intensityPct = int(data["intensityPct"])
        p.note = str(data["note"]) ?? ""
        p.startedAt = date(data["startedAt"])
        p.createdAt = date(data["createdAt"]) ?? p.createdAt
    }
}
