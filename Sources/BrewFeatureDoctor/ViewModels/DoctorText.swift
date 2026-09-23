import Foundation

/// Translates known Homebrew prose at the presentation boundary, leaving unknown diagnostics intact.
/// Homebrew wraps paragraphs differently by version; whitespace does not change a paragraph's key.
enum DoctorText {
    static func localized(_ text: String, bundle: Bundle = #bundle) -> String {
        let exact = bundle.localizedString(forKey: text, value: text, table: nil)
        if exact != text { return exact }
        let paragraph = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let translated = bundle.localizedString(forKey: paragraph, value: paragraph, table: nil)
        return translated == paragraph ? text : translated
    }

    static func prose(_ lines: [String], bundle: Bundle = #bundle) -> [String] {
        var result: [String] = []
        var start = 0
        while start < lines.count {
            var matchedEnd: Int?
            // A parser may group a wrapped paragraph and a trailing package/path in one prose block.
            // Translate the longest known span, then preserve the remaining data independently.
            for end in stride(from: lines.count, through: start + 1, by: -1) {
                let original = lines[start ..< end].joined(separator: "\n")
                let translated = localized(original, bundle: bundle)
                if translated != original {
                    result.append(translated)
                    matchedEnd = end
                    break
                }
            }
            if let matchedEnd {
                start = matchedEnd
            } else {
                result.append(lines[start])
                start += 1
            }
        }
        return result
    }
}
