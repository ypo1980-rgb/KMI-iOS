import Foundation

enum HebrewTokenizer {
    private static let splitRegex = try! NSRegularExpression(pattern: "[ ,:\\-\\n\\t]+")
    
    static func tokenize(_ text: String) -> [String] {
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let normalized = splitRegex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: " "
        )

        return normalized
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
