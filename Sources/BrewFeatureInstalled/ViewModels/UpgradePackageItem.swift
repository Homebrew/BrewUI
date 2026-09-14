/*
 * [INPUT]: 依赖安装包数据与显式当前语言快照
 * [OUTPUT]: 派生可随语言重算的元信息或操作文案
 * [POS]: 安装展示值；命令字符串与业务判定不受语言影响
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  UpgradePackageItem.swift
//  Brew
//

import BrewCore
import BrewUIComponents
import Foundation

/// Presentation mapping for upgrade actions shown in Installed package detail.
struct UpgradePackageItem {
    private let localization: AppLocalization
    private let package: InstalledBrewPackage

    init(package: InstalledBrewPackage, localization: AppLocalization = AppLocalization()) {
        self.localization = localization
        self.package = package
    }

    var showsUpgradeChrome: Bool {
        package.outdated
    }

    /// Copyable Terminal command for upgrading this package (`CONVENTIONS.md` — transparency).
    var displayCommand: String {
        switch package.kind {
        case .formula:
            "brew upgrade --formula \(package.name)"
        case .cask:
            "brew upgrade --cask \(package.name)"
        }
    }

    /// Primary upgrade button label when the package is outdated.
    var primaryButtonTitle: String? {
        guard showsUpgradeChrome else {
            return nil
        }
        guard let label = InstalledBrewVersionFormatting.upgradeDisplayLabel(from: package.latestVersion) else {
            return nil
        }
        return localization.string("Upgrade to \(label)")
    }
}
