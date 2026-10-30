import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 공통: 경과 시간 타이머

struct ElapsedTimer: View {
    let start: Date
    var size: CGFloat = 56
    var tint: Color = Palette.strength

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let secs = max(0, Int(ctx.date.timeIntervalSince(start)))
            Text(secs.hmsString)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
    }
}

/// 경과 분만 작게 표시 ("12분 경과", "1시간 5분 경과")
struct ElapsedMinutes: View {
    let start: Date
    var tint: Color = Palette.strength

    var body: some View {
        TimelineView(.periodic(from: start, by: 60)) { ctx in
            let m = max(0, Int(ctx.date.timeIntervalSince(start)) / 60)
            Text(m >= 60 ? "\(m / 60)시간 \(m % 60)분 경과" : "\(m)분 경과")
                .font(.rounded(15, .bold)).monospacedDigit()
                .foregroundStyle(tint)
        }
    }
}

/// 근력 세션 헤더 — 시간은 분 단위로만 작게
private struct StrengthHeader: View {
    let start: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Palette.strength).frame(width: 7, height: 7)
            Text("근력 운동 중")
                .font(.rounded(13, .bold))
                .foregroundStyle(Palette.strength)
            Spacer()
            ElapsedMinutes(start: start)
            Text("· 시작 \(start.hourMinute)")
                .font(.rounded(13, .semibold)).monospacedDigit()
                .foregroundStyle(Palette.dim)
        }
    }
}

/// 세션 화면 상단 공통 헤더
private struct SessionHeader: View {
    let start: Date
    let tint: Color
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 7, height: 7)
                Text(title)
                    .font(.rounded(13, .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text("시작 \(start.hourMinute)")
                    .font(.rounded(13, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
            }
            ElapsedTimer(start: start, size: 54, tint: tint)
        }
    }
}

// MARK: - 근력 세션

struct StrengthSessionView: View {
    /// 계획에서 시작했을 때 미리 채워 넣을 종목
    var preset: [LiftEntry] = []
    /// 기록을 저장했을 때 호출 (계획 소진)
    var onFinish: (() -> Void)? = nil
    /// 계획에서 시작했으면 그 계획 — 초안에 같이 저장해 재실행 후에도 소진할 수 있게 한다
    var planID: PersistentIdentifier? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    private var drafts: StrengthDraftStore { .shared }
    /// 저장·버리기 후에는 초안을 다시 쓰지 않는다
    @State private var closed = false

    /// "운동 시작"을 누른 시각. 그 전에는 종목 준비만 하고 시간은 재지 않는다.
    @State private var start: Date?
    /// 준비 화면에서 고르고, 운동 중에는 헤더 아이콘으로 바꾼다.
    @State private var condition: Condition?
    @State private var lifts: [LiftEntry] = []
    @State private var loadedPreset = false
    @State private var showAddLift = false
    @State private var confirmCancel = false
    // 휴식 타이머
    @AppStorage("rest.seconds") private var restSeconds = 120
    @State private var restEnd: Date?
    @State private var restTotal = 120
    @State private var restNext = ""
    /// 지금 휴식이 어느 종목 세트 뒤인지
    @State private var restLiftID: UUID?
    /// 방금 완료한 세트 — 실제 횟수를 바로 고칠 수 있게 아래 바에 띄운다
    @State private var justDone: JustDone?
    /// 메모를 쓰는 대상 (종목 id, 세트 시점)
    @State private var memoTarget: JustDone?
    @State private var memoText = ""

    private var volume: Int { Int(lifts.reduce(0) { $0 + $1.volume }) }

