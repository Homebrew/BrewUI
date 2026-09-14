# Sources/BrewFeatureInstalled/ViewModels/
> L2 | 父级: ../CLAUDE.md

成员清单
InstalledListRowViewModel.swift: BrewCore + BrewUIComponents + Foundation；列表展示模型；不改变 operation observer。
InstalledPackageDetailViewModel.swift: BrewCore + BrewRepositoryInterfaces + BrewUIComponents；安装详情模型；展示快照不改变操作或关系加载生命周期。
InstalledPackageScope.swift: Foundation；Package-kind filter for the Installed and Upgrades list scope pickers. Mirrors the Discover tab's。
InstalledPackagesContent+Placeholdable.swift: BrewCore；InstalledPackagesContent: Placeholdable 的既有实现。
InstalledUninstallBusyPresentation.swift: BrewCore + Foundation；Derived presentation for "uninstall in progress" chrome when observing ``BrewOperationPhase`` for an installed row.。
InstalledUpgradeBusyPresentation.swift: BrewCore + Foundation；"Upgrade in progress" chrome for an installed row, individual or a covering "Upgrade All"。
InstalledViewModel.swift: BrewCore + BrewRepositoryInterfaces + BrewUIComponents；特性展示模型；语言只作为文案函数输入，不进入业务生命周期。
PackageDetailMetadataItem.swift: BrewCore + BrewUIComponents + Foundation；安装展示值；命令字符串与业务判定不受语言影响。
PackageRelationshipItem.swift: BrewCore + BrewUIComponents + Foundation；One dependency or dependent row in installed package detail.。
UninstallPackageItem.swift: BrewCore + BrewUIComponents + Foundation；安装展示值；命令字符串与业务判定不受语言影响。
UpgradePackageItem.swift: BrewCore + BrewUIComponents + Foundation；安装展示值；命令字符串与业务判定不受语言影响。
UpgradesUpToDateCopy.swift: BrewUIComponents + Foundation；安装特性的纯展示帮助函数。
UpgradesViewModel.swift: BrewCore + BrewRepositoryInterfaces + BrewUIComponents；特性展示模型；语言只作为文案函数输入，不进入业务生命周期。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
