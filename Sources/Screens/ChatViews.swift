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

struct Bubble: View {
    @ObservedObject private var st = Settings.shared
    let m: Message
    let mine: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                content
                Text(timeFormatter.string(from: m.createdAt))
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
            if !mine { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder private var content: some View {
        if m.kind == "image", let p = m.mediaPath {
            MediaImage(path: p)
        } else if m.kind == "file", let p = m.mediaPath {
            Button {
                Task {
                    if let u = try? await API.shared.signedURL(bucket: "chat-media", path: p) { openURL(u) }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                    Text(m.fileName ?? "file").lineLimit(2).multilineTextAlignment(.leading)
                }
                .foregroundColor(mine ? .white : Theme.text)
            }
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

    private var thread: [Message] { store.thread(with: friend.id) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(thread) { m in
                                Bubble(m: m, mine: m.sender == store.myId).id(m.id)
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
                inputBar
            }
        }
        .neonScreen(friend.nick)
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
            PhotosPicker(selection: $photoItem, matching: .images) {
                Image(systemName: "photo").font(.system(size: 20)).foregroundColor(Theme.accent)
            }
            Button { showFiles = true } label: {
                Image(systemName: "paperclip").font(.system(size: 20)).foregroundColor(Theme.accent)
            }
            Button { showAI = true } label: {
                Image(systemName: "sparkles").font(.system(size: 20)).foregroundColor(Theme.accent)
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
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundColor(Theme.accent)
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
        text = ""
        error = ""
        haptic()
        Task {
            do { try await store.sendText(t, to: friend.id) } catch { report(error); text = t }
        }
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
        .onAppear { load() }
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
