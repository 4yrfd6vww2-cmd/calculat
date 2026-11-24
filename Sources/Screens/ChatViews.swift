import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

func compressedJPEG(from data: Data, maxSide: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
    guard let img = UIImage(data: data) else { return nil }
    let size = img.size
    let scale = min(1, maxSide / max(size.width, size.height))
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let out = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
    return out.jpegData(compressionQuality: quality)
}

/// Читает файл так, чтобы iCloud успел его скачать (иначе файл «пустой»)
func readFileCoordinated(_ url: URL) -> Data? {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    var coordError: NSError?
    var result: Data?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
        result = try? Data(contentsOf: readURL)
    }
    return result
}

let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = .none
    return f
}()

// MARK: - Список чатов

struct ChatsView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    @ObservedObject private var inbox = AIInbox.shared
    @State private var aiActive = false

    struct Row: Identifiable { let key: String; let title: String; let profile: Profile?; let chat: Chat?; var id: String { key } }
    @State private var showCreate = false
    @State private var showFind = false
    @State private var showCode = false
    @State private var showSearch = false
    @State private var openKey: String?

    private var friends: [Row] {
        var list: [Row] = store.friendIds.compactMap { store.profiles[$0] }.map { Row(key: $0.id, title: store.dname($0), profile: $0, chat: nil) }
        list += store.chats.map { Row(key: "c:" + $0.id, title: $0.title, profile: nil, chat: $0) }
        return list.sorted { a, b in
            let la = store.thread(with: a.key).last?.createdAt ?? .distantPast
            let lb = store.thread(with: b.key).last?.createdAt ?? .distantPast
            let pa = store.isPinned(a.key)
            let pb = store.isPinned(b.key)
            if pa != pb { return pa }
            if la != lb { return la > lb }
            return a.title < b.title
        }
    }

    private func titleLine(_ r: Row) -> String {
        return r.title
    }

    private func rowMenuActions(_ k: String) -> [MenuAction] {
        [
            MenuAction(icon: "pin", title: store.isPinned(k) ? tr("Открепить чат", "Unpin chat", "Chat lösen") : tr("Закрепить чат", "Pin chat", "Chat anheften")) {
                Task { await store.setPref(k, "pinned", !store.isPinned(k)) }
            },
            MenuAction(icon: "bell.slash", title: store.isMuted(k) ? tr("Включить уведомления", "Unmute", "Ton an") : tr("Выключить уведомления", "Mute", "Stummschalten")) {
                Task { await store.setPref(k, "muted", !store.isMuted(k)) }
            }
        ]
    }

    private func previewIcon(_ m: Message?) -> String? {
        guard let m = m else { return nil }
        switch m.kind {
        case "image": return m.isSticker ? "tag.fill" : "photo.fill"
        case "file": return "paperclip"
        case "album":
            let a = m.attachments ?? []
            if !a.isEmpty && a.allSatisfy({ $0.type == "voice" }) { return "mic.fill" }
            if !a.isEmpty && a.allSatisfy({ $0.type == "image" }) { return "photo.fill" }
            if !a.isEmpty && a.allSatisfy({ $0.type == "video" }) { return "video.fill" }
            return "paperclip"
        default: return nil
        }
    }

    private func preview(_ m: Message?) -> String {
        guard let m = m else { return tr("Нет сообщений", "No messages", "Keine Nachrichten") }
        let prefix = m.sender == store.myId ? tr("Вы: ", "You: ", "Du: ") : (m.chatId != nil ? store.dnameId(m.sender) + ": " : "")
        switch m.kind {
        case "image": return prefix + (m.isSticker ? tr("Стикер", "Sticker", "Sticker") : tr("Фото", "Photo", "Foto"))
        case "file": return prefix + (m.fileName ?? tr("Файл", "File", "Datei"))
        case "album":
            let a = m.attachments ?? []
            var base: String
            if !a.isEmpty && a.allSatisfy({ $0.type == "voice" }) { base = tr("Голосовое сообщение", "Voice message", "Sprachnachricht") }
            else if !a.isEmpty && a.allSatisfy({ $0.type == "image" }) { base = tr("Фото", "Photo", "Foto") + (a.count > 1 ? " (\(a.count))" : "") }
            else if !a.isEmpty && a.allSatisfy({ $0.type == "video" }) { base = tr("Видео", "Video", "Video") + (a.count > 1 ? " (\(a.count))" : "") }
            else { base = tr("Вложения", "Attachments", "Anhänge") + " (\(a.count))" }
            if let b = m.body, !b.isEmpty { base += ": " + b }
            return prefix + base
        default: return prefix + (m.body ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 10) {
                        NavigationLink(destination: AIChatView()) {
                            GlassCard {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Theme.accentGradient)
                                        Image(systemName: "sparkles").foregroundColor(.white)
                                    }
                                    .frame(width: 40, height: 40)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tr("Умный Чат (ИИ)", "Smart Chat (AI)", "Smarter Chat (KI)"))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Theme.text)
                                        Text(tr("Вопросы и картинки", "Questions and images", "Fragen und Bilder"))
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 18) {
                            Button { showCreate = true } label: { Label(tr("Группа / канал", "Group / channel", "Gruppe / Kanal"), systemImage: "plus.circle") }
                            Button { showFind = true } label: { Label(tr("Найти канал", "Find channel", "Kanal suchen"), systemImage: "magnifyingglass") }
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 4)

                        HStack(spacing: 18) {
                            Button { showSearch = true } label: { Label(tr("Поиск сообщений", "Search messages", "Nachrichten suchen"), systemImage: "text.magnifyingglass") }
                            Button { showCode = true } label: { Label(tr("Войти по коду", "Join by code", "Per Code"), systemImage: "key.fill") }
                            Spacer()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 4)

                        ForEach(friends) { p in
                            NavigationLink(destination: ChatView(key: p.key)) {
                                GlassCard {
                                    HStack(spacing: 12) {
                                        if let pr = p.profile {
                                            Avatar(nick: pr.nick, url: pr.avatarUrl, size: 40)
                                        } else {
                                            Avatar(nick: p.title, url: p.chat?.avatarUrl, size: 40)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                if store.isPinned(p.key) {
                                                    Image(systemName: "pin.fill").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                                                }
                                                Text(titleLine(p))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Theme.text)
                                                if p.profile != nil, !store.levelBadge(p.key).isEmpty {
                                                    Text(store.levelBadge(p.key))
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(Theme.accent)
                                                }
                                                if store.isMuted(p.key) {
                                                    Image(systemName: "bell.slash.fill").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                                                }
                                            }
                                            HStack(spacing: 4) {
                                                if let icon = previewIcon(store.thread(with: p.key).last) {
                                                    Image(systemName: icon).font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                                                }
                                                Text(preview(store.thread(with: p.key).last))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Theme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        let n = store.unread(from: p.key)
                                        if n > 0 {
                                            Text("\(n)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(store.isMuted(p.key) ? Theme.textSecondary : Theme.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .customActionMenu(actions: rowMenuActions(p.key))
                        }

                        if friends.isEmpty {
                            Text(tr("Добавь друзей на вкладке «Друзья», чтобы начать переписку.",
                                    "Add friends in the Friends tab to start chatting.",
                                    "Füge im Tab „Freunde“ Freunde hinzu, um zu chatten."))
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 24)
                        }
                    }
                    .padding(16)
                }
            }
            .neonScreen(tr("Чаты", "Chats", "Chats"))
            .navigationDestination(isPresented: $aiActive) { AIChatView() }
            .navigationDestination(isPresented: Binding(get: { openKey != nil }, set: { if !$0 { openKey = nil } })) {
                if let k = openKey { ChatView(key: k) }
            }
            .sheet(isPresented: $showCreate) { CreateChatSheet { k in showCreate = false; openKey = k } }
            .sheet(isPresented: $showFind) { FindChannelSheet { k in showFind = false; openKey = k } }
            .sheet(isPresented: $showCode) { JoinCodeSheet { k in showCode = false; openKey = k } }
            .sheet(isPresented: $showSearch) { SearchSheet(only: nil) { k, id in showSearch = false; store.jumpTo = id; openKey = k } }
            .onChange(of: inbox.pending) { v in
                if v != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { aiActive = true }
                }
            }
        }
    }
}

