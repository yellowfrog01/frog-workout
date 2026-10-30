import SwiftUI
import UserNotifications

// MARK: - 휴식 알림

/// 휴식 종료 로컬 알림. 앱이 백그라운드·잠금이어도 울리고, 잠금 상태면 워치로 넘어간다.
final class RestAlert: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestAlert()
    private let id = "rest.timer"

    func prepare() {
        let c = UNUserNotificationCenter.current()
        c.delegate = self
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(at end: Date, body: String) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [id])
        let secs = end.timeIntervalSinceNow
        guard secs > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = "휴식 끝"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secs, repeats: false)
        c.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [id])
        c.removeDeliveredNotifications(withIdentifiers: [id])
    }

    /// 앱이 앞에 있어도 배너와 소리를 낸다
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }
}

// MARK: - 휴식 카운트다운 바

struct RestBar: View {
    let end: Date
    let total: Int
    let next: String
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let left = max(0, Int(end.timeIntervalSince(ctx.date).rounded(.up)))
            let progress = total > 0 ? 1 - Double(left) / Double(total) : 1
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("휴식")
                            .font(.rounded(12, .bold))
                            .foregroundStyle(Palette.dim)
                        Text(left.clockString)
                            .font(.rounded(34, .heavy)).monospacedDigit()
                            .foregroundStyle(left == 0 ? Palette.strength : .white)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 4)
                    adjust("−15") { onAdjust(-15) }
                    adjust("+15") { onAdjust(15) }
                    Button(action: onSkip) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 40)
                            .background(Palette.strength, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                ProgressView(value: min(1, max(0, progress)))
                    .tint(Palette.strength)
                if !next.isEmpty {
                    Text(next)
                        .font(.rounded(12, .semibold))
                        .foregroundStyle(Palette.dimmer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .background(Palette.card, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.strength.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 4)
        }
    }

    private func adjust(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            Text(title)
                .font(.rounded(14, .bold)).monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 50, height: 40)
                .background(Color.white.opacity(0.1), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
