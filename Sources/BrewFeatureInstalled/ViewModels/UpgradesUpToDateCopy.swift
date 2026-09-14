/*
 * [INPUT]: 依赖数量与语言快照
 * [OUTPUT]: 生成升级空态数量文案
 * [POS]: 安装特性的纯展示帮助函数
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  UpgradesUpToDateCopy.swift
//  BrewFeatureInstalled
//

import BrewUIComponents
import Foundation

/// One phrase for "nothing to upgrade", shared by the four places the tab makes that claim at once.
enum UpgradesUpToDateCopy {
    static func headline(localization: AppLocalization = AppLocalization()) -> String {
        localization.string("Everything is up to date")
    }

    static func installedDetail(count: Int, localization: AppLocalization = AppLocalization()) -> String {
        switch count {
        case 0:
            localization.string("No installed packages to check.")
        case 1:
            localization.string("Your installed package is up to date.")
        default:
            localization.string("All \(count) installed packages are up to date.")
        }
    }
}
