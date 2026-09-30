//
//  DoctorMessageCopyTests.swift
//  BrewTests
//

@testable import BrewFeatureDoctor
import BrewRepositories
import Foundation
import Testing

struct DoctorMessageCopyTests {
    @Test(arguments: [
        ("Some installed formulae are deprecated or disabled.",
         "部分已安装的配方已弃用或停用。", "部分已安裝的配方已棄用或停用。"),
        ("Some installed casks are deprecated or disabled.",
         "部分已安装的 Cask 已弃用或停用。", "部分已安裝的 Cask 已棄用或停用。"),
        ("The following taps are not trusted:", "以下 tap 尚未受信任：", "以下 tap 尚未受信任："),
        ("You have unlinked kegs in your Cellar.", "Cellar 中有尚未链接的 keg。", "Cellar 中有尚未連結的 keg。"),
        ("Unbrewed header files were found in /some/other/include.",
         "在 /some/other/include 中发现了未经 Homebrew 安装的头文件。", "在 /some/other/include 中發現了未經 Homebrew 安裝的標頭檔。"),
        ("Unbrewed dylibs were found in /usr/local/lib.",
         "在 /usr/local/lib 中发现了非 Homebrew 管理的动态链接库。", "在 /usr/local/lib 中發現了非 Homebrew 管理的動態連結程式庫。"),
        ("Unbrewed static libraries were found in /usr/local/lib.",
         "在 /usr/local/lib 中发现了未经 Homebrew 安装的静态库。", "在 /usr/local/lib 中發現了未經 Homebrew 安裝的靜態函式庫。"),
        ("Unbrewed '.pc' files were found in /usr/local/lib/pkgconfig.",
         "在 /usr/local/lib/pkgconfig 中发现了非 Homebrew 管理的“.pc”文件。", "在 /usr/local/lib/pkgconfig 中發現了非 Homebrew 管理的「.pc」檔案。"),
        ("Unbrewed '.la' files were found in /usr/local/lib.",
         "在 /usr/local/lib 中发现了非 Homebrew 管理的“.la”文件。", "在 /usr/local/lib 中發現了非 Homebrew 管理的「.la」檔案。"),
    ])
    func `recognised titles resolve in both Chinese locales`(_ source: String, _ simplified: String, _ traditional: String) throws {
        for (language, expected) in [("zh-Hans", simplified), ("zh-Hant", traditional)] {
            try withChineseBundle(language) { bundle in
                #expect(DoctorMessageCopy.title(source, bundle: bundle) == expected)
            }
        }
    }

    @Test(arguments: [
        ("You should find replacements for the following formulae:", "请为以下配方寻找替代品：", "請為以下配方尋找替代品："),
        ("You should find replacements for the following casks:", "请为以下 Cask 寻找替代品：", "請為以下 Cask 尋找替代品："),
        ("Unexpected header files:", "意外的头文件：", "意外的標頭檔："),
        ("Unexpected dylibs:", "意外的动态库：", "意外的動態函式庫："),
        ("Unexpected static libraries:", "意外的静态库：", "意外的靜態函式庫："),
        ("Unexpected '.pc' files:", "意外的 '.pc' 文件：", "意外的 '.pc' 檔案："),
        ("Unexpected '.la' files:", "意外的 '.la' 文件：", "非預期的「.la」檔案："),
        ("Trust installed formulae from these taps with:", "可用以下命令信任这些 tap 中已安装的配方：", "可用以下命令信任這些 tap 中已安裝的配方："),
        ("Trust installed casks from these taps with:", "可用以下命令信任这些 tap 中已安装的 Cask：", "可用以下命令信任這些 tap 中已安裝的 Cask："),
        ("Trust other specific casks and commands with:", "可用以下命令信任其他具体的 Cask 和命令：", "可用以下命令信任其他特定的 Cask 和命令："),
        ("Untap them with:", "可用以下命令移除这些 tap：", "可用以下命令移除這些 tap："),
        ("For more information, see:", "更多信息：", "更多資訊："),
        ("Affects:", "涉及：", "涉及："),
        ("More information:", "更多信息：", "更多資訊："),
        ("Run `brew link` on these:", "对以下 keg 运行 `brew link`：", "對以下 keg 執行 `brew link`："),
        ("You can solve this by running:", "可以运行以下命令解决：", "可執行以下命令解決："),
    ])
    func `recognised captions resolve in both Chinese locales`(_ source: String, _ simplified: String, _ traditional: String) throws {
        for (language, expected) in [("zh-Hans", simplified), ("zh-Hant", traditional)] {
            try withChineseBundle(language) { bundle in
                #expect(DoctorMessageCopy.caption(source, bundle: bundle) == expected)
            }
        }
    }

