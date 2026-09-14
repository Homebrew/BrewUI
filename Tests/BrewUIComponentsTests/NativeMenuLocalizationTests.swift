/*
 * [INPUT]: 依赖 AppKit 菜单对象、测试 Bundle 与 NativeMenuLocalization
 * [OUTPUT]: 验证真实标准 action 绑定、同对象双向切换、未知菜单保护与幂等更新
 * [POS]: 原生菜单适配的离线契约测试；不启动窗口或替换系统菜单
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import AppKit
@testable import BrewUIComponents
import Foundation
import Testing

@MainActor
struct NativeMenuLocalizationTests {
    @Test func `standard actions identify menus independent of display text`() throws {
        try withBundle { bundle in
            let root = NSMenu()
            let file = NSMenu(title: "任意旧标题")
            let close = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
            let target = NSWindow.self
            close.target = target
            file.addItem(close)
            let owner = NSMenuItem()
            owner.submenu = file
            root.addItem(owner)
            let action = close.action
            let modifiers = close.keyEquivalentModifierMask
            NativeMenuLocalization.apply(mainMenu: root, localization: AppLocalization(language: "zh-Hans", bundle: bundle))
            #expect(owner.title == "文件" && file.title == "文件" && close.title == "Close")
            #expect(close.action == action && close.keyEquivalent == "w" && close.keyEquivalentModifierMask == modifiers)
            #expect(close.target === target)
            NativeMenuLocalization.apply(mainMenu: root, localization: AppLocalization(language: "en", bundle: bundle))
            #expect(owner.title == "File" && close.title == "Close")
        }
    }

    @Test func `ambiguous menus and lookalike display titles stay untouched`() {
        let root = NSMenu()
        for title in ["File", "Plugin"] {
            let menu = NSMenu(title: title)
            menu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = menu
            root.addItem(item)
        }
        NativeMenuLocalization.apply(mainMenu: root, localization: AppLocalization(language: "zh-Hans"))
        #expect(root.items.map(\.title) == ["File", "Plugin"])
    }

    @Test func `view uses existing command shortcuts rather than menu position`() throws {
        try withBundle { bundle in
            let root = NSMenu()
            let view = NSMenu(title: "Untranslated")
            for key in ["`", "1", "2", "3", "4", "5"] {
                view.addItem(NSMenuItem(title: key, action: nil, keyEquivalent: key))
            }
            let owner = NSMenuItem()
            owner.submenu = view
            root.addItem(owner)
            NativeMenuLocalization.apply(mainMenu: root, localization: AppLocalization(language: "zh-Hans", bundle: bundle))
            #expect(owner.title == "显示")
            #expect(view.items.map(\.title) == ["`", "1", "2", "3", "4", "5"])
        }
    }

    @Test func `services content and command attributes are preserved`() throws {
        try withBundle { bundle in
            let root = NSMenu()
            let services = NSMenu(title: "Services")
            let item = NSMenuItem(title: "Third-party Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
            services.addItem(item)
            let owner = NSMenuItem()
            owner.submenu = services
            root.addItem(owner)
            NativeMenuLocalization.apply(mainMenu: root, servicesMenu: services, localization: AppLocalization(language: "zh-Hans", bundle: bundle))
            #expect(owner.title == "服务" && item.title == "Third-party Copy")
        }
    }

    @Test func `same language does not write item titles again`() throws {
        try withBundle { bundle in
            let root = NSMenu()
            let menu = NSMenu()
            let item = CountingMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
            menu.addItem(item)
            let owner = CountingMenuItem()
            owner.submenu = menu
            root.addItem(owner)
            let localization = AppLocalization(language: "zh-Hans", bundle: bundle)
            NativeMenuLocalization.apply(mainMenu: root, localization: localization)
            let writes = owner.titleWrites
            NativeMenuLocalization.apply(mainMenu: root, localization: localization)
            #expect(writes > 0 && owner.titleWrites == writes)
        }
    }

    private final nonisolated class CountingMenuItem: NSMenuItem {
        var titleWrites = 0
        override var title: String {
            didSet { titleWrites += 1 }
        }
    }

    private func withBundle(_ body: (Bundle) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, strings) in [
            ("en", "\"File\" = \"File\";\n\"Close\" = \"Close\";\n"),
            ("zh-Hans", "\"File\" = \"文件\";\n\"Close\" = \"关闭\";\n\"View\" = \"显示\";\n\"Services\" = \"服务\";\n"),
        ] {
            let folder = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try strings.write(to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        try body(#require(Bundle(url: root)))
    }
}
