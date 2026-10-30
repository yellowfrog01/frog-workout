import SwiftUI

// MARK: - 종목 배지 (BW · 한쪽)

struct LiftBadges: View {
    let badges: [String]
    var size: CGFloat = 10

    init(_ lift: LiftEntry, size: CGFloat = 10) {
        badges = lift.badges
        self.size = size
    }
    init(badges: [String], size: CGFloat = 10) {
        self.badges = badges
        self.size = size
    }

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: 3) {
                ForEach(badges, id: \.self) { b in
                    Text(b)
                        .font(Font.rounded(size, .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, size * 0.45)
                        .padding(.vertical, size * 0.12)
                        .background(Palette.strength.opacity(0.85), in: .capsule)
                        .fixedSize(horizontal: true, vertical: true)
                }
            }
        }
    }
}

/// 이름 + 배지 한 줄
struct LiftNameLine: View {
    let lift: LiftEntry
    var size: CGFloat
    var weight: Font.Weight = .bold
    var color: Color = .white

    var body: some View {
        HStack(spacing: 5) {
            Text(lift.name)
                .font(.rounded(size, weight))
                .foregroundStyle(color)
                .lineLimit(1)
            LiftBadges(lift, size: max(9, size * 0.62))
        }
    }
}

// MARK: - 세트·횟수 입력

/// 기본은 "N세트 × M회". 토글하면 세트별 횟수(8-8-7-7)로 입력한다.
struct SetRepsEditor: View {
    @Binding var lift: LiftEntry

    var body: some View {
        VStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { lift.isVaried },
                set: { v in withAnimation(.snappy) { lift.setVaried(v) } }
            )) {
                Text("세트별 무게·횟수 다르게")
                    .font(.rounded(14, .medium))
                    .foregroundStyle(Palette.dim)
            }
            .tint(Palette.strength)

            StepRow(label: "세트",
                    value: Binding(get: { lift.sets }, set: { lift.resizeSets($0) }),
                    step: 1, range: 1...12) { "\($0)세트" }

            if lift.isVaried {
                ForEach(0..<lift.repsList.count, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text("\(i + 1)세트")
                            .font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
                        Spacer(minLength: 0)
                        WeightField(weight: Binding(get: { lift.weightAt(i) },
                                                    set: { lift.setWeight($0, at: i) }),
                                    bw: lift.isBW, size: 17, showsUnit: true)
                        Text("\(repsBinding(i).wrappedValue)회")
                            .font(.rounded(15, .semibold)).monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(minWidth: 38, alignment: .trailing)
                        Stepper("", value: repsBinding(i), in: 0...50)
                            .labelsHidden().scaleEffect(0.8).frame(width: 78)
                        // 이 세트만 삭제
                        if lift.sets > 1 {
                            Button {
                                withAnimation(.snappy) { lift.removeSet(at: i) }
                                Haptics.tap()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                StepRow(label: "횟수", value: $lift.reps, step: 1, range: 1...50) { "\($0)회" }
            }
        }
    }

    private func repsBinding(_ i: Int) -> Binding<Int> {
        Binding(
            get: {
                let l = lift.repsList
                return i < l.count ? l[i] : lift.reps
            },
            set: { v in
                var l = lift.repsList
                guard i < l.count else { return }
                l[i] = v
                lift.setReps = l
            }
        )
    }
}

// MARK: - 무게 직접 입력

/// 무게. 숫자를 눌러 직접 입력한다 (2.5 단위에 안 맞는 덤벨 12kg·원판·조끼 무게 등).
/// 맨몸이면 앞에 "+" (추가 중량). 옆의 스테퍼(2.5 단위)도 그대로 쓸 수 있다.
struct WeightField: View {
    @Binding var weight: Double
    var bw = false
    var size: CGFloat = 24
    var showsUnit = true
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            if bw { Text("+") }
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .multilineTextAlignment(.trailing)
                .fixedSize()
                .padding(.horizontal, 4)
                .background(focused ? Color.white.opacity(0.1) : .clear, in: .rect(cornerRadius: 6))
            if showsUnit { Text("kg") }
        }
        .font(.rounded(size, .heavy)).monospacedDigit()
        .foregroundStyle(Palette.strength)
        .onAppear { text = weight.trimmed }
        .onChange(of: text) {
            let t = text.replacingOccurrences(of: ",", with: ".")
            if t.isEmpty { weight = 0 }
            else if let v = Double(t), v >= 0, v <= 400 { weight = v }
        }
        .onChange(of: weight) { if !focused { text = weight.trimmed } }
        .onChange(of: focused) { if !focused { text = weight.trimmed } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focused {
                    Spacer()
                    Button("완료") { focused = false }.foregroundStyle(Palette.strength)
                }
            }
        }
    }
}

// MARK: - RIR 입력

