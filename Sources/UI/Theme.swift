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
    static let bgTop = Color(hex: 0x040817)
    static let bgBottom = Color(hex: 0x060B1F)
    static let accent = Color(hex: 0x4AA8FF)
    static let accent2 = Color(hex: 0x8B6CFF)
    static let card = Color.white.opacity(0.05)
    static let stroke = Color.white.opacity(0.10)
    static let textSecondary = Color.white.opacity(0.6)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct GlassField: View {
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
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.stroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct NeonButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Theme.accent.opacity(0.45), radius: 14, y: 4)
        }
    }
}
