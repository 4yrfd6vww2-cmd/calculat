import SwiftUI
import PhotosUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

// MARK: - Ссылки

/// Текст, в котором ссылки подсвечены и открываются в браузере по нажатию.
func linkified(_ s: String, mine: Bool) -> AttributedString {
    var a = AttributedString(s)
    guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return a }
    let ns = s as NSString
    for m in det.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
        guard let url = m.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
        guard let r = Range(m.range, in: s) else { continue }
        guard let ar = Range<AttributedString.Index>(r, in: a) else { continue }
        a[ar].link = url
        a[ar].underlineStyle = .single
    }
    return a
}

// MARK: - Смайлики

let EMOJI_GROUPS: [[String]] = [
    "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝 🤗 🤭 🤔 🤨 😐 😑 😶 🙄 😏 😴 😌 😔 😪 🤤 😷 🤒 🤕 🤢 🤮 🥵 🥶 😵 🤯 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 💀 💩 🤡 👻 👽 🤖",
    "👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤝 🙏 💪 👏 🙌 👐 🤲 ✍️ 💅 🧠 👀 👅 👄 🙋 🤦 🤷 💃 🕺 🚶 🏃",
    "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 ✨ ⭐ 🌟 💫 🔥 💥 💯 ✅ ❌ ❓ ❗ ⚡ 🎉 🎊 🎁 🏆 🥇 🎵 🎶 💤 💢 💬",
    "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🐺 🐴 🦄 🐝 🦋 🐌 🐞 🐢 🐍 🐙 🦀 🐠 🐬 🐳 🌸 🌹 🌻 🌷 🌲 🌴 🍀 🍁 🌈 ☀️ 🌙 ☁️ ❄️ 🌊",
    "🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🥦 🥕 🌽 🥔 🍞 🧀 🍳 🥞 🥓 🍔 🍟 🍕 🌭 🌮 🍝 🍣 🍜 🍦 🍩 🍪 🎂 🍰 🍫 🍬 🍭 ☕ 🍵 🥤 🍺 🍷 🥂",
    "⚽ 🏀 🏈 ⚾ 🎾 🏐 🎱 🏓 🎮 🎲 🎯 🎸 🎹 🎤 🎧 📱 💻 ⌨️ 📷 🎬 📚 ✏️ 📌 📎 🔑 🔒 💡 💰 💳 🚗 ✈️ 🚀 🏠"
].map { $0.split(separator: " ").map(String.init) }

struct EmojiPanel: View {
    var onPick: (String) -> Void
    @State private var cat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(EMOJI_GROUPS.indices, id: \.self) { i in
                    Button { cat = i } label: {
                        Text(EMOJI_GROUPS[i][0]).font(.system(size: 18)).padding(6)
                            .background(cat == i ? Theme.accent.opacity(0.25) : Color.clear)
                            .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8).padding(.top, 6)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42))], spacing: 4) {
                    ForEach(EMOJI_GROUPS[cat], id: \.self) { e in
                        Button { onPick(e) } label: { Text(e).font(.system(size: 22)) }
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .frame(height: 200)
        }
        .background(Theme.card)
    }
}

// MARK: - Стикеры

struct StickerPanel: View {
    @ObservedObject private var store = Store.shared
    var onEmoji: (String) -> Void
    var onOwn: (Sticker) -> Void
    @State private var addItem: PhotosPickerItem?
    @State private var err = ""

