import SwiftUI
import PhotosUI

struct SettingsRow: View {
    let icon: String
    let title: String
    var value: String = ""

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.text)
                Spacer()
                if !value.isEmpty {
                    Text(value).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 10) {
                        NavigationLink(destination: ProfileSettings()) {
                            GlassCard {
                                HStack(spacing: 14) {
                                    Avatar(nick: store.me?.nick ?? "?", url: store.me?.avatarUrl, size: 56)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(store.me?.nick ?? "")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(Theme.text)
                                        Text(tr("Профиль", "Profile", "Profil"))
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: EmailSettings()) {
                            SettingsRow(icon: "envelope.fill", title: tr("Почта", "Email", "E-Mail"),
                                        value: store.recoveryEmail == nil
                                        ? tr("не привязана", "not bound", "nicht verknüpft")
                                        : tr("привязана", "bound", "verknüpft"))
                        }.buttonStyle(.plain)
                        NavigationLink(destination: LookSettings()) {
                            SettingsRow(icon: "paintpalette.fill", title: tr("Оформление", "Appearance", "Aussehen"))
                        }.buttonStyle(.plain)
                        NavigationLink(destination: SoundSettings()) {
                            SettingsRow(icon: "speaker.wave.2.fill", title: tr("Звуки", "Sounds", "Töne"))
                        }.buttonStyle(.plain)
                        NavigationLink(destination: LangSettings()) {
                            SettingsRow(icon: "globe", title: tr("Язык", "Language", "Sprache"), value: st.lang.title)
                        }.buttonStyle(.plain)
                        NavigationLink(destination: NoxView()) {
                            SettingsRow(icon: "bolt.fill", title: tr("Мой nox", "My nox", "Mein nox"))
                        }.buttonStyle(.plain)
                        NavigationLink(destination: StatsView()) {
                            SettingsRow(icon: "chart.bar.fill", title: tr("Статистика", "Statistics", "Statistik"))
                        }.buttonStyle(.plain)
                        NavigationLink(destination: AboutView()) {
                            SettingsRow(icon: "info.circle.fill", title: tr("О приложении", "About", "Über die App"), value: "v\(Config.appVersion)")
                        }.buttonStyle(.plain)

                        Button {
                            Store.shared.logout()
                        } label: {
                            Text(tr("Выйти", "Sign out", "Abmelden"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: 0xFF6B6B))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Theme.card)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 10)

                        Text("neirox \(Config.appVersion)")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary.opacity(0.7))
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .neonScreen(tr("Настройки", "Settings", "Einstellungen"))
        }
    }
}

struct ProfileSettings: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    @State private var item: PhotosPickerItem?
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                Avatar(nick: store.me?.nick ?? "?", url: store.me?.avatarUrl, size: 110)
                    .padding(.top, 30)
                Text(store.me?.nick ?? "")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                PhotosPicker(selection: $item, matching: .images) {
                    Text(busy ? "…" : tr("Сменить фото", "Change photo", "Foto ändern"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 46)
                        .background(Theme.accentGradient)
                        .clipShape(Capsule())
                }
                ErrorText(text: error)
                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .neonScreen(tr("Профиль", "Profile", "Profil"))
        .onChange(of: item) { new in
            guard let new = new else { return }
            busy = true
            error = ""
            Task {
                do {
                    guard let data = try await new.loadTransferable(type: Data.self),
                          let jpg = compressedJPEG(from: data, maxSide: 600, quality: 0.85) else {
                        throw APIError(message: "Bad image")
                    }
                    try await store.uploadAvatar(jpg)
                } catch {
                    self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
                }
                busy = false
                item = nil
            }
        }
    }
}

struct EmailSettings: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    @State private var email = ""
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 14) {
                    if let e = store.recoveryEmail {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(tr("Привязанная почта", "Bound email", "Verknüpfte E-Mail"))
                                    .font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                                Text(e).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                                Text(tr("Почту нельзя изменить после привязки", "The email cannot be changed after binding", "Die E-Mail kann nach der Verknüpfung nicht geändert werden"))
                                    .font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        GlassCard {
                            Text(tr("Почта не привязана. Без неё забытый пароль восстановить не получится. Привязать можно один раз, изменить потом нельзя.",
                                    "No email is bound. Without it a forgotten password cannot be recovered. You can bind it once; it cannot be changed later.",
                                    "Keine E-Mail verknüpft. Ohne sie kann ein vergessenes Passwort nicht wiederhergestellt werden. Du kannst sie einmal verknüpfen, danach nicht mehr ändern."))
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: 0xFFC857))
                        }
                        GlassField(placeholder: tr("Адрес почты", "Email address", "E-Mail-Adresse"), text: $email)
                        ErrorText(text: error)
                        NeonButton(title: tr("Привязать почту", "Bind email", "E-Mail verknüpfen"), busy: busy) {
                            bind()
                        }
                    }
                }
                .padding(16)
            }
        }
        .neonScreen(tr("Почта", "Email", "E-Mail"))
    }

    private func bind() {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.contains("@"), e.contains(".") else {
            error = friendlyError("bad_email")
            return
        }
        busy = true
        error = ""
        Task {
            do { try await store.bindEmail(e) } catch {
                let raw = (error as? APIError)?.message ?? error.localizedDescription
                self.error = raw.contains("duplicate") || raw.contains("unique") ? friendlyError("email_taken") : friendlyError("bad_email")
            }
            busy = false
        }
    }
}

