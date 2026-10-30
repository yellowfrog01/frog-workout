import SwiftUI
import SwiftData

/// 운동 프로그램 스토어. 근력/유산소별로 검증된 프로그램을 보고 내 계획에 담는다.
struct ProgramStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ProgramKind = .strength

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PillPicker(items: ProgramKind.allCases, selection: $kind,
                               title: { $0.label }, tint: { $0.tint })
                    ForEach(ProgramCatalog.all(kind)) { p in
                        NavigationLink { ProgramDetailView(program: p) } label: {
                            ProgramCard(program: p)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("프로그램은 공개된 자료를 정리한 것입니다. 무게·강도는 본인 수준에 맞춰 조정하세요.")
                        .font(.rounded(11, .medium))
                        .foregroundStyle(Palette.dimmer)
                        .padding(.horizontal, 4).padding(.top, 4)
                }
                .padding(18).padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("프로그램")
            .toolbarTitleDisplayMode(.large)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Palette.strength)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Palette.strength)
    }
}

// MARK: - 목록 카드

struct ProgramCard: View {
    let program: WorkoutProgram
    private var tint: Color { program.kind.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: program.kind.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(tint, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(program.title)
                        .font(.rounded(17, .heavy)).foregroundStyle(.white)
                    Text(program.summary)
                        .font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.dimmer)
                    .padding(.top, 8)
            }
            HStack(spacing: 6) {
                TagChip(program.goal, tint)
                TagChip(program.level, .white.opacity(0.5))
                TagChip(program.scheduleLabel, .white.opacity(0.5))
            }
            if program.rating > 0 {
                HStack(spacing: 6) {
                    StarRow(rating: program.rating)
                    Text("리뷰 \(program.reviews.count)")
                        .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardStroke, lineWidth: 1))
    }
}

struct TagChip: View {
    let text: String
    let tint: Color
    init(_ text: String, _ tint: Color) { self.text = text; self.tint = tint }
    var body: some View {
        Text(text)
            .font(.rounded(11, .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(tint.opacity(0.12), in: .capsule)
    }
}

struct StarRow: View {
    let rating: Double
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating.rounded() ? "star.fill" : "star")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.13))
            }
            Text(String(format: "%.1f", rating))
                .font(.rounded(11, .heavy)).monospacedDigit()
                .foregroundStyle(Palette.dim)
                .padding(.leading, 3)
        }
    }
}

// MARK: - 상세