    /// 세트 완료 직후 휴식 시작. 다음 할 일을 함께 보여준다.
    private func startRest(after lift: LiftEntry) {
        // 종목의 마지막 세트면 세트 휴식 대신 종목 간 휴식 (다음 운동 시작·추가를 누를 때까지)
        if lift.done >= lift.sets {
            stopRest()
            return
        }
        let total = lift.restSec ?? restSeconds
        let end = Date().addingTimeInterval(TimeInterval(total))
        restLiftID = lift.id
        restTotal = total
        restEnd = end
        if lift.done < lift.sets {
            let n = lift.repsList.indices.contains(lift.done) ? lift.repsList[lift.done] : lift.reps
            restNext = "다음: \(lift.name) \(lift.done + 1)세트 · \(lift.weightText(at: lift.done)) \(n)회"
        } else if let nx = lifts.first(where: { $0.done < $0.sets && $0.id != lift.id }) {
            restNext = "다음: \(nx.name) \(nx.done + 1)세트 · \(nx.weightText(at: nx.done))"
        } else {
            restNext = "\(lift.name) 완료"
        }
        RestAlert.shared.schedule(at: end, body: restNext)
    }

    private func adjustRest(_ delta: Int) {
        guard let end = restEnd else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(delta))
        guard newEnd > Date() else { stopRest(); return }
        restEnd = newEnd
        restTotal = max(15, restTotal + delta)
        // 휴식은 종목마다 일정하게: 조정한 값이 그 종목의 목표 휴식이 된다
        if let id = restLiftID, let i = lifts.firstIndex(where: { $0.id == id }) {
            lifts[i].restSec = min(600, max(15, (lifts[i].restSec ?? restSeconds) + delta))
        } else {
            restSeconds = min(600, max(15, restSeconds + delta))
        }
        RestAlert.shared.schedule(at: newEnd, body: restNext)
    }

    private func stopRest() {
        restEnd = nil
        RestAlert.shared.cancel()
    }

    /// 지금 상태를 초안으로 저장 (나가도·재설치해도 이어서)
    private func persist() {
        guard !closed, loadedPreset else { return }
        drafts.save(StrengthDraft(lifts: lifts, condition: condition, start: start,
                                  planID: planID ?? drafts.draft?.planID,
                                  restEnd: restEnd, restTotal: restTotal, restNext: restNext,
                                  restLiftID: restLiftID, resumeID: drafts.draft?.resumeID))
    }

    private func openMemo(_ id: UUID, set: Int) {
        memoText = ""
        memoTarget = JustDone(id: id, idx: set)
    }

    private func saveMemo() {
        let t = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let m = memoTarget, !t.isEmpty,
              let i = lifts.firstIndex(where: { $0.id == m.id }) else { return }
        lifts[i].memos.append(LiftMemo(text: t, afterSet: m.idx))
        Haptics.success()
    }

    private func discard() {
        closed = true
        drafts.clear()
        stopRest()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    CardBox {
                        if let start {
                            HStack(spacing: 10) {
                                StrengthHeader(start: start)
                                conditionMenu
                            }
                        } else {
                            startButton
                        }
                    }

                    let gaps = LiftTiming.transitions(lifts)
                    ForEach($lifts) { $lift in
                        // 앞 종목과의 종목 간 휴식
                        if let g = gaps[lift.id] { TransitionGapLine(seconds: g) }
                        VStack(spacing: 6) {
                            LiftLiveRow(lift: $lift, locked: start == nil,
                                        onSetDone: {
                                            justDone = JustDone(id: lift.id, idx: lift.done - 1)
                                            startRest(after: lift)
                                        },
                                        onSetUndone: { justDone = nil; stopRest() },
                                        onMemo: { openMemo(lift.id, set: lift.done) }) {
                                if justDone?.id == lift.id { justDone = nil }
                                withAnimation(.snappy) { lifts.removeAll { $0.id == lift.id } }
                            }
                            if start != nil {
                                HStack(spacing: 10) {
                                    if let sec = LiftTiming.durations(lifts, start: start)[lift.id] {
                                        LiftDurationLabel(seconds: sec)
                                    }
                                    Label("목표 휴식 \((lift.restSec ?? restSeconds).hmsString)", systemImage: "timer")
                                        .font(.rounded(12, .semibold)).monospacedDigit()
                                        .foregroundStyle(Palette.dim)
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                            }
                            if !lift.memos.isEmpty {
                                LiftMemoLines(memos: lift.memos, liftName: lift.name) { m in
                                    lift.memos.removeAll { $0.id == m.id }
                                }
                            }
                            // 준비 중에만 같은 종목의 최근 기록을 보여준다
                            if start == nil { LiftLastLine(name: lift.name) }
                        }
                    }

                    Button {
                        showAddLift = true
                        Haptics.tap()
                    } label: {
                        Label("종목 추가", systemImage: "plus.circle.fill")
                            .font(.rounded(16, .semibold))
                            .foregroundStyle(Palette.strength)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.strength.opacity(0.12), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    if !lifts.isEmpty {
                        HStack {
                            Text("총 볼륨").font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
                            Spacer()
                            Text("\(volume.formatted()) kg")
                                .font(.rounded(20, .heavy)).monospacedDigit()
                                .foregroundStyle(Palette.strength)
                        }
                        .padding(.horizontal, 4)
                    }

                    finishButton

                    // 준비 중에만 지난 근력 기록을 아래에 펼친다
                    if start == nil { StrengthHistoryList().padding(.top, 10) }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let jd = justDone, let i = lifts.firstIndex(where: { $0.id == jd.id }) {
                        DoneRepsBar(lift: $lifts[i], idx: jd.idx,
                                    onMemo: { openMemo(jd.id, set: jd.idx + 1) }) {
                            withAnimation(.snappy) { justDone = nil }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let end = restEnd {
                        RestBar(end: end, total: restTotal, next: restNext,
                                onAdjust: adjustRest, onSkip: {
                            withAnimation(.snappy) { stopRest() }
                        })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if start != nil {
                        switch lifts.phase {
                        case .transition(let since, let i):
                            TransitionBar(since: since, next: i.map { lifts[$0] }) {
                                if let i {
                                    withAnimation(.snappy) { lifts[i].warmupAt = Date().timeIntervalSince1970 }
                                } else {
                                    showAddLift = true
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        case .warmup(let since, let i):
                            WarmupBar(since: since, lift: lifts[i])
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
            .animation(.snappy, value: restEnd)
            .animation(.snappy, value: justDone)
            // 앱이 앞에 있을 때 끝나면 진동 후 바를 닫는다 (배너·소리는 로컬 알림이 낸다)
            .task(id: restEnd) {
                guard let end = restEnd else { return }
                let wait = end.timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                guard !Task.isCancelled, restEnd == end else { return }
                Haptics.success()
                try? await Task.sleep(for: .seconds(3))
                if restEnd == end { restEnd = nil }
            }
            .onAppear {
                RestAlert.shared.prepare()
                if !loadedPreset {
                    loadedPreset = true
                    if let d = drafts.draft {
                        lifts = d.lifts; condition = d.condition; start = d.start
                        // 아직 안 끝난 휴식은 이어서 센다 (알림은 이미 예약돼 있다)
                        if let re = d.restEnd, re > .now {
                            restTotal = d.restTotal ?? restSeconds
                            restNext = d.restNext ?? ""
                            restLiftID = d.restLiftID
                            restEnd = re
                        }
                    } else {
                        if lifts.isEmpty && !preset.isEmpty { lifts = preset }
                        persist()
                    }
                }
            }
            .onChange(of: lifts) { persist() }
            .onChange(of: condition) { persist() }
            .onChange(of: start) { persist() }
            .onChange(of: restEnd) { persist() }
            // 잠금화면에서 세트를 완료하면 초안이 바뀌므로 화면 값을 다시 읽는다
            .onChange(of: drafts.externalRevision) {
                guard let d = drafts.draft else { return }
                lifts = d.lifts
                restTotal = d.restTotal ?? restTotal
                restNext = d.restNext ?? restNext
                restLiftID = d.restLiftID
                restEnd = d.restEnd
            }
            .background(Palette.bg)
            .navigationTitle("")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // 나가기: 초안은 남기고 메인으로 (휴식 알림도 유지)
                ToolbarItem(placement: .cancellationAction) {
                    Button("나가기") { persist(); dismiss() }
                        .foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("버리기") {
                        if lifts.isEmpty { discard() } else { confirmCancel = true }
                    }
                    .foregroundStyle(Palette.dimmer)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddLift) { AddLiftSheet { lifts.append($0) } }
        .alert("메모", isPresented: Binding(get: { memoTarget != nil },
                                           set: { if !$0 { memoTarget = nil } })) {
            TextField("예: 삼두에 힘 더 주기", text: $memoText)
            Button("저장") { saveMemo(); memoTarget = nil }
            Button("취소", role: .cancel) { memoTarget = nil }
        } message: {
            if let m = memoTarget, let l = lifts.first(where: { $0.id == m.id }) {
                Text("\(l.name) · \(LiftMemo(text: "", afterSet: m.idx).setLabel)")
            }
        }
        .alert(start == nil ? "작성 중인 계획을 버릴까요?" : "운동을 취소할까요?", isPresented: $confirmCancel) {
            Button("기록 버리기", role: .destructive) { discard() }
            Button("계속하기", role: .cancel) { }
        }
    }

    /// 준비 상태 → 실제 운동 시작
    private var startButton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(Palette.dim).frame(width: 7, height: 7)
                Text("준비 중 · 시간 측정 전")
                    .font(.rounded(13, .bold))
                    .foregroundStyle(Palette.dim)
            }
            conditionPicker
            Button {
                withAnimation(.snappy) {
                    start = .now
                    // 첫 종목은 운동 시작과 함께 웜업 시작
                    if let i = lifts.firstIndex(where: { $0.done < $0.sets }) {
                        lifts[i].warmupAt = Date().timeIntervalSince1970
                    }
                }
                Haptics.success()
            } label: {
                Label(condition == nil ? "컨디션을 고르세요" : "운동 시작", systemImage: "play.fill")
                    .font(.rounded(18, .bold))
                    .foregroundStyle(condition == nil ? Palette.dimmer : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(condition == nil ? Color.white.opacity(0.08) : Palette.strength,
                                in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(condition == nil)
            .animation(.snappy, value: condition)
        }
    }

    /// 운동 중 컨디션 변경 (헤더 오른쪽 아이콘)
    private var conditionMenu: some View {
        Menu {
            Picker("컨디션", selection: $condition) {
                ForEach(Condition.allCases) { c in
                    Label(c.label, systemImage: c.symbol).tag(Optional(c))
                }
            }
        } label: {
            let c = condition ?? .normal
            Image(systemName: c.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.condition(c))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: .circle)
        }
    }

    /// 오늘 컨디션 — 고르기 전에는 운동 시작 불가
    private var conditionPicker: some View {
        HStack(spacing: 8) {
            ForEach(Condition.allCases) { c in
                let on = condition == c
                Button {
                    condition = c
                    Haptics.tap()
                } label: {
                    Label(c.label, systemImage: c.symbol)
                        .font(.rounded(14, .semibold))
                        .foregroundStyle(on ? .black : Palette.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? Palette.strength : Color.white.opacity(0.06),
                                    in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var finishButton: some View {
        Button {
            guard let start else { return }
            // 저장된 기록을 이어서 한 경우엔 그 기록을 갱신한다
            if let rid = drafts.draft?.resumeID, let old = ctx.model(for: rid) as? Session {
                old.lifts = lifts
                old.condition = condition ?? old.condition
                old.endAt = .now
            } else {
                let s = Session(date: start, kind: .strength, condition: condition ?? .normal,
                                lifts: lifts, startAt: start, endAt: .now)
                ctx.insert(s)
            }
            closed = true
            drafts.clear()
            onFinish?()
            stopRest()
            Haptics.success()
            dismiss()
        } label: {
            Label("운동 완료", systemImage: "checkmark.circle.fill")
                .font(.rounded(18, .bold))
                .foregroundStyle(canFinish ? .black : Palette.dimmer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(canFinish ? Palette.strength : Color.white.opacity(0.08),
                            in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!canFinish)
        .animation(.snappy, value: canFinish)
    }

    private var canFinish: Bool { start != nil && !lifts.isEmpty
    }
}

/// 방금 완료한 세트를 가리킨다
private struct JustDone: Equatable {
    let id: UUID
    let idx: Int
}

/// 방금 끝낸 세트의 실제 횟수 조정 (5×5 목표인데 4회만 했을 때 등).
/// 목표와 다르게 고치면 그 종목을 세트별 방식으로 바꿔 해당 세트만 바꾼다.
private struct DoneRepsBar: View {
    @Binding var lift: LiftEntry
    let idx: Int
    let onMemo: () -> Void
    let onClose: () -> Void

    private var value: Int {
        let l = lift.repsList
        return l.indices.contains(idx) ? l[idx] : lift.reps
    }

    private func set(_ v: Int) {
        guard v >= 0, v <= 50, lift.repsList.indices.contains(idx) else { return }
        if !lift.isVaried { lift.setVaried(true) }
        lift.setReps?[idx] = v
        Haptics.tap()
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(lift.name) \(idx + 1)세트")
                    .font(.rounded(13, .bold)).foregroundStyle(.white).lineLimit(1)
                Text("실제 횟수 · 목표 \(lift.reps)회")
                    .font(.rounded(11, .semibold)).foregroundStyle(Palette.dim)
            }
            Spacer(minLength: 4)
            step("minus") { set(value - 1) }
            Text("\(value)")
                .font(.rounded(26, .heavy)).monospacedDigit()
                .foregroundStyle(value < lift.reps ? .orange : Palette.strength)
                .frame(minWidth: 36)
                .contentTransition(.numericText())
            step("plus") { set(value + 1) }
            Button(action: onMemo) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.strength)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.dim)
                    .frame(width: 30, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardStroke, lineWidth: 1))
        .animation(.snappy, value: value)
    }

    private func step(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 36)
                .background(Color.white.opacity(0.1), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

/// 운동 중 종목 행 — 카드 전체 탭으로 세트 완료. 마지막 세트 후 RIR 입력.
private struct LiftLiveRow: View {
    @Binding var lift: LiftEntry
    /// 운동 시작 전에는 세트 완료를 막는다
    var locked = false
    let onSetDone: () -> Void
    let onSetUndone: () -> Void
    var onMemo: (() -> Void)? = nil
    let onDelete: () -> Void
    @State private var editing = false

    private var finished: Bool { lift.sets > 0 && lift.done >= lift.sets }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                LiftNameLine(lift: lift, size: 17)
                Spacer(minLength: 6)
                Text(lift.weightLabel(at: min(lift.done, max(lift.sets - 1, 0))))
                    .font(.rounded(24, .heavy)).monospacedDigit()
                    .foregroundStyle(Palette.strength)
                // 무게가 세트마다 다르면 세트 칩에 무게·횟수가 보이므로 여기선 생략
                if !lift.hasMixedWeights {
                    Text(lift.repsLabel)
                        .font(.rounded(15, .semibold)).monospacedDigit()
                        .foregroundStyle(Palette.dim)
                }
            }
            if lift.isVaried {
                VariedSetChips(lift: $lift)
            } else {
                SetDots(total: lift.sets, done: $lift.done, tint: Palette.strength,
                        size: 34, interactive: false)
            }
            if finished {
                Divider().overlay(Palette.cardStroke)
                RIRPicker(rir: $lift.rir)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(
            finished ? Palette.strength.opacity(0.5) : Palette.cardStroke, lineWidth: 1))
        .contentShape(.rect(cornerRadius: 18))
        .onTapGesture {
            guard !locked, lift.done < lift.sets else { return }
            withAnimation(.snappy(duration: 0.2)) { lift.markSetDone() }
            Haptics.tap()
            onSetDone()
        }
        .contextMenu {
            if let onMemo { Button("메모 추가", systemImage: "square.and.pencil", action: onMemo) }
            Button("정보 수정", systemImage: "pencil") { editing = true }
            Button("세트 되돌리기", systemImage: "arrow.uturn.backward") {
                if lift.done > 0 { withAnimation(.snappy) { lift.undoSet() }; onSetUndone() }
            }
            Button("세트 초기화", systemImage: "arrow.counterclockwise") {
                withAnimation(.snappy) { lift.resetSets() }
                onSetUndone()
            }
            if lift.isVaried {
                Button("같은 횟수로 기록", systemImage: "equal.square") {
                    withAnimation(.snappy) { lift.setVaried(false) }
                }
                if lift.sets > 1 {
                    Button("마지막 세트 빼기", systemImage: "minus.circle") {
                        withAnimation(.snappy) { lift.resizeSets(lift.sets - 1) }
                    }
                }
            } else {
                Button("세트별 횟수로 기록", systemImage: "list.number") {
                    withAnimation(.snappy) { lift.setVaried(true) }
                }
                if lift.sets > 1 {
                    Button("마지막 세트 빼기", systemImage: "minus.circle") {
                        withAnimation(.snappy) { lift.removeSet(at: lift.sets - 1) }
                    }
                }
            }
            Button("삭제", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .sheet(isPresented: $editing) { LiftEditSheet(lift: $lift) }
    }
}

// MARK: - 유산소 세션 (실데이터: GPS 경로 + HealthKit 심박)

struct CardioSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let mode: CardioMode
    var condition: Condition = .normal
    /// 계획에서 시작했을 때 미리 채워 넣을 인터벌 구성
    var presetInterval: IntervalEntry? = nil
    /// 기록을 저장했을 때 호출 (계획 소진)
    var onFinish: (() -> Void)? = nil

    @State private var ownStart = Date()
    @State private var iv = IntervalEntry()
    @State private var loadedPreset = false
    @State private var confirmCancel = false
    @State private var finishing = false
    @State private var hrm = HeartRateMonitor()
    private var rec: RunRecorder { RunRecorder.shared }
    private var gps: LocationTracker { rec.gps }
    private var motion: MotionTracker { rec.motion }
    private var watch: WatchLink { WatchLink.shared }

    /// 워치가 세션을 갖고 있으면 그 시작 시각을 기준으로 삼는다
    private var start: Date { watch.startedAt ?? ownStart }

    /// 워치가 측정한 거리가 있으면 그걸 쓰고, 없으면 아이폰 GPS
    private var km: Double {
        watch.meters > 0 ? watch.meters / 1000 : gps.distanceMeters / 1000
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    liveMetrics
                    RouteMap(points: gps.points, height: 230, follow: true)
                    hrSection
                    if mode == .interval { intervalCard }
                    finishButton
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("")
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { confirmCancel = true }.foregroundStyle(Palette.dim)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("운동을 취소할까요?", isPresented: $confirmCancel) {
            Button("기록 버리기", role: .destructive) { stop(); dismiss() }
            Button("계속하기", role: .cancel) { }
        }
        .onAppear {
            watch.activateIfNeeded()
            if !loadedPreset {
                loadedPreset = true
                if let p = presetInterval { iv = p }
            }
            // 워치가 이미 러닝 중이면 그 세션에 합류, 아니면 새로 시작 명령
            if !watch.running { watch.startWorkout(mode: mode) }
            let s = start
            ownStart = s
            rec.begin(at: s)          // 이미 돌고 있으면 무시된다
            hrm.begin(at: s)
        }
        .onChange(of: watch.running) { _, isRunning in
            // 워치에서 종료하면 아이폰 세션도 저장하고 닫는다
            if !isRunning && !finishing { finish() }
        }
        .onChange(of: watch.bpm) { _, _ in pushLive() }
        .onChange(of: gps.distanceMeters) { _, _ in pushLive() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.interval).frame(width: 7, height: 7)
                Text("\(mode.label) 러닝 중")
                    .font(.rounded(13, .bold)).foregroundStyle(Palette.interval)
                Spacer()
                if watch.running {
                    Image(systemName: watch.isLive ? "applewatch.radiowaves.left.and.right" : "applewatch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(watch.isLive ? WatchTint.pace : Palette.dimmer)
                }
                Text("시작 \(start.hourMinute)")
                    .font(.rounded(13, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
            }
            ElapsedTimer(start: start, size: 58, tint: WatchTint.time)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.cardStroke, lineWidth: 1))
    }

    private var liveMetrics: some View {
        HStack(alignment: .top, spacing: 0) {
            BigMetric(label: "거리", value: String(format: "%.2f", km),
                      unit: "KM", color: WatchTint.distance, size: 34)
            Spacer()
            if watch.kcal > 0 {
                BigMetric(label: "칼로리", value: "\(watch.kcal)",
                          unit: "KCAL", color: WatchTint.energy, size: 34)
                Spacer()
            }
            BigMetric(label: "평균 페이스", value: paceText,
                      unit: "/KM", color: WatchTint.pace, size: 34)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.cardStroke, lineWidth: 1))
    }

    /// 워치 실시간 값이 살아있으면 그걸 쓰고, 아니면 HealthKit 폴백
    private var liveBPM: Int { watch.isLive ? watch.bpm : hrm.current }
    private var hrSamples: [HRPoint] { watch.samples.count > hrm.samples.count ? watch.samples : hrm.samples }
    private var hrAvg: Int {
        let s = hrSamples
        return s.isEmpty ? 0 : Int(s.map(\.bpm).reduce(0,+) / Double(s.count))
    }
    private var hrPeak: Int { Int(hrSamples.map(\.bpm).max() ?? 0) }

    private var hrSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                BigMetric(label: watch.isLive ? "심박수 · 워치" : "심박수",
                          value: liveBPM > 0 ? "\(liveBPM)" : "––",
                          unit: "BPM", color: WatchTint.heart,
                          size: liveBPM > 0 ? 42 : 28)
                Spacer()
                if hrAvg > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("평균 \(hrAvg)")
                            .font(.rounded(13, .bold)).monospacedDigit()
                        Text("최고 \(hrPeak)")
                            .font(.rounded(13, .bold)).monospacedDigit()
                    }
                    .foregroundStyle(WatchTint.heart.opacity(0.8))
                }
            }
            HRChart(samples: hrSamples, height: 150)
            Text(hint)
                .font(.rounded(12, .semibold))
                .foregroundStyle(watch.isLive ? WatchTint.heart.opacity(0.8) : Palette.dimmer)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.cardStroke, lineWidth: 1))
    }

    private var hint: String {
        if watch.isLive { return "워치와 동기화 중 · 실시간 수신" }
        if watch.running && watch.pendingStart {
            return "워치에서 운동로그 앱을 열면 자동으로 시작됩니다"
        }
        if watch.running { return "워치 세션 연결됨 · 심박 대기 중" }
        if !watch.paired { return "애플워치가 페어링되어 있지 않습니다" }
        if !watch.watchAppInstalled { return "워치에 이 앱을 설치하면 실시간 심박이 나옵니다" }
        if !hrm.note.isEmpty { return hrm.note }
        return "워치 연결 대기 중"
    }

    private var paceText: String {
        guard km > 0.05 else { return "--:--" }
        return Int(Date.now.timeIntervalSince(start) / km).clockString
    }

    private var intervalCard: some View {
        CardBox {
            SectionLabel(text: "인터벌")
            StepRow(label: "고강도", value: $iv.workSeconds, step: 5, range: 5...300) { "\($0)초" }
            StepRow(label: "강도", value: $iv.intensity, step: 5, range: 50...100) { "\($0)%" }
            StepRow(label: "회복", value: $iv.restSeconds, step: 15, range: 15...600) { $0.clockString }
            StepRow(label: "회복 페이스", value: $iv.recoveryPace, step: 10, range: 180...900) { "\($0.clockString)/km" }
            StepRow(label: "세트", value: $iv.sets, step: 1, range: 1...20) { "\($0)set" }
            Divider().overlay(Palette.cardStroke)
            SectionLabel(text: "완료 세트")
            SetDots(total: iv.sets, done: $iv.done, tint: Palette.interval, size: 32)
        }
    }

    private func stop() {
        hrm.end()
        watch.stopWorkout()     // RunRecorder·LiveRun 종료 포함
    }

    /// 잠금화면 상황판 갱신
    private func pushLive() {
        let pace = km > 0.05 ? Int(Date.now.timeIntervalSince(start) / km) : 0
        LiveRun.update(startedAt: start, bpm: liveBPM, km: km,
                       pace: pace, kcal: watch.kcal, watchLive: watch.isLive)
    }

    /// 워치 + 아이폰 수집분을 하나로 합친다
    private func buildTelemetry() -> Telemetry {
        var t = watch.telemetry
        if t.hr.isEmpty {
            t.hr = hrSamples.map { MetricPoint(t: $0.t, v: $0.bpm) }
        }
        t.cadence     = motion.cadenceSeries
        t.altitude    = motion.altitudeSeries
        t.gpsSpeed    = gps.points.enumerated().compactMap { i, p in
            guard i > 0 else { return nil }
            let prev = gps.points[i-1]
            let dt = p.t - prev.t
            guard dt > 0 else { return nil }
            let d = CLLocation(latitude: prev.lat, longitude: prev.lon)
                .distance(from: CLLocation(latitude: p.lat, longitude: p.lon))
            return MetricPoint(t: p.t, v: d / dt)
        }
        t.gpsDistance = gps.distanceMeters
        // 워치 전체 시계열이 아직 안 왔어도 실시간으로 받은 값은 살린다
        if t.activeKcal == 0, watch.kcal > 0 { t.activeKcal = Double(watch.kcal) }
        if t.watchDistance == 0, watch.meters > 0 { t.watchDistance = watch.meters }
        if t.steps == 0 { t.steps = motion.steps }
        let e = RouteAnalysis.elevation(motion.altitudeSeries)
        t.elevationGain = e.gain
        t.elevationLoss = e.loss
        t.splits = RouteAnalysis.splits(route: gps.points, hr: t.hr, totalMeters: t.distance)
        return t
    }

    private func finish() {
        guard !finishing else { return }
        finishing = true
        stop()
        let tele = buildTelemetry()
            let s = Session(date: start, kind: .interval, condition: condition,
                            interval: mode == .interval ? iv : nil,
                            startAt: start, endAt: .now,
                            cardioMode: mode,
                            route: gps.points, hr: hrSamples,
                            distanceMeters: tele.distance,
                            telemetry: tele)
        s.watchSessionID = watch.sessionID
        ctx.insert(s)
        onFinish?()
        Haptics.success()
        RunRecorder.shared.reset()
        dismiss()
    }

    private var finishButton: some View {
        Button { finish() } label: {
            Label("운동 완료", systemImage: "checkmark.circle.fill")
                .font(.rounded(18, .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Palette.interval, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
