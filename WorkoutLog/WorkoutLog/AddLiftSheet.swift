import SwiftUI
import SwiftData

struct AddLiftSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (LiftEntry) -> Void
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]
    /// 종목별 목표 휴식의 기본값 (운동 중 휴식 조정으로 바뀌는 그 값)
    @AppStorage("rest.seconds") private var defaultRest = 120
    @State private var rest: Int?

    private typealias Preset = (name: String, weight: Double, sets: Int, reps: Int, bw: Bool, uni: Bool, rest: Int?)
    /// 지난 기록에 있는 종목(최근 순, 마지막 무게·세트·횟수) + 기본 목록 중 아직 없는 것
    private var presetItems: [Preset] {
        func key(_ n: String) -> String { n.trimmingCharacters(in: .whitespaces).lowercased() }
        var seen = Set<String>()
        var out: [Preset] = []
        for s in sessions where s.kind == .strength {
            for l in s.lifts where seen.insert(key(l.name)).inserted {
                out.append((l.name, l.weight, l.sets, l.reps, l.isBW, l.isUnilateral, l.restSec))
            }
        }
        for p in LiftPreset.all where seen.insert(key(p.name)).inserted {
            out.append((p.name, p.weight, p.sets, p.reps, p.bw, false, nil))
        }
        return out
    }

    @State private var name = ""
    @State private var weight = 20.0
    @State private var sets = 3
    @State private var reps = 8
    @State private var setReps: [Int]? = nil
    @State private var setWeights: [Double]? = nil
    @State private var isBW = false
    @State private var isUni = false

    /// 세트·횟수 편집기에 넘기는 임시 LiftEntry
    private var draft: Binding<LiftEntry> {
        Binding(
            get: { LiftEntry(name: name, weight: weight, sets: sets, reps: reps,
                             bw: isBW, setReps: setReps, setWeights: setWeights, uni: isUni) },
            set: { sets = $0.sets; reps = $0.reps; setReps = $0.setReps
                   weight = $0.weight; setWeights = $0.setWeights }
        )
    }
    private var totalReps: Int { draft.wrappedValue.repsList.reduce(0, +) }
    /// 세트별 무게 × 횟수 합 (한쪽 보정 없음)
    private var totalLoad: Double {
        let d = draft.wrappedValue
        return d.repsList.enumerated().reduce(0) { $0 + d.weightAt($1.offset) * Double($1.element) }
    }
    @FocusState private var nameFocused: Bool

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    presets

                    CardBox {
                        SectionLabel(text: "종목")
                        TextField("종목 이름", text: $name)
                            .font(.rounded(18, .semibold))
                            .foregroundStyle(.white)
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }

                    LiftHistoryCard(name: name)

                    CardBox {
                        Toggle(isOn: Binding(get: { isBW }, set: { on in
                            withAnimation(.snappy) {
                                isBW = on
                                if on { weight = 0; setWeights = nil }   // 맨몸은 추가 중량 +0 에서 시작
                            }
                        })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("맨몸 운동")
                                    .font(.rounded(15, .semibold))
                                    .foregroundStyle(.white)
                                Text(isBW ? "무게는 추가로 단 중량" : "바벨·머신 중량")
                                    .font(.rounded(11, .medium))
                                    .foregroundStyle(Palette.dimmer)
                            }
                        }
                        .tint(Palette.strength)
                        Toggle(isOn: $isUni.animation(.snappy)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("한쪽씩 (원암·원레그)")
                                    .font(.rounded(15, .semibold))
                                    .foregroundStyle(.white)
                                Text("무게·횟수는 한쪽 기준")
                                    .font(.rounded(11, .medium))
                                    .foregroundStyle(Palette.dimmer)
                            }
                        }
                        .tint(Palette.strength)
                        Divider().overlay(Palette.cardStroke)

                        if !draft.wrappedValue.isVaried {
                            HStack {
                                Text(isBW ? "추가 중량" : "무게")
                                    .font(.rounded(15, .medium))
                                    .foregroundStyle(Palette.dim)
                                Spacer()
                                WeightField(weight: $weight, bw: isBW, size: 30, showsUnit: false)
                                Text("kg")
                                    .font(.rounded(13, .semibold))
                                    .foregroundStyle(Palette.dimmer)
                                Stepper("", value: $weight, in: 0...400, step: 2.5)
                                    .labelsHidden().scaleEffect(0.88).frame(width: 86)
                            }
                            Divider().overlay(Palette.cardStroke)
                        }
                        SetRepsEditor(lift: draft)
                        Divider().overlay(Palette.cardStroke)
                        StepRow(label: "목표 휴식",
                                value: Binding(get: { rest ?? defaultRest }, set: { rest = $0 }),
                                step: 15, range: 15...600, format: { $0.hmsString })

                        HStack {
                            Text("볼륨").font(.rounded(13, .medium)).foregroundStyle(Palette.dim)
                            Spacer()
                            Text(isBW && draft.wrappedValue.weight == 0
                                 ? "\(totalReps)회"
                                 : "\(Int(totalLoad).formatted()) kg")
                                .font(.rounded(17, .bold)).monospacedDigit()
                                .foregroundStyle(Palette.strength)
                        }
                    }
                }
                .padding(18)
            }
            .background(Palette.bg)
            .navigationTitle("종목 추가")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.foregroundStyle(Palette.dim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        onAdd(LiftEntry(name: name.trimmingCharacters(in: .whitespaces),
                                        weight: weight, sets: sets, reps: reps, bw: isBW,
                                        setReps: setReps, setWeights: setWeights, uni: isUni ? true : nil,
                                        restSec: rest ?? defaultRest))
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
        .presentationDetents([.large])
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "자주 하는 종목")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetItems, id: \.name) { p in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                name = p.name; weight = p.weight
                                sets = p.sets; reps = p.reps; isBW = p.bw; setReps = nil; setWeights = nil; isUni = p.uni
                                rest = p.rest
                            }
                            Haptics.tap()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.name)
                                    .font(.rounded(14, .bold))
                                    .foregroundStyle(name == p.name ? .black : .white)
                                Text("\(LiftEntry(name: p.name, weight: p.weight, sets: p.sets, reps: p.reps, bw: p.bw, uni: p.uni).weightText) \(p.sets)×\(p.reps)")
                                    .font(.rounded(11, .semibold)).monospacedDigit()
                                    .foregroundStyle(name == p.name ? .black.opacity(0.6) : Palette.dimmer)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(name == p.name ? Palette.strength : Color.white.opacity(0.07),
                                        in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - 지난 기록

/// 입력한 종목 이름과 같은 과거 기록을 최근 순으로 보여준다.
private struct LiftHistoryCard: View {
    let name: String
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    private struct Row: Identifiable {
        let id: UUID
        let day: Date
        let lift: LiftEntry
    }

    private var rows: [Row] {
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return [] }
        var out: [Row] = []
        for s in sessions where s.kind == .strength {
            for l in s.lifts where l.name.trimmingCharacters(in: .whitespaces).lowercased() == key {
                out.append(Row(id: l.id, day: s.logicalDay, lift: l))
            }
            if out.count >= 3 { break }
        }
        return Array(out.prefix(3))
    }

    var body: some View {
        let list = rows
        if !list.isEmpty {
            CardBox {
                SectionLabel(text: "지난 기록")
                ForEach(Array(list.enumerated()), id: \.element.id) { i, r in
                    if i > 0 { Divider().overlay(Palette.cardStroke) }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(r.day.monthDay) (\(r.day.weekdayShort))")
                            .font(.rounded(13, .semibold)).monospacedDigit()
                            .foregroundStyle(i == 0 ? .white : Palette.dim)
                            .frame(width: 70, alignment: .leading)
                        Text(r.lift.weightText)
                            .font(.rounded(i == 0 ? 18 : 15, .heavy)).monospacedDigit()
                            .foregroundStyle(i == 0 ? Palette.strength : Palette.dim)
                        Spacer(minLength: 6)
                        Text(r.lift.repsDetail)
                            .font(.rounded(13, .semibold)).monospacedDigit()
                            .foregroundStyle(i == 0 ? .white : Palette.dim)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
            .transition(.opacity)
        }
    }
}
