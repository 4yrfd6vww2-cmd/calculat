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
    @ObservedObject private var calls = Calls.shared

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
        .fullScreenCover(isPresented: Binding(get: { calls.state != .idle && store.loggedIn }, set: { _ in })) {
            CallView()
        }
        .overlay(alignment: .top) { if store.loggedIn { UpdateBanner() } }
        .task {
            Updater.shared.start()
            if store.loggedIn { await store.start() }
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            PlayerStore.shared.importFiles([url]) { added, _ in
                if added > 0 { Store.shared.selectedTab = 2 }
            }
        }
    }
}

struct MainTabs: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared

    private var totalUnread: Int {
        store.totalUnread
    }

    var body: some View {
        TabView(selection: $store.selectedTab) {
            ChatsView()
                .tabItem { Label(tr("Чаты", "Chats", "Chats"), systemImage: "bubble.left.and.bubble.right.fill") }
                .badge(totalUnread)
                .tag(0)
            FriendsView()
                .tabItem { Label(tr("Друзья", "Friends", "Freunde"), systemImage: "person.2.fill") }
                .badge(store.incoming.count)
                .tag(1)
            PlayerView()
                .tabItem { Label(tr("Плеер", "Player", "Player"), systemImage: "music.note") }
                .tag(2)
            SettingsView()
                .tabItem { Label(tr("Настройки", "Settings", "Einstellungen"), systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(Theme.accent)
        .onAppear { if #unavailable(iOS 26) { applyTabBarStyle() } }
        .onChange(of: st.accentHex) { _ in if #unavailable(iOS 26) { applyTabBarStyle() } }
        .onChange(of: st.mode) { _ in if #unavailable(iOS 26) { applyTabBarStyle() } }
    }
}

func applyTabBarStyle() {
    let a = UITabBarAppearance()
    a.configureWithOpaqueBackground()
    a.backgroundColor = UIColor(Theme.bgBottom)
    let selected = UIColor(Theme.accent)
    let normal = UIColor(Theme.textSecondary)
    for l in [a.stackedLayoutAppearance, a.inlineLayoutAppearance, a.compactInlineLayoutAppearance] {
        l.selected.iconColor = selected
        l.selected.titleTextAttributes = [.foregroundColor: selected]
        l.normal.iconColor = normal
        l.normal.titleTextAttributes = [.foregroundColor: normal]
    }
    UITabBar.appearance().standardAppearance = a
    UITabBar.appearance().scrollEdgeAppearance = a
    for scene in UIApplication.shared.connectedScenes {
        if let ws = scene as? UIWindowScene {
            for w in ws.windows { restyleTabBars(in: w, a) }
        }
    }
}

private func restyleTabBars(in view: UIView, _ a: UITabBarAppearance) {
    if let tb = view as? UITabBar {
        tb.standardAppearance = a
        tb.scrollEdgeAppearance = a
    }
    for s in view.subviews { restyleTabBars(in: s, a) }
}

struct NavBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // iOS 26: системное «жидкое стекло» — не перекрываем фон панели
            content.toolbarColorScheme(Theme.scheme, for: .navigationBar)
        } else {
            content
                .toolbarBackground(Theme.bgTop, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(Theme.scheme, for: .navigationBar)
        }
    }
}

extension View {
    func neonScreen(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(NavBarStyle())
    }
}
