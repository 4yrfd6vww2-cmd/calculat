import SwiftUI

enum Lang: String, CaseIterable, Identifiable {
    case ru, en, de
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .de: return "Deutsch"
        }
    }
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark, black, light
    var id: String { rawValue }
}

enum TextSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var dynamic: DynamicTypeSize {
        switch self {
        case .small: return .small
        case .medium: return .large
        case .large: return .xxxLarge
        }
    }
}

let accentPalette: [UInt32] = [
    0x4AA8FF, 0x9B6BFF, 0x35E0B4, 0xFF6BB5, 0xFF8A4A, 0xFFD24A,
    0x4AE0E0, 0x7CFF6B, 0xFF5C5C, 0xB06BFF, 0x6B8BFF, 0xE06BFF
]

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var lang: Lang { didSet { d.set(lang.rawValue, forKey: "s.lang") } }
    @Published var mode: ThemeMode { didSet { d.set(mode.rawValue, forKey: "s.mode") } }
    @Published var textSize: TextSize { didSet { d.set(textSize.rawValue, forKey: "s.size") } }
    @Published var accentHex: UInt32 { didSet { d.set(Int(accentHex), forKey: "s.accent") } }
    @Published var messageSound: Bool { didSet { d.set(messageSound, forKey: "s.sound") } }
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "s.haptics") } }

    init() {
        lang = Lang(rawValue: d.string(forKey: "s.lang") ?? "") ?? .ru
        mode = ThemeMode(rawValue: d.string(forKey: "s.mode") ?? "") ?? .dark
        textSize = TextSize(rawValue: d.string(forKey: "s.size") ?? "") ?? .medium
        let a = d.integer(forKey: "s.accent")
        accentHex = a == 0 ? 0x4AA8FF : UInt32(a)
        messageSound = d.object(forKey: "s.sound") as? Bool ?? true
        haptics = d.object(forKey: "s.haptics") as? Bool ?? true
    }
}

/// Простой перевод: tr("русский", "english", "deutsch")
func tr(_ ru: String, _ en: String, _ de: String) -> String {
    switch Settings.shared.lang {
    case .ru: return ru
    case .en: return en
    case .de: return de
    }
}
