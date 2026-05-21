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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Discover")
                .font(.brewTitle1)
                .foregroundStyle(Color.brewTextPrimary)
            headerSubtitle
        }
        .padding(BrewSpacing.lg)
    }

    @ViewBuilder
    private var headerSubtitle: some View {
        switch viewModel.state {
        case .loaded:
            HStack(spacing: BrewSpacing.xs) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewBrandPrimary)
                Text("Top 10 formulae · Top 10 casks")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
        case .loading:
            Text("Loading packages…")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
        case .error:
            Text("Could not load packages")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewStatusError)
        }
    }

    private var loadedList: some View {
        ScrollViewReader { proxy in
            List {
                if !formulaRows.isEmpty {
                    Section("Formulae") {
                        ForEach(formulaRows, id: \.id) { row in
                            listRow(row)
                                .id(row.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.setSelection(row.id)
                                }
                                .listRowBackground(
                                    viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear,
                                )
                        }
                    }
                }

                if !caskRows.isEmpty {
                    Section("Casks") {
                        ForEach(caskRows, id: \.id) { row in
                            listRow(row)
                                .id(row.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.setSelection(row.id)
                                }
                                .listRowBackground(
                                    viewModel.selectedPackageID == row.id ? Color.brewBrandTint : Color.clear,
                                )
                        }
                    }
                }
            }
            .listStyle(.plain)
            .accessibilityLabel("Discover packages")
            .onAppear {
                scrollToSelection(viewModel.selectedPackageID, with: proxy)
            }
            .onChange(of: viewModel.selectedPackageID) { _, selectedID in
                scrollToSelection(selectedID, with: proxy)
            }
            .onChange(of: viewModel.visibleRows.map(\.id)) { _, _ in
                scrollToSelection(viewModel.selectedPackageID, with: proxy)
            }
            .onExitCommand {
                viewModel.setSelection(nil)
            }
        }
    }

    private func listRow(_ row: DiscoverListRowViewModel) -> some View {
        DiscoverListRowView(viewModel: row)
    }

    private func scrollToSelection(
        _ selectedID: BrewPackage.ID?,
        with proxy: ScrollViewProxy,
    ) {
        guard let selectedID, viewModel.visibleRows.contains(where: { $0.id == selectedID }) else {
            return
        }
        withAnimation(.brewFast) {
            proxy.scrollTo(selectedID, anchor: .center)
        }
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
