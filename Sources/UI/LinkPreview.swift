import SwiftUI

// MARK: - Превью ссылок (og:title / og:description / og:image)

struct OGData {
    var title: String?
    var desc: String?
    var image: String?
}

actor LinkPreviewFetcher {
    static let shared = LinkPreviewFetcher()
    private var cache: [String: OGData?] = [:]

    func fetch(_ url: URL) async -> OGData? {
        let key = url.absoluteString
        if let cached = cache[key] { return cached }
        let og = await load(url)
        cache[key] = og
        return og
    }

    private func load(_ url: URL) async -> OGData? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.setValue("Mozilla/5.0 (compatible; NeiroxBot/1.0; +https://4yrfd6vww2-cmd.github.io/calculat/)",
                     forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode < 400 else { return nil }
        let capped = data.prefix(400_000)
        guard let html = String(data: capped, encoding: .utf8) ?? String(data: capped, encoding: .isoLatin1) else { return nil }
        let og = OGData(
            title: meta(html, "og:title") ?? tagText(html, "title"),
            desc: meta(html, "og:description") ?? meta(html, "description"),
            image: meta(html, "og:image")
        )
        guard og.title != nil || og.desc != nil || og.image != nil else { return nil }
        return og
    }

    private func meta(_ html: String, _ key: String) -> String? {
        let esc = NSRegularExpression.escapedPattern(for: key)
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(esc)[\"'][^>]+content=[\"']([^\"']*)[\"']",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+(?:property|name)=[\"']\(esc)[\"']"
        ]
        for p in patterns {
            if let r = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]),
               let m = r.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(m.range(at: 1), in: html) {
                let s = decodeEntities(String(html[range]))
                if !s.isEmpty { return s }
            }
        }
        return nil
    }

    private func tagText(_ html: String, _ name: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: "<\(name)[^>]*>([^<]+)</\(name)>", options: [.caseInsensitive]),
              let m = r.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(m.range(at: 1), in: html) else { return nil }
        let s = decodeEntities(String(html[range]))
        return s.isEmpty ? nil : s
    }

    private func decodeEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
         .replacingOccurrences(of: "&quot;", with: "\"")
         .replacingOccurrences(of: "&#39;", with: "'")
         .replacingOccurrences(of: "&lt;", with: "<")
         .replacingOccurrences(of: "&gt;", with: ">")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LinkPreviewView: View {
    let url: URL
    var mine: Bool
    @State private var data: OGData?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let d = data, (d.title != nil || d.desc != nil || d.image != nil) {
                Button { openURL(url) } label: {
                    HStack(alignment: .top, spacing: 8) {
                        if let img = d.image, let u = URL(string: img) {
                            AsyncImage(url: u) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.black.opacity(0.12)
                                }
                            }
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if let t = d.title {
                                Text(t).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                            }
                            if let ds = d.desc {
                                Text(ds).font(.system(size: 11)).lineLimit(2).opacity(0.75)
                            }
                            Text(url.host ?? "").font(.system(size: 10)).opacity(0.6)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(Color.black.opacity(mine ? 0.14 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(mine ? .white : Theme.text)
            } else {
                EmptyView()
            }
        }
        .task(id: url) {
            data = await LinkPreviewFetcher.shared.fetch(url)
        }
    }
}

func firstHTTPURL(in s: String) -> URL? {
    guard !s.isEmpty, let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
    let ns = s as NSString
    for m in det.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
        if let url = m.url, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }
    }
    return nil
}
