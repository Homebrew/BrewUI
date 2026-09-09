//
//  UpgradesChromeBudgetTests.swift
//  BrewFeatureInstalledTests
//

import AppKit
import BrewCore
@testable import BrewFeatureInstalled
@testable import BrewFeatureSelfUpgrade
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI
import Testing

/// Upgrades is what ``BrewLayout/mainPaneMinHeight`` is sized for. Measured against the real views rather
/// than an arithmetic budget, and against the shell's banner too, since its height comes off this list.
@MainActor
struct UpgradesChromeBudgetTests {
    /// Private inside `UpgradesPackagesView`, so this one stays a measured constant.
    private static let scopePickerAndDivider: CGFloat = 49

    /// A width in the middle of the list column's range. The chrome wraps nothing, so it does not vary.
    private static let columnWidth: CGFloat = 400

    private func height(_ view: some View) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(width: Self.columnWidth))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    private func makeUpgradesViewModel() -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(
                packages: (0 ..< 13).map { .fixture(name: "pkg\($0)", kind: .formula, outdated: true) },
            ),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }

    private var bannerHeight: CGFloat {
        let coordinator = SelfUpgradeCoordinator(
            statusProvider: StubSelfUpgradeStatusProvider(
                selfUpgradeStatus: SelfUpgradeStatus(
                    runningVersion: "0.2.3",
                    latestVersion: "99.0.0",
                    homepageURL: nil,
                    isUpgradeAvailable: true,
                ),
            ),
            preferences: StubSelfUpgradePreferences(),
            handoff: RecordingSelfUpgradeHandoff(),
        )
        // The padding `SelfUpgradeBanner` applies around the content, which is part of what the list loses.
        return height(
            SelfUpgradeBannerContent(coordinator: coordinator)
                .padding(.horizontal, BrewSpacing.lg)
                .padding(.top, BrewSpacing.lg),
        )
    }

    @Test func `the main pane's floor clears the Upgrades chrome with two rows to spare`() {
        let chrome = bannerHeight
            + height(UpgradesHeaderView(viewModel: makeUpgradesViewModel()))
            + Self.scopePickerAndDivider
        let row = height(
            InstalledListRowView(
                package: .fixture(name: "cmake", kind: .formula, outdated: true),
                brewCommandCenter: StubBrewCommandCenter(),
            ),
        )

        #expect(BrewLayout.mainPaneMinHeight >= chrome + 2 * row)
    }

    /// Bounded separately: the banner is the part that grew when Upgrade and Later moved onto it.
    @Test func `the self-upgrade banner stays within two lines of chrome`() {
        #expect(bannerHeight <= 130)
    }
}
