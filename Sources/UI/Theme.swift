import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    private static var mode: ThemeMode { Settings.shared.mode }
    private static var isLight: Bool { mode == .light }

    static var bgTop: Color {
        switch mode {
        case .dark: return Color(hex: 0x040817)
        case .black: return Color(hex: 0x000000)
        case .light: return Color(hex: 0xF3F6FF)
        }
    }
    static var bgBottom: Color {
        switch mode {
        case .dark: return Color(hex: 0x060B1F)
        case .black: return Color(hex: 0x05060A)
        case .light: return Color(hex: 0xE6ECFF)
        }
    }
    static var accent: Color { Color(hex: Settings.shared.accentHex) }
    static var accent2: Color { Color(hex: 0x8B6CFF) }
    static var text: Color { isLight ? Color(hex: 0x0F1530) : .white }
    static var textSecondary: Color { isLight ? Color(hex: 0x0F1530, opacity: 0.55) : Color.white.opacity(0.6) }
    static var card: Color { isLight ? Color.white.opacity(0.75) : Color.white.opacity(0.05) }
    static var stroke: Color { isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.10) }
    static var scheme: ColorScheme { isLight ? .light : .dark }

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

struct AppBackground: View {
    @ObservedObject private var st = Settings.shared
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct GlassField: View {
    @ObservedObject private var st = Settings.shared
    let placeholder: String
    @Binding var text: String
    var secure = false

    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.textSecondary))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Theme.textSecondary))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .foregroundColor(Theme.text)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct NeonButton: View {
    @ObservedObject private var st = Settings.shared
    let title: String
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 4)
        }
        .disabled(busy)
    }
}

struct GlassCard<Content: View>: View {
    @ObservedObject private var st = Settings.shared
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(14)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ErrorText: View {
    let text: String
    var body: some View {
        if text.isEmpty {
            EmptyView()
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0xFF6B6B))
                .multilineTextAlignment(.center)
        }
    }
}

struct Avatar: View {
    let nick: String
    let url: String?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Theme.accentGradient)
            Text(String(nick.prefix(1)).uppercased())
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white)
            if let u = url, let link = URL(string: u) {
                AsyncImage(url: link) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

func haptic() {
    if Settings.shared.haptics {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
