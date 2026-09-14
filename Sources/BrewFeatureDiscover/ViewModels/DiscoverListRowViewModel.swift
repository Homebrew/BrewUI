/*
 * [INPUT]: 依赖 BrewCore 包身份、RepositoryInterfaces 状态与共享展示本地化
 * [OUTPUT]: 提供 DiscoverListRowViewModel
 * [POS]: Discover 展示策略；语言解析不参与仓库或安装任务生命周期
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

@Observable
@MainActor
final class DiscoverListRowViewModel: Identifiable {
    private(set) var discoveryPackage: DiscoveryBrewPackage
    /// Shared installed-status reader. Read through it so the installed badge/version stay reactive to
    /// installs and uninstalls happening on other surfaces.
    @ObservationIgnored let installedRepository: any InstalledPackageStatusReading
    /// Catalogue search results carry no analytics, so install-count metadata is suppressed for them.
    let showsInstallMetrics: Bool
    @ObservationIgnored private let brewCommandCenter: any BrewCommandCenter

    /// Latest phase from the command center stream (see ``observeRowUpdates()``); drives the install spinner.
    private var operationPhase: BrewOperationPhase = .idle
    /// Keeps the spinner up after the install finishes until the installed badge resolves (bridges the
    /// gap before ``installedRepository`` re-reads). See ``DiscoverInstallBusyPresentation``.
    private var awaitingInstallResolution = false

    init(
        discoveryPackage: DiscoveryBrewPackage,
        installedRepository: any InstalledPackageStatusReading,
        brewCommandCenter: any BrewCommandCenter,
        showsInstallMetrics: Bool = true,
    ) {
        self.discoveryPackage = discoveryPackage
        self.installedRepository = installedRepository
        self.brewCommandCenter = brewCommandCenter
        self.showsInstallMetrics = showsInstallMetrics
    }

    var id: BrewPackage.ID {
        discoveryPackage.id
    }

    var name: String {
        discoveryPackage.displayName
    }

    var packageKind: HomebrewPackageKind {
        discoveryPackage.kind
    }

    var packageKindChrome: PackageKindChrome {
        discoveryPackage.kind.chrome
    }

    var descriptionText: String {
        discoveryPackage.description
    }

    var hasDescription: Bool {
        !descriptionText.isEmpty
    }

    var thirtyDayInstallCount: Int {
        discoveryPackage.thirtyDayInstallCount
    }

    func installs30DayLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        thirtyDayInstallCount.formatted(.number.locale(localization.locale))
    }

    var stableVersionLabel: String {
        discoveryPackage.latestVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var installedPackage: InstalledBrewPackage? {
        installedRepository.info(for: id)
    }

    var installedVersionLabel: String? {
        guard let pkg = installedPackage,
              let raw = pkg.linkedKeg ?? pkg.installedVersions.first
        else {
            return nil
        }
        return InstalledBrewVersionFormatting.displayVersionLabel(trimmedRaw: raw)
    }

    func installedStatusLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String? {
        guard installedRepository.isInstalled(id) else {
            return nil
        }
        return localization.string("Installed")
    }

    /// True while an install for this package is in flight (and bridging until the installed badge appears).
    var showsInstallBusy: Bool {
        DiscoverInstallBusyPresentation.showsInstallBusy(
            phase: operationPhase,
            awaitingResolution: awaitingInstallResolution,
            isInstalled: installedRepository.isInstalled(id),
        )
    }

    func rowAccessibilityLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        var summary = accessibilityLabel(localization: localization)
        if showsInstallBusy {
            let installing = localization.string("Installing")
            summary += ", \(installing)"
        }
        return summary
    }

    private func accessibilityLabel(localization: AppLocalization = AppLocalization(language: "en")) -> String {
        var parts = [name, packageKindChrome.badgeLabel]
        if showsInstallMetrics {
            parts.append(localization.string("\(installs30DayLabel(localization: localization)) installs in 30 days"))
        }
        if let installedStatusLabel = installedStatusLabel(localization: localization) {
            parts.append(installedStatusLabel)
        }
        return parts.joined(separator: ", ")
    }

    /// Run while the row is on screen to track install progress (`InstalledListRowViewModel` pattern).
    func observeRowUpdates() async {
        let operationID = BrewOperationID(kind: packageKind, name: discoveryPackage.name)
        let stream = await brewCommandCenter.phaseChanges(for: operationID)
        for await phase in stream {
            let wasRunningInstall = operationPhase.isRunningInstall
            operationPhase = phase
            if phase.isRunningInstall {
                awaitingInstallResolution = true
            } else if case .idle = phase, wasRunningInstall {
                awaitingInstallResolution = true
            } else if case .failed = phase {
                awaitingInstallResolution = false
            }
        }
    }

    func update(discoveryPackage newDiscoveryPackage: DiscoveryBrewPackage) {
        guard newDiscoveryPackage != discoveryPackage else {
            return
        }
        discoveryPackage = newDiscoveryPackage
        operationPhase = .idle
        awaitingInstallResolution = false
    }
}
