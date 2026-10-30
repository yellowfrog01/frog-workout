import SwiftUI

/// 동기화 현황 시트: 상태(자동 동기화), 로그인, 로그아웃. 동기화는 자동이라 수동 버튼은 두지 않는다.
struct SyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    /// 시트로 띄울 때만 닫기 버튼 (맥 사이드바에 넣을 때는 false)
    var showsClose = true
    private var sync: SyncService { .shared }

    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    statusCard
                    if !sync.isConfigured {
                        note("Supabase.plist 가 없어 동기화가 꺼져 있습니다.")
                    } else if sync.isSignedIn {
                        actions
                    } else {
                        loginCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("동기화")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            #endif
            .toolbar {
                if showsClose {
                    ToolbarItem(placement: toolbarPlacement) {
                        Button("닫기") { dismiss() }
                            .font(.rounded(15, .semibold))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Palette.strength)
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .confirmationAction
        #endif
    }

    // MARK: 상태

    private var statusCard: some View {
        CardBox {
            SectionLabel(text: "상태")
            row("계정", sync.email ?? "로그인 안 됨")
            row("마지막 업로드", sync.lastUploadAt.map(Self.format) ?? "없음")
            row("마지막 받기", sync.lastPullAt.map(Self.format) ?? "없음")
            row("대기", "\(sync.pendingCount)건")
            row("네트워크", sync.isOnline ? "연결됨" : "오프라인")
            if let e = sync.lastError {
                Text(e)
                    .font(.rounded(13, .medium))
                    .foregroundStyle(Palette.interval)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.rounded(14, .medium)).foregroundStyle(Palette.dim)
            Spacer()
            Text(value).font(.rounded(14, .semibold)).foregroundStyle(.white)
        }
    }

    // MARK: 로그인

    private var loginCard: some View {
        CardBox {
            SectionLabel(text: "로그인")
            TextField("이메일", text: $email)
                #if os(iOS)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .field()
            SecureField("비밀번호", text: $password)
                #if os(iOS)
                .textContentType(.password)
                #endif
                .field()
            if let m = message {
                Text(m)
                    .font(.rounded(13, .medium))
                    .foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button { Task { await signIn() } } label: {
                    label("로그인", filled: true)
                }
                Button { Task { await signUp() } } label: {
                    label("가입", filled: false)
                }
            }
            .disabled(busy || email.isEmpty || password.isEmpty)
            .opacity(busy || email.isEmpty || password.isEmpty ? 0.5 : 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if sync.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("동기화 중…").font(.rounded(13, .semibold)).foregroundStyle(Palette.dim)
                }
            }
            Button { sync.signOut() } label: {
                label("로그아웃", filled: false)
            }
        }
    }

    private func label(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.rounded(16, .bold))
            .foregroundStyle(filled ? Color.black : Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(filled ? Palette.strength : Color.white.opacity(0.07), in: .capsule)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.rounded(13, .medium))
            .foregroundStyle(Palette.dim)
    }

    // MARK: 동작

    private func signIn() async {
        busy = true; message = nil
        defer { busy = false }
        do {
            try await sync.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            password = ""
            Haptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func signUp() async {
        busy = true; message = nil
        defer { busy = false }
        do {
            let signedIn = try await sync.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            if signedIn { password = "" } else { message = "가입 확인 메일을 확인한 뒤 로그인하세요" }
        } catch {
            message = error.localizedDescription
        }
    }

    private static func format(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 a h:mm"
        return f.string(from: d)
    }
}

private extension View {
    /// 입력칸 공통 모양
    func field() -> some View {
        self.font(.rounded(16, .medium))
            .padding(12)
            .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 12))
    }
}
