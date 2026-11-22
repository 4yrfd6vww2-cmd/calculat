import SwiftUI

/// Баннер «Доступно новое обновление»: по кнопке открывает наш сайт в браузере.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    @Published var newVersion: String?
    @Published var url: URL?
    @Published var dismissed = false
    private var started = false

    var visible: Bool { newVersion != nil && !dismissed }

    func start() {
        guard !started else { return }
        started = true
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            while true {
                await check()
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            }
        }
    }

    private func check() async {
        guard let u = URL(string: "https://4yrfd6vww2-cmd.github.io/calculat/version.json"),
              let (data, _) = try? await URLSession.shared.data(from: u),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ios = obj["ios"] as? [String: Any],
              let v = ios["version"] as? String else { return }
        if isNewer(v, than: Config.appVersion) {
            if newVersion != v { dismissed = false }
            newVersion = v
            url = URL(string: (ios["url"] as? String) ?? "https://4yrfd6vww2-cmd.github.io/calculat/")
        } else {
            newVersion = nil
        }
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.filter { $0.isNumber }) ?? 0 } }
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

struct UpdateBanner: View {
    @ObservedObject private var up = Updater.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        if up.visible, let v = up.newVersion {
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Доступно новое обновление ", "New update available ", "Neues Update verfügbar ") + v)
                    .font(.system(size: 15)).foregroundColor(Theme.text)
                HStack {
                    Spacer()
                    Button(tr("Не устанавливать", "Not now", "Nicht jetzt")) { up.dismissed = true }
                        .foregroundColor(Theme.textSecondary)
                    Button(tr("Установить", "Install", "Installieren")) {
                        if let u = up.url { openURL(u) }
                        up.dismissed = true
                    }
                    .fontWeight(.semibold).foregroundColor(Theme.accent)
                }
                .font(.system(size: 15))
            }
            .padding(12)
            .background(Theme.bgBottom)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
    }
}