    static let builtin: [String] = [
        "😀", "😂", "🥹", "😍", "🥰", "😎", "🤩", "😭", "😡", "🤯", "🥳", "😴", "🤔", "🙄", "😘", "🤗",
        "👍", "👎", "👏", "🙏", "💪", "🔥", "❤️", "💔", "🎉", "🎂", "☕", "🍕", "🐱", "🐶", "🦄", "🌈",
        "⭐", "💯", "🚀", "🎁", "🌹", "🤝", "👋", "🫶"
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !err.isEmpty { Text(err).font(.system(size: 12)).foregroundColor(.red).padding(.top, 4) }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 62))], spacing: 6) {
                    PhotosPicker(selection: $addItem, matching: .images) {
                        Text("＋").font(.system(size: 24)).foregroundColor(Theme.accent).frame(width: 51, height: 51)
                    }
                    ForEach(store.stickers) { s in
                        stickerCell(s)
                    }
                    ForEach(StickerPanel.builtin, id: \.self) { e in
                        Button { onEmoji(e) } label: { Text(e).font(.system(size: 27)) }
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
            }
            .frame(height: 230)
        }
        .background(Theme.card)
        .onChange(of: addItem) { item in
            guard let item = item else { return }
            Task { await add(item) }
        }
    }

    private func stickerCell(_ s: Sticker) -> some View {
        MediaImage(path: s.path)
            .frame(width: 51, height: 51)
            .onTapGesture { onOwn(s) }
            .contextMenu {
                Button(role: .destructive) { Task { await store.deleteSticker(s.id) } } label: {
                    Label(tr("Удалить", "Delete", "Löschen"), systemImage: "trash")
                }
            }
    }

    @MainActor private func add(_ item: PhotosPickerItem) async {
        err = ""
        if let d = try? await item.loadTransferable(type: Data.self) {
            if d.count > 4 * 1024 * 1024 {
                err = tr("Стикер больше 4 МБ", "Sticker is larger than 4 MB", "Sticker ist größer als 4 MB")
            } else {
                let t = item.supportedContentTypes.first
                let ext: String = t?.preferredFilenameExtension ?? "png"
                let mime: String = t?.preferredMIMEType ?? "image/png"
                do { try await store.addSticker(d, mime: mime, ext: ext) } catch { err = friendlyError((error as? APIError)?.message ?? error.localizedDescription) }
            }
        }
        addItem = nil
    }
}

// MARK: - Вложения в очереди

struct MovieFile: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            try FileManager.default.copyItem(at: received.file, to: dst)
            return MovieFile(url: dst)
        }
    }
}

struct PendingItem: Identifiable {
    let id = UUID()
    let kind: String          // image / video / file
    let name: String
    var data: Data? = nil
    var fileURL: URL? = nil
    var thumb: UIImage? = nil

    private static let maxBytes = 50 * 1024 * 1024

    private static func tooBig() -> APIError {
        APIError(message: tr("Файл больше 50 МБ", "File is larger than 50 MB", "Datei ist größer als 50 MB"))
    }

    func makeOutItem() async throws -> OutItem {
        switch kind {
        case "image":
            guard let d = data, let jpg = compressedJPEG(from: d) else {
                throw APIError(message: tr("Не удалось прочитать фото", "Could not read the photo", "Foto konnte nicht gelesen werden"))
            }
            return OutItem(data: jpg, mime: "image/jpeg", name: "photo.jpg", kind: "image")
        case "video":
            guard let u = fileURL else { throw APIError(message: "Bad video") }
            let mp4 = await convertToMP4(u)
            let src = mp4 ?? u
            let d = try Data(contentsOf: src, options: .mappedIfSafe)
            guard d.count <= PendingItem.maxBytes else { throw PendingItem.tooBig() }
            let isMP4 = src.pathExtension.lowercased() == "mp4"
            return OutItem(data: d, mime: isMP4 ? "video/mp4" : "video/quicktime", name: isMP4 ? "video.mp4" : "video.mov", kind: "video")
        default:
            var d = data
            if d == nil, let u = fileURL {
                d = await Task.detached(operation: { readFileCoordinated(u) }).value
            }
            guard let bytes = d else {
                throw APIError(message: tr("Не удалось прочитать файл", "Could not read the file", "Datei konnte nicht gelesen werden"))
            }
            guard bytes.count <= PendingItem.maxBytes else { throw PendingItem.tooBig() }
            let ext = (name as NSString).pathExtension
            let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
            return OutItem(data: bytes, mime: mime, name: name, kind: "file")
        }
    }
}

/// Перекодирует видео в MP4 (H.264, до 720p), чтобы оно играло везде и было меньше.
func convertToMP4(_ url: URL) async -> URL? {
    let asset = AVURLAsset(url: url)
    guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return nil }
    let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
    ex.outputURL = out
    ex.outputFileType = .mp4
    ex.shouldOptimizeForNetworkUse = true
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        ex.exportAsynchronously { c.resume() }
    }
    return ex.status == .completed ? out : nil
}

