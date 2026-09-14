# Tests/BrewFeatureInstalledTests/
> L2 | 父级: ../CLAUDE.md

成员清单
BrewTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；BrewTests 的既有实现。
InstalledDetailMutationParityTests.swift: BrewCLI + BrewCore + BrewCoreTestSupport；安装特性错误回归测试。
InstalledDetailsViewModelTests.swift: BrewCLI + BrewCore + BrewCoreTestSupport；特性测试；显式调用展示函数而不修改业务预期。
InstalledDetailsViewModelTestsSupport.swift: BrewCLI + BrewCore + BrewCoreTestSupport；安装特性错误回归测试。
InstalledFeatureTestSupport.swift: BrewCLI + BrewCore + BrewCoreTestSupport；InstalledFeatureTestSupport 的既有实现。
InstalledListRowViewModelTests.swift: BrewCLI + BrewCore + BrewCoreTestSupport；行展示单元测试。
InstalledPackageRowPresentationTests.swift: BrewCLI + BrewCore + BrewCoreTestSupport；行展示单元测试。
InstalledUninstallBusyPresentationTests.swift: BrewCore + Foundation + Testing；InstalledUninstallBusyPresentationTests 的既有实现。
InstalledUpgradeBusyPresentationTests.swift: BrewCore + Foundation + Testing；InstalledUpgradeBusyPresentationTests 的既有实现。
InstalledViewModelPresentationTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；特性单元测试，不改动业务预期。
InstalledViewModelScopeTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；特性单元测试，不改动业务预期。
InstalledViewModelSearchTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；InstalledViewModelSearchTests 的既有实现。
InstalledViewModelTests.swift: BrewCLI + BrewCore + BrewCoreTestSupport；InstalledViewModelTests 的既有实现。
InstalledViewModelTestsSupport.swift: BrewCLI + BrewCore + BrewCoreTestSupport；Repository that has not loaded yet — stays in `.loading` until `load()` is called.。
PackageDetailMetadataItemTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；PackageDetailMetadataItemTests 的既有实现。
PackageListBannerSlotTests.swift: AppKit + BrewAppEnvironment + BrewCore；Measured rather than asserted structurally: a slot that is read but never placed still compiles.。
PackageRelationshipItemTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；PackageRelationshipItemTests 的既有实现。
SelfUpgradeBannerSlotTests.swift: AppKit + BrewAppEnvironment + BrewCore；The real banner in the real slot, composed the way `MainWindowView` composes it — including when the。
SelfUpgradeCaskExclusionTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；Anywhere the app's own cask reaches an ordinary `brew upgrade`, it is replaced under the running app.。
UninstallPackageItemTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；UninstallPackageItemTests 的既有实现。
UpgradePackageItemTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositories；UpgradePackageItemTests 的既有实现。
UpgradesChromeBudgetTests.swift: AppKit + BrewCore + BrewRepositoryInterfaces；Upgrades is what ``BrewLayout/mainPaneMinHeight`` is sized for. Measured against the real views rather。
UpgradesUpToDateCopyTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；特性单元测试，不改动业务预期。
UpgradesViewModelCheckFailureTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；特性单元测试，不改动业务预期。
UpgradesViewModelRefreshTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；Loaded-state inventory whose `load` parks until released, so a test can observe the view model。
UpgradesViewModelScopeTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；特性单元测试，不改动业务预期。
UpgradesViewModelTests.swift: BrewCore + BrewCoreTestSupport + BrewRepositoryInterfaces；特性单元测试，不改动业务预期。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
