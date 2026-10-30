import SwiftUI

struct RootTabs: View {
    /// 진행 중인 근력 운동이 있으면 운동 탭에서 시작한다 (앱이 꺼졌다 켜져도 바로 이어서)
    @State private var tab = StrengthDraftStore.shared.draft?.start != nil ? 1 : 0

    var body: some View {
        TabView(selection: $tab) {
            StatusView()
                .tabItem { Label("상태", systemImage: "person.crop.circle.badge.checkmark") }
                .tag(0)
            MainView()
                .tabItem { Label("운동", systemImage: "figure.run") }
                .tag(1)
        }
        .tint(Palette.strength)
        .preferredColorScheme(.dark)
    }
}
