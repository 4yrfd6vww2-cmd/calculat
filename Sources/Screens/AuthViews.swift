import SwiftUI

func friendlyError(_ raw: String) -> String {
    let s = raw.lowercased()
    if s.contains("invalid login") || s.contains("invalid_credentials") {
        return tr("Неверный ник или пароль", "Wrong nick or password", "Nick oder Passwort falsch")
    }
    if s.contains("nick_taken") { return tr("Этот ник уже занят", "This nick is taken", "Dieser Nick ist vergeben") }
    if s.contains("email_taken") { return tr("Эта почта уже привязана к другому аккаунту", "This email is already used", "Diese E-Mail wird bereits verwendet") }
    if s.contains("bad_nick") { return tr("Ник: 3–20 символов, только a–z, цифры и _", "Nick: 3–20 chars, a–z, digits and _", "Nick: 3–20 Zeichen, a–z, Ziffern und _") }
    if s.contains("bad_password") { return tr("Пароль: минимум 6 символов", "Password: at least 6 characters", "Passwort: mindestens 6 Zeichen") }
    if s.contains("bad_email") { return tr("Проверь адрес почты", "Check the email address", "E-Mail prüfen") }
    if s.contains("offline") || s.contains("internet") || s.contains("network") || s.contains("connection") {
        return tr("Нет связи с сервером", "No connection to server", "Keine Verbindung zum Server")
    }
    return raw
}

struct AuthFlow: View {
    @ObservedObject private var st = Settings.shared
    @State private var screen = 0

    var body: some View {
        ZStack {
            AppBackground()
            if screen == 0 {
                LoginView(go: { screen = $0 })
            } else if screen == 1 {
                RegisterView(go: { screen = $0 })
            } else {
                ForgotView(go: { screen = $0 })
            }
        }
    }
}

struct AuthHeader: View {
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text("neirox")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.bottom, 20)
    }
}

struct LoginView: View {
    @ObservedObject private var st = Settings.shared
    let go: (Int) -> Void
    @State private var nick = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 90)
                AuthHeader(subtitle: tr("Умный Чат", "Smart Chat", "Smarter Chat"))
                GlassField(placeholder: tr("Ник", "Nick", "Nick"), text: $nick)
                GlassField(placeholder: tr("Пароль", "Password", "Passwort"), text: $password, secure: true)
                ErrorText(text: error)
                NeonButton(title: tr("Войти", "Sign in", "Anmelden"), busy: busy) { submit() }
                    .padding(.top, 4)
                Button(tr("Забыли пароль?", "Forgot password?", "Passwort vergessen?")) { go(2) }
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                Button(tr("Создать аккаунт", "Create account", "Konto erstellen")) { go(1) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.accent)
                Spacer(minLength: 30)
                Text("neirox \(Config.appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 28)
        }
    }

    private func submit() {
        let n = nick.trimmingCharacters(in: .whitespaces).lowercased()
        guard !n.isEmpty, !password.isEmpty else { return }
        busy = true
        error = ""
        Task {
            do {
                try await Store.shared.login(nick: n, password: password)
            } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
            busy = false
        }
    }
}

struct RegisterView: View {
    @ObservedObject private var st = Settings.shared
    let go: (Int) -> Void
    @State private var nick = ""
    @State private var password = ""
    @State private var email = ""
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 70)
                AuthHeader(subtitle: tr("Создание аккаунта", "Create account", "Konto erstellen"))
                GlassField(placeholder: tr("Ник (a–z, цифры, _)", "Nick (a–z, digits, _)", "Nick (a–z, Ziffern, _)"), text: $nick)
                GlassField(placeholder: tr("Пароль (от 6 символов)", "Password (6+ chars)", "Passwort (ab 6 Zeichen)"), text: $password, secure: true)
                GlassField(placeholder: tr("Почта · рекомендуем", "Email · recommended", "E-Mail · empfohlen"), text: $email)
                GlassCard {
                    Text(tr("Почта нужна, чтобы восстановить пароль. Без неё забытый пароль вернуть не получится. Привязать почту можно и позже в настройках, но изменить её после привязки нельзя.",
                            "Email is used to recover your password. Without it a forgotten password cannot be restored. You can bind it later in settings, but it cannot be changed afterwards.",
                            "Die E-Mail dient zur Passwort-Wiederherstellung. Ohne sie kann ein vergessenes Passwort nicht zurückgesetzt werden. Du kannst sie später in den Einstellungen hinzufügen, aber nicht mehr ändern."))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xFFC857))
                }
                ErrorText(text: error)
                NeonButton(title: tr("Создать аккаунт", "Create account", "Konto erstellen"), busy: busy) { submit() }
                Button(tr("Уже есть аккаунт? Войти", "Have an account? Sign in", "Schon ein Konto? Anmelden")) { go(0) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.accent)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 28)
        }
    }

    private func submit() {
        let n = nick.trimmingCharacters(in: .whitespaces).lowercased()
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !n.isEmpty, !password.isEmpty else { return }
        busy = true
        error = ""
        Task {
            do {
                try await API.shared.register(nick: n, password: password, email: e)
                try await Store.shared.login(nick: n, password: password)
            } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
            busy = false
        }
    }
}

struct ForgotView: View {
    @ObservedObject private var st = Settings.shared
    let go: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 90)
                AuthHeader(subtitle: tr("Восстановление пароля", "Password recovery", "Passwort zurücksetzen"))
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Восстановление по почте пока в разработке: для отправки писем нужно подключить почтовый сервис.",
                                "Recovery by email is still in development: a mail service has to be connected first.",
                                "Die Wiederherstellung per E-Mail ist noch in Entwicklung: dafür muss zuerst ein Mail-Dienst angebunden werden."))
                            .foregroundColor(Theme.text)
                        Text(tr("Если почта к аккаунту не привязана, пароль восстановить нельзя.",
                                "If no email is bound to the account, the password cannot be recovered.",
                                "Ist keine E-Mail verknüpft, kann das Passwort nicht wiederhergestellt werden."))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .font(.system(size: 14))
                }
                Button(tr("Назад ко входу", "Back to sign in", "Zurück zur Anmeldung")) { go(0) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
        }
    }
}