func videoThumbnail(_ url: URL) async -> UIImage? {
    await Task.detached { () -> UIImage? in
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 400, height: 400)
        guard let cg = try? gen.copyCGImage(at: CMTime(seconds: 0.1, preferredTimescale: 600), actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }.value
}

struct PendingTray: View {
    let items: [PendingItem]
    var onRemove: (PendingItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { p in
                    ZStack(alignment: .topTrailing) {
                        thumb(p)
                            .frame(width: 72, height: 72)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button { onRemove(p) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 2)
                        }
                        .padding(2)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Theme.bgBottom.opacity(0.95))
    }

    @ViewBuilder private func thumb(_ p: PendingItem) -> some View {
        if let t = p.thumb {
            Image(uiImage: t).resizable().scaledToFill()
                .overlay(
                    Group {
                        if p.kind == "video" { Image(systemName: "play.circle.fill").font(.system(size: 21)).foregroundColor(.white.opacity(0.9)) }
                    }
                )
        } else if p.kind == "video" {
            Image(systemName: "film").font(.system(size: 21)).foregroundColor(Theme.accent)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "doc.fill").font(.system(size: 18)).foregroundColor(Theme.accent)
                Text(p.name).font(.system(size: 9)).lineLimit(2).multilineTextAlignment(.center)
                    .foregroundColor(Theme.textSecondary).padding(.horizontal, 3)
            }
        }
    }
}

// MARK: - Голосовые сообщения

final class VoiceRecorder: NSObject, ObservableObject {
    @Published var recording = false
    @Published var seconds = 0
    private var rec: AVAudioRecorder?
    private var timer: Timer?
    private var url: URL?

    func start(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            DispatchQueue.main.async {
                guard ok else { completion(false); return }
                do {
                    let s = AVAudioSession.sharedInstance()
                    try s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                    try s.setActive(true)
                    let u = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
                    let settings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderBitRateKey: 64000
                    ]
                    let r = try AVAudioRecorder(url: u, settings: settings)
                    guard r.record() else { completion(false); return }
                    self.rec = r
                    self.url = u
                    self.seconds = 0
                    self.recording = true
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                        self.seconds = Int(r.currentTime)
                    }
                    completion(true)
                } catch {
                    completion(false)
                }
            }
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        rec?.stop()
        recording = false
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }

    /// Останавливает запись и возвращает файл и длительность в секундах.
    func stop() -> (URL, Int)? {
        let secs = Int(rec?.currentTime ?? 0)
        finish()
        let u = url
        rec = nil
        url = nil
        guard let f = u else { return nil }
        return (f, secs)
    }

    func cancel() {
        finish()
        if let u = url { try? FileManager.default.removeItem(at: u) }
        rec = nil
        url = nil
    }
}

final class VoicePlayerModel: ObservableObject {
    @Published var playing = false
    @Published var loading = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    private var player: AVPlayer?
    private var observer: Any?
    private var endObserver: NSObjectProtocol?

    func toggle(path: String) {
        if let p = player {
            if playing { p.pause(); playing = false } else { p.play(); playing = true }
            return
        }
        if loading { return }
        loading = true
        Task { @MainActor in
            defer { self.loading = false }
            guard let url = try? await API.shared.signedURL(bucket: "chat-media", path: path) else { return }
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            let p = AVPlayer(playerItem: item)
            self.player = p
            self.observer = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
                guard let self = self else { return }
                self.position = t.seconds
                let d = item.duration.seconds
                if d.isFinite && d > 0 { self.duration = d }
            }
            self.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.playing = false
                self?.position = 0
                self?.player?.seek(to: .zero)
            }
            p.play()
            self.playing = true
        }
    }

    deinit {
        if let o = observer { player?.removeTimeObserver(o) }
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        player?.pause()
    }
}

func fmtSecs(_ s: Double) -> String {
    let n = Int(max(0, s.isFinite ? s : 0))
    return String(format: "%d:%02d", n / 60, n % 60)
}

struct VoiceBubble: View {
    let path: String
    let mine: Bool
    @StateObject private var model = VoicePlayerModel()

