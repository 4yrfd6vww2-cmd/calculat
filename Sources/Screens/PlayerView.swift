import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct Track: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var file: String   // имя файла в папке Music внутри приложения
}

final class PlayerStore: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = PlayerStore()

    @Published var tracks: [Track] = []
    @Published var current: Track?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let listKey = "neirox.player.tracks"

    private var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        super.init()
        if let d = UserDefaults.standard.data(forKey: listKey),
           let list = try? JSONDecoder().decode([Track].self, from: d) {
            tracks = list.filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.file).path) }
        }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(tracks) { UserDefaults.standard.set(d, forKey: listKey) }
    }

    func importFiles(_ urls: [URL]) {
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let ext = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
            let name = UUID().uuidString + "." + ext
            let dest = folder.appendingPathComponent(name)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                let title = url.deletingPathExtension().lastPathComponent
                tracks.append(Track(title: title, file: name))
            } catch {
                continue
            }
        }
        save()
    }

    func remove(_ t: Track) {
        if current == t { stop() }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(t.file))
        tracks.removeAll { $0 == t }
        save()
    }

    func play(_ t: Track) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: folder.appendingPathComponent(t.file))
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
            current = t
            duration = p.duration
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    func toggle() {
        guard let p = player else {
            if let t = tracks.first { play(t) }
            return
        }
        if p.isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
        isPlaying = false
        position = 0
        timer?.invalidate()
    }

    func next() { step(1) }
    func prev() { step(-1) }

    private func step(_ d: Int) {
        guard !tracks.isEmpty else { return }
        let i = tracks.firstIndex { $0 == current } ?? -1
        let n = (i + d + tracks.count) % tracks.count
        play(tracks[n])
    }

    func seek(_ v: Double) {
        player?.currentTime = v
        position = v
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let p = self.player else { return }
            self.position = p.currentTime
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.next() }
    }
}

struct PlayerView: View {
    @ObservedObject private var st = Settings.shared
    @ObservedObject private var pl = PlayerStore.shared
    @State private var showImport = false

    private func fmt(_ s: Double) -> String {
        let t = Int(s.isFinite ? s : 0)
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if pl.tracks.isEmpty {
                                Text(tr("Добавь MP3-файлы с телефона. Они сохранятся в приложении и не пропадут после перезапуска.",
                                        "Add MP3 files from your phone. They are stored in the app and stay after restart.",
                                        "Füge MP3-Dateien vom Handy hinzu. Sie bleiben in der App gespeichert."))
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 30)
                            }
                            ForEach(pl.tracks) { t in
                                Button { pl.play(t) } label: {
                                    GlassCard {
                                        HStack(spacing: 12) {
                                            Image(systemName: pl.current == t && pl.isPlaying ? "waveform" : "music.note")
                                                .foregroundColor(pl.current == t ? Theme.accent : Theme.textSecondary)
                                                .frame(width: 24)
                                            Text(t.title)
                                                .font(.system(size: 15, weight: pl.current == t ? .semibold : .regular))
                                                .foregroundColor(Theme.text)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) { pl.remove(t) } label: {
                                        Label(tr("Удалить", "Delete", "Löschen"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    VStack(spacing: 8) {
                        Text(pl.current?.title ?? tr("Ничего не играет", "Nothing playing", "Nichts läuft"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Slider(value: Binding(get: { pl.position }, set: { pl.seek($0) }),
                               in: 0...max(pl.duration, 1))
                            .tint(Theme.accent)
                        HStack {
                            Text(fmt(pl.position)).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(fmt(pl.duration)).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                        HStack(spacing: 34) {
                            Button { pl.prev() } label: { Image(systemName: "backward.fill").font(.system(size: 24)) }
                            Button { pl.toggle() } label: {
                                Image(systemName: pl.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 52))
                            }
                            Button { pl.next() } label: { Image(systemName: "forward.fill").font(.system(size: 24)) }
                        }
                        .foregroundColor(Theme.accent)
                    }
                    .padding(16)
                    .background(Theme.bgBottom.opacity(0.95))
                }
            }
            .neonScreen(tr("Плеер", "Player", "Player"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showImport = true } label: { Image(systemName: "plus") }
                }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { pl.importFiles(urls) }
            }
        }
    }
}
