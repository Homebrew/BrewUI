/*
 * [INPUT]: 依赖应用实际 String Catalog，不使用与产品脱节的翻译副本
 * [OUTPUT]: 验证三种语言覆盖、翻译状态及每个复数分支的格式参数一致性
 * [POS]: 资源发布契约；新增文案缺译或占位符损坏会阻止包测试通过
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import Foundation
import Testing

struct LocalizationCatalogTests {
    @Test func `shipping languages cover every key and preserve format arguments`() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Homebrew/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        #expect(!strings.isEmpty)
        for (key, entry) in strings {
            let localizations = try #require(entry["localizations"] as? [String: [String: Any]])
            for language in ["en", "zh-Hans", "zh-Hant"] {
                let translation = try #require(localizations[language], "Missing \(language): \(key)")
                let units = stringUnits(in: translation)
                #expect(!units.isEmpty, "Empty \(language): \(key)")
                for unit in units {
                    #expect(unit["state"] == "translated", "Unreviewed \(language): \(key)")
                    let value = try #require(unit["value"])
                    #expect(try placeholders(in: value) == placeholders(in: key), "Format mismatch \(language): \(key)")
                }
            }
        }
    }

    private func stringUnits(in node: [String: Any]) -> [[String: String]] {
        if let unit = node["stringUnit"] as? [String: String] { return [unit] }
        return node.values.compactMap { $0 as? [String: Any] }.flatMap(stringUnits)
    }

    private func placeholders(in value: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:lld|d|@)"#)
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
            .compactMap { Range($0.range, in: value).map { String(value[$0]) } }
            .sorted()
    }
}
