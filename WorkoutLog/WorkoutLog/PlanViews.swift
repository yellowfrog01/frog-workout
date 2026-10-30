import SwiftUI
import SwiftData

/// 운동 탭 위쪽에 붙는 예정 운동 목록
struct PlanSection: View {
    let plans: [PlannedWorkout]
    let onStart: (PlannedWorkout) -> Void
    @State private var detail: PlannedWorkout?

    private var head: [PlannedWorkout] { Array(plans.prefix(3)) }

    var body: some View {
        if !plans.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "예정")
                    Spacer()
                    if plans.count > head.count {
                        NavigationLink { PlanListView(onStart: onStart) } label: {
                            HStack(spacing: 3) {
                                Text("전체 \(plans.count)")
                                    .font(.rounded(12, .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(Palette.strength)
                        }
                    }
                }
                .padding(.horizontal, 4)
                ForEach(head) { p in
                    Button { detail = p } label: { PlanRow(plan: p) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
            .sheet(item: $detail) { p in
                PlanDetailSheet(plan: p, onStart: onStart)
            }
        }
    }
}

/// 예정 운동 한 줄
struct PlanRow: View {
    let plan: PlannedWorkout
    private var tint: Color { plan.kind == .strength ? Palette.strength : Palette.interval }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 2) {
                Text(plan.date.monthDay)
                    .font(.rounded(15, .bold)).monospacedDigit()
                    .foregroundStyle(plan.isOverdue ? Palette.dim : .white)
                Text(plan.date.weekdayShort)
                    .font(.rounded(11, .semibold))
                    .foregroundStyle(Palette.dimmer)
            }
            .frame(width: 46)

            Rectangle()
                .fill(tint.opacity(plan.isOverdue ? 0.2 : 0.5))
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: plan.kind.symbol)
                        .font(.system(size: 11, weight: .bold))
                    Text(plan.title)
                        .font(.rounded(14, .bold))
                    Spacer(minLength: 0)
                    Text(plan.whenLabel)
                        .font(.rounded(11, .bold))
                        .foregroundStyle(plan.daysAway == 0 ? .black : Palette.dim)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(plan.daysAway == 0 ? tint : Color.white.opacity(0.09), in: .capsule)
                }
                .foregroundStyle(plan.isOverdue ? Palette.dim : tint)

                Text(plan.spec)
                    .font(.rounded(12, .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.dim)
                if let t = plan.programTitle {
                    Text("\(t) · \(plan.week)주차")
                        .font(.rounded(11, .medium))
                        .foregroundStyle(Palette.dimmer)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.dimmer)
        }
        .padding(14)
        .background(Palette.card, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(plan.daysAway == 0 ? tint.opacity(0.5) : Palette.cardStroke,
                        style: StrokeStyle(lineWidth: 1, dash: plan.daysAway == 0 ? [] : [4, 3]))
        )
    }
}

/// 예정 운동 상세 — 여기서 바로 시작하거나 지운다
struct PlanDetailSheet: View {
    let plan: PlannedWorkout
    let onStart: (PlannedWorkout) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var confirmDeleteProgram = false
    private var tint: Color { plan.kind == .strength ? Palette.strength : Palette.interval }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CardBox {
                        HStack(spacing: 8) {
                            Image(systemName: plan.kind.symbol)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 28, height: 28)
                                .background(tint, in: .rect(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title).font(.rounded(18, .heavy)).foregroundStyle(.white)
                                Text(plan.date.fullKorean)
                                    .font(.rounded(12, .semibold)).foregroundStyle(Palette.dim)
                            }
                            Spacer(minLength: 0)
                        }
                        if let t = plan.programTitle {
                            TagChip("\(t) · \(plan.week)주차", tint)
                        }
                        if !plan.note.isEmpty {
                            Text(plan.note)
                                .font(.rounded(13, .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if plan.kind == .strength {
                        CardBox {
                            SectionLabel(text: "종목")
                            ForEach(plan.lifts) { l in
                                HStack(spacing: 6) {
                                    LiftNameLine(lift: l, size: 14, weight: .semibold, color: .white)
                                    Spacer(minLength: 4)
                                    Text("\(l.weightLabel) \(l.repsLabel)")
                                        .font(.rounded(13, .semibold)).monospacedDigit()
                                        .foregroundStyle(Palette.dim)
                                }
                            }
                        }
                    } else {
                        CardBox {
                            SectionLabel(text: "구성")
                            Text(plan.spec)
                                .font(.rounded(16, .heavy)).monospacedDigit()
                                .foregroundStyle(tint)
                        }
                    }

                    startButton
                    deleteButtons
                }
                .padding(18).padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("예정 운동")
            .toolbarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }.foregroundStyle(Palette.dim)
                }
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog("이 프로그램의 남은 계획을 모두 지울까요?",
                            isPresented: $confirmDeleteProgram, titleVisibility: .visible) {
            Button("모두 삭제", role: .destructive) { deleteProgram() }
            Button("취소", role: .cancel) { }
        }
    }

    private var startButton: some View {
        Button {
            let p = plan
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onStart(p) }
        } label: {
            Label("이 계획으로 시작", systemImage: "play.fill")
                .font(.rounded(18, .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(tint, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var deleteButtons: some View {
        VStack(spacing: 8) {
            Button {
                ctx.delete(plan)
                try? ctx.save()
                dismiss()
            } label: {
                Text("이 날 계획 삭제")
                    .font(.rounded(15, .semibold))
                    .foregroundStyle(Palette.interval)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.interval.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            if plan.programID != nil {
                Button { confirmDeleteProgram = true } label: {
                    Text("이 프로그램 전체 삭제")
                        .font(.rounded(13, .semibold))
                        .foregroundStyle(Palette.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deleteProgram() {
        guard let pid = plan.programID else { return }
        let all = (try? ctx.fetch(FetchDescriptor<PlannedWorkout>())) ?? []
        for p in all where p.programID == pid && p.startedAt == nil {
            ctx.delete(p)
        }
        try? ctx.save()
        dismiss()
    }
}

/// 예정 운동 전체 목록
struct PlanListView: View {
    let onStart: (PlannedWorkout) -> Void
    @Environment(\.modelContext) private var ctx
    @Query(sort: \PlannedWorkout.date) private var plans: [PlannedWorkout]
    @State private var detail: PlannedWorkout?

    private var pending: [PlannedWorkout] { plans.filter { !$0.isDone } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if pending.isEmpty {
                    Text("예정된 운동이 없습니다")
                        .font(.rounded(14, .semibold))
                        .foregroundStyle(Palette.dimmer)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
                ForEach(pending) { p in
                    Button { detail = p } label: { PlanRow(plan: p) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("삭제", systemImage: "trash", role: .destructive) {
                                ctx.delete(p)
                            }
                        }
                }
            }
            .padding(18).padding(.bottom, 30)
        }
        .background(Palette.bg)
        .navigationTitle("예정 운동")
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .sheet(item: $detail) { p in PlanDetailSheet(plan: p, onStart: onStart) }
    }
}
