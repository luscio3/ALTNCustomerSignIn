import Foundation

/// Lightweight input formatters. Kept dependency-free for offline support.
enum FieldFormatters {
    /// Format a raw phone input into `(555) 123-4567`, digits only in parens.
    static func phone(_ raw: String) -> String {
        let digits = Array(raw.filter(\.isNumber).prefix(10))
        switch digits.count {
        case 0:      return ""
        case 1...3:  return "(\(String(digits)))"
        case 4...6:  return "(\(String(digits[0..<3]))) \(String(digits[3..<digits.count]))"
        default:
            let a = String(digits[0..<3])
            let b = String(digits[3..<6])
            let c = String(digits[6..<digits.count])
            return "(\(a)) \(b)-\(c)"
        }
    }

    /// Keep only the first 5 digits of a ZIP input.
    static func zip(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(5))
    }

    static func isValidEmail(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return false }
        let regex = try? NSRegularExpression(pattern: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: .caseInsensitive)
        let range = NSRange(location: 0, length: s.utf16.count)
        return regex?.firstMatch(in: s, options: [], range: range) != nil
    }
}
