import SwiftUI
import PhotosUI

struct CreateChatSheet: View {
    @ObservedObject private var store = Store.shared
    var onCreated: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var channel = false
    @State private var title = ""
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
                if !channel {
                    Section(tr("Участники из друзей", "Members from friends", "Mitglieder aus Freunden")) {
                        ForEach(store.friendIds.compactMap { store.profiles[$0] }) { p in
                            Button {
                                if picked.contains(p.id) { picked.remove(p.id) } else { picked.insert(p.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: picked.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                    Avatar(nick: p.nick, url: p.avatarUrl, size: 32)
                                    Text(p.nick)
                                }
                            }
                        }
                    }
                }
                if !error.isEmpty { Text(error).foregroundColor(.red).font(.system(size: 13)) }
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
                                                   friends: channel ? [] : Array(picked))
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

    var body: some View {
        NavigationStack {
            List {
                TextField(tr("Название канала", "Channel title", "Kanaltitel"), text: $q)
                    .onChange(of: q) { v in Task { results = await store.findChannels(v) } }
                ForEach(results) { c in
                    HStack {
                        Text("📢 " + c.title).onTapGesture { onOpen("c:" + c.id) }
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

struct ChatInfoSheet: View {
    @ObservedObject private var store = Store.shared
    let key: String
    var onLeft: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nick = ""
    @State private var error = ""
    @State private var avItem: PhotosPickerItem?

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
                            Avatar(nick: c.title, url: c.avatarUrl, size: 56)
                            Text((c.kind == "channel" ? tr("Канал", "Channel", "Kanal") : tr("Группа", "Group", "Gruppe")) + " · \(mem.count)")
                                .foregroundColor(.secondary)
                        }
                        if isAdmin {
                            PhotosPicker(selection: $avItem, matching: .images) {
                                Text("🖼 " + tr("Сменить аватарку", "Change avatar", "Avatar ändern"))
                            }
                        }
                    }
                    if c.kind == "group" && isAdmin {
                        Section(tr("Добавить участника", "Add member", "Mitglied hinzufügen")) {
                            let have = Set(mem.map { $0.userId })
                            ForEach(store.friendIds.filter { !have.contains($0) }.compactMap { store.profiles[$0] }) { p in
                                Button("＋ " + p.nick) { Task { try? await store.addMember(c.id, p.id) } }
                            }
                            TextField(tr("Или ник", "Or nick", "Oder Nick"), text: $nick).autocapitalization(.none)
                            Button(tr("Добавить по нику", "Add by nick", "Per Nick hinzufügen")) { addByNick(c.id) }
                            if !error.isEmpty { Text(error).foregroundColor(.red).font(.system(size: 13)) }
                        }
                    }
                    if c.kind == "group" || isAdmin {
                        Section(tr("Участники", "Members", "Mitglieder")) {
                            ForEach(mem, id: \.userId) { m in
                                HStack {
                                    Text((m.userId == store.myId ? tr("Вы", "You", "Du") : (store.profiles[m.userId]?.nick ?? ""))
                                         + (m.role == "owner" ? " 👑" : (m.role == "admin" ? " ★" : "")))
                                    Spacer()
                                    if isOwner && m.userId != store.myId {
                                        Button { Task { await store.setRole(c.id, m.userId, m.role == "admin" ? "member" : "admin") } } label: {
                                            Image(systemName: m.role == "admin" ? "star.fill" : "star")
                                        }
                                        .buttonStyle(.borderless)
                                        Button { Task { try? await store.kickMember(c.id, m.userId) } } label: { Image(systemName: "xmark") }
                                            .buttonStyle(.borderless)
                                    }
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
