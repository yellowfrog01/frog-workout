import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    @Query(sort: \PlannedWorkout.date) private var plans: [PlannedWorkout]

    @State private var editing: Session?
    @State private var picking = false
    @State private var pickingCardio = false
    /// 종류까지 고른 뒤 컨디션을 묻는 단계
    @State private var pendingWorkout: ActiveWorkout?
    @State private var pickingCondition = false
    @State private var importing = false
    @State private var showCalendar = false
    @State private var showStore = false
    @State private var active: ActiveWorkout?
    /// 근력 초안이 있는데 새로 시작하려 할 때 고르게 한다
    @State private var pendingStrength: ActiveWorkout?
    @State private var askingDraft = false
    @State private var draftBlocking = false
    /// 앱 실행 후 한 번만: 진행 중인 근력 운동 화면을 자동으로 다시 연다
    @State private var autoResumed = false
    private var drafts: StrengthDraftStore { .shared }
    private var watch: WatchLink { WatchLink.shared }
    @Environment(\.scenePhase) private var phase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        PlanSection(plans: pendingPlans, onStart: startPlan)
                        if sessions.isEmpty && pendingPlans.isEmpty && drafts.draft == nil { emptyState }
                        // 작성 중·진행 중인 근력 운동 — 저장되면 이 자리에 기록이 들어간다
                        if let d = drafts.draft, active == nil {
                            Button { resumeDraft() } label: { DraftSessionRow(draft: d) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("이어서 하기", systemImage: "play.fill") { resumeDraft() }
                                    Button("버리기", systemImage: "trash", role: .destructive) { drafts.clear() }
                                }
                        }
                        // 이어서 하는 중인 기록은 위의 진행 중 카드로 대신 보여준다
                        ForEach(sessions.filter { $0.persistentModelID != drafts.draft?.resumeID }) { s in
                            Button { editing = s } label: { SessionRow(session: s) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("상세", systemImage: "chart.xyaxis.line") { editing = s }
                                    if s.kind == .strength {
                                        Button("이어서 하기", systemImage: "play.fill") { resumeSession(s) }
                                    }
                                    Button("삭제", systemImage: "trash", role: .destructive) {
                                        ctx.delete(s)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 120)   // FAB 가림 방지
                }
                VStack(spacing: 8) {
                    if watch.running && active == nil { watchBanner }
                    if !diag.isEmpty {
                        Text(diag)
                            .font(.rounded(10, .semibold))
                            .foregroundStyle(Palette.dimmer)
                            .padding(.horizontal, 18)
                            .multilineTextAlignment(.center)
                    }
                    startButton
                }
            }
            .background(Palette.bg)
            .navigationTitle("운동")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showCalendar = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.strength)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showStore = true } label: {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.strength)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.strength)
                    }
                }
            }
            .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .tint(Palette.strength)
        .sheet(item: $editing) { SessionDetailView(session: $0) }
        .sheet(isPresented: $importing) { ImportSheet() }
        .sheet(isPresented: $showCalendar) { CalendarSheet() }
        .sheet(isPresented: $showStore) { ProgramStoreView() }
        .confirmationDialog("운동 종류", isPresented: $picking, titleVisibility: .visible) {
            Button("근력") { askCondition(ActiveWorkout(kind: .strength, mode: nil)) }
            Button("유산소") { pickingCardio = true }
            Button("취소", role: .cancel) { }
        }
        .confirmationDialog("유산소 방식", isPresented: $pickingCardio, titleVisibility: .visible) {
            Button("인터벌") { askCondition(ActiveWorkout(kind: .interval, mode: .interval)) }
            Button("일반") { askCondition(ActiveWorkout(kind: .interval, mode: .steady)) }
            Button("취소", role: .cancel) { }
        }
        .alert("작성 중인 근력 운동이 있습니다", isPresented: $draftBlocking) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("진행 중인 운동을 완료하거나 버린 뒤에 이어서 할 수 있습니다.")
        }
        .confirmationDialog("작성 중인 근력 운동이 있습니다", isPresented: $askingDraft, titleVisibility: .visible) {
            Button("이어서 하기") { pendingStrength = nil; resumeDraft() }
            Button("버리고 새로 시작", role: .destructive) {
                drafts.clear()
                if let w = pendingStrength { active = w }
                pendingStrength = nil
            }
            Button("취소", role: .cancel) { pendingStrength = nil }
        }
        .confirmationDialog("오늘 컨디션", isPresented: $pickingCondition, titleVisibility: .visible) {
            ForEach(Condition.allCases) { c in
                Button(c.label) {
                    guard var w = pendingWorkout else { return }
                    w.condition = c
                    pendingWorkout = nil
                    active = w
                }
            }
            Button("취소", role: .cancel) { pendingWorkout = nil }
        }
        .onAppear {
            watch.activateIfNeeded(); watch.retryLiveActivityIfNeeded()
            if !autoResumed {
                autoResumed = true
                if active == nil, drafts.draft?.start != nil { resumeDraft() }
            }
        }
        .onChange(of: phase) { _, p in
            if p == .active { watch.activateIfNeeded(); watch.retryLiveActivityIfNeeded() }
        }
        .onChange(of: watch.arrivedSID) { _, sid in
            mergeArrived(sid)
        }
        .task { mergeArrived(watch.arrivedSID) }
        .onChange(of: phase) { _, p in if p == .active { mergeArrived(watch.arrivedSID) } }

        .onChange(of: watch.running) { _, isRunning in
            if isRunning && active == nil {
                active = ActiveWorkout(kind: .interval, mode: .steady)
            }
        }
        .fullScreenCover(item: $active) { w in
            if w.kind == .strength {
                StrengthSessionView(preset: w.lifts, onFinish: w.onFinish, planID: w.planID)
            } else {
                CardioSessionView(mode: w.mode ?? .steady, condition: w.condition,
                                  presetInterval: w.interval, onFinish: w.onFinish)
            }
        }
    }

    /// 아직 시작하지 않은 계획 (지난 것 포함, 날짜 순)
    private var pendingPlans: [PlannedWorkout] {
        plans.filter { !$0.isDone }
    }

    /// 계획을 눌러 시작. 컨디션만 다시 물어보고 내용은 그대로 채운다.
    /// 계획은 운동을 실제로 저장했을 때만 소진된다 (중간에 취소하면 그대로 남는다).
    private func startPlan(_ p: PlannedWorkout) {
        var w = ActiveWorkout(kind: p.kind, mode: p.kind == .strength ? nil : (p.cardioMode ?? .steady))
        w.lifts = p.lifts
        w.interval = p.interval
        w.planID = p.persistentModelID
        w.onFinish = { [weak p] in
            p?.startedAt = .now
            try? ctx.save()
        }
        askCondition(w)
    }

    /// 종류 선택 직후 컨디션을 묻는다 (다이얼로그가 닫힌 뒤 띄워야 겹치지 않는다)
    private func askCondition(_ w: ActiveWorkout) {
        // 근력은 세션 화면 안(준비 상태)에서 컨디션을 고른다
        if w.kind == .strength {
            if drafts.draft != nil {
                pendingStrength = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { askingDraft = true }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { active = w }
            }
            return
        }
        pendingWorkout = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pickingCondition = true }
    }

    /// 이미 저장된 근력 기록을 다시 열어 이어서 한다. 완료하면 그 기록을 갱신한다.
    private func resumeSession(_ s: Session) {
        guard drafts.draft == nil else { draftBlocking = true; return }
        drafts.save(StrengthDraft(lifts: s.lifts, condition: s.condition,
                                  start: s.startAt ?? s.date, resumeID: s.persistentModelID))
        resumeDraft()
    }

    /// 저장해 둔 근력 초안으로 다시 들어간다. 계획에서 시작한 초안이면 저장 시 그 계획을 소진한다.
    private func resumeDraft() {
        var w = ActiveWorkout(kind: .strength, mode: nil)
        let pid = drafts.draft?.planID
        w.planID = pid
        w.onFinish = {
            if let pid, let p = ctx.model(for: pid) as? PlannedWorkout {
                p.startedAt = .now
                try? ctx.save()
            }
        }
        active = w
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Palette.dimmer)
            Text("아직 기록이 없습니다")
                .font(.rounded(16, .semibold))
                .foregroundStyle(Palette.dim)
            Text("아래 버튼으로 운동을 시작하세요")
                .font(.rounded(13, .medium))
                .foregroundStyle(Palette.dimmer)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    /// 워치가 뒤늦게 보낸 전체 시계열을 해당 세션에 병합
    private func mergeArrived(_ sid: String) {

            // 워치가 종료 후 보낸 전체 시계열을 해당 세션에 병합한다
            guard !sid.isEmpty, let t = watch.arrivedTelemetry else { return }
            // 워치 세션 ID 가 정확히 일치할 때만 병합한다.
            // (예전엔 아무 인터벌 세션이나 잡아서 다른 기록을 덮어썼다)
            if let target = sessions.first(where: { $0.watchSessionID == sid }) {
                var merged = t
                merged.cadence  = target.telemetry.cadence
                merged.altitude = target.telemetry.altitude
                merged.gpsSpeed = target.telemetry.gpsSpeed
                merged.gpsDistance = target.telemetry.gpsDistance
                // 심박이 뒤늦게 들어오므로 스플릿은 항상 다시 계산한다
                merged.splits = RouteAnalysis.splits(route: target.route, hr: merged.hr, totalMeters: merged.distance)
                merged.elevationGain = target.telemetry.elevationGain
                merged.elevationLoss = target.telemetry.elevationLoss
                target.telemetry = merged
                if merged.distance > 0 { target.distanceMeters = merged.distance }
            }
            watch.arrivedTelemetry = nil
            watch.arrivedSID = ""
            }

    /// 워치 수신·상황판 상태 (진단)
    private var diag: String {
        var p: [String] = []
        if !watch.lastEvent.isEmpty { p.append("워치: " + watch.lastEvent) }
        if !LiveRunStatus.shared.note.isEmpty { p.append(LiveRunStatus.shared.note) }
        return p.joined(separator: " · ")
    }

    private var watchBanner: some View {
        Button { active = ActiveWorkout(kind: .interval, mode: .steady) } label: {
            HStack(spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("워치에서 러닝 중")
                        .font(.rounded(14, .bold))
                    if watch.bpm > 0 {
                        Text("\(watch.bpm) BPM")
                            .font(.rounded(11, .semibold)).monospacedDigit()
                            .foregroundStyle(.black.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Palette.interval, in: .capsule)
            .shadow(color: Palette.interval.opacity(0.3), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private var startButton: some View {
        Button {
            picking = true
            Haptics.tap()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                Text("운동 시작").font(.rounded(18, .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 30)
            .padding(.vertical, 17)
            .background(Palette.strength, in: .capsule)
            .shadow(color: Palette.strength.opacity(0.3), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 26)
    }
}

struct ActiveWorkout: Identifiable {
    let id = UUID()
    let kind: WorkoutKind
    let mode: CardioMode?
    var condition: Condition = .normal
    /// 계획에서 시작할 때 미리 채워 넣을 내용
    var lifts: [LiftEntry] = []
    var interval: IntervalEntry? = nil
    /// 계획에서 시작했으면 그 계획 (근력 초안에 같이 저장)
    var planID: PersistentIdentifier? = nil
    /// 기록을 저장했을 때 호출. 계획을 소진 처리한다.
    var onFinish: (() -> Void)? = nil
}

// MARK: - 과거 기록 한 줄

struct SessionRow: View {
    let session: Session
    private var tint: Color {
        switch session.kind {
        case .strength: Palette.strength
        case .interval: Palette.interval
        case .activity: Palette.activity
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 2) {
                Text(session.logicalDay.monthDay)
                    .font(.rounded(15, .bold)).monospacedDigit()
                    .foregroundStyle(.white)
                Text(session.logicalDay.weekdayShort)
                    .font(.rounded(11, .semibold))
                    .foregroundStyle(Palette.dimmer)
            }
            .frame(width: 46)

            Rectangle().fill(tint.opacity(0.5)).frame(width: 2)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: session.kind == .activity
                          ? ActivityPreset.symbol(for: session.activityName ?? "") : session.kind.symbol)
                        .font(.system(size: 11, weight: .bold))
                    Text(session.kind == .activity
                         ? (session.activityName ?? session.kind.label)
                         : (session.cardioMode?.label ?? session.kind.label))
                        .font(.rounded(13, .bold))
                    if let st = session.startAt {
                        Text(session.clock(st))
                            .font(.rounded(11, .semibold)).monospacedDigit()
                            .foregroundStyle(Palette.dim)
                    }
                    if let d = session.durationSeconds, d > 0 {
                        Text(d.hmsString)
                            .font(.rounded(11, .semibold)).monospacedDigit()
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.white.opacity(0.1), in: .capsule)
                            .foregroundStyle(Palette.dim)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: session.condition.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.condition(session.condition))
                }
                .foregroundStyle(tint)

                if let iv = session.interval {
                    Text(iv.summary)
                        .font(.rounded(13, .medium))
                        .foregroundStyle(Palette.dim)
                }
                if let d = session.intervalDetail {
                    IntervalRowSummary(detail: d, hr: session.telemetry.hr)
                }
                if session.kind == .interval {
                    HStack(spacing: 10) {
                        if session.distanceKm > 0.01 {
                            Label(String(format: "%.2fkm", session.distanceKm), systemImage: "location.fill")
                                .foregroundStyle(WatchTint.distance)
                        }
                        if let p = session.avgPace {
                            Label("\(p.clockString)/km", systemImage: "speedometer")
                                .foregroundStyle(WatchTint.pace)
                        }
                        if session.avgHR > 0 {
                            Label("\(session.avgHR)bpm", systemImage: "heart.fill")
                                .foregroundStyle(WatchTint.heart)
                        }
                    }
                    .font(.rounded(12, .bold)).monospacedDigit()
                    if !session.route.isEmpty {
                        RouteMap(points: session.route, height: 120)
                            .padding(.top, 2)
                    }
                }
                ForEach(session.lifts) { l in
                    HStack(spacing: 6) {
                        LiftNameLine(lift: l, size: 13, weight: .medium, color: Palette.dim)
                        Spacer(minLength: 4)
                        Text("\(l.weightLabel) \(l.repsDetail)")
                            .font(.rounded(13, .semibold)).monospacedDigit()
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                if session.totalVolume > 0 {
                    Text("총 \(Int(session.totalVolume).formatted()) kg")
                        .font(.rounded(12, .bold)).monospacedDigit()
                        .foregroundStyle(tint.opacity(0.85))
                        .padding(.top, 1)
                }
                if session.kind == .activity, !session.note.isEmpty {
                    Text(session.note)
                        .font(.rounded(13, .medium))
                        .foregroundStyle(Palette.dim)
                }
                if session.isEmpty {
                    let extra = session.note == (session.bodyPart?.label ?? "") ? "" : session.note
                    Text(extra.isEmpty ? "세부 기록 없음" : extra)
                        .font(.rounded(13, .medium))
                        .foregroundStyle(extra.isEmpty ? Palette.dimmer : Palette.dim)
                }
            }
        }
        .padding(14)
        .background(Palette.card, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardStroke, lineWidth: 1))
    }
}

// MARK: - 세트 완료 점

struct SetDots: View {
    let total: Int
    @Binding var done: Int
    let tint: Color
    var size: CGFloat = 26
    var interactive: Bool = true

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                let filled = i < done
                Button {
                    guard interactive else { return }
                    withAnimation(.snappy(duration: 0.2)) { done = (i < done) ? i : i + 1 }
                    Haptics.tap()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(filled ? tint : Color.white.opacity(0.18), lineWidth: 2)
                            .background(Circle().fill(filled ? tint : .clear))
                        if filled {
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.38, weight: .black))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: size, height: size)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(interactive)
            }
            Spacer(minLength: 0)
            Text("\(done)/\(total)")
                .font(.rounded(12, .semibold)).monospacedDigit()
                .foregroundStyle(done == total && total > 0 ? tint : Palette.dimmer)
        }
    }
}

// MARK: - 스테퍼 한 줄

struct StepRow: View {
    let label: String
    @Binding var value: Int
    let step: Int
    let range: ClosedRange<Int>
    let format: (Int) -> String

    var body: some View {
        HStack {
            Text(label).font(.rounded(15, .medium)).foregroundStyle(Palette.dim)
            Spacer()
            Text(format(value))
                .font(.rounded(17, .bold)).monospacedDigit()
                .foregroundStyle(.white)
                .frame(minWidth: 84, alignment: .trailing)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden().scaleEffect(0.88).frame(width: 86)
        }
    }
}