struct ProgramDetailView: View {
    let program: WorkoutProgram
    @State private var adding = false
    private var tint: Color { program.kind.tint }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                routine
                CardBox {
                    SectionLabel(text: "증량 방식")
                    Text(program.progression)
                        .font(.rounded(14, .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                CardBox {
                    SectionLabel(text: "목적")
                    Text(program.goal)
                        .font(.rounded(20, .heavy)).foregroundStyle(tint)
                    ForEach(Array(program.detailParagraphs.enumerated()), id: \.offset) { _, p in
                        Text(p)
                            .font(.rounded(14, .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !program.reviews.isEmpty { reviews }
            }
            .padding(18).padding(.bottom, 110)
        }
        .background(Palette.bg)
        .navigationTitle(program.title)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { addButton }
        .sheet(isPresented: $adding) { AddProgramSheet(program: program) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: program.kind.symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(tint, in: .rect(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.title).font(.rounded(22, .heavy)).foregroundStyle(.white)
                    Text(program.author).font(.rounded(12, .semibold)).foregroundStyle(Palette.dim)
                }
                Spacer(minLength: 0)
            }
            Text(program.origin)
                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
            HStack(spacing: 6) {
                TagChip(program.level, tint)
                TagChip("주 \(program.daysPerWeek)회", .white.opacity(0.5))
                TagChip(program.weeksLabel, .white.opacity(0.5))
                if program.rating > 0 { StarRow(rating: program.rating) }
            }
            if !program.tags.isEmpty {
                Text(program.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
            }
        }
    }

    /// 권장 요일 (담기 화면의 기본값과 같다)
    private var suggestedWeekdays: [Int] {
        Array(AddProgramSheet.defaultWeekdays(program.daysPerWeek)).sorted()
    }

    private var routine: some View {
        let cycle = program.cycle
        let roll = cycle.isEmpty ? 0 : program.daysPerWeek % cycle.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                SectionLabel(text: "루틴 · \(cycle.count)일 주기")
                Text(cycle.map(\.label).joined(separator: " → "))
                    .font(.rounded(11, .bold)).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            CardBox {
                WeekStrip(cycle: cycle, weekdays: suggestedWeekdays, tint: tint)
                if roll != 0 {
                    Text("다음 주는 \(cycle[roll].label) 부터 이어집니다")
                        .font(.rounded(11, .bold)).foregroundStyle(tint.opacity(0.9))
                }
                Text("권장 요일 기준입니다. 담을 때 바꿀 수 있습니다.")
                    .font(.rounded(10, .medium)).foregroundStyle(Palette.dimmer)
            }

            ForEach(Array(cycle.enumerated()), id: \.offset) { i, day in
                CardBox {
                    HStack(spacing: 8) {
                        Text("\(i + 1)")
                            .font(.rounded(12, .heavy)).monospacedDigit()
                            .foregroundStyle(.black)
                            .frame(width: 22, height: 22)
                            .background(tint, in: .circle)
                        Text(day.heading).font(.rounded(16, .heavy)).foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }
                    if !day.note.isEmpty {
                        Text(day.note)
                            .font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let c = day.cardio {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.mode.label)
                                .font(.rounded(14, .bold)).foregroundStyle(tint)
                            Text(c.spec)
                                .font(.rounded(13, .semibold)).monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                            if !c.note.isEmpty {
                                Text(c.note).font(.rounded(12, .medium)).foregroundStyle(Palette.dim)
                            }
                        }
                    }
                    ForEach(day.lifts) { l in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                ForEach(l.badges, id: \.self) { b in
                                    Text(b)
                                        .font(.rounded(9, .heavy))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(tint.opacity(0.85), in: .capsule)
                                }
                                Text(l.name).font(.rounded(14, .semibold)).foregroundStyle(.white)
                                Spacer(minLength: 4)
                                Text(l.spec)
                                    .font(.rounded(12, .semibold)).monospacedDigit()
                                    .foregroundStyle(Palette.dim)
                            }
                            if !l.note.isEmpty {
                                Text(l.note).font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                            }
                        }
                    }
                }
            }
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "리뷰")
                .padding(.horizontal, 4)
            ForEach(program.reviews) { r in
                CardBox {
                    HStack(spacing: 8) {
                        Text(r.source).font(.rounded(13, .bold)).foregroundStyle(.white)
                        Spacer(minLength: 0)
                        StarRow(rating: Double(r.rating))
                    }
                    Text(r.text)
                        .font(.rounded(13, .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            adding = true
            Haptics.tap()
        } label: {
            Label("내 계획에 추가", systemImage: "arrow.down.circle.fill")
                .font(.rounded(18, .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(tint, in: .capsule)
                .shadow(color: tint.opacity(0.3), radius: 16, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            LinearGradient(colors: [Palette.bg.opacity(0), Palette.bg, Palette.bg],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

// MARK: - 계획에 담기

struct AddProgramSheet: View {
    let program: WorkoutProgram
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    @State private var start = Calendar.current.startOfDay(for: .now)
    @State private var weekdays: Set<Int> = []
    @State private var weeks = 4
    private var tint: Color { program.kind.tint }
    private let cal = Calendar.current

    private var preview: [PlannedWorkout] {
        PlanBuilder.make(program: program, from: start,
                         weekdays: Array(weekdays), weeks: weeks, history: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardBox {
                        SectionLabel(text: "시작일")
                        DatePicker("", selection: $start, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(tint)
                    }
                    CardBox {
                        SectionLabel(text: "운동할 요일 · 주 \(program.daysPerWeek)회 권장")
                        weekdayPicker
                        if weekdays.count != program.daysPerWeek {
                            Text(weekdays.isEmpty
                                 ? "요일을 고르세요"
                                 : "\(weekdays.count)일 선택 — 권장은 \(program.daysPerWeek)일입니다")
                                .font(.rounded(11, .semibold))
                                .foregroundStyle(weekdays.isEmpty ? Palette.interval : Palette.dim)
                        }
                    }
                    CardBox {
                        StepRow(label: "몇 주 분량", value: $weeks, step: 1, range: 1...16) { "\($0)주" }
                        if program.weeks > 0 {
                            Text("프로그램 권장 기간은 \(program.weeks)주입니다")
                                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                        }
                    }
                    if !preview.isEmpty {
                        CardBox {
                            SectionLabel(text: "미리보기 · \(preview.count)회")
                            ForEach(Array(preview.prefix(6).enumerated()), id: \.offset) { _, p in
                                HStack(spacing: 8) {
                                    Text(p.date.monthDay)
                                        .font(.rounded(12, .heavy)).monospacedDigit()
                                        .foregroundStyle(tint)
                                        .frame(width: 42, alignment: .leading)
                                    Text(p.date.weekdayShort)
                                        .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                                    Text(p.title).font(.rounded(13, .semibold)).foregroundStyle(.white)
                                    Spacer(minLength: 0)
                                }
                            }
                            if preview.count > 6 {
                                Text("… 외 \(preview.count - 6)회")
                                    .font(.rounded(11, .semibold)).foregroundStyle(Palette.dimmer)
                            }
                        }
                        if program.kind == .strength {
                            Text("무게는 최근 기록에서 가져옵니다. 기록이 없는 종목은 0kg 으로 담기니 운동 중에 맞추세요.")
                                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
                                .padding(.horizontal, 4)
                        }
                    }
                    addButton
                }
                .padding(18).padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("계획에 추가")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Palette.dim)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if weekdays.isEmpty { weekdays = Self.defaultWeekdays(program.daysPerWeek) }
            weeks = program.weeks > 0 ? min(program.weeks, 16) : 4
        }
    }

    private var weekdayPicker: some View {
        let order = (0..<7).map { (cal.firstWeekday + $0 - 1) % 7 + 1 }
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { wd in
                let on = weekdays.contains(wd)
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        if on { weekdays.remove(wd) } else { weekdays.insert(wd) }
                    }
                    Haptics.tap()
                } label: {
                    Text(Self.weekdayName(wd))
                        .font(.rounded(14, on ? .heavy : .medium))
                        .foregroundStyle(on ? .black : Palette.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? tint : Color.white.opacity(0.07), in: .rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButton: some View {
        Button {
            for p in preview { ctx.insert(p) }
            try? ctx.save()
            Haptics.success()
            dismiss()
        } label: {
            Text(preview.isEmpty ? "요일을 고르세요" : "\(preview.count)회 담기")
                .font(.rounded(18, .bold))
                .foregroundStyle(preview.isEmpty ? Palette.dimmer : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(preview.isEmpty ? Color.white.opacity(0.08) : tint,
                            in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(preview.isEmpty)
    }

    static func weekdayName(_ wd: Int) -> String {
        ["일", "월", "화", "수", "목", "금", "토"][max(0, min(6, wd - 1))]
    }

    /// 주 N회에 흔히 쓰는 요일 배치
    static func defaultWeekdays(_ n: Int) -> Set<Int> {
        switch n {
        case 1: [4]
        case 2: [3, 6]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 6]
        case 5: [2, 3, 4, 5, 6]
        case 6: [2, 3, 4, 5, 6, 7]
        default: [1, 2, 3, 4, 5, 6, 7]
        }
    }
}

// MARK: - 주간 가로 달력

/// 주기(A·B…)를 권장 요일에 얹어 한 주를 가로로 보여준다.
struct WeekStrip: View {
    let cycle: [ProgramDay]
    /// 1(일) ~ 7(토)
    let weekdays: [Int]
    let tint: Color
    private let cal = Calendar.current

    var body: some View {
        let order = (0..<7).map { (cal.firstWeekday + $0 - 1) % 7 + 1 }
        HStack(spacing: 4) {
            ForEach(order, id: \.self) { wd in
                let day = weekdays.firstIndex(of: wd).flatMap { i in
                    cycle.isEmpty ? nil : cycle[i % cycle.count]
                }
                cell(wd, day)
            }
        }
    }

    private func cell(_ wd: Int, _ day: ProgramDay?) -> some View {
        VStack(spacing: 4) {
            Text(AddProgramSheet.weekdayName(wd))
                .font(.rounded(11, .bold))
                .foregroundStyle(wd == 1 ? Palette.interval.opacity(0.75) : Palette.dimmer)
            ZStack {
                if let day {
                    VStack(spacing: 1) {
                        Text(day.label)
                            .font(.rounded(11, .heavy))
                            .foregroundStyle(tint)
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(Self.sub(day))
                            .font(.rounded(8, .semibold)).monospacedDigit()
                            .foregroundStyle(Palette.dim)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .padding(.horizontal, 2)
                } else {
                    Text("휴식")
                        .font(.rounded(9, .semibold))
                        .foregroundStyle(Palette.dimmer)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(day == nil ? Color.clear : tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(day == nil ? Color.white.opacity(0.08) : tint.opacity(0.4),
                                  style: StrokeStyle(lineWidth: 1, dash: day == nil ? [3, 2] : []))
            )
        }
    }

    /// 칸 아래 한 줄 요약
    static func sub(_ day: ProgramDay) -> String {
        if let c = day.cardio {
            if c.mode == .interval {
                let m = c.workSeconds / 60, s = c.workSeconds % 60
                let work = s == 0 ? "\(m)분" : (m == 0 ? "\(s)초" : "\(m):\(String(format: "%02d", s))")
                return "\(work)×\(c.sets)"
            }
            return c.minutes > 0 ? "\(c.minutes)분" : c.mode.label
        }
        return "\(day.lifts.count)종목"
    }
}
