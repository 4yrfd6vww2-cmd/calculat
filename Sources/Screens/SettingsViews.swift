import SwiftUI
import PhotosUI

struct SettingsRow: View {
    @ObservedObject private var st = Settings.shared
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
    @State private var newNick = ""
    @State private var nickBusy = false
    @State private var nickMsg = ""

    private func changeNick() {
        let n = newNick.trimmingCharacters(in: .whitespaces).lowercased()
        guard !n.isEmpty, n != store.me?.nick else { return }
        nickBusy = true
        nickMsg = ""
        Task {
            do {
                try await store.changeNick(n)
                nickMsg = tr("Ник изменён", "Nick changed", "Nick geändert")
                newNick = ""
            } catch {
                nickMsg = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
            nickBusy = false
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
            VStack(spacing: 16) {
                Avatar(nick: store.me?.nick ?? "?", url: store.me?.avatarUrl, size: 110)
                    .padding(.top, 30)
                Text(store.me?.nick ?? "")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.text)
                Text("★ " + levelStr(store.levels[store.myId] ?? 0))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.accent)
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

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Сменить ник", "Change nick", "Nick ändern"))
                            .font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                        GlassField(placeholder: tr("Новый ник (a–z, цифры, _)", "New nick (a–z, digits, _)", "Neuer Nick (a–z, Ziffern, _)"), text: $newNick)
                        Text(tr("Ник должен быть уникальным: чужие ники занять нельзя. Вход выполняется по новому нику.",
                                "A nick must be unique: nicks of other people cannot be taken. Sign in with the new nick.",
                                "Ein Nick muss einmalig sein: fremde Nicks können nicht verwendet werden. Die Anmeldung erfolgt mit dem neuen Nick."))
                            .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                        NeonButton(title: tr("Сохранить ник", "Save nick", "Nick speichern"), busy: nickBusy) { changeNick() }
                        if !nickMsg.isEmpty {
                            Text(nickMsg).font(.system(size: 13)).foregroundColor(Theme.accent)
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
            }
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
        .task {
            do { try await store.reloadRecoveryEmail() } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
        }
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

func hexString(of c: Color) -> String {
    let u = UIColor(c)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    u.getRed(&r, green: &g, blue: &b, alpha: &a)
    let v = (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
    return "#" + String(format: "%06x", v)
}

struct LookSettings: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared

    private var customColorValues: [UInt32] {
        store.colors.compactMap { c in
            guard let h = c.color else { return nil }
            return UInt32(h.dropFirst(), radix: 16)
        }
    }

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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(customColorValues, id: \.self) { h in
                            Button { st.accentHex = h } label: {
                                Circle()
                                    .fill(Color(hex: h))
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().stroke(Theme.text, lineWidth: st.accentHex == h ? 3 : 0))
                            }
                        }
                    }
                    Text(tr("Свои цвета открываются за nox: раздел «Мой nox».", "Custom colors are unlocked with nox: see “My nox”.", "Eigene Farben schaltest du mit nox frei: „Mein nox“."))
                        .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
    @ObservedObject private var store = Store.shared
    @State private var error = ""
    @State private var pickId: Int?
    @State private var picked = Color(hex: 0x9B6BFF)

    private func act(_ block: @escaping () async throws -> Void) {
        error = ""
        Task {
            do { try await block() } catch {
                let m = (error as? APIError)?.message ?? error.localizedDescription
                if m.contains("not_enough") { self.error = tr("Не хватает nox", "Not enough nox", "Nicht genug nox") }
                else if m.contains("max_level") { self.error = tr("Максимальный уровень", "Maximum level reached", "Maximales Level erreicht") }
                else { self.error = friendlyError(m) }
            }
        }
    }

    private func head(_ t: String) -> some View {
        Text(t).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func note(_ t: String) -> some View {
        Text(t).font(.system(size: 13)).foregroundColor(Theme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func smallButton(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
                .padding(.horizontal, 14).frame(height: 38)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var walletCard: some View {
        let w = store.wallet ?? Wallet(balance: 0, earned: 0, streak: 0, level: 0)
        return GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("⚡ \(w.balance) nox").font(.system(size: 30, weight: .heavy)).foregroundColor(Theme.text)
                note(tr("Всего заработано: ", "Total earned: ", "Insgesamt verdient: ") + String(w.earned))
                note(tr("Серия входов: ", "Login streak: ", "Login-Serie: ") + String(w.streak) + " / 3 · " + tr("за 3 дня подряд +5 nox", "+5 nox for 3 days in a row", "+5 nox für 3 Tage in Folge"))
            }
        }
    }

    private var colorsSection: some View {
        VStack(spacing: 8) {
            head(tr("Свои цвета темы", "Custom theme colors", "Eigene Themenfarben"))
            note(tr("10 nox за один цвет. Покупки хранятся на сервере.", "10 nox per color. Purchases are stored on the server.", "10 nox pro Farbe. Käufe werden auf dem Server gespeichert."))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                ForEach(store.colors) { c in
                    colorCell(c)
                }
            }
            HStack {
                smallButton(tr("Купить цвет · 10 nox", "Buy a color · 10 nox", "Farbe kaufen · 10 nox")) {
                    act { pickId = try await store.buyColor() }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder private func colorCell(_ c: ThemeColor) -> some View {
        if let h = c.color, let v = UInt32(h.dropFirst(), radix: 16) {
            Button { st.accentHex = v } label: {
                Circle().fill(Color(hex: v)).frame(width: 38, height: 38)
                    .overlay(Circle().stroke(Theme.text, lineWidth: st.accentHex == v ? 3 : 0))
            }
        } else {
            smallButton(tr("Выбрать цвет", "Pick color", "Farbe wählen")) { picked = Color(hex: 0x9B6BFF); pickId = c.id }
        }
    }

    private var levelSection: some View {
        let w = store.wallet ?? Wallet(balance: 0, earned: 0, streak: 0, level: 0)
        return VStack(spacing: 8) {
            head(tr("Уровень: ★ ", "Level: ★ ", "Level: ★ ") + levelStr(w.level) + " / 100.0")
            note(tr("Виден всем. 0.01 уровня = 1 nox.", "Visible to everyone. 0.01 level = 1 nox.", "Für alle sichtbar. 0.01 Level = 1 nox."))
            HStack(spacing: 8) {
                smallButton("+0.01") { act { try await store.buyLevel(1) } }
                smallButton("+0.10") { act { try await store.buyLevel(10) } }
                smallButton("+1.00") { act { try await store.buyLevel(100) } }
                Spacer()
            }
        }
    }

    private func boardRow(_ i: Int, _ r: BoardRow) -> some View {
        HStack(spacing: 10) {
            Text(String(i + 1)).foregroundColor(Theme.textSecondary).frame(width: 26)
            Avatar(nick: r.nick, url: r.avatarUrl, size: 36)
            Text(r.nick + (r.level > 0 ? "  ★ " + levelStr(r.level) : "")).foregroundColor(Theme.text).font(.system(size: 15, weight: .medium))
            Spacer()
            Text(String(r.earned) + " nox").foregroundColor(Theme.accent).font(.system(size: 14, weight: .semibold))
        }
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var boardSection: some View {
        VStack(spacing: 8) {
            head(tr("Таблица лидеров", "Leaderboard", "Bestenliste"))
            if store.board.isEmpty { note(tr("Пока никого нет", "Nobody yet", "Noch niemand")) }
            ForEach(Array(store.board.enumerated()), id: \.element.id) { pair in
                boardRow(pair.offset, pair.element)
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    walletCard
                    if !error.isEmpty { ErrorText(text: error) }
                    colorsSection
                    levelSection
                    boardSection
                }
                .padding(16)
            }
        }
        .neonScreen(tr("Мой nox", "My nox", "Mein nox"))
        .task { await store.noxOpen() }
        .sheet(isPresented: Binding(get: { pickId != nil }, set: { if !$0 { pickId = nil } })) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text(tr("Цвет выбирается один раз, потом он сохранится в палитре.", "You pick the color once, then it stays in your palette.", "Die Farbe wird einmal gewählt und bleibt in deiner Palette."))
                        .font(.system(size: 14)).multilineTextAlignment(.center)
                    ColorPicker(tr("Цвет", "Color", "Farbe"), selection: $picked, supportsOpacity: false)
                    Spacer()
                }
                .padding(20)
                .navigationTitle(tr("Свой цвет", "Custom color", "Eigene Farbe"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(tr("Позже", "Later", "Später")) { pickId = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("Сохранить", "Save", "Speichern")) {
                            guard let id = pickId else { return }
                            let hex = hexString(of: picked)
                            pickId = nil
                            act {
                                try await store.setColor(id, hex)
                                if let v = UInt32(hex.dropFirst(), radix: 16) { st.accentHex = v }
                            }
                        }
                    }
                }
            }
        }
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
