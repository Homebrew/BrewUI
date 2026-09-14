/*
 * [INPUT]: 依赖 BrewCore 包身份、RepositoryInterfaces 状态与共享展示本地化
 * [OUTPUT]: 提供 DiscoverInstallBusyPresentation
 * [POS]: Discover 展示策略；语言解析不参与仓库或安装任务生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  DiscoverInstallBusyPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// Derived presentation for "install in progress" chrome on a Discover row.
///
/// The Discover list (search/trending results) is not reloaded when an install completes, so a
/// stored-flag-only approach cannot self-clear the way ``InstalledUpgradeBusyPresentation`` does.
/// Instead, bridge the gap between the operation finishing and the installed badge appearing by
/// reading the observable installed-state: stay busy while the operation is running, and keep busy
/// after it finishes until the package is observed as installed.
enum DiscoverInstallBusyPresentation {
    static func showsInstallBusy(
        phase: BrewOperationPhase,
        awaitingResolution: Bool,
        isInstalled: Bool,
    ) -> Bool {
        if phase.isRunningInstall {
            return true
        }
        return awaitingResolution && !isInstalled
    }
}

extension BrewOperationPhase {
    var isRunningInstall: Bool {
        switch self {
        case .running(.installFormula), .running(.installCask):
            true
        default:
            false
        }
    }
}
