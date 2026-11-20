import Foundation

// MARK: - Expression parser

enum CalcError: Error {
    case syntax
    case divisionByZero
    case range
}

private func isAsciiDigit(_ c: Character) -> Bool {
    return c >= "0" && c <= "9"
}

/// Recursive-descent parser for + - * / ( ) and postfix %.
/// "100 + 10%" evaluates to 110, like on a phone calculator.
struct ExpressionParser {
    typealias Operand = (value: Double, percent: Bool)

    private let chars: [Character]
    private var pos = 0

    init(_ source: String) {
        let normalized = source
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
        chars = Array(normalized)
    }

    private var current: Character? {
        return pos < chars.count ? chars[pos] : nil
    }

    mutating func evaluate() throws -> Double {
        let value = try parseExpression()
        guard pos == chars.count else { throw CalcError.syntax }
        guard value.isFinite else { throw CalcError.range }
        return value
    }

    private mutating func parseExpression() throws -> Double {
        var value = try parseTerm().value
        while let c = current, c == "+" || c == "-" {
            pos += 1
            var rhs = try parseTerm()
            if rhs.percent { rhs.value = value * rhs.value }
            value = (c == "+") ? value + rhs.value : value - rhs.value
        }
        return value
    }

    private mutating func parseTerm() throws -> Operand {
        var result = try parseUnary()
        while let c = current, c == "*" || c == "/" {
            pos += 1
            let rhs = try parseUnary()
            result.percent = false
            if c == "/" {
                if rhs.value == 0 { throw CalcError.divisionByZero }
                result.value = result.value / rhs.value
            } else {
                result.value = result.value * rhs.value
            }
        }
        return result
    }

    private mutating func parseUnary() throws -> Operand {
        if current == "-" {
            pos += 1
            let inner = try parseUnary()
            return (value: -inner.value, percent: inner.percent)
        }
        if current == "+" {
            pos += 1
            return try parseUnary()
        }
        return try parsePostfix()
    }

    private mutating func parsePostfix() throws -> Operand {
        var value = try parsePrimary()
        var percent = false
        while current == "%" {
            pos += 1
            value = value / 100
            percent = true
        }
        return (value: value, percent: percent)
    }

    private mutating func parsePrimary() throws -> Double {
        if current == "(" {
            pos += 1
            let inner = try parseExpression()
            guard current == ")" else { throw CalcError.syntax }
            pos += 1
            return inner
        }
        var text = ""
        while let c = current, isAsciiDigit(c) || c == "." {
            text.append(c)
            pos += 1
        }
        guard !text.isEmpty, let number = Double(text) else { throw CalcError.syntax }
        return number
    }
}

// MARK: - Number formatting

enum NumberText {
    /// Rounds away binary noise: 0.1 + 0.2 -> 0.3
    static func clean(_ value: Double) -> Double {
        return Double(String(format: "%.12g", value)) ?? value
    }

    /// Plain machine form with "." and "-" (used to continue a calculation).
    static func plain(_ value: Double) -> String {
        let v = clean(value)
        if v == v.rounded() && abs(v) < 1e15 {
            return String(Int64(v))
        }
        return String(v)
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 10
        f.usesGroupingSeparator = true
        f.minusSign = "−"
        return f
    }()

    /// Display form: "1 234,5"
    static func display(_ value: Double) -> String {
        let v = clean(value)
        return formatter.string(from: NSNumber(value: v)) ?? plain(v)
    }
}

// MARK: - Calculator state

final class CalculatorModel: ObservableObject {
    @Published private(set) var expression = ""
    @Published private(set) var finished = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastExpression = ""
    @Published private(set) var lastResult = 0.0

    private static let operators: Set<Character> = ["+", "−", "×", "÷"]

    var hasError: Bool { return errorMessage != nil }

    var mainText: String {
        if finished { return NumberText.display(lastResult) }
        if expression.isEmpty { return "0" }
        return expression.replacingOccurrences(of: ".", with: ",")
    }

