# Sources/BrewFeatureInstalled/Views/
> L2 | 父级: ../CLAUDE.md

成员清单
InstalledColumns.swift: BrewAppEnvironment + BrewCore + BrewRepositoryInterfaces；InstalledColumns: View 的既有实现。
InstalledListRowView.swift: BrewAppEnvironment + BrewCore + BrewRepositoryInterfaces；列表行展示边界，不重置观察任务。
InstalledOutdatedBadge.swift: BrewUIComponents + SwiftUI；界面展示层，不翻译包名、配置值或原始错误。
InstalledPackageDetailSubviewSections.swift: AppKit + BrewCore + BrewUIComponents；详情 View 保留现有包、任务、滚动和弹窗身份。
InstalledPackageDetailView.swift: AppKit + BrewAccessibilityID + BrewAppEnvironment；安装详情展示层；保留包选择与命令任务身份。
InstalledPackagesView.swift: BrewAccessibilityID + BrewAppEnvironment + BrewCore；特性 View 在展示时解析文案，保留原有任务与选择。
InstalledUpgradesColumns.swift: BrewAppEnvironment + BrewCore + BrewRepositoryInterfaces；Hosts the Installed and Upgrades columns under one stable view identity so a single toolbar。
SearchFocusPreviewHost.swift: Swift；SearchFocusPreviewHost<Content: View>: View 的既有实现。
UpgradesColumns.swift: BrewAppEnvironment + BrewCore + BrewRepositoryInterfaces；UpgradesColumns: View 的既有实现。
UpgradesHeaderView.swift: BrewAccessibilityID + BrewCore + BrewUIComponents；特性 View 在展示时解析文案，保留原有任务与选择。
UpgradesPackagesView.swift: BrewAccessibilityID + BrewAppEnvironment + BrewCore；特性 View 在展示时解析文案，保留原有任务与选择。
UpgradesSidebarBadge.swift: BrewAppEnvironment + BrewUIComponents + SwiftUI；Warning-tinted count badge for the Upgrades sidebar row.。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
