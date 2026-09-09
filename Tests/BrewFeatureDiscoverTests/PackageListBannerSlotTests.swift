//
//  PackageListBannerSlotTests.swift
//  BrewFeatureDiscoverTests
//

import AppKit
import BrewAppEnvironment
import BrewCore
@testable import BrewFeatureDiscover
import BrewRepositoryInterfaces
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

    private func makeViewModel() -> DiscoverViewModel {
        DiscoverViewModel(
            discoverPackagesRepository: StubDiscoverPackagesRepository(state: .loaded([])),
            catalogueRepository: StubCatalogueRepository(formulaCatalogue: [], caskCatalogue: []),
            installedRepository: StubInstalledPackagesRepository(packages: []),
        )
    }

    @Test func `the Discover list makes room for the banner slot`() {
        let viewModel = makeViewModel()
        let empty = height(DiscoverPackagesView(viewModel: viewModel))
        let filled = height(
            DiscoverPackagesView(viewModel: viewModel)
                .environment(\.packageListBanner, PackageListBanner { probe }),
        )

        #expect(filled - empty == Self.probeHeight)
    }

    /// Nothing is injected in previews, tests, or any tab the shell does not fill the slot for.
    @Test func `an unfilled slot costs the list nothing`() {
        let viewModel = makeViewModel()
        let unfilled = height(DiscoverPackagesView(viewModel: viewModel))
        let explicitlyEmpty = height(
            DiscoverPackagesView(viewModel: viewModel)
                .environment(\.packageListBanner, PackageListBanner { EmptyView() }),
        )

        #expect(unfilled == explicitlyEmpty)
    }
}
