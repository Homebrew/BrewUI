//
//  SecurityColumns.swift
//  BrewFeatureSecurity
//

import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Dependency-composition boundary for the Security surface: reads app-level dependencies from the
/// environment and constructs the feature view model (`ARCHITECTURE.md` — root-view ownership).
public struct SecurityColumnsRoot: View {
    @Environment(\.securityAdvisoryRepository) private var securityAdvisoryRepository
    @Environment(\.navigateToInstalledPackage) private var navigateToInstalledPackage

    public init() {}

    public var body: some View {
        SecurityColumns(
            repository: securityAdvisoryRepository,
            showInInstalled: navigateToInstalledPackage,
        )
    }
}

/// Feature-owned content/detail columns for the Security surface, mirroring the Doctor split.
struct SecurityColumns: View {
    @State private var viewModel: SecurityViewModel
    private let showInInstalled: @MainActor (HomebrewPackageID) -> Void

    init(
        repository: any SecurityAdvisoryRepository,
        showInInstalled: @escaping @MainActor (HomebrewPackageID) -> Void,
    ) {
        _viewModel = State(initialValue: SecurityViewModel(repository: repository))
        self.showInInstalled = showInInstalled
    }

    var body: some View {
        HSplitView {
            SecurityView(viewModel: viewModel)
                .frame(
                    minWidth: BrewLayout.installedListColumnMinWidth,
                    idealWidth: BrewLayout.installedListColumnIdealWidth,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading,
                )

            Group {
                if let item = viewModel.selectedItem {
                    SecurityPackageDetailView(item: item, showInInstalled: showInInstalled)
                } else {
                    SecurityDetailPlaceholder()
                }
            }
            .frame(
                minWidth: BrewLayout.inspectorWidth,
                idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load(forceRefresh: false)
        }
    }
}

#if DEBUG
    #Preview("Security - findings") {
        SecurityColumns(
            repository: PreviewSupport.makeSecurityAdvisoryRepository(),
            showInInstalled: { _ in },
        )
        .frame(minWidth: 800, minHeight: 520)
    }
#endif
