# Sources/BrewRepositoryInterfaces/Protocols/
> L2 | 父级: ../CLAUDE.md

成员清单
CatalogueRepository.swift: BrewCore + Foundation；CatalogueRepository: Sendable 的既有实现。
CommandJobsObserving.swift: BrewCore + Foundation + Observation；Observable cache of command-center operations, for surfaces that render the live console.。
ConfigRepository.swift: BrewCore + Foundation；App-scoped, cached source of truth for `brew config` + the effective `HOMEBREW_*` process。
DiscoverPackagesRepository.swift: BrewCore + Foundation + Observation；App-scoped source of truth for Discover's trending list: one observable load state plus a cache-first。
DoctorRepository.swift: BrewCore + Foundation + Observation；App-scoped, observable source of truth for `brew doctor` diagnostics.。
InstalledDependentsRepository.swift: BrewCore + Foundation；Reverse dependency lookups over the installed inventory snapshot.。
InstalledInventoryObserving+Outdated.swift: BrewCore；InstalledInventoryObserving 的既有实现。
InstalledInventoryObserving.swift: BrewCore + Foundation + Observation；Observable installed-inventory state plus its load lifecycle, for surfaces that render the whole list.。
InstalledInventoryReading.swift: BrewCore + Foundation；Read-only access to the set of installed package identities (used for dependency "installed?" checks).。
InstalledPackageStatusReading.swift: BrewCore + Foundation；Synchronous installed-status lookups for row rendering. Backed by the observable inventory source of。
InstalledPackagesRepository.swift: Foundation；App-scoped source of truth for installed/outdated package state: the observable inventory plus the。
SelfUpgradeHandoff.swift: Foundation；交接协议边界；实现只返回失败原因，不选择界面语言。
SelfUpgradePreferences.swift: Foundation + Observation；SelfUpgradePreferences: AnyObject, Observable, Sendable 的既有实现。
SelfUpgradeStatusProviding.swift: BrewCore + Foundation + Observation；A seam so detection can be tested without `Bundle.main`, which in a test process is the runner.。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
