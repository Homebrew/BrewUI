//
//  SelfUpgradeBannerSlotTests.swift
//  BrewFeatureInstalledTests
//

import AppKit
import BrewAppEnvironment
import BrewCore
@testable import BrewFeatureInstalled
@testable import BrewFeatureSelfUpgrade
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI
import Testing

/// The real banner in the real slot, composed the way `MainWindowView` composes it — including when the
/// status changes *after* the first render, which an erased view in an environment value could break.
@MainActor
struct SelfUpgradeBannerSlotTests {
    private static let noUpgrade = SelfUpgradeStatus.upToDate(runningVersion: "1.0.0")

    private static let upgradeAvailable = SelfUpgradeStatus(
        runningVersion: "1.0.0",
        latestVersion: "99.0.0",
        homepageURL: nil,
        isUpgradeAvailable: true,
    )

    @Test func `a coordinator reporting an upgrade puts the banner in the list`() {
        let viewModel = makeUpgradesViewModel()
        let quiet = makeCoordinator(StubSelfUpgradeStatusProvider(selfUpgradeStatus: Self.noUpgrade))
        let announcing = makeCoordinator(StubSelfUpgradeStatusProvider(selfUpgradeStatus: Self.upgradeAvailable))

        #expect(height(list(viewModel, coordinator: announcing)) > height(list(viewModel, coordinator: quiet)))
    }

    /// Hosted in a window and flipped mid-flight, because that is what the Debug menu does to a running app.
    @Test func `a status that becomes available mid-session brings the banner in`() {
        let provider = StubSelfUpgradeStatusProvider(selfUpgradeStatus: Self.noUpgrade)
        let coordinator = makeCoordinator(provider)
        let host = NSHostingView(rootView: list(makeUpgradesViewModel(), coordinator: coordinator))
        host.frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false,
        )
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        settle()
        let before = host.fittingSize.height

        provider.selfUpgradeStatus = Self.upgradeAvailable
        settle()
        host.layoutSubtreeIfNeeded()

        #expect(host.fittingSize.height > before)
    }

    /// SwiftUI applies the change on the next run-loop pass, so the measurement has to wait for it.
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    private func makeUpgradesViewModel() -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: []),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }

    private func makeCoordinator(_ provider: StubSelfUpgradeStatusProvider) -> SelfUpgradeCoordinator {
        SelfUpgradeCoordinator(
            statusProvider: provider,
            preferences: StubSelfUpgradePreferences(),
            handoff: RecordingSelfUpgradeHandoff(),
        )
    }

    private func list(_ viewModel: UpgradesViewModel, coordinator: SelfUpgradeCoordinator) -> some View {
        BannerSlotFocusHost { UpgradesPackagesView(viewModel: viewModel, focus: $0) }
            .environment(\.packageListBanner, PackageListBanner { SelfUpgradeBanner() })
            .environment(\.selfUpgradeCoordinator, coordinator)
            .environment(\.brewCommandCenter, StubBrewCommandCenter())
            .environment(\.mutatingCommandFactory, StubMutatingCommandFactory())
    }

    private func height(_ view: some View) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(width: 400))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }
}

private struct BannerSlotFocusHost<Content: View>: View {
    @FocusState private var focus: SearchFocusTarget?
    @ViewBuilder let content: (FocusState<SearchFocusTarget?>.Binding) -> Content

    var body: some View {
        content($focus)
    }
}
