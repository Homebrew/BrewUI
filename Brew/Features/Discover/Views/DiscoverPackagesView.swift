import SwiftUI

/// Middle column of the main window: Discover filter chrome and package list.
struct DiscoverPackagesView: View {
    @Bindable var viewModel: DiscoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            switch viewModel.state {
            case .loading:
                loadingView
            case let .error(message):
                errorView(message)
            case .loaded:
                loadedList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.brewSurface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Discover")
                    .font(.brewTitle1)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(packageCountSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Picker("Filter", selection: $viewModel.selectedSegment) {
                Text("All").tag(DiscoverFilterSegment.all)
                Text("Formula").tag(DiscoverFilterSegment.formula)
                Text("Cask").tag(DiscoverFilterSegment.cask)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Package type filter")
        }
        .padding(BrewSpacing.lg)
    }

    private var packageCountSubtitle: String {
        switch viewModel.state {
        case .loaded:
            let count = viewModel.visibleRows.count
            return "\(count) package\(count == 1 ? "" : "s")"
        case .loading:
            return "Loading packages…"
        case .error:
            return "Could not load packages"
        }
    }

    private var loadedList: some View {
        List(selection: selectionBinding) {
            if viewModel.selectedSegment != .cask, !formulaRows.isEmpty {
                Section("Formulae") {
                    ForEach(formulaRows, id: \.id) { row in
                        DiscoverListRowView(viewModel: row)
                            .tag(row.id)
                            .listRowBackground(
                                viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear,
                            )
                    }
                }
            }

            if viewModel.selectedSegment != .formula, !caskRows.isEmpty {
                Section("Casks") {
                    ForEach(caskRows, id: \.id) { row in
                        DiscoverListRowView(viewModel: row)
                            .tag(row.id)
                            .listRowBackground(
                                viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear,
                            )
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Discover packages")
    }

    private var selectionBinding: Binding<BrewPackage.ID?> {
        Binding(
            get: { viewModel.selectedPackageID },
            set: { viewModel.setSelection($0) },
        )
    }

    private var formulaRows: [DiscoverListRowViewModel] {
        viewModel.visibleRows.filter { $0.packageKind == .formula }
    }

    private var caskRows: [DiscoverListRowViewModel] {
        viewModel.visibleRows.filter { $0.packageKind == .cask }
    }

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            ProgressView()
                .controlSize(.small)
            Text("Loading Discover packages…")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.bottom, BrewSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.brewCallout)
            .foregroundStyle(Color.brewStatusError)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.lg)
    }
}
