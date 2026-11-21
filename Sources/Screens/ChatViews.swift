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

    private var friends: [Profile] {
        let list = store.friendIds.compactMap { store.profiles[$0] }
        return list.sorted { a, b in
            let la = store.thread(with: a.id).last?.createdAt ?? .distantPast
            let lb = store.thread(with: b.id).last?.createdAt ?? .distantPast
            if la != lb { return la > lb }
            return a.nick < b.nick
        }
    }

    private func preview(_ m: Message?) -> String {
        guard let m = m else { return tr("Нет сообщений", "No messages", "Keine Nachrichten") }
        let prefix = m.sender == store.myId ? tr("Вы: ", "You: ", "Du: ") : ""
        switch m.kind {
        case "image": return prefix + tr("📷 Фото", "📷 Photo", "📷 Foto")
        case "file": return prefix + "📎 " + (m.fileName ?? tr("Файл", "File", "Datei"))
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
                                    .frame(width: 46, height: 46)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tr("Умный Чат (ИИ)", "Smart Chat (AI)", "Smarter Chat (KI)"))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Theme.text)
                                        Text(tr("Вопросы и картинки", "Questions and images", "Fragen und Bilder"))
                                            .font(.system(size: 13))
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(friends) { p in
                            NavigationLink(destination: ChatView(friend: p)) {
                                GlassCard {
                                    HStack(spacing: 12) {
                                        Avatar(nick: p.nick, url: p.avatarUrl, size: 46)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(p.nick)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(Theme.text)
                                            Text(preview(store.thread(with: p.id).last))
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        let n = store.unread(from: p.id)
                                        if n > 0 {
                                            Text("\(n)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Theme.accent)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if friends.isEmpty {
                            Text(tr("Добавь друзей на вкладке «Друзья», чтобы начать переписку.",
                                    "Add friends in the Friends tab to start chatting.",
                                    "Füge im Tab „Freunde“ Freunde hinzu, um zu chatten."))
                                .font(.system(size: 14))
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
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                content
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
            .onLongPressGesture(minimumDuration: 0.4) { haptic(); onToggle() }
            if !mine { Spacer(minLength: 50) }
        }
        .padding(.vertical, 2)
        .background(selected ? Theme.accent.opacity(0.2) : Color.clear)
    }

    @ViewBuilder private var content: some View {
        if m.kind == "image", let p = m.mediaPath {
            MediaImage(path: p)
        } else if m.kind == "file", let p = m.mediaPath {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                Text(m.fileName ?? "file").lineLimit(2).multilineTextAlignment(.leading)
            }
            .foregroundColor(mine ? .white : Theme.text)
        } else {
            Text(m.body ?? "")
                .foregroundColor(mine ? .white : Theme.text)
        }
    }
}

struct ChatView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var store = Store.shared
    let friend: Profile

    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
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

    private var thread: [Message] { store.thread(with: friend.id) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(thread) { m in
                                Bubble(m: m, mine: m.sender == store.myId,
                                       selected: selected.contains(m.id), selecting: !selected.isEmpty,
                                       onToggle: { toggle(m.id) }, onImage: { fullscreenPath = $0 }).id(m.id)
                            }
                        }
                        .padding(14)
                    }
                    .onChange(of: thread.count) { _ in
                        if let last = thread.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                        Task { await store.markRead(from: friend.id) }
                    }
                    .onAppear {
                        if let last = thread.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                if !error.isEmpty { ErrorText(text: error).padding(.horizontal, 14) }
                if editing != nil {
                    HStack {
                        Text("✏️ " + tr("Редактирование", "Editing", "Bearbeiten")).font(.system(size: 13)).foregroundColor(Theme.accent)
                        Spacer()
                        Button { editing = nil; text = "" } label: { Image(systemName: "xmark").foregroundColor(Theme.textSecondary) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Theme.card)
                }
                inputBar
            }
        }
        .neonScreen(friend.nick)
        .toolbar {
            if !selected.isEmpty {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if selMsgs.count == 1, let one = selMsgs.first, one.sender == store.myId, one.kind == "text" {
                        Button { editing = one; text = one.body ?? ""; selected = [] } label: { Image(systemName: "pencil") }
                    }
                    Button { copySelected() } label: { Image(systemName: "doc.on.doc") }
                    Button { showForward = true } label: { Image(systemName: "arrowshape.turn.up.right") }
                    Button { showDelete = true } label: { Image(systemName: "trash") }
                    Button { selected = [] } label: { Image(systemName: "xmark") }
                }
            }
        }
        .sheet(isPresented: $showForward) { forwardSheet }
        .confirmationDialog(tr("Удалить сообщения?", "Delete messages?", "Nachrichten löschen?"), isPresented: $showDelete, titleVisibility: .visible) {
            Button(tr("У меня", "For me", "Für mich"), role: .destructive) { deleteSelected(forAll: false) }
            if !selMsgs.isEmpty && selMsgs.allSatisfy({ $0.sender == store.myId }) {
                Button(tr("У всех", "For everyone", "Für alle"), role: .destructive) { deleteSelected(forAll: true) }
            }
            Button(tr("Отмена", "Cancel", "Abbrechen"), role: .cancel) {}
        }
        .fullScreenCover(isPresented: Binding(get: { fullscreenPath != nil }, set: { if !$0 { fullscreenPath = nil } })) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let p = fullscreenPath { MediaImageFull(path: p) }
            }
            .onTapGesture { fullscreenPath = nil }
        }
        .task { await store.markRead(from: friend.id) }
        .sheet(isPresented: $showFiles) {
            DocPicker(types: [.item]) { urls in
                showFiles = false
                for u in urls { sendFile(u) }
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
        .alert(tr("Картинка от ИИ", "AI image", "KI-Bild"), isPresented: $showAI) {
            TextField(tr("Опиши картинку", "Describe the image", "Bild beschreiben"), text: $aiPrompt)
            Button(tr("Создать и отправить", "Create and send", "Erstellen und senden")) { sendAIImage() }
            Button(tr("Отмена", "Cancel", "Abbrechen"), role: .cancel) { aiPrompt = "" }
        }
        .onChange(of: photoItem) { item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    sendImage(data)
                }
                photoItem = nil
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            if editing == nil {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo").font(.system(size: 20)).foregroundColor(Theme.accent)
                }
                Button { showFiles = true } label: {
                    Image(systemName: "paperclip").font(.system(size: 20)).foregroundColor(Theme.accent)
                }
                Button { showAI = true } label: {
                    Image(systemName: "sparkles").font(.system(size: 20)).foregroundColor(Theme.accent)
                }
            }
            TextField("", text: $text, prompt: Text(tr("Сообщение", "Message", "Nachricht")).foregroundColor(Theme.textSecondary))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.stroke, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 21))
            if busy {
                ProgressView()
            } else {
                Button { sendText() } label: {
                    Image(systemName: editing != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(Theme.accent)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.bgBottom.opacity(0.95))
    }

    private func report(_ e: Error) {
        error = friendlyError((e as? APIError)?.message ?? e.localizedDescription)
    }

    private func sendText() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        Task {
            do { try await store.sendText(t, to: friend.id) } catch { report(error); text = t }
        }
    }

    private func copySelected() {
        let parts = selMsgs.sorted { $0.createdAt < $1.createdAt }.compactMap { m -> String? in
            m.kind == "text" ? m.body : (m.kind == "file" ? m.fileName : nil)
        }
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
                ForEach(store.friendIds.compactMap { store.profiles[$0] }) { p in
                    Button { forwardTo(p.id) } label: {
                        HStack(spacing: 12) { Avatar(nick: p.nick, url: p.avatarUrl, size: 36); Text(p.nick) }
                    }
                }
            }
            .navigationTitle(tr("Переслать", "Forward", "Weiterleiten"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func sendImage(_ data: Data) {
        busy = true
        error = ""
        Task {
            do {
                guard let jpg = compressedJPEG(from: data) else { throw APIError(message: "Bad image") }
                try await store.sendMedia(data: jpg, mime: "image/jpeg", fileName: "photo.jpg", kind: "image", to: friend.id)
            } catch { report(error) }
            busy = false
        }
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
        busy = true
        error = ""
        do {
            if data.count > 25 * 1024 * 1024 {
                throw APIError(message: tr("Файл больше 25 МБ", "File is larger than 25 MB", "Datei ist größer als 25 MB"))
            }
            if isImage, let jpg = compressedJPEG(from: data) {
                try await store.sendMedia(data: jpg, mime: "image/jpeg", fileName: "photo.jpg", kind: "image", to: friend.id)
            } else {
                let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
                try await store.sendMedia(data: data, mime: mime, fileName: fileName, kind: "file", to: friend.id)
            }
        } catch { report(error) }
        busy = false
    }

    private func sendFile(_ url: URL) {
        busy = true
        error = ""
        Task {
            do {
                guard let data = await Task.detached(operation: { readFileCoordinated(url) }).value else {
                    throw APIError(message: tr("Не удалось прочитать файл", "Could not read the file", "Datei konnte nicht gelesen werden"))
                }
                if data.count > 25 * 1024 * 1024 {
                    throw APIError(message: tr("Файл больше 25 МБ", "File is larger than 25 MB", "Datei ist größer als 25 MB"))
                }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                try await store.sendMedia(data: data, mime: mime, fileName: url.lastPathComponent, kind: "file", to: friend.id)
            } catch { report(error) }
            busy = false
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
                try await store.sendMedia(data: data, mime: "image/jpeg", fileName: "ai.jpg", kind: "image", to: friend.id)
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
                                    .font(.system(size: 14))
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

                HStack(spacing: 10) {
                    TextField("", text: $input, prompt: Text(imageMode ? tr("Что нарисовать?", "What to draw?", "Was zeichnen?") : tr("Сообщение", "Message", "Nachricht")).foregroundColor(Theme.textSecondary))
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Theme.stroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 21))
                    Button { send() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(Theme.accent)
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
                    Text(m.text).foregroundColor(mine ? .white : Theme.text)
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
            .contextMenu {
                if images[m.id] == nil {
                    Button { UIPasteboard.general.string = m.text } label: {
                        Label(tr("Копировать", "Copy", "Kopieren"), systemImage: "doc.on.doc")
                    }
                }
            }
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
                    let m = AIMsg(role: "assistant", text: "🖼")
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
