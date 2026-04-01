import Foundation

enum HebrewNormalize {
    static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(
                of: "[\u{0591}-\u{05C7}]",
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func commonHebrewFixes(_ text: String) -> String {
        var value = text
        let fixes: [(String, String)] = [
            ("איימון", "אימון"),
            ("אימונם", "אימונים"),
            ("אימונין", "אימונים"),
            ("מאממ", "מאמן"),
            ("ממן", "מאמן"),
            ("אמון", "אימון"),
            ("אאמון", "אימון"),
            ("אימנ", "אימון"),
            ("אימן", "אימון")
        ]

        for (wrong, right) in fixes where value.contains(wrong) {
            value = value.replacingOccurrences(of: wrong, with: right)
        }

        return value
    }
}
