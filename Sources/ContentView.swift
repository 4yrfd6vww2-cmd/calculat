import SwiftUI
import UIKit

// MARK: - Theme (follows the system light/dark setting)

enum Theme {
    static let background = dynamic(light: (230, 235, 238), dark: (11, 17, 20))
    static let key = dynamic(light: (255, 255, 255), dark: (29, 40, 45))
    static let keyInk = dynamic(light: (22, 38, 46), dark: (230, 238, 240))
    static let op = dynamic(light: (211, 230, 227), dark: (28, 58, 56))
    static let opInk = dynamic(light: (11, 90, 84), dark: (134, 227, 216))
    static let accent = dynamic(light: (15, 118, 110), dark: (45, 212, 191))
    static let accentInk = dynamic(light: (255, 255, 255), dark: (4, 33, 30))
    static let edge = dynamic(light: (212, 220, 224), dark: (38, 52, 58))
    static let danger = dynamic(light: (180, 35, 24), dark: (255, 138, 122))

    private static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        let provider: (UITraitCollection) -> UIColor = { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat(c.0) / 255,
                green: CGFloat(c.1) / 255,
                blue: CGFloat(c.2) / 255,
                alpha: 1
            )
        }
        return Color(UIColor(dynamicProvider: provider))
    }
}

// MARK: - Keys

enum KeyKind {
    case digit
    case function
    case op
    case equals
}

struct CalcKey: Identifiable {
    let label: String
    let token: String
    let kind: KeyKind
    var hint: String = ""

    var id: String { return token }
}

private let keyRows: [[CalcKey]] = [
    [
        CalcKey(label: "C", token: "C", kind: .function, hint: "Очистить"),
        CalcKey(label: "(", token: "(", kind: .function, hint: "Открывающая скобка"),
        CalcKey(label: ")", token: ")", kind: .function, hint: "Закрывающая скобка"),
        CalcKey(label: "⌫", token: "back", kind: .function, hint: "Стереть"),
    ],
    [
        CalcKey(label: "7", token: "7", kind: .digit),
        CalcKey(label: "8", token: "8", kind: .digit),
        CalcKey(label: "9", token: "9", kind: .digit),
        CalcKey(label: "÷", token: "÷", kind: .op, hint: "Разделить"),
    ],
    [
        CalcKey(label: "4", token: "4", kind: .digit),
        CalcKey(label: "5", token: "5", kind: .digit),
        CalcKey(label: "6", token: "6", kind: .digit),
        CalcKey(label: "×", token: "×", kind: .op, hint: "Умножить"),
    ],
    [
        CalcKey(label: "1", token: "1", kind: .digit),
        CalcKey(label: "2", token: "2", kind: .digit),
        CalcKey(label: "3", token: "3", kind: .digit),
        CalcKey(label: "−", token: "−", kind: .op, hint: "Вычесть"),
    ],
    [
        CalcKey(label: "0", token: "0", kind: .digit),
        CalcKey(label: ",", token: ".", kind: .digit, hint: "Запятая"),
        CalcKey(label: "%", token: "%", kind: .function, hint: "Процент"),
        CalcKey(label: "+", token: "+", kind: .op, hint: "Сложить"),
    ],
]

private let equalsKey = CalcKey(label: "=", token: "=", kind: .equals, hint: "Равно")

// MARK: - Views

struct ContentView: View {
    @StateObject private var model = CalculatorModel()

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let keyHeight = max(50, min(76, (geo.size.height - 190 - gap * 5) / 6))

            VStack(spacing: 16) {
                display

                VStack(spacing: gap) {
                    ForEach(keyRows.indices, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(keyRows[row]) { key in
                                KeyButton(key: key, height: keyHeight) { tap(key.token) }
                            }
                        }
                    }
                    KeyButton(key: equalsKey, height: keyHeight) { tap("=") }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(model.previewText)
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(model.hasError ? Theme.danger : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .trailing)

            Text(model.mainText)
                .font(.system(size: 56, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.keyInk)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: .infinity, alignment: .bottom)
    }

    private func tap(_ token: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        model.press(token)
    }
}

struct KeyButton: View {
    let key: CalcKey
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(key.label)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(KeyButtonStyle(kind: key.kind))
        .accessibilityLabel(key.hint.isEmpty ? key.label : key.hint)
    }

    private var fontSize: CGFloat {
        switch key.kind {
        case .digit: return 26
        case .function: return 22
        case .op: return 30
        case .equals: return 32
        }
    }
}

struct KeyButtonStyle: ButtonStyle {
    let kind: KeyKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.edge, lineWidth: hasEdge ? 1 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var hasEdge: Bool {
        return kind == .digit || kind == .function
    }

    private var background: Color {
        switch kind {
        case .digit, .function: return Theme.key
        case .op: return Theme.op
        case .equals: return Theme.accent
        }
    }

    private var foreground: Color {
        switch kind {
        case .digit: return Theme.keyInk
        case .function, .op: return Theme.opInk
        case .equals: return Theme.accentInk
        }
    }
}
