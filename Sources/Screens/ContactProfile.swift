import SwiftUI

@MainActor
private func sharedMedia(_ store: Store, _ friendId: String) -> [Message] {
    store.thread(with: friendId).filter { $0.kind == "image" && $0.mediaPath != nil && !$0.isSticker }
}

struct ContactProfileSheet: View {
    @ObservedObject private var store = Store.shared
    let friendId: String
    var onCall: () -> Void
    var onSearch: () -> Void
    var onClose: () -> Void

    @State private var showName = false
    @State private var nameText = ""
    @State private var showAllMedia = false
    @State private var error = ""

    private var friend: Profile { store.profiles[friendId] ?? Profile(id: friendId, nick: "") }
    private var media: [Message] { sharedMedia(store, friendId) }
    private var blockedByMe: Bool { store.iBlocked(friendId) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill(
                                RadialGradient(colors: [Theme.accent.opacity(0.55), Theme.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 80)
                            ).frame(width: 150, height: 150)
                            Avatar(nick: friend.nick, url: friend.avatarUrl, size: 108)
                        }
                        .padding(.top, 10)

                        Text(store.dname(friend))
                            .font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
                        if friend.nick != store.dname(friend) {
                            Text("@" + friend.nick).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                        }
                        let lb = store.levelBadge(friendId)
                        if !lb.isEmpty {
                            Text(lb).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.accent)
                        }
                        Text(store.isOnline(friend) ? tr("в сети", "online", "online") : tr("был(а) недавно", "last seen recently", "zuletzt online"))
                            .font(.system(size: 13)).foregroundColor(Theme.textSecondary)

                        HStack(spacing: 14) {
                            profilePill("phone.fill", tr("Звонок", "Call", "Anruf"), enabled: !blockedByMe) { onCall(); onClose() }
                            profilePill(store.isMuted(friendId) ? "bell.fill" : "bell.slash.fill",
                                        store.isMuted(friendId) ? tr("Звук", "Unmute", "Ton an") : tr("Без звука", "Mute", "Stumm"), enabled: true) {
                                Task { await store.setPref(friendId, "muted", !store.isMuted(friendId)) }
                            }
                            profilePill("magnifyingglass", tr("Поиск", "Search", "Suche"), enabled: true) { onSearch(); onClose() }
                            profilePill(blockedByMe ? "checkmark.circle" : "hand.raised.fill",
                                        blockedByMe ? tr("Разблок.", "Unblock", "Entsperren") : tr("Блок.", "Block", "Blockieren"),
                                        enabled: true, danger: !blockedByMe) {
                                Task {
                                    do {
                                        if blockedByMe { try await store.unblockUser(friendId) } else { try await store.blockUser(friendId) }
                                    } catch { self.error = friendlyError("\(error)") }
                                }
                            }
                        }
                        if !error.isEmpty { ErrorText(text: error) }

                        VStack(spacing: 10) {
                            HStack {
                                Text(tr("Имя контакта", "Contact name", "Kontaktname")).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text(store.alias[friendId] ?? tr("не задано", "not set", "nicht gesetzt")).font(.system(size: 13)).foregroundColor(Theme.accent)
                            }
                            HStack {
                                Text(tr("Сообщений", "Messages", "Nachrichten")).font(.system(size: 13)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(store.thread(with: friendId).count)").font(.system(size: 13)).foregroundColor(Theme.text)
                            }
                        }
                        .padding(16)
                        .background(Theme.card)
                        .cornerRadius(16)
                        .contentShape(Rectangle())
                        .onTapGesture { nameText = store.alias[friendId] ?? ""; showName = true }
                        .padding(.horizontal, 16)

                        if !media.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(tr("Общие медиа", "Shared media", "Geteilte Medien")).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.text)
                                    Spacer()
                                    if media.count > 8 {
                                        Button(tr("Показать все", "Show all", "Alle anzeigen")) { showAllMedia = true }
                                            .font(.system(size: 13)).foregroundColor(Theme.accent)
                                    }
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(media.suffix(12).reversed()) { m in
                                            if let p = m.mediaPath {
                                                MediaImage(path: p).frame(width: 84, height: 84).clipped().cornerRadius(10)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onClose() } label: { Image(systemName: "chevron.left") }
                }
            }
            .alert(tr("Имя контакта", "Contact name", "Kontaktname"), isPresented: $showName) {
                TextField(tr("Имя", "Name", "Name"), text: $nameText)
                Button(tr("Сохранить", "Save", "Speichern")) { Task { await store.setAlias(friendId, String(nameText.prefix(40))) } }
                Button(tr("Отмена", "Cancel", "Abbrechen"), role: .cancel) {}
            }
            .sheet(isPresented: $showAllMedia) {
                NavigationStack {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                            ForEach(media.reversed()) { m in
                                if let p = m.mediaPath {
                                    MediaImage(path: p).frame(height: 120).clipped()
                                }
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { showAllMedia = false } label: { Image(systemName: "chevron.left") }
                        }
                    }
                    .navigationTitle(tr("Общие медиа", "Shared media", "Geteilte Medien"))
                }
            }
        }
    }

    @ViewBuilder
    private func profilePill(_ icon: String, _ label: String, enabled: Bool, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: enabled ? action : {}) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 11)).lineLimit(1)
            }
            .foregroundColor(danger ? .red : Theme.textSecondary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.card)
            .cornerRadius(16)
        }
        .opacity(enabled ? 1 : 0.4)
    }
}
