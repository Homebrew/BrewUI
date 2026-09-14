import AppKit
import Foundation

@MainActor
public enum NativeMenuLocalization {
    public static func applyStandard(to application: NSApplication, localization: AppLocalization) {
        apply(
            mainMenu: application.mainMenu,
            windowsMenu: application.windowsMenu,
            helpMenu: application.helpMenu,
            servicesMenu: application.servicesMenu,
            localization: localization,
        )
    }

    static func apply(
        mainMenu: NSMenu?,
        windowsMenu: NSMenu? = nil,
        helpMenu: NSMenu? = nil,
        servicesMenu: NSMenu? = nil,
        localization: AppLocalization,
    ) {
        guard let mainMenu else { return }
        let menus = mainMenu.items.compactMap(\.submenu).filter { $0 !== servicesMenu }
        let fileMenu = uniqueMenu(in: menus, actions: ["performClose:", "newDocument:", "openDocument:"], commandKeys: ["n", "w"])
        let editMenu = uniqueMenu(in: menus, actions: ["undo:", "cut:", "copy:", "paste:"], commandKeys: ["x", "c", "v", "a", "z"])
        // View 没有标准 AppKit action；用本应用已定义的控制台及五个侧栏快捷键识别，不依赖显示语言或位置。
        let viewCandidates = menus.filter { menu in
            let commandKeys = Set(menu.items.filter { $0.keyEquivalentModifierMask == .command }.map(\.keyEquivalent))
            return Set(["`", "1", "2", "3", "4", "5"]).isSubset(of: commandKeys)
        }
        let viewMenu = viewCandidates.count == 1 ? viewCandidates.first : nil
        for (menu, key): (NSMenu?, String.LocalizationValue) in [
            (fileMenu, "File"), (editMenu, "Edit"), (viewMenu, "View"),
            (windowsMenu, "Window"), (helpMenu, "Help"), (servicesMenu, "Services"),
        ] {
            if let menu { update(menu: menu, in: mainMenu, title: localization.string(key)) }
        }
    }

    private static func uniqueMenu(in menus: [NSMenu], actions: Set<String>, commandKeys: Set<String>) -> NSMenu? {
        let matches = menus.filter { menu in
            let hasStandardAction = menu.items.contains { item in
                item.action.map { actions.contains(NSStringFromSelector($0)) } ?? false
            }
            let keys = Set(menu.items.filter { $0.keyEquivalentModifierMask == .command }.map(\.keyEquivalent))
            return hasStandardAction || commandKeys.isSubset(of: keys)
        }
        return matches.count == 1 ? matches.first : nil
    }

    private static func update(menu: NSMenu, in root: NSMenu, title: String) {
        if menu.title != title { menu.title = title }
        // servicesMenu 位于 App 子菜单；通过对象身份找到宿主，不通过旧标题猜测。
        for item in root.items {
            if item.submenu === menu {
                update(item: item, title: title)
                return
            }
            if let submenu = item.submenu, submenu !== menu {
                if let owner = submenu.items.first(where: { $0.submenu === menu }) {
                    update(item: owner, title: title)
                    return
                }
            }
        }
    }

    private static func update(item: NSMenuItem, title: String) {
        guard item.title != title else { return }
        item.title = title
    }
}
