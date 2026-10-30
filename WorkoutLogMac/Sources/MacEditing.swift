import SwiftUI
import SwiftData

// MARK: - 숫자 입력 (파싱 실패 시 이전 값 유지)

/// 소수 입력. 비어 있으면 0, 파싱 실패/범위 밖이면 이전 값을 유지한다.
private struct MacDoubleField: View {
    @Binding var value: Double
    var width: CGFloat = 64
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.rounded(15, .semibold)).monospacedDigit()
            .foregroundStyle(.white)
            .focused($focused)
            .frame(width: width)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 8))
            .onAppear { text = value.trimmed }
            .onChange(of: text) {
                let t = text.replacingOccurrences(of: ",", with: ".")
                if t.isEmpty { value = 0 }
                else if let v = Double(t), v >= 0, v <= 400 { value = v }
            }
            .onChange(of: value) { if !focused { text = value.trimmed } }
            .onChange(of: focused) { if !focused { text = value.trimmed } }
    }
}

/// 정수 입력. 파싱 실패/범위 밖이면 이전 값 유지.
private struct MacIntField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var width: CGFloat = 52
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.rounded(15, .semibold)).monospacedDigit()
            .foregroundStyle(.white)
            .focused($focused)
            .frame(width: width)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: .rect(cornerRadius: 8))
            .onAppear { text = String(value) }
            .onChange(of: text) {
                if let v = Int(text.trimmingCharacters(in: .whitespaces)), range.contains(v) { value = v }
            }
            .onChange(of: value) { if !focused { text = String(value) } }
            .onChange(of: focused) { if !focused { text = String(value) } }
    }
}

// MARK: - 종목 편집기

/// 종목 카드 목록. 이름·BW/한쪽·세트별 무게/횟수·RIR·목표 휴식을 고친다.
struct LiftsEditor: View {
    @Binding var lifts: [LiftEntry]

