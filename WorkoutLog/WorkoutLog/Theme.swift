import SwiftUI

// 애플 피트니스 계열 팔레트. 근력 = 라임, 인터벌 = 무브 핑크.
enum Palette {
    static let bg = Color.black
    static let card = Color.white.opacity(0.055)
    static let cardStroke = Color.white.opacity(0.07)
    static let strength = Color(red: 0.694, green: 0.961, blue: 0.173)
    static let interval = Color(red: 0.980, green: 0.067, blue: 0.310)
    static let activity = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let dim = Color.white.opacity(0.45)
    static let dimmer = Color.white.opacity(0.28)

    static func condition(_ c: Condition) -> Color {
        switch c {
        case .good:   return Color(red: 0.30, green: 0.85, blue: 0.39)
        case .normal: return Color(red: 1.00, green: 0.78, blue: 0.13)
        case .bad:    return Color(red: 0.98, green: 0.35, blue: 0.31)
        }
    }
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// 카드 컨테이너
struct CardBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardStroke, lineWidth: 1))
    }
}

// 섹션 소제목
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.rounded(12, .bold))
            .foregroundStyle(Palette.dimmer)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}

// 선택형 알약 버튼
struct PillPicker<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    let tint: (T) -> Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                let on = item == selection
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selection = item }
                    Haptics.tap()
                } label: {
                    Text(title(item))
                        .font(.rounded(15, on ? .bold : .medium))
                        .foregroundStyle(on ? Color.black : Palette.dim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(on ? tint(item) : Color.white.opacity(0.07), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

extension Int {
    /// 150 -> "2:30"
    var clockString: String { String(format: "%d:%02d", self / 60, self % 60) }
}
