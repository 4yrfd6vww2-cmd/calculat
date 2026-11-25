import SwiftUI
import PhotosUI

struct CreateChatSheet: View {
    @ObservedObject private var store = Store.shared
    var onCreated: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var channel = false
    @State private var title = ""
    @State private var desc = ""
    @State private var picked = Set<String>()
    @State private var error = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Picker("", selection: $channel) {
                    Text(tr("Группа", "Group", "Gruppe")).tag(false)
                    Text(tr("Канал", "Channel", "Kanal")).tag(true)
                }
                .pickerStyle(.segmented)
                TextField(tr("Название", "Title", "Titel"), text: $title)
                TextField(tr("Описание (необязательно)", "Description (optional)", "Beschreibung (optional)"), text: $desc)
                if !channel {
                    Section(tr("Участники из друзей", "Members from friends", "Mitglieder aus Freunden")) {
                        ForEach(store.friendIds.compactMap { store.profiles[$0] }) { p in
                            Button {
                                if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: picked.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                    Avatar(nick: p.nick, url: p.avatarUrl, size: 28)
                                    Text(store.dname(p))
                                }
                            }
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundColor(.red).font(.system(size: 11)) }
            }
            .navigationTitle(tr("Новый чат", "New chat", "Neuer Chat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Отмена", "Cancel", "Abbrechen")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Создать", "Create", "Erstellen")) { create() }.disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        busy = true
        error = ""
        Task {
            do {
                let k = try await store.createChat(kind: channel ? "channel" : "group",
                                                   title: title.trimmingCharacters(in: .whitespaces),
                                                   friends: channel ? [] : Array(picked), desc: desc)
                onCreated(k)
            } catch {
                let m = (error as? APIError)?.message ?? error.localizedDescription
                self.error = m.contains("duplicate") || m.contains("23505")
                    ? tr("Канал с таким названием уже есть", "A channel with this title exists", "Kanal existiert bereits")
                    : friendlyError(m)
            }
            busy = false
        }
    }
}

struct FindChannelSheet: View {
    @ObservedObject private var store = Store.shared
    var onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var results: [Chat] = []
    @State private var counts: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                TextField(tr("Название канала", "Channel title", "Kanaltitel"), text: $q)
                    .onChange(of: q) { v in Task { results = await store.findChannels(v); counts = await store.channelCounts(results.map { $0.id }) } }
                ForEach(results) { c in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "megaphone.fill").font(.system(size: 12)).foregroundColor(Theme.accent)
                                Text(c.title)
                            }
                            Text(subLine(c)).font(.system(size: 12)).foregroundColor(.secondary).lineLimit(2)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen("c:" + c.id) }
                        Spacer()
                        if store.isMember(c.id) {
                            Image(systemName: "checkmark").foregroundColor(Theme.accent)
                        } else {
                            Button(tr("Подписаться", "Subscribe", "Abonnieren")) {
                                Task { try? await store.joinChat(c.id); onOpen("c:" + c.id) }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                if results.isEmpty && !q.isEmpty {
                    Text(tr("Ничего не найдено", "Nothing found", "Nichts gefunden")).foregroundColor(.secondary)
                }
            }
            .navigationTitle(tr("Найти канал", "Find channel", "Kanal suchen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Закрыть", "Close", "Schließen")) { dismiss() } } }
        }
    }
}

extension FindChannelSheet {
    fileprivate func subLine(_ c: Chat) -> String {
        var parts: [String] = []
        if let n = counts[c.id] { parts.append(tr("Подписчиков: ", "Subscribers: ", "Abonnenten: ") + String(n)) }
        if let d = c.description, !d.isEmpty { parts.append(d) }
        return parts.joined(separator: " · ")
    }
}

