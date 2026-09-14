import Foundation
import Testing

struct LocalizationCatalogTests {
    private static let requiredSimplifiedChineseKeys = [
        "Doctor",
        "Doctor issues",
        "Doctor warning preamble",
        "A newer Command Line Tools release is available.",
        "Update them from Software Update in System Settings.",
        "If that doesn't show you any updates, run:",
        "Alternatively, manually download them from:",
        "You should download the Command Line Tools for Xcode %@.",
        "Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.",
        "Homebrew is currently ignoring formulae, casks and commands",
        "from these taps because tap trust is required.",
        "Untap them with:",
        "Trust specific formulae, casks and commands with:",
        "Whole-tap trust is broader and includes all current and future formulae, casks and commands from the listed taps. Trust whole taps with:",
        "Whole-tap trust is broader and includes all current and future formulae,",
        "casks and commands from the listed taps. Trust whole taps with:",
        "For more information, see:",
        "The following taps are not trusted:",
        "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` instead.",
        "Please report this issue to the %@ (not Homebrew/* repositories), or even better, submit a PR to fix it:",
        "This is a Tier 2 configuration:",
        "You can report issues with Tier 2 configurations to Homebrew/* repositories!",
        "Read the above document before opening any issues or PRs.",
        "Language",
        "System Default",
        "English",
        "Simplified Chinese",
        "Restart Required",
        "Language changes will take effect after restarting the app.",
        "Running brew doctor…",
        "Re-checking…",
        "No problems found",
        "Warnings found",
        "The check could not be completed",
        "Last checked",
        "Your system is ready to brew",
        "brew doctor found no problems.",
        "Fix available",
        "Needs admin · runs in Terminal",
        "Run Fix",
        "Raw output",
        "No selection",
        "Run diagnostics, then choose an issue to see details and fixes.",
        "Warning",
        "Danger",
        "Unsupported",
        "Details",
        "Latest version",
        "Installed on",
        "Install reason",
        "License",
        "Pinned",
        "Keg-only",
        "Yes",
        "Dependencies",
        "No dependencies.",
        "Dependents",
        "No dependents.",
        "30-day installs",
        "Install",
        "Uninstall",
        "Source",
        "Homepage",
        "just now",
        "1 minute ago",
        "%lld minutes ago",
        "1 hour ago",
        "%lld hours ago",
        "1 day ago",
        "%lld days ago",
        "Terminal command",
        "Terminal commands",
        "Copy all",
        "Search Installed Packages",
        "Search Upgrades",
        "Search Homebrew's Packages",
        "Browse or search your installed packages",
        "Trending",
        "Most-installed packages in the last 30 days",
        "Popular Formulae",
        "Popular Casks",
        "Loading packages…",
        "Searching…",
        "Could not load packages",
        "Could not search packages",
        "Something went wrong loading packages.",
        "No matches",
        "Results",
        "Everything is up to date",
        "Upgrades every outdated package",
        "Upgrades every outdated formula",
        "Upgrades every outdated cask",
        "Upgrades the 1 package matching your search",
        "Upgrades the %lld packages matching your search",
        "No installed packages to check.",
        "Your installed package is up to date.",
        "All %lld installed packages are up to date.",
        "Uninstalls this package from this Mac",
        "Upgrades this package to the latest available version",
        "Installs this package on your Mac",
    ]