/// 마지막 세트 RIR. 같은 값을 다시 누르면 해제.
struct RIRPicker: View {
    @Binding var rir: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RIR")
                .font(.rounded(13, .semibold))
                .foregroundStyle(Palette.dim)
            HStack(spacing: 6) {
                ForEach(0...4, id: \.self) { v in
                    let on = rir == v
                    Button {
                        withAnimation(.snappy(duration: 0.15)) { rir = on ? nil : v }
                        Haptics.tap()
                    } label: {
                        Text(v == 4 ? "4+" : "\(v)")
                            .font(.rounded(16, .bold)).monospacedDigit()
                            .foregroundStyle(on ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(on ? Palette.strength : Color.white.opacity(0.08),
                                        in: .rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 운동 중 세트별 칩

/// 세트별 방식일 때: 칩 = 그 세트의 횟수. 칩을 누르면 횟수를 고친다.
/// 완료 표시는 카드 전체 탭으로 한다 (기존 방식과 같음).
struct VariedSetChips: View {
    @Binding var lift: LiftEntry
    var size: CGFloat = 34

    var body: some View {
        let list = lift.repsList
        let mixed = lift.hasMixedWeights
        let s = list.count > 6 ? size * 0.82 : size
        HStack(spacing: 7) {
            ForEach(Array(list.enumerated()), id: \.offset) { i, n in
                Menu {
                    Picker("\(i + 1)세트 횟수", selection: repsBinding(i)) {
                        ForEach(0...30, id: \.self) { Text("\($0)회").tag($0) }
                    }
                    Button("무게 +2.5kg (\(i + 1)세트부터)", systemImage: "plus") {
                        withAnimation(.snappy(duration: 0.2)) { lift.shiftWeight(from: i, by: 2.5) }
                        Haptics.tap()
                    }
                    Button("무게 −2.5kg (\(i + 1)세트부터)", systemImage: "minus") {
                        withAnimation(.snappy(duration: 0.2)) { lift.shiftWeight(from: i, by: -2.5) }
                        Haptics.tap()
                    }
                    if lift.sets > 1 {
                        Button("\(i + 1)세트 삭제", systemImage: "trash", role: .destructive) {
                            withAnimation(.snappy(duration: 0.2)) { lift.removeSet(at: i) }
                            Haptics.tap()
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        if mixed {
                            Text(i == 0 || lift.weightAt(i) != lift.weightAt(i - 1) ? lift.weightAt(i).trimmed : " ")
                                .font(.rounded(10, .semibold)).monospacedDigit()
                                .foregroundStyle(Palette.dim)
                                .lineLimit(1).fixedSize()
                                .frame(width: s)
                        }
                        chip(n, filled: i < lift.done, size: s)
                    }
                }
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) { lift.resizeSets(lift.sets + 1) }
                Haptics.tap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: s * 0.36, weight: .bold))
                    .foregroundStyle(Palette.dim)
                    .frame(width: s, height: s)
                    .background(Circle().strokeBorder(Color.white.opacity(0.18),
                                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
            }
            .buttonStyle(.plain)
            .disabled(lift.sets >= 12)
            Spacer(minLength: 0)
            Text("\(lift.done)/\(lift.sets)")
                .font(.rounded(12, .semibold)).monospacedDigit()
                .foregroundStyle(lift.done == lift.sets ? Palette.strength : Palette.dimmer)
        }
    }

    private func chip(_ n: Int, filled: Bool, size: CGFloat) -> some View {
        Text("\(n)")
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(filled ? .black : .white)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? Palette.strength : .clear))
            .overlay(Circle().strokeBorder(filled ? Palette.strength : Color.white.opacity(0.18),
                                           lineWidth: 2))
    }

    private func repsBinding(_ i: Int) -> Binding<Int> {
        Binding(
            get: {
                let l = lift.repsList
                return i < l.count ? l[i] : lift.reps
            },
            set: { v in
                var l = lift.repsList
                guard i < l.count else { return }
                l[i] = v
                lift.setReps = l
                Haptics.tap()
            }
        )
    }
}

// MARK: - 운동 중 종목 정보 수정

/// 이름·무게·맨몸·한쪽·세트/횟수·RIR 을 고친다. 저장을 눌러야 반영된다.
struct LiftEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var lift: LiftEntry
    @State private var draft: LiftEntry
    @AppStorage("rest.seconds") private var defaultRest = 120

    init(lift: Binding<LiftEntry>) {
        _lift = lift
        _draft = State(initialValue: lift.wrappedValue)
    }

    private var valid: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CardBox {
                        SectionLabel(text: "종목")
                        TextField("종목 이름", text: $draft.name)
                            .font(.rounded(18, .semibold))
                            .foregroundStyle(.white)
                    }

                    CardBox {
                        Toggle(isOn: Binding(get: { draft.isBW },
                                             set: { on in
                                                 draft.bw = on ? true : nil
                                                 if on { draft.weight = 0; draft.setWeights = nil }
                                             })) {
                            Text("맨몸 운동").font(.rounded(15, .semibold)).foregroundStyle(.white)
                        }
                        .tint(Palette.strength)
                        Toggle(isOn: Binding(get: { draft.isUnilateral },
                                             set: { draft.uni = $0 ? true : nil })) {
                            Text("한쪽씩 (원암·원레그)").font(.rounded(15, .semibold)).foregroundStyle(.white)
                        }
                        .tint(Palette.strength)
                        Divider().overlay(Palette.cardStroke)

                        if !draft.isVaried {
                            HStack {
                                Text(draft.isBW ? "추가 중량" : "무게")
                                    .font(.rounded(15, .medium)).foregroundStyle(Palette.dim)
                                Spacer()
                                WeightField(weight: $draft.weight, bw: draft.isBW, size: 24)
                                Stepper("", value: $draft.weight, in: 0...400, step: 2.5)
                                    .labelsHidden().scaleEffect(0.88).frame(width: 86)
                            }
                            Divider().overlay(Palette.cardStroke)
                        }
                        SetRepsEditor(lift: $draft)
                        Divider().overlay(Palette.cardStroke)
                        StepRow(label: "목표 휴식",
                                value: Binding(get: { draft.restSec ?? defaultRest },
                                               set: { draft.restSec = $0 }),
                                step: 15, range: 15...600, format: { $0.hmsString })
                    }

                    CardBox {
                        RIRPicker(rir: $draft.rir)
                    }
                }
                .padding(18)
            }
            .background(Palette.bg)
            .navigationTitle("종목 수정")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
                        lift = draft
                        Haptics.success()
                        dismiss()
                    }
                    .font(.rounded(16, .bold))
                    .foregroundStyle(valid ? Palette.strength : Palette.dimmer)
                    .disabled(!valid)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