    var previewText: String {
        if let message = errorMessage { return message }
        if finished {
            return lastExpression.replacingOccurrences(of: ".", with: ",") + " ="
        }
        let body = expression.hasPrefix("−") ? String(expression.dropFirst()) : expression
        let hasOperation = body.contains { "+−×÷%()".contains($0) }
        guard hasOperation else { return "" }
        guard let value = try? evaluateLenient(expression) else { return "" }
        return "= " + NumberText.display(value)
    }

    // MARK: Input

    func press(_ key: String) {
        errorMessage = nil

        switch key {
        case "C":
            expression = ""
            finished = false
            return
        case "back":
            if finished {
                expression = ""
                finished = false
            } else if !expression.isEmpty {
                expression.removeLast()
            }
            return
        case "=":
            evaluateAndFinish()
            return
        default:
            break
        }

        let keyChar = key.first
        let keyIsOperator = keyChar.map { Self.operators.contains($0) } ?? false

        if finished {
            let raw = NumberText.plain(lastResult).replacingOccurrences(of: "-", with: "−")
            finished = false
            let continues = (keyIsOperator || key == "%") && !raw.contains("e")
            expression = continues ? raw : ""
        }

        let last = expression.last
        let lastIsValueEnd = last.map { isDigit($0) || $0 == ")" || $0 == "%" } ?? false

        if let c = keyChar, key.count == 1, isDigit(c) {
            if lastIsValueEnd && !(last.map { isDigit($0) } ?? false) { expression += "×" }
            if trailingNumber() == "0" { expression.removeLast() }
            expression += key
        } else if key == "." {
            let number = trailingNumber()
            if !number.isEmpty {
                if !number.contains(".") { expression += "." }
            } else {
                if last == ")" || last == "%" { expression += "×" }
                expression += "0."
            }
        } else if keyIsOperator {
            if expression.isEmpty {
                if key == "−" { expression = "−" }
            } else if let l = last, Self.operators.contains(l) {
                if expression.count > 1 || l != "−" {
                    expression.removeLast()
                    expression += key
                }
            } else if last == "(" {
                if key == "−" { expression += key }
            } else {
                expression += key
            }
        } else if key == "%" {
            if lastIsValueEnd { expression += "%" }
        } else if key == "(" {
            let needsTimes = lastIsValueEnd || last == "."
            expression += needsTimes ? "×(" : "("
        } else if key == ")" {
            let open = expression.filter { $0 == "(" }.count
            let close = expression.filter { $0 == ")" }.count
            if open > close && lastIsValueEnd { expression += ")" }
        }
    }

    // MARK: Helpers

    private func isDigit(_ c: Character) -> Bool {
        return c >= "0" && c <= "9"
    }

    private func trailingNumber() -> String {
        var result = ""
        for ch in expression.reversed() {
            if isDigit(ch) || ch == "." {
                result.insert(ch, at: result.startIndex)
            } else {
                break
            }
        }
        return result
    }

    private func evaluateAndFinish() {
        guard !expression.isEmpty, !finished else { return }
        do {
            guard let value = try evaluateLenient(expression) else { return }
            lastExpression = expression
            lastResult = NumberText.clean(value)
            finished = true
        } catch CalcError.divisionByZero {
            errorMessage = "Деление на ноль"
        } catch {
            errorMessage = "Проверьте выражение"
        }
    }

    /// Drops dangling operators, closes open brackets, then evaluates.
    private func evaluateLenient(_ source: String) throws -> Double? {
        var text = source
        while let last = text.last, "+−×÷(".contains(last) {
            text.removeLast()
        }
        if text.isEmpty { return nil }
        let open = text.filter { $0 == "(" }.count
        let close = text.filter { $0 == ")" }.count
        if open > close {
            text += String(repeating: ")", count: open - close)
        }
        var parser = ExpressionParser(text)
        return try parser.evaluate()
    }
}