    private static let expectedUpgradeTranslations: [String: String] = [
        "Upgrade": "更新",
        "Upgrades": "更新",
        "Upgrade all %@ packages": "更新全部 %@ 个软件包",
        "Upgrade All (%@)": "全部更新（%@）",
        "Available upgrades": "可用更新",
        "Review and upgrade outdated packages": "查看并更新过时的软件包",
        "Upgrades this package to the latest available version": "将此软件包更新到最新可用版本",
        "Search Installed Packages": "搜索已安装的软件包",
        "Search Upgrades": "搜索更新",
        "Search Homebrew's Packages": "搜索 Homebrew 软件包",
        "Browse or search your installed packages": "浏览或搜索已安装的软件包",
        "Homebrew is currently ignoring formulae, casks and commands from these taps because tap trust is required.": "由于需要信任 Tap，Homebrew 当前忽略了这些 Tap 中的 Formula、Cask 和命令。",
        "Homebrew is currently ignoring formulae, casks and commands": "Homebrew 当前忽略了以下 Formula、Cask 和命令",
        "from these taps because tap trust is required.": "这些内容来自需要信任的 Tap。",
        "Untap them with:": "使用以下命令取消 Tap：",
        "Trust specific formulae, casks and commands with:": "使用以下命令信任指定的 Formula、Cask 和命令：",
        "Whole-tap trust is broader and includes all current and future formulae, casks and commands " +
            "from the listed taps. Trust whole taps with:": "信任整个 Tap 的范围更广，会包括列出 Tap 中当前和未来的所有 Formula、Cask 及命令。使用以下命令信任整个 Tap：",
        "Whole-tap trust is broader and includes all current and future formulae,": "信任整个 Tap 的范围更广，会包括列出的 Tap 中当前和未来的所有 Formula、",
        "casks and commands from the listed taps. Trust whole taps with:": "Cask 及命令。使用以下命令信任整个 Tap：",
        "For more information, see:": "更多信息请参阅：",
        "The following taps are not trusted:": "以下 Tap 不受信任：",
        "Calling string comparison format for `depends_on macos:` is deprecated! Use `depends_on macos: :big_sur` " +
            "instead.": "用于比较字符串的 `depends_on macos:` 格式已弃用！请改用 `depends_on macos: :big_sur`。",
        "Please report this issue to the %@ (not Homebrew/* repositories), or even better, submit a PR to fix it:": "请将此问题报告给 %@（而不是 Homebrew/* 仓库）；更好的做法是提交 PR 来修复：",
        "This is a Tier 2 configuration:": "这是 Tier 2 配置：",
        "You can report issues with Tier 2 configurations to Homebrew/* repositories!": "你可以将 Tier 2 配置的问题报告到 Homebrew/* 仓库！",
        "Read the above document before opening any issues or PRs.": "提交任何问题或 PR 前，请先阅读上述文档。",
        "Language": "语言",
        "System Default": "跟随系统",
        "English": "English",
        "Simplified Chinese": "简体中文",
        "Restart Required": "需要重启",
        "Language changes will take effect after restarting the app.": "语言更改将在重启 App 后生效。",
        "Trending": "热门趋势",
        "Most-installed packages in the last 30 days": "过去 30 天安装量最高的软件包",
        "Popular Formulae": "热门 Formula",
        "Popular Casks": "热门 Cask",
        "Loading packages…": "正在加载软件包…",
        "Searching…": "正在搜索…",
        "Could not load packages": "无法加载软件包",
        "Could not search packages": "无法搜索软件包",
        "Something went wrong loading packages.": "加载软件包时出错。",
        "No matches": "无匹配项",
        "Results": "搜索结果",
        "Everything is up to date": "所有软件包均为最新版本",
        "Upgrades every outdated package": "更新所有过时的软件包",
        "Upgrades every outdated formula": "更新所有过时的 Formula",
        "Upgrades every outdated cask": "更新所有过时的 Cask",
        "Upgrades the 1 package matching your search": "更新与你的搜索匹配的 1 个软件包",
        "Upgrades the %lld packages matching your search": "更新与你的搜索匹配的 %lld 个软件包",
        "No installed packages to check.": "没有可检查的已安装软件包。",
        "Your installed package is up to date.": "已安装的软件包为最新版本。",
        "All %lld installed packages are up to date.": "全部 %lld 个已安装的软件包均为最新版本。",
        "No formulae match": "没找到匹配的 Formula",
        "No casks match": "没找到匹配的 Cask",
        "Installing": "安装中",
        "Upgrading": "升级中",
        "Uninstalling": "卸载中",
        "Homebrew command failed.": "Homebrew 命令执行失败。",
        "Homebrew not found": "没有找到该 Homebrew",
    ]

    @Test func `doctor and package detail copy has required translations`() throws {
        let strings = try Self.catalogStrings()
        for key in Self.requiredSimplifiedChineseKeys {
            let entry = try #require(strings[key] as? [String: Any], "Missing catalog entry for \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            let simplifiedChinese = try #require(localizations["zh-Hans"] as? [String: Any])
            let stringUnit = try #require(simplifiedChinese["stringUnit"] as? [String: Any])
            let value = try #require(stringUnit["value"] as? String)
            #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test func `every catalog entry has a Simplified Chinese translation`() throws {
        let strings = try Self.catalogStrings()

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

    @Test func `upgrade terminology uses 更新`() throws {
        let strings = try Self.catalogStrings()
        for (key, value) in Self.expectedUpgradeTranslations {
            let entry = try #require(strings[key] as? [String: Any], "Missing catalog entry for \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            let simplifiedChinese = try #require(localizations["zh-Hans"] as? [String: Any])
            let stringUnit = try #require(simplifiedChinese["stringUnit"] as? [String: Any])
            #expect(stringUnit["value"] as? String == value)
        }
    }

    private static func catalogStrings() throws -> [String: Any] {
        let testFile = URL(fileURLWithPath: #filePath)
        let catalogURL = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Homebrew/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: Any])
    }
}
