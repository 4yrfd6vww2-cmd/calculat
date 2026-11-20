import SwiftUI

@main
struct NeiroxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @ObservedObject private var store = Store.shared
    @ObservedObject private var st = Settings.shared

    var body: some View {
        Group {
            if store.loggedIn {
                MainTabs()
            } else {
                AuthFlow()
            }
        }
        .preferredColorScheme(Theme.scheme)
        .dynamicTypeSize(st.textSize.dynamic)
        .task {
            if store.loggedIn { await store.start() }
        }
    }
}

struct MainTabs: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared

    private var totalUnread: Int {
        store.messages.filter { $0.receiver == store.myId && $0.readAt == nil }.count
    }

    var body: some View {
        TabView {
            ChatsView()
                .tabItem { Label(tr("Чаты", "Chats", "Chats"), systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(totalUnread)
            FriendsView()
                .tabItem { Label(tr("Друзья", "Friends", "Freunde"), systemImage: "person.2.fill") }
                .badge(store.incoming.count)
            PlayerView()
                .tabItem { Label(tr("Плеер", "Player", "Player"), systemImage: "music.note") }
            SettingsView()
                .tabItem { Label(tr("Настройки", "Settings", "Einstellungen"), systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
    }
}

extension View {
    func neonScreen(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(Theme.scheme, for: .navigationBar)
            .toolbarBackground(Theme.bgBottom, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(Theme.scheme, for: .tabBar)
    }
}
