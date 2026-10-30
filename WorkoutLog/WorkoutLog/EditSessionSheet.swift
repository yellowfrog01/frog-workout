import SwiftUI
import SwiftData

/// 과거 기록 편집 · 삭제
struct EditSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var session: Session

    // 취소를 지원하려고 로컬 사본에서 편집한 뒤 저장 시에만 반영
    @State private var date: Date = .now
    @State private var startAt: Date = .now
    @State private var endAt: Date = .now
    @State private var hasTimes = false
    @State private var condition: Condition = .normal
    @State private var lifts: [LiftEntry] = []
    @State private var interval = IntervalEntry()
    @State private var note = ""
    @State private var showAddLift = false
    @State private var confirmDelete = false
    @State private var loaded = false

    private var tint: Color {
        switch session.kind {
        case .strength: Palette.strength
        case .interval: Palette.interval
        case .activity: Palette.activity
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CardBox {
                        HStack {
                            Image(systemName: session.kind == .activity
                                  ? ActivityPreset.symbol(for: session.activityName ?? "") : session.kind.symbol)
                                .font(.system(size: 15, weight: .semibold))
                            Text(session.kind == .activity
                                 ? (session.activityName ?? session.kind.label) : session.kind.label)
                                .font(.rounded(17, .bold))
                            Spacer()
                        }
                        .foregroundStyle(tint)

                        DatePicker("날짜", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .font(.rounded(15, .medium))
                            .tint(tint)

                        Toggle(isOn: $hasTimes.animation(.snappy)) {
                            Text("시작·종료 시각")
                                .font(.rounded(15, .medium))
                                .foregroundStyle(Palette.dim)
                        }
                        .tint(tint)

                        if hasTimes {
                            DatePicker("시작", selection: $startAt, displayedComponents: .hourAndMinute)
                                .font(.rounded(15, .medium)).tint(tint)
                            DatePicker("종료", selection: $endAt, displayedComponents: .hourAndMinute)
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
                                       title: \.label, tint: Palette.condition)
                        }
                    }

                    if session.kind == .activity {
                        activityBlock
                    } else if session.kind == .strength {
                        strengthBlock
                    } else if session.cardioMode == .interval || session.interval != nil {
                        intervalBlock
                    } else {
                        steadyBlock
                    }

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("이 기록 삭제", systemImage: "trash")
                            .font(.rounded(16, .bold))
                            .foregroundStyle(Color(red: 0.98, green: 0.35, blue: 0.31))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.98, green: 0.35, blue: 0.31).opacity(0.13),
                                        in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("기록 편집")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { commit() }
                        .font(.rounded(16, .bold))
                        .foregroundStyle(tint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddLift) {
            AddLiftSheet { lifts.append($0) }
        }
        .alert("기록을 삭제할까요?", isPresented: $confirmDelete) {
            Button("삭제", role: .destructive) {
                ctx.delete(session)
                Haptics.success()
                dismiss()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("되돌릴 수 없습니다.")
        }
        .onAppear {
            guard !loaded else { return }
            date = session.date
            condition = session.condition
            lifts = session.lifts
            interval = session.interval ?? IntervalEntry()
            note = session.note
            startAt = session.startAt ?? session.date
            endAt = session.endAt ?? session.date
            hasTimes = session.startAt != nil
            loaded = true
        }
    }

    // MARK: - 근력

    @ViewBuilder
    private var strengthBlock: some View {
        VStack(spacing: 12) {
            ForEach($lifts) { $lift in
                LiftEditRow(lift: $lift) {
                    withAnimation(.snappy) { lifts.removeAll { $0.id == lift.id } }
                }
            }

            Button {
                showAddLift = true
                Haptics.tap()
            } label: {
                Label("종목 추가", systemImage: "plus.circle.fill")
                    .font(.rounded(15, .semibold))
                    .foregroundStyle(Palette.strength)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Palette.strength.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if !lifts.isEmpty {
                HStack {
                    Text("총 볼륨").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                    Spacer()
                    Text("\(Int(lifts.reduce(0) { $0 + $1.volume }).formatted()) kg")
                        .font(.rounded(17, .bold)).monospacedDigit()
                        .foregroundStyle(Palette.strength)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 기타 운동

    @ViewBuilder
    private var activityBlock: some View {
        CardBox {
            SectionLabel(text: "메모")
            TextField("메모 (선택)", text: $note, axis: .vertical)
                .font(.rounded(16, .medium))
                .foregroundStyle(.white)
                .lineLimit(1...4)
        }
    }

    // MARK: - 일반 유산소 (인터벌 설정 없음)

    @ViewBuilder
    private var steadyBlock: some View {
        CardBox {
            SectionLabel(text: "기록 요약")
            row("거리", String(format: "%.2f km", session.distanceKm))
            if let p = session.avgPace { row("평균 페이스", "\(p.clockString)/km") }
            if session.avgHR > 0 { row("평균 심박", "\(session.avgHR) bpm") }
            if session.peakHR > 0 { row("최고 심박", "\(session.peakHR) bpm") }
            if session.telemetry.activeKcal > 0 {
                row("활동 칼로리", "\(Int(session.telemetry.activeKcal)) kcal")
            }
            Text("측정값은 편집할 수 없습니다. 날짜·시각·컨디션만 수정됩니다.")
                .font(.rounded(11, .medium)).foregroundStyle(Palette.dimmer)
        }
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
            Spacer()
            Text(v).font(.rounded(16, .bold)).monospacedDigit().foregroundStyle(.white)
        }
    }

    // MARK: - 인터벌

    @ViewBuilder
    private var intervalBlock: some View {
        CardBox {
            StepRow(label: "고강도", value: $interval.workSeconds,
                    step: 5, range: 5...300, format: { "\($0)초" })
            StepRow(label: "강도", value: $interval.intensity,
                    step: 5, range: 50...100, format: { "\($0)%" })
            StepRow(label: "회복", value: $interval.restSeconds,
                    step: 15, range: 15...600, format: { $0.clockString })
            StepRow(label: "회복 페이스", value: $interval.recoveryPace,
                    step: 10, range: 180...900, format: { "\($0.clockString)/km" })
            StepRow(label: "세트", value: $interval.sets,
                    step: 1, range: 1...20, format: { "\($0)set" })
            Divider().overlay(Palette.cardStroke)
            SectionLabel(text: "완료 세트")
            SetDots(total: interval.sets, done: $interval.done, tint: Palette.interval)
        }
    }

    private func commit() {
        session.date = date
        session.condition = condition
        if hasTimes {
            // 날짜는 date, 시각은 픽커 값으로 합성
            session.startAt = merge(day: date, time: startAt)
            session.endAt = merge(day: date, time: endAt)
        } else {
            session.startAt = nil
            session.endAt = nil
        }
        if session.kind == .activity {
            session.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            // 자정을 넘기는 운동: 종료가 시작 이하이면 다음 날로
            if let s = session.startAt, let e = session.endAt, e <= s {
                session.endAt = Calendar.current.date(byAdding: .day, value: 1, to: e)
            }
        } else if session.kind == .strength {
            session.lifts = lifts
        } else if session.cardioMode == .interval || session.interval != nil {
            session.interval = interval
        }
        Haptics.success()
        dismiss()
    }

    /// 날짜는 day에서, 시/분은 time에서 가져와 합성
    private func merge(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? day
    }
}

// MARK: - 편집 가능한 종목 행

private struct LiftEditRow: View {
    @Binding var lift: LiftEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("종목", text: $lift.name)
                    .font(.rounded(16, .bold))
                    .foregroundStyle(.white)
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.dimmer)
                }
                .buttonStyle(.plain)
            }

            if !lift.isVaried {
                HStack {
                    Text(lift.isBW ? "추가 중량" : "무게")
                        .font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
                    Spacer()
                    WeightField(weight: $lift.weight, bw: lift.isBW, size: 22)
                    Stepper("", value: $lift.weight, in: 0...400, step: 2.5)
                        .labelsHidden().scaleEffect(0.86).frame(width: 84)
                }
            }

            Toggle(isOn: Binding(get: { lift.isBW },
                                 set: { on in
                                     lift.bw = on ? true : nil
                                     if on { lift.weight = 0; lift.setWeights = nil }
                                 })) {
                Text("맨몸 운동")
                    .font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
            }
            .tint(Palette.strength)

            Toggle(isOn: Binding(get: { lift.isUnilateral },
                                 set: { lift.uni = $0 ? true : nil })) {
                Text("한쪽씩 (원암·원레그)")
                    .font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
            }
            .tint(Palette.strength)

            SetRepsEditor(lift: $lift)

            SetDots(total: lift.sets, done: $lift.done, tint: Palette.strength)

            RIRPicker(rir: $lift.rir)
        }
        .padding(14)
        .background(Palette.card, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardStroke, lineWidth: 1))
    }
}