struct LookSettings: View {
    @ObservedObject private var st = Settings.shared

    private func hex(of c: Color) -> UInt32 {
        let u = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
    }

    private func modeTitle(_ m: ThemeMode) -> String {
        switch m {
        case .dark: return tr("Тёмная", "Dark", "Dunkel")
        case .black: return tr("Чёрная", "Black", "Schwarz")
        case .light: return tr("Светлая", "Light", "Hell")
        }
    }

    private func sizeTitle(_ s: TextSize) -> String {
        switch s {
        case .small: return tr("Мелкий", "Small", "Klein")
        case .medium: return tr("Средний", "Medium", "Mittel")
        case .large: return tr("Крупный", "Large", "Groß")
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selected ? .white : Theme.text)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.stroke, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func label(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 12) {
                    label(tr("Акцентный цвет", "Accent color", "Akzentfarbe"))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(accentPalette, id: \.self) { h in
                            Button { st.accentHex = h } label: {
                                Circle()
                                    .fill(Color(hex: h))
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(Theme.text, lineWidth: st.accentHex == h ? 3 : 0))
                            }
                        }
                    }
                    ColorPicker(tr("Свой цвет", "Custom color", "Eigene Farbe"),
                                selection: Binding(get: { Color(hex: st.accentHex) },
                                                   set: { st.accentHex = hex(of: $0) }),
                                supportsOpacity: false)
                        .foregroundColor(Theme.text)

                    label(tr("Тема", "Theme", "Design")).padding(.top, 10)
                    HStack(spacing: 8) {
                        ForEach(ThemeMode.allCases) { m in
                            chip(modeTitle(m), selected: st.mode == m) { st.mode = m }
                        }
                    }

                    label(tr("Размер текста", "Text size", "Textgröße")).padding(.top, 10)
                    HStack(spacing: 8) {
                        ForEach(TextSize.allCases) { s in
                            chip(sizeTitle(s), selected: st.textSize == s) { st.textSize = s }
                        }
                    }
                }
                .padding(16)
            }
        }
        .neonScreen(tr("Оформление", "Appearance", "Aussehen"))
    }
}

struct SoundSettings: View {
    @ObservedObject private var st = Settings.shared

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 12) {
                GlassCard {
                    Toggle(tr("Звук нового сообщения", "New message sound", "Ton bei neuer Nachricht"), isOn: $st.messageSound)
                        .foregroundColor(Theme.text)
                        .tint(Theme.accent)
                }
                GlassCard {
                    Toggle(tr("Вибрация", "Haptics", "Vibration"), isOn: $st.haptics)
                        .foregroundColor(Theme.text)
                        .tint(Theme.accent)
                }
                Spacer()
            }
            .padding(16)
        }
        .neonScreen(tr("Звуки", "Sounds", "Töne"))
    }
}

struct LangSettings: View {
    @ObservedObject private var st = Settings.shared

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                ForEach(Lang.allCases) { l in
                    Button { st.lang = l } label: {
                        GlassCard {
                            HStack {
                                Text(l.title).font(.system(size: 16)).foregroundColor(Theme.text)
                                Spacer()
                                if st.lang == l {
                                    Image(systemName: "checkmark").foregroundColor(Theme.accent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(16)
        }
        .neonScreen(tr("Язык", "Language", "Sprache"))
    }
}

struct NoxView: View {
    @ObservedObject private var st = Settings.shared

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accentGradient)
                    .padding(.top, 60)
                Text(tr("Пока что данная механика nox находится в разработке",
                        "The nox mechanic is still in development",
                        "Die nox-Mechanik ist noch in Entwicklung"))
                    .font(.system(size: 16))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Spacer()
            }
        }
        .neonScreen(tr("Мой nox", "My nox", "Mein nox"))
    }
}

struct StatsView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared

    private func card(_ title: String, _ value: String) -> some View {
        GlassCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    var body: some View {
        let sent = store.messages.filter { $0.sender == store.myId }.count
        let received = store.messages.filter { $0.receiver == store.myId }.count
        let days: Int = {
            guard let c = store.me?.createdAt else { return 0 }
            return max(1, Calendar.current.dateComponents([.day], from: c, to: Date()).day ?? 0)
        }()
        ZStack {
            AppBackground()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    card(tr("Отправлено", "Sent", "Gesendet"), "\(sent)")
                    card(tr("Получено", "Received", "Empfangen"), "\(received)")
                    card(tr("Друзей", "Friends", "Freunde"), "\(store.friendIds.count)")
                    card(tr("Дней с нами", "Days with us", "Tage bei uns"), "\(days)")
                }
                .padding(16)
            }
        }
        .neonScreen(tr("Статистика", "Statistics", "Statistik"))
    }
}

struct AboutView: View {
    @ObservedObject private var st = Settings.shared

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 10) {
                Text("neirox")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accentGradient)
                    .padding(.top, 50)
                Text(tr("Умный Чат", "Smart Chat", "Smarter Chat"))
                    .foregroundColor(Theme.textSecondary)
                Text("v\(Config.appVersion)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .padding(.top, 6)
                Spacer()
            }
        }
        .neonScreen(tr("О приложении", "About", "Über die App"))
    }
}
