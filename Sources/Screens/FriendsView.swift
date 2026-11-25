import SwiftUI

struct FriendsView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    @State private var query = ""
    @State private var results: [Profile] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var error = ""
    @State private var showQR = false

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private func row<T: View>(_ p: Profile, @ViewBuilder trailing: () -> T) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                Avatar(nick: p.nick, url: p.avatarUrl, size: 37)
                Text(Store.shared.dname(p) + (Store.shared.alias[p.id] != nil ? " (" + p.nick + ")" : ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.text)
                Spacer()
                trailing()
            }
        }
    }

    private func smallButton(_ title: String, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(filled ? .white : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.card))
                .clipShape(Capsule())
        }
    }

    private func run(_ block: @escaping () async throws -> Void) {
        error = ""
        Task {
            do { try await block() } catch {
                self.error = friendlyError((error as? APIError)?.message ?? error.localizedDescription)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        GlassField(placeholder: tr("Найти по нику", "Search by nick", "Nach Nick suchen"), text: $query, clearable: true)
                        ErrorText(text: error)

                        if !query.isEmpty {
                            sectionTitle(tr("Результаты", "Results", "Ergebnisse"))
                            if results.isEmpty {
                                Text(tr("Никого не найдено", "Nobody found", "Niemand gefunden"))
                                    .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                            ForEach(results) { p in
                                row(p) {
                                    if let f = store.friendship(with: p.id) {
                                        Text(f.status == "accepted"
                                             ? tr("Друг", "Friend", "Freund")
                                             : tr("Заявка", "Pending", "Anfrage"))
                                            .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                                    } else {
                                        smallButton(tr("Добавить", "Add", "Hinzufügen")) {
                                            run { try await store.sendRequest(to: p.id) }
                                        }
                                    }
                                }
                            }
                        }

                        if !store.incoming.isEmpty {
                            sectionTitle(tr("Заявки в друзья", "Friend requests", "Freundschaftsanfragen"))
                            ForEach(store.incoming) { f in
                                if let p = store.profiles[f.requester] {
                                    row(p) {
                                        HStack(spacing: 8) {
                                            smallButton(tr("Принять", "Accept", "Annehmen")) { run { try await store.accept(f) } }
                                            smallButton(tr("Отклонить", "Decline", "Ablehnen"), filled: false) { run { try await store.removeFriendship(f) } }
                                        }
                                    }
                                }
                            }
                        }

                        sectionTitle(tr("Друзья", "Friends", "Freunde"))
                        let friends = store.friendIds.compactMap { store.profiles[$0] }.sorted { $0.nick < $1.nick }
                        if friends.isEmpty {
                            Text(tr("Пока нет друзей. Найди человека по нику и отправь заявку.",
                                    "No friends yet. Find someone by nick and send a request.",
                                    "Noch keine Freunde. Suche jemanden per Nick und sende eine Anfrage."))
                                .font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                        }
                        ForEach(friends) { p in
                            row(p) {
                                if let f = store.friendship(with: p.id) {
                                    smallButton(tr("Удалить", "Remove", "Entfernen"), filled: false) {
                                        run { try await store.removeFriendship(f) }
                                    }
                                }
                            }
                        }

                        if !store.outgoing.isEmpty {
                            sectionTitle(tr("Отправленные заявки", "Sent requests", "Gesendete Anfragen"))
                            ForEach(store.outgoing) { f in
                                if let p = store.profiles[f.addressee] {
                                    row(p) {
                                        smallButton(tr("Отменить", "Cancel", "Abbrechen"), filled: false) {
                                            run { try await store.removeFriendship(f) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .neonScreen(tr("Друзья", "Friends", "Freunde"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showQR = true } label: { Image(systemName: "qrcode") }
                }
            }
            .sheet(isPresented: $showQR) { AddFriendQRScreen() }
            .onChange(of: query) { q in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    if Task.isCancelled { return }
                    let r = await store.search(q)
                    if !Task.isCancelled { results = r }
                }
            }
        }
    }
}
