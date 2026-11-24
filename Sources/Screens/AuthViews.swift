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
    if s.contains("bad_code") { return tr("Неверный или просроченный код", "Wrong or expired code", "Code falsch oder abgelaufen") }
    if s.contains("blocked") { return tr("Нельзя написать: пользователь заблокировал переписку", "Can't send: the user has blocked this chat", "Kann nicht senden: der Nutzer hat den Chat blockiert") }
    if s.contains("too_many") { return tr("Слишком много попыток, попробуй через час", "Too many attempts, try again in an hour", "Zu viele Versuche, versuche es in einer Stunde erneut") }
    if s.contains("mail_failed") || s.contains("mail_not_configured") { return tr("Не удалось отправить письмо, попробуй позже", "Could not send the email, try later", "E-Mail konnte nicht gesendet werden") }
    if s.contains("no_profile") { return tr("Профиль не найден", "Profile not found", "Profil nicht gefunden") }
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
    @ObservedObject private var st = Settings.shared
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text("neirox")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
            Text(subtitle)
                .font(.system(size: 13))
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
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Button(tr("Создать аккаунт", "Create account", "Konto erstellen")) { go(1) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.accent)
                Spacer(minLength: 30)
                Text("neirox \(Config.appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 25)
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
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: 0xFFC857))
                }
                ErrorText(text: error)
                NeonButton(title: tr("Создать аккаунт", "Create account", "Konto erstellen"), busy: busy) { submit() }
                Button(tr("Уже есть аккаунт? Войти", "Have an account? Sign in", "Schon ein Konto? Anmelden")) { go(0) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.accent)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 25)
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
    @State private var nick = ""
    @State private var code = ""
    @State private var password = ""
    @State private var step = 0
    @State private var busy = false
    @State private var error = ""
    @State private var done = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 90)
                AuthHeader(subtitle: tr("Восстановление пароля", "Password recovery", "Passwort zurücksetzen"))
                if done {
                    GlassCard {
                        Text(tr("Пароль изменён. Теперь можно войти с новым паролем.",
                                "Password changed. You can sign in with the new password now.",
                                "Passwort geändert. Du kannst dich jetzt mit dem neuen Passwort anmelden."))
                            .font(.system(size: 12))
                            .foregroundColor(Theme.text)
                    }
                } else if step == 0 {
                    GlassField(placeholder: tr("Ник", "Nick", "Nick"), text: $nick)
                    GlassCard {
                        Text(tr("Код придёт на почту, привязанную к аккаунту. Если почта не привязана, пароль восстановить нельзя.",
                                "The code is sent to the email bound to the account. If none is bound, the password cannot be recovered.",
                                "Der Code geht an die verknüpfte E-Mail. Ist keine verknüpft, kann das Passwort nicht wiederhergestellt werden."))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    ErrorText(text: error)
                    NeonButton(title: tr("Отправить код", "Send code", "Code senden"), busy: busy) { sendCode() }
                } else {
                    GlassCard {
                        Text(tr("Если к нику привязана почта, мы отправили на неё 6-значный код. Он действует 15 минут. Проверь и папку «Спам».",
                                "If an email is bound to this nick, a 6-digit code was sent. It is valid for 15 minutes. Check Spam too.",
                                "Ist eine E-Mail verknüpft, wurde ein 6-stelliger Code gesendet. Er gilt 15 Minuten. Prüfe auch den Spam-Ordner."))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    GlassField(placeholder: tr("Код из письма", "Code from email", "Code aus der E-Mail"), text: $code)
                    GlassField(placeholder: tr("Новый пароль", "New password", "Neues Passwort"), text: $password, secure: true)
                    ErrorText(text: error)
                    NeonButton(title: tr("Сменить пароль", "Change password", "Passwort ändern"), busy: busy) { confirm() }
                    Button(tr("Отправить код ещё раз", "Send code again", "Code erneut senden")) { sendCode() }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Button(tr("Назад ко входу", "Back to sign in", "Zurück zur Anmeldung")) { go(0) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 25)
        }
    }

    private func sendCode() {
        let n = nick.trimmingCharacters(in: .whitespaces).lowercased()
        guard !n.isEmpty else { error = tr("Введи ник", "Enter your nick", "Nick eingeben"); return }
        busy = true; error = ""
        Task {
            do {
                try await API.shared.recoverRequest(nick: n)
                step = 1
            } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
            busy = false
        }
    }

    private func confirm() {
        let n = nick.trimmingCharacters(in: .whitespaces).lowercased()
        busy = true; error = ""
        Task {
            do {
                try await API.shared.recoverConfirm(nick: n, code: code.trimmingCharacters(in: .whitespaces), newPassword: password)
                done = true
            } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
            busy = false
        }
    }
}
