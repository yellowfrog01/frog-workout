import SwiftUI
import SwiftData

/// 사이드바 항목
enum MacSection: String, CaseIterable, Identifiable {
    case records, calendar, status, body, sync
    var id: String { rawValue }
    var label: String {
        switch self {
        case .records: "기록"
        case .calendar: "달력"
        case .status: "상태"
        case .body: "체성분"
        case .sync: "동기화"
        }
    }
    var symbol: String {
        switch self {
        case .records: "list.bullet.rectangle"
        case .calendar: "calendar"
        case .status: "chart.bar.xaxis"
        case .body: "scalemass"
        case .sync: "icloud"
        }
    }
}

/// 앱 전역 화면 상태. 메뉴 명령(⌘N)과 화면이 공유한다.
@Observable
final class MacNav {
    var section: MacSection = .records
    /// 새 기록 시트를 띄울 날짜. nil 이면 닫힘. ⌘N, 달력의 "추가" 버튼이 채운다.
    var newRecordDay: Date?
    /// 기록 화면에서 선택된 세션
    var selectedSession: PersistentIdentifier?
}

struct MacRootView: View {
    @Environment(MacNav.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        NavigationSplitView {
            List(MacSection.allCases, selection: $nav.section) { s in
                Label(s.label, systemImage: s.symbol)
                    .font(.rounded(15, .semibold))
                    .tag(s)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 220)
        } detail: {
            Group {
                switch nav.section {
                case .records: MacRecordsView()
                case .calendar: MacCalendarView()
                case .status: MacStatusView()
                case .body: MacBodyView()
                case .sync: SyncSettingsView(showsClose: false)
                }
            }
            .background(Palette.bg)
        }
        .sheet(item: $nav.newRecordDay) { day in
            NewRecordSheet(day: day)
        }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}