struct ChatInfoSheet: View {
    @ObservedObject private var store = Store.shared
    let key: String
    var onLeft: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nick = ""
    @State private var error = ""
    @State private var avItem: PhotosPickerItem?
    @State private var editDesc = false
    @State private var descText = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                if let c = store.chatByKey(key) {
                    let isOwner = c.owner == store.myId
                    let role = store.myMember(key)?.role
                    let isAdmin = isOwner || role == "admin"
                    let mem = store.members.filter { $0.chatId == c.id }
                    Section {
                        HStack(spacing: 12) {
                            Avatar(nick: c.title, url: c.avatarUrl, size: 49)
                            Text((c.kind == "channel" ? tr("Канал", "Channel", "Kanal") : tr("Группа", "Group", "Gruppe")) + " · \(mem.count)")
                                .foregroundColor(.secondary)
                        }
                        if let d = c.description, !d.isEmpty, !editDesc {
                            Text(d).font(.system(size: 12))
                        }
                        if isAdmin {
                            if editDesc {
                                TextField(tr("Описание", "Description", "Beschreibung"), text: $descText)
                                Button(tr("Сохранить", "Save", "Speichern")) {
                                    Task { try? await store.setDescription(c.id, descText); editDesc = false }
                                }
                            } else {
                                Button { descText = c.description ?? ""; editDesc = true } label: {
                                    Label(tr("Описание", "Description", "Beschreibung"), systemImage: "pencil")
                                }
                            }
                        }
                        if let code = c.inviteCode, !code.isEmpty {
                            HStack {
                                Text(tr("Код приглашения: ", "Invite code: ", "Einladungscode: ")).foregroundColor(.secondary)
                                Text(code).fontWeight(.bold)
                                Spacer()
                                Button(copied ? tr("Скопировано", "Copied", "Kopiert") : tr("Копировать", "Copy", "Kopieren")) {
                                    UIPasteboard.general.string = code
                                    copied = true
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        if isAdmin {
                            PhotosPicker(selection: $avItem, matching: .images) {
                                Label(tr("Сменить аватарку", "Change avatar", "Avatar ändern"), systemImage: "photo.fill")
                            }
                        }
                    }
                    if c.kind == "group" && isAdmin {
                        Section(tr("Добавить участника", "Add member", "Mitglied hinzufügen")) {
                            let have = Set(mem.map { $0.userId })
                            ForEach(store.friendIds.filter { !have.contains($0) }.compactMap { store.profiles[$0] }) { p in
                                Button("＋ " + store.dname(p)) { Task { try? await store.addMember(c.id, p.id) } }
                            }
                            TextField(tr("Или ник", "Or nick", "Oder Nick"), text: $nick).autocapitalization(.none)
                            Button(tr("Добавить по нику", "Add by nick", "Per Nick hinzufügen")) { addByNick(c.id) }
                            if !error.isEmpty { Text(error).foregroundColor(.red).font(.system(size: 11)) }
                        }
                    }
                    if c.kind == "group" || isAdmin {
                        Section(tr("Участники", "Members", "Mitglieder")) {
                            ForEach(mem, id: \.userId) { m in
                                HStack {
                                    HStack(spacing: 4) {
                                        Text(m.userId == store.myId ? tr("Вы", "You", "Du") : store.dnameId(m.userId))
                                        if m.role == "owner" {
                                            Image(systemName: "crown.fill").font(.system(size: 11)).foregroundColor(Theme.accent)
                                        } else if m.role == "admin" {
                                            Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(Theme.accent)
                                        }
                                    }
                                    Spacer()
                                    if isOwner && m.userId != store.myId {
                                        Button { Task { await store.setRole(c.id, m.userId, m.role == "admin" ? "member" : "admin") } } label: {
                                            Image(systemName: m.role == "admin" ? "star.fill" : "star")
                                        }
                                        .buttonStyle(.borderless)
                                        Button { Task { try? await store.kickMember(c.id, m.userId) } } label: { Image(systemName: "xmark") }
                                            .buttonStyle(.borderless)
                                        Button { Task { await store.banMember(c.id, m.userId) } } label: { Image(systemName: "nosign") }
                                            .buttonStyle(.borderless)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    if isOwner && !store.bansFor(c.id).isEmpty {
                        Section(tr("Заблокированные", "Banned", "Gesperrt")) {
                            ForEach(store.bansFor(c.id), id: \.userId) { b in
                                HStack {
                                    Text(store.dnameId(b.userId))
                                    Spacer()
                                    Button(tr("Разблокировать", "Unban", "Entsperren")) {
                                        Task { await store.unbanMember(c.id, b.userId) }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    Section {
                        if isOwner {
                            Button(tr("Удалить", "Delete", "Löschen"), role: .destructive) {
                                Task { try? await store.deleteChat(c.id); onLeft() }
                            }
                        } else {
                            Button(c.kind == "channel" ? tr("Отписаться", "Unsubscribe", "Abbestellen") : tr("Выйти", "Leave", "Verlassen"), role: .destructive) {
                                Task { try? await store.leaveChat(c.id); onLeft() }
                            }
                        }
                    }
                }
            }
            .onChange(of: avItem) { item in
                guard let item = item, let cid = store.chatByKey(key)?.id else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self), let jpg = compressedJPEG(from: d, maxSide: 800) {
                        try? await store.setChatAvatar(cid, jpg)
                    }
                    avItem = nil
                }
            }
            .navigationTitle(store.chatByKey(key)?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Закрыть", "Close", "Schließen")) { dismiss() } } }
        }
    }

    private func addByNick(_ cid: String) {
        let n = nick.trimmingCharacters(in: .whitespaces).lowercased()
        Task {
            let r = await store.search(n).first { $0.nick.lowercased() == n }
            if let r = r {
                do { try await store.addMember(cid, r.id); nick = ""; error = "" } catch { self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription) }
            } else {
                error = tr("Пользователь не найден", "User not found", "Nutzer nicht gefunden")
            }
        }
    }
}

struct JoinCodeSheet: View {
    @ObservedObject private var store = Store.shared
    var onJoined: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            List {
                TextField(tr("Код приглашения", "Invite code", "Einladungscode"), text: $code)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                if !error.isEmpty { Text(error).foregroundColor(.red).font(.system(size: 11)) }
            }
            .navigationTitle(tr("Войти по коду", "Join by code", "Per Code beitreten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Отмена", "Cancel", "Abbrechen")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Войти", "Join", "Beitreten")) { join() }.disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func join() {
        Task {
            do {
                let cid = try await store.joinByCode(code)
                onJoined("c:" + cid)
            } catch {
                let m = (error as? APIError)?.message ?? error.localizedDescription
                self.error = m.contains("not_found") ? tr("Такого кода нет", "No such code", "Code nicht gefunden") : friendlyError(m)
            }
        }
    }
}

/// Поиск по загруженным сообщениям (последние ~1000). only — ключ одного чата или nil для всех.
struct SearchSheet: View {
    @ObservedObject private var store = Store.shared
    let only: String?
    var onPick: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""

    private func keyOf(_ m: Message) -> String {
        if let c = m.chatId { return "c:" + c }
        return m.sender == store.myId ? (m.receiver ?? "") : m.sender
    }

    private var found: [Message] {
        let n = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard n.count >= 2 else { return [] }
        let list = store.messages.filter { m in
            (only == nil || keyOf(m) == only) &&
            ((m.body ?? "").lowercased().contains(n) || (m.fileName ?? "").lowercased().contains(n))
        }
        return Array(list.sorted { $0.createdAt > $1.createdAt }.prefix(50))
    }

    private func titleOf(_ k: String) -> String {
        store.chatByKey(k)?.title ?? store.dnameId(k)
    }

    var body: some View {
        NavigationStack {
            List {
                TextField(tr("Что ищем?", "What to find?", "Was suchen?"), text: $q)
                ForEach(found) { m in
                    Button {
                        onPick(keyOf(m), m.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(titleOf(keyOf(m)) + " · " + timeFormatter.string(from: m.createdAt))
                                .font(.system(size: 12)).foregroundColor(Theme.accent)
                            Text((m.body?.isEmpty == false ? m.body! : m.fileName) ?? "").font(.system(size: 12)).lineLimit(2).foregroundColor(.primary)
                        }
                    }
                }
                if found.isEmpty && q.trimmingCharacters(in: .whitespaces).count >= 2 {
                    Text(tr("Ничего не найдено", "Nothing found", "Nichts gefunden")).foregroundColor(.secondary)
                }
            }
            .navigationTitle(tr("Поиск по сообщениям", "Search messages", "Nachrichten suchen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(tr("Закрыть", "Close", "Schließen")) { dismiss() } } }
        }
    }
}
