import Foundation
import Testing

struct LocalizationCatalogTests {
    private func catalogs() throws -> [[String: Any]] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        let modules = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
        let urls = [root.appendingPathComponent("Homebrew/Localizable.xcstrings")] + modules
            .map { $0.appendingPathComponent("Resources/Localizable.xcstrings") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        return try urls.map { url in
            let data = try Data(contentsOf: url)
            let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(catalog["sourceLanguage"] as? String == "en")
            return try #require(catalog["strings"] as? [String: Any])
        }
    }

    @Test func `every translated entry preserves interpolation argument types`() throws {
        let pattern = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:lld|ld|d|u|f|@)"#)
        func arguments(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                guard let range = Range($0.range, in: text) else { return nil }
                return String(text[range]).replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
            }.sorted()
        }
        for (key, value) in try catalogs().flatMap(\.self) {
            let entry = try #require(value as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any])
            let chinese = try #require(localizations["zh-Hans"] as? [String: Any])
            let unit = try #require(chinese["stringUnit"] as? [String: String])
            let translation = try #require(unit["value"])
            #expect(unit["state"] == "translated", "Unfinished translation: \(key)")
            #expect(!translation.isEmpty, "Empty translation: \(key)")
            #expect(arguments(key) == arguments(translation), "Format argument mismatch: \(key)")
        }
    }

    @Test func `catalog covers navigation and interpolated package counts`() throws {
        let entries = try catalogs().reduce(into: [String: Any]()) { $0.merge($1) { first, _ in first } }
        for key in ["Installed", "Upgrades", "Discover", "Doctor", "Configuration",
                    "%lld packages", "Upgrade to %@", "%lld minutes ago"]
        {
            #expect(entries[key] != nil, "Missing required entry: \(key)")
        }
    }
}
