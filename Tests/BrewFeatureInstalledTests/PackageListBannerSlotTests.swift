//
//  PackageListBannerSlotTests.swift
//  BrewFeatureInstalledTests
//

import AppKit
import BrewAppEnvironment
import BrewCore
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI
import Testing

/// Measured rather than asserted structurally: a slot that is read but never placed still compiles.
@MainActor
struct PackageListBannerSlotTests {
    private static let probeHeight: CGFloat = 120

    private static let columnWidth: CGFloat = 400

    private func height(_ view: some View) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(width: Self.columnWidth))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }

    /// A view of known height, so the delta is the slot's contribution and nothing else.
    private var probe: some View {
        Color.clear.frame(height: Self.probeHeight)
    }

    private func makeUpgradesViewModel() -> UpgradesViewModel {
        UpgradesViewModel(
            repository: StubInstalledPackagesRepository(
                packages: [.fixture(name: "ripgrep", kind: .formula, outdated: true)],
            ),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
    }

    @Test func `the Upgrades list makes room for the banner slot`() {
        let viewModel = makeUpgradesViewModel()
        let empty = height(FocusHost { UpgradesPackagesView(viewModel: viewModel, focus: $0) })
        let filled = height(
            FocusHost { UpgradesPackagesView(viewModel: viewModel, focus: $0) }
                .environment(\.packageListBanner, PackageListBanner { probe }),
        )

        #expect(filled - empty == Self.probeHeight)
    }

    @Test func `the Installed list makes room for the banner slot`() async {
        let viewModel = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "ripgrep", kind: .formula)],
        )
        let empty = height(FocusHost { InstalledPackagesView(viewModel: viewModel, focus: $0) })
        let filled = height(
            FocusHost { InstalledPackagesView(viewModel: viewModel, focus: $0) }
                .environment(\.packageListBanner, PackageListBanner { probe }),
        )

        #expect(filled - empty == Self.probeHeight)
    }

    /// Nothing is injected in previews, tests, or any tab the shell does not fill the slot for.
    @Test func `an unfilled slot costs the list nothing`() {
        let viewModel = makeUpgradesViewModel()
        let unfilled = height(FocusHost { UpgradesPackagesView(viewModel: viewModel, focus: $0) })
        let explicitlyEmpty = height(
            FocusHost { UpgradesPackagesView(viewModel: viewModel, focus: $0) }
                .environment(\.packageListBanner, PackageListBanner { EmptyView() }),
        )

        #expect(unfilled == explicitlyEmpty)
    }
}

/// The list views take a `@FocusState.Binding`, which only a view can vend.
private struct FocusHost<Content: View>: View {
    @FocusState private var focus: SearchFocusTarget?
    @ViewBuilder let content: (FocusState<SearchFocusTarget?>.Binding) -> Content

    var body: some View {
        content($focus)
    }
}