    var body: some View {
        let color: Color = mine ? .white : Theme.text
        HStack(spacing: 10) {
            Button { model.toggle(path: path) } label: {
                if model.loading {
                    ProgressView().tint(color).frame(width: 25, height: 25)
                } else {
                    Image(systemName: model.playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 22)).foregroundColor(color)
                }
            }
            .buttonStyle(.plain)
            ProgressView(value: model.duration > 0 ? min(1, model.position / model.duration) : 0)
                .tint(color)
                .frame(width: 100)
            Text(fmtSecs(model.playing || model.position > 0 ? model.position : model.duration))
                .font(.system(size: 11)).foregroundColor(color.opacity(0.7))
        }
    }
}

// MARK: - Альбом в сообщении

struct AlbumImage: View {
    let path: String
    let side: CGFloat
    @State private var url: URL?

    var body: some View {
        ZStack {
            Theme.card
            if let url = url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else if phase.error != nil { Image(systemName: "photo").foregroundColor(Theme.textSecondary) }
                    else { ProgressView() }
                }
            } else { ProgressView() }
        }
        .frame(width: side, height: side)
        .clipped()
        .task { url = try? await API.shared.signedURL(bucket: "chat-media", path: path) }
    }
}

struct AlbumVideo: View {
    let path: String
    let side: CGFloat
    @State private var thumb: UIImage?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            if let t = thumb { Image(uiImage: t).resizable().scaledToFill() }
            Image(systemName: "play.circle.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.92))
        }
        .frame(width: side, height: side)
        .clipped()
        .task {
            if let u = try? await API.shared.signedURL(bucket: "chat-media", path: path) {
                thumb = await videoThumbnail(u)
            }
        }
    }
}

struct AlbumView: View {
    let m: Message
    let mine: Bool
    let selecting: Bool
    var onToggle: () -> Void
    var onImage: (String) -> Void
    var onVideo: (String) -> Void
    @Environment(\.openURL) private var openURL

    private var atts: [Attachment] { m.attachments ?? [] }

    var body: some View {
        let visual = atts.filter { $0.type == "image" || $0.type == "video" }
        let side: CGFloat = visual.count == 1 ? 220 : 108
        let rows: [[Attachment]] = stride(from: 0, to: visual.count, by: 2).map { Array(visual[$0..<min($0 + 2, visual.count)]) }
        let color: Color = mine ? .white : Theme.text
        VStack(alignment: .leading, spacing: 6) {
            if !visual.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows.indices, id: \.self) { ri in
                        HStack(spacing: 4) {
                            ForEach(rows[ri], id: \.path) { a in
                                Group {
                                    if a.type == "image" { AlbumImage(path: a.path, side: side) }
                                    else { AlbumVideo(path: a.path, side: side) }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture {
                                    if selecting { onToggle() }
                                    else if a.type == "image" { onImage(a.path) }
                                    else { onVideo(a.path) }
                                }
                            }
                        }
                    }
                }
            }
            ForEach(atts.filter { $0.type == "voice" }, id: \.path) { a in
                VoiceBubble(path: a.path, mine: mine)
            }
            ForEach(atts.filter { $0.type == "file" }, id: \.path) { a in
                HStack(spacing: 8) {
                    Image(systemName: "doc.fill")
                    Text(a.name).lineLimit(2).multilineTextAlignment(.leading)
                }
                .foregroundColor(color)
                .onTapGesture {
                    if selecting { onToggle(); return }
                    Task { if let u = try? await API.shared.signedURL(bucket: "chat-media", path: a.path) { openURL(u) } }
                }
            }
            if let b = m.body, !b.isEmpty {
                Text(linkified(b, mine: mine)).foregroundColor(color).tint(mine ? .white : Theme.accent)
            }
        }
    }
}

struct VideoFullView: View {
    let path: String
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let p = player { VideoPlayer(player: p).ignoresSafeArea() } else { ProgressView().tint(.white) }
        }
        .task {
            if let u = try? await API.shared.signedURL(bucket: "chat-media", path: path) {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                try? AVAudioSession.sharedInstance().setActive(true)
                let p = AVPlayer(url: u)
                player = p
                p.play()
            }
        }
        .onDisappear { player?.pause() }
    }
}
