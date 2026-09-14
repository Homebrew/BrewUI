import BrewCore
@testable import BrewFeatureDoctor
import Foundation
import Testing

@MainActor
struct DoctorLocalizationTests {
    private func withChineseBundle(_ body: (Bundle) throws -> Void) throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Homebrew/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        var translations: [String: String] = [:]
        for (key, entry) in entries {
            let locales = entry["localizations"] as? [String: [String: Any]]
            let unit = locales?["zh-Hans"]?["stringUnit"] as? [String: String]
            translations[key] = unit?["value"]
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DoctorLocalization-\(UUID().uuidString).bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let strings = try PropertyListSerialization.data(fromPropertyList: translations, format: .binary, options: 0)
        try strings.write(to: directory.appendingPathComponent("Localizable.strings"))
        let bundle = try #require(Bundle(url: directory))
        try body(bundle)
    }

    @Test func `diagnostic translation preserves identity commands and raw output`() throws {
        try withChineseBundle { bundle in
            let command = DoctorFixStep(displayCommand: "brew link openssl@3", arguments: ["link", "openssl@3"], needsAdmin: false)
            let issue = DoctorIssue(
                title: "You have unlinked kegs in your Cellar.",
                severity: .caution,
                blocks: [DoctorBlock(id: 0, caption: "You can solve this by running:", content: .command([command]))],
                rawBody: "You can solve this by running:\n  brew link openssl@3",
            )
            let item = DoctorIssueItem(issue: issue, bundle: bundle)
            #expect(item.title == "Cellar 中有尚未链接的软件包。")
            #expect(item.blocks.first?.caption == "可以运行以下命令解决此问题：")
            #expect(item.rawText == issue.rawText)
            #expect(item.id == DoctorIssueItem.contentID(for: issue))
            #expect(item.primaryRunnableStep == command)
        }
    }

    @Test func `wrapped paragraphs translate while unknown output stays intact`() throws {
        try withChineseBundle { bundle in
            let lines = [
                "Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on",
                "those kegs to fail to run properly once built.",
                "openssl@3",
            ]
            #expect(DoctorText.prose(lines, bundle: bundle) == [
                "未链接的软件包可能导致构建问题，并使依赖它们的命令行工具在构建后无法正常运行。",
                "openssl@3",
            ])
            let unknown = "Unknown warning:\n  /some/path remains verbatim"
            #expect(DoctorText.localized(unknown, bundle: bundle) == unknown)
        }
    }
}