// MARK: - Переписка

struct MediaImage: View {
    let path: String
    @State private var url: URL?

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Image(systemName: "photo").foregroundColor(Theme.textSecondary)
                    } else {
                        ProgressView()
                    }
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: 220, maxHeight: 260)
        .task { url = try? await API.shared.signedURL(bucket: "chat-media", path: path) }
    }
}

struct MediaImageFull: View {
    let path: String
    @State private var url: URL?
    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFit() } else { ProgressView() }
                }
            } else { ProgressView() }
        }
        .task { url = try? await API.shared.signedURL(bucket: "chat-media", path: path) }
    }
}

final class AIInbox: ObservableObject {
    static let shared = AIInbox()
    @Published var pending: String?
}

struct Bubble: View {
    @ObservedObject private var st = Settings.shared
    let m: Message
    let mine: Bool
    var selected: Bool = false
    var selecting: Bool = false
    var onToggle: () -> Void = {}
    var onImage: (String) -> Void = { _ in }
    var onVideo: (String) -> Void = { _ in }
    var onCopy: () -> Void = {}
    var onEdit: (() -> Void)? = nil
    var onForward: () -> Void = {}
    var onDelete: () -> Void = {}
    var onPin: (() -> Void)? = nil
    var pinnedNow: Bool = false
    var quoted: Message? = nil
    var showNick: Bool = false
    var rx: [Reaction] = []
    var onReply: () -> Void = {}
    var onReact: (String) -> Void = { _ in }
    @Environment(\.openURL) private var openURL
    private let store = Store.shared
    @State private var dragX: CGFloat = 0

