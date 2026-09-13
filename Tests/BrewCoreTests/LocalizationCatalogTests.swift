import Foundation
import Testing

struct LocalizationCatalogTests {
    @Test func `every catalog entry has a Simplified Chinese translation`() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let catalogURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Homebrew/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])

        for (key, value) in strings {
            let entry = try #require(value as? [String: Any])
            let localizations = try #require(entry["localizations"] as? [String: Any], "Missing localizations for \(key)")
            let simplifiedChinese = try #require(
                localizations["zh-Hans"] as? [String: Any],
                "Missing zh-Hans localization for \(key)",
            )
            let stringUnit = try #require(
                simplifiedChinese["stringUnit"] as? [String: Any],
                "Missing zh-Hans string unit for \(key)",
            )
            let value = try #require(stringUnit["value"] as? String)
            #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