    var body: some View {
        VStack(spacing: 12) {
            ForEach($lifts) { $lift in
                MacLiftCard(lift: $lift) {
                    withAnimation(.snappy) { lifts.removeAll { $0.id == lift.id } }
                }
            }

            Menu {
                ForEach(LiftPreset.all, id: \.name) { p in
                    Button(p.name) {
                        lifts.append(LiftEntry(name: p.name, weight: p.weight, sets: p.sets, reps: p.reps,
                                               bw: p.bw ? true : nil))
                    }
                }
                Divider()
                Button("직접 입력 (빈 종목)") {
                    lifts.append(LiftEntry(name: "", weight: 0, sets: 3, reps: 8))
                }
            } label: {
                Label("종목 추가", systemImage: "plus.circle.fill")
                    .font(.rounded(15, .semibold))
                    .foregroundStyle(Palette.strength)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.strength.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }
}

private struct MacLiftCard: View {
    @Binding var lift: LiftEntry
    let onDelete: () -> Void

    private var restBinding: Binding<Int> {
        Binding(get: { lift.restSec ?? 0 },
                set: { lift.restSec = $0 > 0 ? $0 : nil })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("종목 이름", text: $lift.name)
                    .textFieldStyle(.plain)
                    .font(.rounded(16, .bold))
                    .foregroundStyle(.white)
                Toggle("BW", isOn: Binding(
                    get: { lift.isBW },
                    set: { on in
                        lift.bw = on ? true : nil
                        if on { lift.weight = 0; lift.setWeights = nil }
                    }))
                    .toggleStyle(.button)
                    .tint(Palette.strength)
                Toggle("한쪽", isOn: Binding(
                    get: { lift.isUnilateral },
                    set: { lift.uni = $0 ? true : nil }))
                    .toggleStyle(.button)
                    .tint(Palette.strength)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.98, green: 0.35, blue: 0.31))
                }
                .buttonStyle(.plain)
                .help("종목 삭제")
            }

            ForEach(0..<max(lift.sets, 0), id: \.self) { i in
                HStack(spacing: 8) {
                    Text("\(i + 1)세트")
                        .font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                        .frame(width: 48, alignment: .leading)
                    if lift.isBW { Text("+").font(.rounded(13, .medium)).foregroundStyle(Palette.dim) }
                    MacDoubleField(value: Binding(get: { lift.weightAt(i) },
                                                  set: { lift.setWeight($0, at: i) }))
                    Text("kg").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                    Text("×").foregroundStyle(Palette.dimmer)
                    MacIntField(value: Binding(get: { repsAt(i) },
                                               set: { setReps($0, at: i) }),
                                range: 0...999)
                    Text("회").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                    Spacer()
                    if lift.sets > 1 {
                        Button {
                            withAnimation(.snappy) { lift.removeSet(at: i) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("이 세트 삭제")
                    }
                }
            }

            HStack(spacing: 16) {
                Button {
                    withAnimation(.snappy) { lift.resizeSets(lift.sets + 1) }
                } label: {
                    Label("세트 추가", systemImage: "plus")
                        .font(.rounded(13, .semibold))
                        .foregroundStyle(Palette.strength)
                }
                .buttonStyle(.plain)
                .disabled(lift.sets >= 12)

                Spacer()

                Text("목표 휴식").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                MacIntField(value: restBinding, range: 0...3600, width: 56)
                Text("초").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
            }

            HStack(spacing: 6) {
                Text("RIR").font(.rounded(13, .semibold)).foregroundStyle(Palette.dim)
                    .frame(width: 48, alignment: .leading)
                rirButton(nil, "없음")
                ForEach(0...4, id: \.self) { v in rirButton(v, v == 4 ? "4+" : "\(v)") }
                Spacer()
            }
        }
        .padding(14)
        .background(Palette.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardStroke, lineWidth: 1))
    }

    private func rirButton(_ v: Int?, _ title: String) -> some View {
        let on = lift.rir == v
        return Button { lift.rir = v } label: {
            Text(title)
                .font(.rounded(13, .bold))
                .foregroundStyle(on ? .black : .white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(on ? Palette.strength : Color.white.opacity(0.08), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func repsAt(_ i: Int) -> Int {
        let l = lift.repsList
        return i < l.count ? l[i] : lift.reps
    }

    /// 세트별 방식으로 전환한 뒤 i번째 횟수만 바꾼다.
    private func setReps(_ v: Int, at i: Int) {
        if !lift.isVaried { lift.setVaried(true) }
        var l = lift.repsList
        guard i < l.count else { return }
        l[i] = v
        lift.setReps = l
    }
}

// MARK: - 시각 합성 (새벽 4시 규칙)

private enum MacTime {
    /// day 의 날짜 + time 의 시·분. 새벽 4시 전이면 앱의 기록 날짜 규칙상 전날로 잡히므로 다음 날로 넘긴다.
    static func startAt(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let h = cal.component(.hour, from: time), m = cal.component(.minute, from: time)
        let s = cal.date(bySettingHour: h, minute: m, second: 0, of: day) ?? day
        return h < Session.dayCutoffHour ? cal.date(byAdding: .day, value: 1, to: s) ?? s : s
    }

    /// 소요 분. 종료가 시작 이하이면 다음 날 종료로 본다.
    static func minutes(from start: Date, to end: Date) -> Int {
        let cal = Calendar.current
        let s = cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start)
        let e = cal.component(.hour, from: end) * 60 + cal.component(.minute, from: end)
        return e > s ? e - s : e - s + 24 * 60
    }
}

// MARK: - 하단 버튼 바

private struct MacSheetFooter: View {
    let tint: Color
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Palette.cardStroke)
            HStack {
                Spacer()
                Button("취소", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("저장", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(14)
        }
        .tint(tint)
    }
}

// MARK: - 새 기록

private enum NewRecordMode: String, CaseIterable, Identifiable {
    case strength, activity
    var id: String { rawValue }
    var label: String { self == .strength ? "근력" : "기타 운동" }
    var tint: Color { self == .strength ? Palette.strength : Palette.activity }
}

struct NewRecordSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var mode: NewRecordMode = .strength
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var condition: Condition = .normal
    @State private var note = ""
    // 근력
    @State private var bodyPart: BodyPart?
    @State private var lifts: [LiftEntry] = []
    // 기타 운동
    @State private var preset: String?
    @State private var custom = false
    @State private var customName = ""

    init(day: Date) {
        self.day = day
        let start = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: day) ?? day
        _date = State(initialValue: day)
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: start.addingTimeInterval(3600))
    }

    private var activityName: String {
        custom ? customName.trimmingCharacters(in: .whitespacesAndNewlines) : (preset ?? "")
    }
    private var valid: Bool {
        switch mode {
        case .strength: !lifts.isEmpty
        case .activity: !activityName.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    PillPicker(items: NewRecordMode.allCases, selection: $mode,
                               title: \.label, tint: { $0.tint })

                    CardBox {
                        DatePicker("날짜", selection: $date, displayedComponents: .date)
                            .font(.rounded(15, .medium)).tint(mode.tint)
                        DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                            .font(.rounded(15, .medium)).tint(mode.tint)
                        DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                            .font(.rounded(15, .medium)).tint(mode.tint)
                        HStack {
                            Text("소요").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                            Spacer()
                            Text((MacTime.minutes(from: startTime, to: endTime) * 60).hmKorean)
                                .font(.rounded(17, .bold)).monospacedDigit()
                                .foregroundStyle(mode.tint)
                        }
                    }

                    if mode == .strength { strengthBlock } else { activityBlock }

                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(text: "컨디션")
                        PillPicker(items: Condition.allCases, selection: $condition,
                                   title: \.label, tint: { Palette.condition($0) })
                    }

                    CardBox {
                        SectionLabel(text: "메모")
                        TextField("메모 (선택)", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.rounded(15, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1...4)
                    }
                }
                .padding(20)
            }
            MacSheetFooter(tint: mode.tint, canSave: valid, onCancel: { dismiss() }, onSave: save)
        }
        .frame(minWidth: 560, minHeight: 620)
        .background(Palette.bg)
        .preferredColorScheme(.dark)
    }

    // MARK: 근력

    @ViewBuilder
    private var strengthBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: "부위")
            Picker("", selection: $bodyPart) {
                Text("선택 안 함").tag(BodyPart?.none)
                ForEach(BodyPart.allCases) { Text($0.label).tag(BodyPart?.some($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        LiftsEditor(lifts: $lifts)
    }

    // MARK: 기타 운동

    @ViewBuilder
    private var activityBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "운동 종류")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(ActivityPreset.all, id: \.name) { p in
                    chip(p.symbol, p.name, on: !custom && preset == p.name) {
                        custom = false
                        preset = p.name
                    }
                }
                chip("square.and.pencil", "직접 입력", on: custom) {
                    custom = true
                    preset = nil
                }
            }
            if custom {
                TextField("운동 이름", text: $customName)
                    .textFieldStyle(.plain)
                    .font(.rounded(16, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 12))
            }
        }
    }

    private func chip(_ symbol: String, _ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                Text(title).font(.rounded(12, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.black : Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(on ? Palette.activity : Color.white.opacity(0.07), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: 저장

    private func save() {
        guard valid else { return }
        let start = MacTime.startAt(day: date, time: startTime)
        let end = Calendar.current.date(byAdding: .minute,
                                        value: MacTime.minutes(from: startTime, to: endTime),
                                        to: start) ?? start
        let memo = note.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .strength:
            // 사후 입력이므로 모든 세트를 완료로 기록
            let done = lifts.map { l -> LiftEntry in
                var l = l
                l.name = l.name.trimmingCharacters(in: .whitespaces)
                l.done = l.sets
                return l
            }
            ctx.insert(Session(date: start, kind: .strength, condition: condition, bodyPart: bodyPart,
                               lifts: done, note: memo, startAt: start, endAt: end))
        case .activity:
            let s = Session(date: start, kind: .activity, condition: condition,
                            note: memo, startAt: start, endAt: end)
            s.activityName = activityName
            ctx.insert(s)
        }
        dismiss()
    }
}

// MARK: - 기록 편집

struct SessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session

    @State private var date: Date
    @State private var hasTimes: Bool
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var condition: Condition
    @State private var note: String
    @State private var bodyPart: BodyPart?
    @State private var lifts: [LiftEntry]
    @State private var activityName: String

    init(session: Session) {
        self.session = session
        _date = State(initialValue: session.date)
        _hasTimes = State(initialValue: session.startAt != nil)
        _startAt = State(initialValue: session.startAt ?? session.date)
        _endAt = State(initialValue: session.endAt ?? session.startAt ?? session.date)
        _condition = State(initialValue: session.condition)
        _note = State(initialValue: session.note)
        _bodyPart = State(initialValue: session.bodyPart)
        _lifts = State(initialValue: session.lifts)
        _activityName = State(initialValue: session.activityName ?? "")
    }

    private var tint: Color {
        switch session.kind {
        case .strength: Palette.strength
        case .interval: Palette.interval
        case .activity: Palette.activity
        }
    }

    private var valid: Bool {
        session.kind != .activity || !activityName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    CardBox {
                        HStack {
                            Image(systemName: session.kind.symbol)
                            Text("기록 편집").font(.rounded(17, .bold))
                            Spacer()
                        }
                        .foregroundStyle(tint)

                        if session.kind == .activity {
                            TextField("운동 이름", text: $activityName)
                                .textFieldStyle(.plain)
                                .font(.rounded(16, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 12))
                        }

                        DatePicker("날짜", selection: $date, displayedComponents: .date)
                            .font(.rounded(15, .medium)).tint(tint)

                        Toggle(isOn: $hasTimes.animation(.snappy)) {
                            Text("시작·종료 시각").font(.rounded(15, .medium)).foregroundStyle(Palette.dim)
                        }
                        .tint(tint)

                        if hasTimes {
                            DatePicker("시작", selection: $startAt,
                                       displayedComponents: [.date, .hourAndMinute])
                                .font(.rounded(15, .medium)).tint(tint)
                            DatePicker("종료", selection: $endAt,
                                       displayedComponents: [.date, .hourAndMinute])
                                .font(.rounded(15, .medium)).tint(tint)
                            HStack {
                                Text("소요").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                                Spacer()
                                Text(max(0, Int(endAt.timeIntervalSince(startAt))).hmsString)
                                    .font(.rounded(17, .bold)).monospacedDigit()
                                    .foregroundStyle(tint)
                            }
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            SectionLabel(text: "컨디션")
                            PillPicker(items: Condition.allCases, selection: $condition,
                                       title: \.label, tint: { Palette.condition($0) })
                        }
                    }

                    if session.kind == .strength {
                        VStack(alignment: .leading, spacing: 9) {
                            SectionLabel(text: "부위")
                            Picker("", selection: $bodyPart) {
                                Text("선택 안 함").tag(BodyPart?.none)
                                ForEach(BodyPart.allCases) { Text($0.label).tag(BodyPart?.some($0)) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        LiftsEditor(lifts: $lifts)
                    } else if session.kind == .interval {
                        Text("측정값은 편집할 수 없습니다. 날짜·시각·컨디션·메모만 수정됩니다.")
                            .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    CardBox {
                        SectionLabel(text: "메모")
                        TextField("메모 (선택)", text: $note, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.rounded(15, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1...4)
                    }
                }
                .padding(20)
            }
            MacSheetFooter(tint: tint, canSave: valid, onCancel: { dismiss() }, onSave: commit)
        }
        .frame(minWidth: 560, minHeight: 620)
        .background(Palette.bg)
        .preferredColorScheme(.dark)
    }

    private func commit() {
        guard valid else { return }
        session.date = date
        session.condition = condition
        session.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasTimes {
            session.startAt = startAt
            session.endAt = endAt
        } else {
            session.startAt = nil
            session.endAt = nil
        }
        switch session.kind {
        case .strength:
            session.bodyPart = bodyPart
            session.lifts = lifts.map { l in
                var l = l
                l.name = l.name.trimmingCharacters(in: .whitespaces)
                // 편집 중 새로 추가한 종목은 사후 입력이므로 완료로 기록 (기존 종목의 완료·체크 시각은 그대로)
                if l.done == 0 && l.doneAt == nil { l.done = l.sets }
                return l
            }
        case .activity:
            session.activityName = activityName.trimmingCharacters(in: .whitespaces)
        case .interval:
            break
        }
        dismiss()
    }
}
