import SwiftUI

struct LoginView: View {
    @State private var nick = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                Spacer()
                Text("neirox")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                Text("Умный Чат")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.bottom, 24)

                GlassField(placeholder: "Ник", text: $nick)
                GlassField(placeholder: "Пароль", text: $password, secure: true)
                NeonButton(title: "Войти") {}
                    .padding(.top, 6)

                Button("Забыли пароль?") {}
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Button("Создать аккаунт") {}
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.accent)

                Spacer()
                Text("neirox \(Config.appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
    }
}
