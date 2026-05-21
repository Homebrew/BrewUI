import SwiftUI

/// Middle column of the main window: Discover package list.
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
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Discover")
                .font(.brewTitle1)
                .foregroundStyle(Color.brewTextPrimary)
            Text(packageCountSubtitle)
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
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
            if !formulaRows.isEmpty {
                Section("Formulae") {
                    ForEach(formulaRows, id: \.id) { row in
                        listRow(row)
                    }
                }
            }

            if !caskRows.isEmpty {
                Section("Casks") {
                    ForEach(caskRows, id: \.id) { row in
                        listRow(row)
                    }
                }
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Discover packages")
    }

    private func listRow(_ row: DiscoverListRowViewModel) -> some View {
        DiscoverListRowView(viewModel: row)
            .tag(row.id)
            .listRowBackground(
                viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear,
            )
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
