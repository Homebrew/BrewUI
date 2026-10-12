import AppKit
import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
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
                .axid(.servicesScopePicker)
                Divider()
                AsyncContentView(
                    state: viewModel.state,
                    onRetry: { Task { await viewModel.refresh() } },
                    loaded: { content in
                        servicesContent(content)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    },
                )
            }
            .frame(minWidth: BrewLayout.installedListColumnMinWidth, idealWidth: BrewLayout.installedListColumnIdealWidth,
                   maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // HSplitView resets its divider when a pane's identity changes, so `.id` stays inside.
            VStack(alignment: .leading, spacing: 0) {
                if let service = viewModel.selectedService {
                    ScrollView {
                        ServiceDetailView(service: service)
                            .padding(BrewSpacing.xl)
                            .brewPaneContentWidth()
                    }
                    .id(service.id)
                } else {
                    ServiceDetailPlaceholder()
                }
            }
            .axid(.serviceDetail)
            .frame(minWidth: BrewLayout.inspectorWidth, idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                   maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .axid(.servicesScreen)
        .task { await viewModel.load() }
        // Services start and stop outside the app.
        .task {
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                await viewModel.refresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Services", bundle: #bundle, comment: "Services list heading")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                if let subtitle = viewModel.runningServiceSubtitle {
                    Text(subtitle).font(.brewSubheadline).foregroundStyle(Color.brewTextSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)
            CommandBlockView(
                command: "brew services info --all --json",
                summaryText: LocalizedStringResource("Shows services for the current user", bundle: #bundle, comment: "Services command: reads the current user inventory"),
            )
            HStack(spacing: BrewSpacing.sm) {
                Spacer(minLength: 0)
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label(String(localized: "Refresh", bundle: #bundle, comment: "Services: read the current service inventory"), systemImage: "arrow.clockwise")
                        .opacity(viewModel.isRefreshing ? 0 : 1)
                        .overlay {
                            if viewModel.isRefreshing { ProgressView().controlSize(.small) }
                        }
                }
                .controlSize(.regular)
                .disabled(viewModel.isRefreshing)
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
    private func servicesContent(_ content: ServicesContent) -> some View {
        if content.services.isEmpty {
            if content.isInventoryEmpty {
                emptyState(
                    title: LocalizedStringResource("No services", bundle: #bundle, comment: "Services: empty inventory title"),
                    detail: LocalizedStringResource("Services from installed formulae will appear here.", bundle: #bundle, comment: "Services: empty inventory explanation"),
                )
            } else {
                emptyState(
                    title: LocalizedStringResource("No matching services", bundle: #bundle, comment: "Services: filter-empty state title"),
                    detail: LocalizedStringResource(
                        "Choose All to see every service.", bundle: #bundle,
                        comment: "Services: filter-empty state hint; All is the status filter option",
                    ),
                )
            }
        } else {
            servicesList(content.services)
        }
    }

    private func emptyState(title: LocalizedStringResource, detail: LocalizedStringResource) -> some View {
        VStack(spacing: BrewSpacing.md) {
            Text(title)
                .font(.brewTitle2).foregroundStyle(Color.brewTextPrimary)
            Text(detail)
                .font(.brewCallout).foregroundStyle(Color.brewTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BrewSpacing.xl)
        .accessibilityElement(children: .combine)
        .axid(.servicesEmptyState)
    }

    private func servicesList(_ services: [BrewService]) -> some View {
        ScrollViewReader { proxy in
            List(services) { service in
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text(verbatim: service.name).font(.brewBodyEmphasized)
                    ServiceStatusView(service: service)
                }
                .padding(.vertical, BrewSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .listRowBackground(
                    RoundedRectangle(cornerRadius: BrewRadius.lg, style: .continuous)
                        .fill(viewModel.activeSelectedServiceID == service.id ? Color.brewBrandTint : Color.clear)
                        .padding(.horizontal, BrewSpacing.sm),
                )
                .onTapGesture { viewModel.selectedServiceID = service.id; listIsFocused = true }
                .id(service.id)
                .accessibilityElement(children: .combine)
                .axid(.serviceRow(name: service.name))
            }
            .listStyle(.inset)
            .accessibilityLabel(String(localized: "Services", bundle: #bundle, comment: "VoiceOver: the services list"))
            .axid(.servicesList)
            .focused($listIsFocused)
            .onChange(of: viewModel.activeSelectedServiceID) { _, id in
                if let id { withAnimation(.brewFast) { proxy.scrollTo(id, anchor: .center) } }
            }
            .onKeyPress(.upArrow) { viewModel.moveSelection(by: -1); return .handled }
            .onKeyPress(.downArrow) { viewModel.moveSelection(by: 1); return .handled }
            .onExitCommand { viewModel.clearSelection() }
        }
    }
}
