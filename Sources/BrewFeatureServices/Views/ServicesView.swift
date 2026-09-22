import BrewAccessibilityID
import BrewAppEnvironment
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

public struct ServicesRoot: View {
    @Environment(\.servicesRepository) private var repository

    public init() {}

    public var body: some View {
        ServicesView(repository: repository)
    }
}

struct ServicesView: View {
    @State private var viewModel: ServicesViewModel
    @FocusState private var listIsFocused: Bool

    init(repository: any ServicesRepository) {
        _viewModel = State(initialValue: ServicesViewModel(repository: repository))
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Picker(String(localized: "Status", bundle: #bundle, comment: "Services: status filter label"), selection: $viewModel.scope) {
                    ForEach(ServiceScope.allCases, id: \.self) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, BrewSpacing.lg)
                .padding(.vertical, BrewSpacing.md)
                Divider()
                content
            }
            .frame(minWidth: BrewLayout.installedListColumnMinWidth, idealWidth: BrewLayout.installedListColumnIdealWidth,
                   maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Keep the split pane stable when the selection resets the inner scroll position.
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    if let service = viewModel.selectedService {
                        ServiceDetailView(service: service).padding(BrewSpacing.xl)
                    } else {
                        Text("Select a service to view details.", bundle: #bundle, comment: "Services: no row selected or selected service hidden by the filter")
                            .foregroundStyle(Color.brewTextSecondary)
                            .padding(BrewSpacing.xl)
                    }
                }
                .id(viewModel.selectedService?.id)
                .axid(.serviceDetail)
            }
            .frame(minWidth: BrewLayout.inspectorWidth, idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                   maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .axid(.servicesScreen)
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Text("Services", bundle: #bundle, comment: "Services list heading")
                .font(.brewTitle2)
                .accessibilityHeading(.h1)
            CommandBlockView(
                command: "brew services info --all --json",
                summaryText: LocalizedStringResource("Shows services for the current user", bundle: #bundle, comment: "Services command: reads the current user inventory"),
            )
            HStack(spacing: BrewSpacing.sm) {
                Spacer(minLength: 0)
                Button {
                    Task { await viewModel.load(forceRefresh: true) }
                } label: {
                    Label(String(localized: "Refresh", bundle: #bundle, comment: "Services: read the current service inventory"), systemImage: "arrow.clockwise")
                        .opacity(viewModel.isRefreshing ? 0 : 1)
                        .overlay {
                            if viewModel.isRefreshing { ProgressView().controlSize(.small) }
                        }
                }
                .controlSize(.regular)
                .disabled(viewModel.isRefreshing)
                .accessibilityLabel(String(localized: "Refresh", bundle: #bundle, comment: "Services: read the current service inventory"))
                .axid(.servicesRefreshButton)
            }
            .frame(height: BrewLayout.headerActionHeight)
            if let message = viewModel.refreshFailure {
                Text(message).foregroundStyle(Color.brewStatusError).textSelection(.enabled)
            }
        }
        .padding(BrewSpacing.lg)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView(String(localized: "Loading services…", bundle: #bundle, comment: "Services: initial loading indicator"))
                .padding(BrewSpacing.lg)
        case let .failed(message):
            Text(message).foregroundStyle(Color.brewStatusError).textSelection(.enabled)
                .padding(BrewSpacing.lg)
                .axid(.errorState)
        case .loaded:
            if viewModel.visibleServices.isEmpty {
                Text("No services in this view.", bundle: #bundle, comment: "Services: empty inventory or no services matching the status filter")
                    .foregroundStyle(Color.brewTextSecondary)
                    .padding(BrewSpacing.lg)
            } else {
                List(viewModel.visibleServices, selection: $viewModel.selectedServiceID) { service in
                    VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                        Text(verbatim: service.name).font(.brewBodyEmphasized)
                        ServiceStatusView(service: service)
                    }
                    .padding(.vertical, BrewSpacing.xs)
                    .tag(service.id)
                    .accessibilityElement(children: .combine)
                    .axid(.serviceRow(name: service.name))
                }
                .listStyle(.inset)
                .focused($listIsFocused)
                .onChange(of: viewModel.selectedServiceID) { _, _ in listIsFocused = true }
            }
        }
    }
}