    @Test(arguments: ["zh-Hans", "zh-Hant"])
    func `unknown upstream findings remain verbatim`(_ language: String) throws {
        let unknown = "Homebrew changed this warning in a future release."
        try withChineseBundle(language) { bundle in
            #expect(DoctorMessageCopy.title(unknown, bundle: bundle) == unknown)
            #expect(DoctorMessageCopy.caption(unknown, bundle: bundle) == unknown)
        }
        #expect(DoctorMessageCopy.prose([unknown]) == unknown)
    }

    @Test func `path values remain unchanged in known titles`() {
        let title = "Unbrewed header files were found in /usr/local/include."
        #expect(DoctorMessageCopy.title(title) == title)
        let other = "Unbrewed header files were found in /some/other/include."
        #expect(DoctorMessageCopy.title(other) == other)
    }

    @Test func `unmanaged file families retain their paths`() {
        let titles = [
            "Unbrewed dylibs were found in /usr/local/lib.",
            "Unbrewed static libraries were found in /usr/local/lib.",
            "Unbrewed '.pc' files were found in /usr/local/lib/pkgconfig.",
        ]
        #expect(titles.map { DoctorMessageCopy.title($0) } == titles)
    }

    @Test func `unlinked keg guidance preserves Homebrew terminology`() {
        let title = "You have unlinked kegs in your Cellar."
        let explanation = [
            "Leaving kegs unlinked can lead to build-trouble and cause formulae that depend on",
            "those kegs to fail to run properly once built.",
        ]
        #expect(DoctorMessageCopy.title(title) == title)
        #expect(DoctorMessageCopy.prose(explanation) == explanation.joined(separator: " "))
        #expect(DoctorMessageCopy.caption("Run `brew link` on these:") == "Run `brew link` on these:")
    }

    @Test func `commands and data are outside the localisation boundary`() {
        let paragraph = [
            "Homebrew is currently ignoring formulae, casks and commands",
            "from these taps because tap trust is required.",
        ]
        #expect(DoctorMessageCopy.prose(paragraph) == paragraph.joined(separator: " "))
        #expect(DoctorMessageCopy.caption("Trust installed formulae from these taps with:") ==
            "Trust installed formulae from these taps with:")
    }

    @Test func `adjacent known prose is localised without consuming unknown text`() {
        let lines = [
            "Homebrew is currently ignoring formulae, casks and commands",
            "from these taps because tap trust is required.",
            "Prefer trusting only the specific formulae, casks or commands you need.",
            "Trust installed formulae from these taps with:",
            "A future Homebrew explanation stays verbatim.",
        ]

        #expect(DoctorMessageCopy.prose(lines) == """
        Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.
        Prefer trusting only the specific formulae, casks or commands you need.
        Trust installed formulae from these taps with:
        A future Homebrew explanation stays verbatim.
        """)
    }

    @Test func `presentation copy does not change parsed evidence`() throws {
        let output = """
        Warning: Some installed formulae are deprecated or disabled.
        You should find replacements for the following formulae:
          dotnet@6
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(issue: issue)

        _ = DoctorMessageCopy.title(item.title)
        _ = DoctorMessageCopy.caption("You should find replacements for the following formulae:")

        #expect(item.rawText == output)
    }

    @Test func `tap trust commands keep their CLI arguments`() throws {
        let output = """
        Warning: The following taps are not trusted:
          oven-sh/bun
        Trust installed formulae from these taps with:
          brew trust --formula oven-sh/bun/bun
        Trust other specific casks and commands with:
          brew trust --cask <user>/<tap>/<cask>
          brew trust --command <user>/<tap>/<command>
        """
        let issue = try #require(DoctorOutputParser.parse(output).issues.first)
        let item = DoctorIssueItem(issue: issue)
        let commands = item.blocks.flatMap { block -> [String] in
            switch block.content {
            case let .command(steps):
                steps.map(\.displayCommand)
            case let .data(items):
                items.filter { $0.hasPrefix("brew trust ") }
            case .prose, .link:
                []
            }
        }

        #expect(commands == [
            "brew trust --formula oven-sh/bun/bun",
            "brew trust --cask <user>/<tap>/<cask>",
            "brew trust --command <user>/<tap>/<command>",
        ])
    }

    private func withChineseBundle(_ language: String, assertions: (Bundle) throws -> Void) throws {
        if let path = Bundle.module.path(forResource: language, ofType: "lproj") {
            try assertions(#require(Bundle(path: path)))
            return
        }

        // The native SwiftPM build copies xcstrings without compiling them. Build a strings
        // bundle from that same catalogue so these assertions also run in scripts/test on CI.
        let catalogURL = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let entries = try #require(catalog["strings"] as? [String: [String: Any]])
        let translations = entries.compactMapValues { entry -> String? in
            let localizations = entry["localizations"] as? [String: [String: Any]]
            let unit = localizations?[language]?["stringUnit"] as? [String: String]
            return unit?["value"]
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try PropertyListSerialization.data(fromPropertyList: translations, format: .binary, options: 0)
        try data.write(to: directory.appendingPathComponent("Localizable.strings"))
        try assertions(#require(Bundle(url: directory)))
    }
}