    private func bubbleMenuActions() -> [MenuAction] {
        var items: [MenuAction] = [
            MenuAction(icon: "arrowshape.turn.up.left", title: tr("Ответить", "Reply", "Antworten")) { onReply() },
            MenuAction(icon: "doc.on.doc", title: tr("Копировать", "Copy", "Kopieren")) { onCopy() }
        ]
        if let e = onEdit {
            items.append(MenuAction(icon: "square.and.pencil", title: tr("Изменить", "Edit", "Bearbeiten")) { e() })
        }
        if let pin = onPin {
            items.append(MenuAction(icon: "pin", title: pinnedNow ? tr("Открепить", "Unpin", "Lösen") : tr("Закрепить", "Pin", "Anheften")) { pin() })
        }
        items.append(MenuAction(icon: "arrowshape.turn.up.right", title: tr("Переслать", "Forward", "Weiterleiten")) { onForward() })
        items.append(MenuAction(icon: "trash", title: tr("Удалить", "Delete", "Löschen"), destructive: true) { onDelete() })
        items.append(MenuAction(icon: "checkmark.circle", title: tr("Выделить", "Select", "Auswählen")) { onToggle() })
        return items
    }

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if showNick {
                    Text(store.dnameId(m.sender)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.accent)
                }
                if m.replyTo != nil { quoteView }
                content
                if !rx.isEmpty { rxView }
                Text((m.editedAt != nil ? tr("изм. ", "edited ", "bearb. ") : "") + timeFormatter.string(from: m.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(mine ? Color.white.opacity(0.7) : Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if mine { Theme.accentGradient } else { LinearGradient(colors: [Theme.card, Theme.card], startPoint: .leading, endPoint: .trailing) }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(mine ? Color.clear : Theme.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .onTapGesture {
                if selecting { onToggle() }
                else if m.kind == "image", let p = m.mediaPath { onImage(p) }
                else if m.kind == "file", let p = m.mediaPath {
                    Task { if let u = try? await API.shared.signedURL(bucket: "chat-media", path: p) { openURL(u) } }
                }
            }
            .customActionMenu(
                reactions: selecting ? [] : ["👍", "❤️", "😂", "😮", "😢", "🔥"],
                onReact: selecting ? nil : { e in onReact(e) },
                actions: selecting ? [] : bubbleMenuActions()
            )
            if !mine { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
        .background(selected ? Theme.accent.opacity(0.2) : Color.clear)
        .offset(x: dragX)
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 25)
            .onChanged { v in
                guard !selecting else { return }
                let w = v.translation.width
                if w > 0 && w > abs(v.translation.height) * 1.5 { dragX = min(w, 80) }
            }
            .onEnded { _ in
                if dragX > 55 { onReply() }
                withAnimation { dragX = 0 }
            }
    }

    private var quoteName: String {
        guard let q = quoted else { return tr("Сообщение удалено", "Message deleted", "Nachricht gelöscht") }
        if q.sender == store.myId { return tr("Вы", "You", "Du") }
        return store.dnameId(q.sender)
    }

    private var quoteView: some View {
        let fg: Color = mine ? Color.white : Theme.text
        return VStack(alignment: .leading, spacing: 1) {
            Text(quoteName).font(.system(size: 11, weight: .semibold))
            if let q = quoted {
                if let body = q.body {
                    Text(body).font(.system(size: 12)).lineLimit(2).opacity(0.85)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip").font(.system(size: 11))
                        Text(tr("Вложение", "Attachment", "Anhang")).font(.system(size: 12))
                    }.opacity(0.85)
                }
            }
        }
        .foregroundColor(fg)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var rxGroups: [(String, Int)] {
        var d: [String: Int] = [:]
        for r in rx { d[r.emoji, default: 0] += 1 }
        return d.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private var rxView: some View {
        HStack(spacing: 4) {
            ForEach(rxGroups, id: \.0) { g in
                let label: String = g.1 > 1 ? g.0 + " " + String(g.1) : g.0
                Text(label)
                    .font(.system(size: 11))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
                    .onTapGesture { onReact(g.0) }
            }
        }
    }

    @ViewBuilder private var content: some View {
        if m.kind == "image", let p = m.mediaPath {
            if m.isSticker { MediaImage(path: p).frame(width: 150, height: 150) } else { MediaImage(path: p) }
        } else if m.kind == "file", let p = m.mediaPath {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                Text(m.fileName ?? "file").lineLimit(2).multilineTextAlignment(.leading)
            }
            .foregroundColor(mine ? .white : Theme.text)
        } else if m.kind == "album" {
            AlbumView(m: m, mine: mine, selecting: selecting, onToggle: onToggle, onImage: onImage, onVideo: onVideo)
        } else if isBigEmoji(m.body) {
            Text(m.body ?? "").font(.system(size: 38))
        } else {
            Text(linkified(m.body ?? "", mine: mine))
                .foregroundColor(mine ? .white : Theme.text)
                .tint(mine ? .white : Theme.accent)
        }
    }
}

struct ChatView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    let key: String
    @State private var replyTo: Message?
    @State private var showInfo = false
    @State private var showProfile = false
    @State private var typingTick = 0
    private var chat: Chat? { store.chatByKey(key) }
    private var friend: Profile { store.profiles[key] ?? Profile(id: key, nick: "") }
    private var subtitle: String {
        let t = store.typingIn(key)
        if !t.isEmpty {
            let who: String = chat != nil ? t.map { store.dname($0) }.joined(separator: ", ") + " " : ""
            return who + tr("печатает…", "typing…", "tippt …")
        }
        if let c = chat {
            let kindName: String = c.kind == "channel" ? tr("Канал", "Channel", "Kanal") : tr("Группа", "Group", "Gruppe")
            return kindName + " · " + String(store.memberCount(key))
        }
        let st: String = store.isOnline(friend) ? tr("в сети", "online", "online") : tr("был(а) недавно", "last seen recently", "zuletzt online")
        return st + store.levelTag(key)
    }
    @State private var text = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var pending: [PendingItem] = []
    @State private var showEmoji = false
    @State private var showStk = false
    @State private var showSearch = false
    @State private var showName = false
    @State private var nameText = ""
    @State private var videoPath: String?
    @StateObject private var recorder = VoiceRecorder()
    @State private var showFiles = false
    @State private var showAI = false
    @State private var aiPrompt = ""
    @State private var busy = false
    @State private var error = ""
    @State private var dropTargeted = false
    @State private var selected = Set<Int>()
    @State private var editing: Message?
    @State private var showForward = false
    @State private var showDelete = false
    @State private var fullscreenPath: String?
    @Environment(\.dismiss) private var dismiss
    var onForwardToAI: ((String) -> Void)? = nil

    private var selMsgs: [Message] { thread.filter { selected.contains($0.id) } }

    private func toggle(_ id: Int) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private var thread: [Message] { store.thread(with: key) }

    private var customHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
            }
            .frame(width: 28, height: 28)
            Text(chat?.title ?? store.dname(friend))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 6)
            if !selected.isEmpty {
                HStack(spacing: 16) {
                    if selMsgs.count == 1, let one = selMsgs.first, one.sender == store.myId, one.kind == "text" {
                        Button { editing = one; text = one.body ?? ""; selected = [] } label: { Image(systemName: "pencil") }
                    }
                    Button { copySelected() } label: { Image(systemName: "doc.on.doc") }
                    Button { showForward = true } label: { Image(systemName: "arrowshape.turn.up.right") }
                    Button { showDelete = true } label: { Image(systemName: "trash") }
                    Button { selected = [] } label: { Image(systemName: "xmark") }
                }
            } else if chat != nil {
                HStack(spacing: 16) {
                    moreMenu
                    Button { showInfo = true } label: { Image(systemName: "info.circle") }
                }
            } else {
                HStack(spacing: 16) {
                    moreMenu
                    if !store.iBlocked(key) {
                        Button { Calls.shared.start(peer: key, video: true) } label: { Image(systemName: "video.fill") }
                        Button { Calls.shared.start(peer: key) } label: { Image(systemName: "phone.fill") }
                    }
                }
            }
        }
        .font(.system(size: 17))
        .foregroundColor(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                customHeader
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(!store.typingIn(key).isEmpty || (chat == nil && store.isOnline(friend)) ? Theme.accent : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture { if chat != nil { showInfo = true } else { showProfile = true } }
                pinBar
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(thread) { m in
                                bubbleRow(m)
                            }
                        }
                        .padding(14)
                    }
                    .onChange(of: thread.count) { _ in
                        if let last = thread.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                        Task { await store.markRead(from: key) }
                    }
                    .onAppear {
                        if let last = thread.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        if store.jumpTo != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { jump(proxy) }
                        }
                    }
                    .onChange(of: store.jumpTo) { _ in jump(proxy) }
                }
                if !error.isEmpty { ErrorText(text: error).padding(.horizontal, 14) }
                if let rt = replyTo, editing == nil {
                    HStack {
                        Image(systemName: "arrowshape.turn.up.left.fill").font(.system(size: 11)).foregroundColor(Theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rt.sender == store.myId ? tr("Вы", "You", "Du") : store.dnameId(rt.sender))
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.accent)
                            HStack(spacing: 4) {
                                if rt.body == nil {
                                    Image(systemName: rt.kind == "image" ? "photo.fill" : "paperclip").font(.system(size: 10))
                                }
                                Text(rt.body ?? (rt.kind == "image" ? tr("Фото", "Photo", "Foto") : tr("Файл", "File", "Datei")))
                                    .font(.system(size: 11)).lineLimit(1)
                            }.foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Button { replyTo = nil } label: { Image(systemName: "xmark").foregroundColor(Theme.textSecondary) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Theme.card)
                }
                if editing != nil {
                    HStack {
                        Image(systemName: "pencil").font(.system(size: 11)).foregroundColor(Theme.accent)
                        Text(tr("Редактирование", "Editing", "Bearbeiten")).font(.system(size: 11)).foregroundColor(Theme.accent)
                        Spacer()
                        Button { editing = nil; text = "" } label: { Image(systemName: "xmark").foregroundColor(Theme.textSecondary) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Theme.card)
                }
                if !pending.isEmpty && editing == nil {
                    PendingTray(items: pending) { p in pending.removeAll { $0.id == p.id } }
                }
                if showEmoji { EmojiPanel { text += $0 } }
                if showStk { StickerPanel(onEmoji: { sendEmojiSticker($0) }, onOwn: { sendOwnSticker($0) }) }
                inputBar
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showForward) { forwardSheet }
        .overlay(
            PromptDialogOverlay(
                isPresented: $showName,
                title: tr("Имя контакта", "Contact name", "Kontaktname"),
                message: tr("Видно только вам. Ник: ", "Only you can see it. Nick: ", "Nur für dich sichtbar. Nick: ") + friend.nick,
                placeholder: tr("Например: папа, начальник", "E.g. dad, boss", "z. B. Papa, Chef"),
                text: $nameText,
                confirmTitle: tr("Сохранить", "Save", "Speichern"),
                onConfirm: { Task { await store.setAlias(key, String(nameText.prefix(40))) } }
            )
        )
        .sheet(isPresented: $showSearch) { SearchSheet(only: key) { _, id in showSearch = false; store.jumpTo = id } }
        .sheet(isPresented: $showInfo) { ChatInfoSheet(key: key) { showInfo = false; dismiss() } }
        .sheet(isPresented: $showProfile) { ContactProfileSheet(friendId: key, onCall: { Calls.shared.start(peer: key) }, onSearch: { showSearch = true }) { showProfile = false } }
        .onChange(of: text) { t in if !t.isEmpty { store.sendTyping(to: key) } }
        .overlay(
            ConfirmDialogOverlay(
                isPresented: $showDelete,
                title: tr("Удалить сообщения?", "Delete messages?", "Nachrichten löschen?"),
                buttons: {
                    var b = [DialogButton(title: tr("У меня", "For me", "Für mich"), destructive: true) { deleteSelected(forAll: false) }]
                    if !selMsgs.isEmpty && selMsgs.allSatisfy({ $0.sender == store.myId }) {
                        b.append(DialogButton(title: tr("У всех", "For everyone", "Für alle"), destructive: true) { deleteSelected(forAll: true) })
                    }
                    b.append(DialogButton(title: tr("Отмена", "Cancel", "Abbrechen"), cancel: true) {})
                    return b
                }()
            )
        )
        .fullScreenCover(isPresented: Binding(get: { fullscreenPath != nil }, set: { if !$0 { fullscreenPath = nil } })) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let p = fullscreenPath { MediaImageFull(path: p) }
            }
            .onTapGesture { fullscreenPath = nil }
        }
        .fullScreenCover(isPresented: Binding(get: { videoPath != nil }, set: { if !$0 { videoPath = nil } })) {
            ZStack(alignment: .topTrailing) {
                if let p = videoPath { VideoFullView(path: p) }
                Button { videoPath = nil } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 24)).foregroundColor(.white.opacity(0.9)).padding(16)
                }
            }
        }
        .task { await store.markRead(from: key) }
        .onDisappear { recorder.cancel() }
        .sheet(isPresented: $showFiles) {
            DocPicker(types: [.item]) { urls in
                showFiles = false
                for u in urls { addFile(u) }
            }
            .ignoresSafeArea()
        }
        .onDrop(of: [.item], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.accent, lineWidth: dropTargeted ? 3 : 0)
                .padding(6)
                .allowsHitTesting(false)
        )
        .overlay(
            PromptDialogOverlay(
                isPresented: $showAI,
                title: tr("Картинка от ИИ", "AI image", "KI-Bild"),
                placeholder: tr("Опиши картинку", "Describe the image", "Bild beschreiben"),
                text: $aiPrompt,
                confirmTitle: tr("Создать и отправить", "Create and send", "Erstellen und senden"),
                onConfirm: { sendAIImage() },
                onCancel: { aiPrompt = "" }
            )
        )
        .onChange(of: photoItems) { items in
            guard !items.isEmpty else { return }
            Task {
                for item in items { await addPhoto(item) }
                photoItems = []
            }
        }
    }

    private var isAdm: Bool {
        guard let c = chat else { return false }
        let r = store.myMember(key)?.role
        return c.owner == store.myId || r == "admin" || r == "owner"
    }

    private var moreMenu: some View {
        Button {
            var items: [MenuAction] = [
                MenuAction(icon: "magnifyingglass", title: tr("Поиск в чате", "Search in chat", "Im Chat suchen")) { showSearch = true }
            ]
            if chat == nil {
                items.append(MenuAction(icon: "pencil", title: tr("Имя контакта", "Contact name", "Kontaktname")) {
                    nameText = store.alias[key] ?? ""; showName = true
                })
            }
            items.append(MenuAction(icon: "bell.slash", title: store.isMuted(key) ? tr("Включить уведомления", "Unmute", "Ton an") : tr("Выключить уведомления", "Mute", "Stummschalten")) {
                Task { await store.setPref(key, "muted", !store.isMuted(key)) }
            })
            items.append(MenuAction(icon: "pin", title: store.isPinned(key) ? tr("Открепить чат", "Unpin chat", "Chat lösen") : tr("Закрепить чат", "Pin chat", "Chat anheften")) {
                Task { await store.setPref(key, "pinned", !store.isPinned(key)) }
            })
            MenuPresenter.shared.show(actions: items)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder private var pinBar: some View {
        if let c = chat, let pid = c.pinnedMsg, let pm = thread.first(where: { $0.id == pid }) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill").font(.system(size: 12)).foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.dnameId(pm.sender)).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.accent)
                    HStack(spacing: 4) {
                        if pm.body == nil {
                            Image(systemName: pm.isSticker ? "tag.fill" : "paperclip").font(.system(size: 10))
                        }
                        Text(pm.body ?? (pm.isSticker ? tr("Стикер", "Sticker", "Sticker") : tr("Файл", "File", "Datei")))
                            .font(.system(size: 11)).lineLimit(1)
                    }.foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if isAdm {
                    Button { Task { await store.pinMessage(c.id, nil) } } label: { Image(systemName: "xmark").foregroundColor(Theme.textSecondary) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(Theme.card)
            .contentShape(Rectangle())
            .onTapGesture { store.jumpTo = pid }
        }
    }

    private func jump(_ proxy: ScrollViewProxy) {
        guard let j = store.jumpTo, thread.contains(where: { $0.id == j }) else { return }
        withAnimation { proxy.scrollTo(j, anchor: .center) }
        store.jumpTo = nil
    }

    private func sendEmojiSticker(_ e: String) {
        let rid = replyTo?.id
        replyTo = nil
        showStk = false
        Task { do { try await store.sendText(e, to: key, reply: rid) } catch { report(error) } }
    }

    private func sendOwnSticker(_ s: Sticker) {
        let rid = replyTo?.id
        replyTo = nil
        showStk = false
        Task { do { try await store.sendSticker(s.path, to: key, reply: rid) } catch { report(error) } }
    }

    private func pinAction(_ m: Message) -> (() -> Void)? {
        guard isAdm, let c = chat else { return nil }
        return { Task { await store.pinMessage(c.id, c.pinnedMsg == m.id ? nil : m.id) } }
    }

    @ViewBuilder private func bubbleRow(_ m: Message) -> some View {
        let isMine: Bool = m.sender == store.myId
        let quotedMsg: Message? = m.replyTo.flatMap { rid in thread.first(where: { $0.id == rid }) }
        let canEdit: Bool = isMine && m.kind == "text"
        Bubble(m: m, mine: isMine,
               selected: selected.contains(m.id), selecting: !selected.isEmpty,
               onToggle: { toggle(m.id) }, onImage: { fullscreenPath = $0 }, onVideo: { videoPath = $0 },
               onCopy: { copyOne(m) },
               onEdit: canEdit ? { editing = m; text = m.body ?? "" } : nil,
               onForward: { selected = [m.id]; showForward = true },
               onDelete: { selected = [m.id]; showDelete = true },
               onPin: pinAction(m),
               pinnedNow: chat?.pinnedMsg == m.id,
               quoted: quotedMsg,
               showNick: chat != nil && !isMine,
               rx: store.reactions(of: m.id),
               onReply: { if store.canPost(key) { replyTo = m } },
               onReact: { e in Task { await store.react(m.id, e) } })
            .id(m.id)
    }

    private var inputBar: some View {
        Group {
            if chat == nil && store.iBlocked(key) {
                HStack {
                    Spacer()
                    Button(tr("Пользователь заблокирован · Разблокировать", "User is blocked · Unblock", "Nutzer ist blockiert · Entsperren")) {
                        Task { try? await store.unblockUser(key) }
                    }
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.accent)
                    Spacer()
                }
                .frame(height: 37)
            } else if chat != nil && !store.canPost(key) {
                HStack {
                    Spacer()
                    if store.myMember(key) == nil {
                        Button(tr("Подписаться", "Subscribe", "Abonnieren")) {
                            Task { try? await store.joinChat(store.cidOf(key)) }
                        }
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.accent)
                    } else {
                        Text(tr("Писать в канал может только владелец", "Only the owner can post", "Nur der Besitzer kann posten"))
                            .font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                .frame(height: 37)
            } else if recorder.recording {
                HStack(spacing: 14) {
                    Image(systemName: "circle.fill").font(.system(size: 12)).foregroundColor(.red)
                    Text(fmtSecs(Double(recorder.seconds))).foregroundColor(Theme.text).font(.system(size: 15))
                    Spacer()
                    Button { recorder.cancel() } label: {
                        Image(systemName: "trash").font(.system(size: 18)).foregroundColor(Theme.textSecondary)
                    }
                    Button { finishRecording() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundColor(Theme.accent)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    if editing == nil {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos])) {
                            Image(systemName: "photo").font(.system(size: 18)).foregroundColor(Theme.accent)
                        }
                        Button { showFiles = true } label: {
                            Image(systemName: "paperclip").font(.system(size: 18)).foregroundColor(Theme.accent)
                        }
                        Button { showAI = true } label: {
                            Image(systemName: "sparkles").font(.system(size: 18)).foregroundColor(Theme.accent)
                        }
                    }
                    Button { showEmoji.toggle(); if showEmoji { showStk = false } } label: {
                        Image(systemName: showEmoji ? "keyboard" : "face.smiling").font(.system(size: 18)).foregroundColor(Theme.accent)
                    }
                    if editing == nil {
                        Button { showStk.toggle(); if showStk { showEmoji = false } } label: {
                            Image(systemName: "star.square").font(.system(size: 18)).foregroundColor(Theme.accent)
                        }
                    }
                    TextField("", text: $text, prompt: Text(tr("Сообщение", "Message", "Nachricht")).foregroundColor(Theme.textSecondary))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 14)
                        .frame(height: 37)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.stroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 21))
                    if busy {
                        ProgressView()
                    } else if editing == nil && pending.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { startRecording() } label: {
                            Image(systemName: "mic.circle.fill").font(.system(size: 26)).foregroundColor(Theme.accent)
                        }
                    } else {
                        Button { sendText() } label: {
                            Image(systemName: editing != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill").font(.system(size: 26)).foregroundColor(Theme.accent)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.bgBottom.opacity(0.95))
    }

    private func startRecording() {
        recorder.start { ok in
            if !ok { error = tr("Нет доступа к микрофону", "No access to the microphone", "Kein Zugriff auf das Mikrofon") }
        }
    }

    private func finishRecording() {
        guard let (url, secs) = recorder.stop() else { return }
        if secs < 1 {
            try? FileManager.default.removeItem(at: url)
            error = tr("Слишком короткое сообщение", "Too short", "Zu kurz")
            return
        }
        busy = true
        error = ""
        Task {
            do {
                let data = try Data(contentsOf: url)
                try await store.sendAlbum([OutItem(data: data, mime: "audio/mp4", name: "voice.m4a", kind: "voice")], caption: "", to: key, reply: replyTo?.id)
                replyTo = nil
                haptic()
            } catch { report(error) }
            try? FileManager.default.removeItem(at: url)
            busy = false
        }
    }

    @MainActor private func addPhoto(_ item: PhotosPickerItem) async {
        if pending.count >= 20 {
            error = tr("Не больше 20 вложений в одном сообщении", "Up to 20 attachments per message", "Höchstens 20 Anhänge pro Nachricht")
            return
        }
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isVideo {
            if let mv = try? await item.loadTransferable(type: MovieFile.self) {
                let th = await videoThumbnail(mv.url)
                pending.append(PendingItem(kind: "video", name: "video", fileURL: mv.url, thumb: th))
            }
        } else if let d = try? await item.loadTransferable(type: Data.self) {
            let th = UIImage(data: d)?.preparingThumbnail(of: CGSize(width: 160, height: 160))
            pending.append(PendingItem(kind: "image", name: "photo.jpg", data: d, thumb: th))
        }
    }

    private func addFile(_ url: URL) {
        if pending.count >= 20 {
            error = tr("Не больше 20 вложений в одном сообщении", "Up to 20 attachments per message", "Höchstens 20 Anhänge pro Nachricht")
            return
        }
        pending.append(PendingItem(kind: "file", name: url.lastPathComponent, fileURL: url))
    }

    private func sendPending(caption: String) {
        let list = pending
        text = ""
        busy = true
        error = ""
        haptic()
        Task {
            do {
                var out: [OutItem] = []
                for p in list { out.append(try await p.makeOutItem()) }
                try await store.sendAlbum(out, caption: caption, to: key, reply: replyTo?.id)
                replyTo = nil
                pending.removeAll { x in list.contains { $0.id == x.id } }
            } catch {
                report(error)
                if text.isEmpty { text = caption }
            }
            busy = false
        }
    }

    private func report(_ e: Error) {
        error = friendlyError((e as? APIError)?.message ?? e.localizedDescription)
    }

    private func sendText() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if editing == nil && !pending.isEmpty && !busy {
            sendPending(caption: t)
            return
        }
        guard !t.isEmpty else { return }
        if let ed = editing {
            error = ""
            Task {
                do {
                    if t != (ed.body ?? "") { try await store.editMessage(ed.id, text: t) }
                    editing = nil
                    text = ""
                } catch { report(error) }
            }
            return
        }
        text = ""
        error = ""
        haptic()
        let rid = replyTo?.id
        replyTo = nil
        Task {
            do { try await store.sendText(t, to: key, reply: rid) } catch { report(error); text = t }
        }
    }

    private func copyText(of m: Message) -> String? {
        switch m.kind {
        case "text": return m.body
        case "file": return m.fileName
        case "album":
            if let b = m.body, !b.isEmpty { return b }
            let names = (m.attachments ?? []).filter { $0.type == "file" }.map { $0.name }
            return names.isEmpty ? nil : names.joined(separator: "\n")
        default: return nil
        }
    }

    private func copyOne(_ m: Message) {
        guard let t = copyText(of: m) else {
            error = tr("Нечего копировать", "Nothing to copy", "Nichts zu kopieren"); return
        }
        UIPasteboard.general.string = t
    }

    private func copySelected() {
        let parts = selMsgs.sorted { $0.createdAt < $1.createdAt }.compactMap { copyText(of: $0) }
        guard !parts.isEmpty else { error = tr("Нечего копировать", "Nothing to copy", "Nichts zu kopieren"); return }
        UIPasteboard.general.string = parts.joined(separator: "\n")
        selected = []
    }

    private func deleteSelected(forAll: Bool) {
        let list = selMsgs
        selected = []
        Task {
            do { forAll ? try await store.deleteForAll(list) : try await store.deleteForMe(list) } catch { report(error) }
        }
    }

    private func forwardTo(_ id: String) {
        let list = selMsgs.sorted { $0.createdAt < $1.createdAt }
        showForward = false
        selected = []
        busy = true
        error = ""
        Task {
            do { for m in list { try await store.forward(m, to: id) } } catch { report(error) }
            busy = false
        }
    }

    private func forwardToAI() {
        let t = selMsgs.sorted { $0.createdAt < $1.createdAt }.filter { $0.kind == "text" }.compactMap { $0.body }.joined(separator: "\n")
        guard !t.isEmpty else {
            error = tr("В ИИ можно переслать только текст", "Only text can be sent to AI", "An die KI kann nur Text gesendet werden")
            showForward = false
            return
        }
        showForward = false
        selected = []
        AIInbox.shared.pending = t
        store.selectedTab = 0
        dismiss()
    }

    private var forwardSheet: some View {
        NavigationStack {
            List {
                Button { forwardToAI() } label: {
                    HStack { Image(systemName: "sparkles"); Text(tr("Умный Чат", "Smart Chat", "Smarter Chat")) }
                }
                ForEach(store.chats.filter { store.canPost("c:" + $0.id) }) { c in
                    Button { forwardTo("c:" + c.id) } label: {
                        HStack(spacing: 12) { Image(systemName: c.kind == "channel" ? "megaphone.fill" : "person.2.fill"); Text(c.title) }
                    }
                }
                ForEach(store.friendIds.compactMap { store.profiles[$0] }) { p in
                    Button { forwardTo(p.id) } label: {
                        HStack(spacing: 12) { Avatar(nick: p.nick, url: p.avatarUrl, size: 32); Text(store.dname(p)) }
                    }
                }
            }
            .navigationTitle(tr("Переслать", "Forward", "Weiterleiten"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for p in providers {
            let ids = p.registeredTypeIdentifiers
            let imageId = ids.first { UTType($0)?.conforms(to: .image) == true }
            guard let typeId = imageId ?? ids.first(where: { UTType($0)?.conforms(to: .data) == true }) else { continue }
            let isImage = imageId != nil
            let suggested = p.suggestedName
            p.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
                guard let url = url, let data = try? Data(contentsOf: url) else { return }
                let ext = url.pathExtension
                let base = suggested ?? url.deletingPathExtension().lastPathComponent
                let fileName = ext.isEmpty || base.lowercased().hasSuffix("." + ext.lowercased()) ? base : base + "." + ext
                Task { @MainActor in await sendDropped(data, fileName: fileName, ext: ext, isImage: isImage) }
            }
        }
    }

    @MainActor private func sendDropped(_ data: Data, fileName: String, ext: String, isImage: Bool) async {
        if pending.count >= 20 { return }
        if data.count > 50 * 1024 * 1024 {
            error = tr("Файл больше 50 МБ", "File is larger than 50 MB", "Datei ist größer als 50 MB")
            return
        }
        if isImage, UIImage(data: data) != nil {
            let th = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 160, height: 160))
            pending.append(PendingItem(kind: "image", name: "photo.jpg", data: data, thumb: th))
        } else {
            pending.append(PendingItem(kind: "file", name: fileName, data: data))
        }
    }

    private func sendAIImage() {
        let p = aiPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        aiPrompt = ""
        guard !p.isEmpty else { return }
        busy = true
        error = ""
        Task {
            do {
                let data = try await API.shared.aiImage(p)
                try await store.sendMedia(data: data, mime: "image/jpeg", fileName: "ai.jpg", kind: "image", to: key, reply: replyTo?.id)
                replyTo = nil
            } catch { report(error) }
            busy = false
        }
    }
}

// MARK: - ИИ-чат

struct AIMsg: Identifiable, Codable {
    var id = UUID()
    var role: String      // user / assistant
    var text: String
}

struct AIChatView: View {
    @ObservedObject private var st = Settings.shared
    @State private var msgs: [AIMsg] = []
    @State private var images: [UUID: Data] = [:]
    @State private var input = ""
    @State private var imageMode = false
    @State private var showEmoji = false
    @State private var busy = false
    @State private var error = ""
    @ObservedObject private var inbox = AIInbox.shared

    private let saveKey = "neirox.ai.history"

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if msgs.isEmpty {
                                Text(tr("Задай вопрос или переключись на «Картинка» и опиши, что нарисовать.",
                                        "Ask a question, or switch to “Image” and describe what to draw.",
                                        "Stelle eine Frage oder wechsle zu „Bild“ und beschreibe, was gezeichnet werden soll."))
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 30)
                            }
                            ForEach(msgs) { m in
                                aiBubble(m).id(m.id)
                            }
                            if busy {
                                HStack { ProgressView(); Spacer() }.padding(.leading, 6)
                            }
                        }
                        .padding(14)
                    }
                    .onChange(of: msgs.count) { _ in
                        if let last = msgs.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                if !error.isEmpty { ErrorText(text: error).padding(.horizontal, 14) }

                Picker("", selection: $imageMode) {
                    Text(tr("Текст", "Text", "Text")).tag(false)
                    Text(tr("Картинка", "Image", "Bild")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.top, 6)

                if showEmoji { EmojiPanel { input += $0 } }
                HStack(spacing: 10) {
                    Button { showEmoji.toggle() } label: {
                        Image(systemName: showEmoji ? "keyboard" : "face.smiling").font(.system(size: 18)).foregroundColor(Theme.accent)
                    }
                    TextField("", text: $input, prompt: Text(imageMode ? tr("Что нарисовать?", "What to draw?", "Was zeichnen?") : tr("Сообщение", "Message", "Nachricht")).foregroundColor(Theme.textSecondary))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 14)
                        .frame(height: 37)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.stroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 21))
                    Button { send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundColor(Theme.accent)
                    }
                    .disabled(busy)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.bgBottom.opacity(0.95))
            }
        }
        .neonScreen(tr("Умный Чат", "Smart Chat", "Smarter Chat"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { msgs = []; images = [:]; save() } label: { Image(systemName: "trash") }
            }
        }
        .onAppear { load(); takePending() }
        .onChange(of: inbox.pending) { _ in takePending() }
    }

    private func takePending() {
        guard let t = inbox.pending else { return }
        inbox.pending = nil
        input = t
        imageMode = false
        send()
    }

    @ViewBuilder private func aiBubble(_ m: AIMsg) -> some View {
        let mine = m.role == "user"
        HStack {
            if mine { Spacer(minLength: 50) }
            Group {
                if let d = images[m.id], let ui = UIImage(data: d) {
                    Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: 260)
                } else {
                    Text(linkified(m.text, mine: mine)).foregroundColor(mine ? .white : Theme.text).tint(mine ? .white : Theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if mine { Theme.accentGradient } else { LinearGradient(colors: [Theme.card, Theme.card], startPoint: .leading, endPoint: .trailing) }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(mine ? Color.clear : Theme.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .customActionMenu(actions: images[m.id] == nil ? [
                MenuAction(icon: "doc.on.doc", title: tr("Копировать", "Copy", "Kopieren")) { UIPasteboard.general.string = m.text }
            ] : [])
            if !mine { Spacer(minLength: 50) }
        }
    }

    private func send() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        input = ""
        error = ""
        haptic()
        msgs.append(AIMsg(role: "user", text: t))
        busy = true
        let asImage = imageMode
        let history = msgs.suffix(20).map { ["role": $0.role, "content": $0.text] }
        Task {
            do {
                if asImage {
                    let data = try await API.shared.aiImage(t)
                    let m = AIMsg(role: "assistant", text: tr("[Изображение]", "[Image]", "[Bild]"))
                    images[m.id] = data
                    msgs.append(m)
                } else {
                    let a = try await API.shared.aiText(history)
                    msgs.append(AIMsg(role: "assistant", text: a))
                }
                save()
            } catch {
                let raw = (error as? APIError)?.message ?? error.localizedDescription
                if raw.contains("rate_limited") {
                    self.error = tr("Лимит запросов в час исчерпан, попробуй позже", "Hourly limit reached, try later", "Stundenlimit erreicht, versuche es später")
                } else {
                    self.error = tr("ИИ сейчас не ответил, попробуй ещё раз", "AI did not answer, try again", "KI hat nicht geantwortet, versuche es erneut")
                }
            }
            busy = false
        }
    }

    private func save() {
        let keep = msgs.filter { images[$0.id] == nil }.suffix(60)
        if let d = try? JSONEncoder().encode(Array(keep)) { UserDefaults.standard.set(d, forKey: saveKey) }
    }

    private func load() {
        guard msgs.isEmpty, let d = UserDefaults.standard.data(forKey: saveKey),
              let list = try? JSONDecoder().decode([AIMsg].self, from: d) else { return }
        msgs = list
    }
}
