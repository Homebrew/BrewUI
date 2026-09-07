//
//  UpgradesChromeBudgetTests.swift
//  BrewFeatureInstalledTests
//

import AppKit
import BrewCore
@testable import BrewFeatureInstalled
@testable import BrewFeatureSelfUpdate
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI
import Testing

/// Upgrades has the tallest chrome of any list and none of it scrolls, so it is what
/// ``BrewLayout/mainPaneMinHeight`` is sized for. These measure the real views rather than trusting an
/// arithmetic budget: set the floor below the chrome and the list is handed negative space, which is
/// how it ended up clipped under the console.
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
        let coordinator = SelfUpdateCoordinator(
            statusProvider: StubSelfUpdateStatusProvider(
                selfUpdateStatus: SelfUpdateStatus(
                    runningVersion: "0.2.3",
                    latestVersion: "99.0.0",
                    homepageURL: nil,
                    isUpdateAvailable: true,
                ),
            ),
            preferences: StubSelfUpdatePreferences(),
            handoff: RecordingSelfUpdateHandoff(),
        )
        // The padding `SelfUpdateBanner` applies around the content, which is part of what the list loses.
        return height(
            SelfUpdateBannerContent(coordinator: coordinator)
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

    /// The banner is the part that grew when Upgrade and Later moved onto it, so it gets its own bound —
    /// a third one would put the list below two rows at the minimum window size.
    @Test func `the self-update banner stays within two lines of chrome`() {
        #expect(bannerHeight <= 130)
    }
}
