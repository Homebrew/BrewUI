//
//  CleanupView.swift
//  BrewFeatureCleanup
//

import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Single scrolling pane previewing `brew cleanup`: what a run would remove, the command it would run and
/// a button that runs it. Every arrival previews again, since installs and upgrades elsewhere change the list.
struct CleanupView: View {
    @State private var viewModel: CleanupViewModel

    init(
        repository: any CleanupRepository,
        commandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        _viewModel = State(initialValue: CleanupViewModel(
            repository: repository,
            commandCenter: commandCenter,
            commandFactory: commandFactory,
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .axid(.cleanupScreen)
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            String(localized: "Clean up Homebrew?", bundle: #bundle, comment: "Cleanup confirmation title"),
            isPresented: $viewModel.showsCleanupConfirmation,
        ) {
            Button(String(localized: "Clean Up", bundle: #bundle, comment: "Cleanup: run brew cleanup"), role: .destructive) {
                viewModel.cleanUp()
            }
            Button(String(localized: "Cancel", bundle: #bundle, comment: "Cleanup confirmation: keep everything"), role: .cancel) {}
        } message: {
            Text(verbatim: viewModel.confirmationMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Cleanup", bundle: #bundle, comment: "Cleanup tab heading")
                        .font(.brewTitle2)
                        .foregroundStyle(Color.brewTextPrimary)
                    Text(viewModel.subtitle)
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityHeading(.h1)
                .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.showsHeaderControls {
                    headerControls
                }
            }
            if viewModel.showsHeaderControls {
                pruneAllToggle
            }
            if let message = viewModel.refreshFailureMessage {
                CleanupErrorText(message: message)
            }
        }
        .padding(BrewSpacing.lg)
        .brewPaneContentWidth()
    }

    private var headerControls: some View {
        HStack(spacing: BrewSpacing.sm) {
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(String(localized: "Checking again", bundle: #bundle, comment: "VoiceOver: Cleanup re-check spinner"))
            }
            Button(String(localized: "Check Again", bundle: #bundle, comment: "Cleanup header: run the dry run again")) {
                Task { await viewModel.load() }
            }
            .controlSize(.small)
            .disabled(viewModel.isRefreshing || viewModel.isCleaningUp)
            .axid(.cleanupCheckAgainButton)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var pruneAllToggle: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            Toggle(isOn: Binding(
                get: { viewModel.pruneAll },
                set: { pruneAll in Task { await viewModel.setPruneAll(pruneAll) } },
            )) {
                Text("Remove all cached downloads", bundle: #bundle, comment: "Cleanup option: add --prune=all")
                    .font(.brewCallout)
            }
            .toggleStyle(.checkbox)
            .disabled(viewModel.isRefreshing || viewModel.isCleaningUp)
            .axid(.cleanupPruneAllToggle)
            Text(
                "Adds --prune=all. Without it, Homebrew keeps recent downloads so reinstalling is quicker.",
                bundle: #bundle,
                comment: "Cleanup option caption explaining --prune=all",
            )
            .font(.brewCaption)
            .foregroundStyle(Color.brewTextSecondary)
            .padding(.leading, BrewSpacing.lg + BrewSpacing.xs)
        }
    }

    private var content: some View {
        AsyncContentView(
            state: viewModel.state,
            onRetry: { Task { await viewModel.load() } },
            loaded: { report in
                if report.isEmpty {
                    cleanState
                } else {
                    removableList(report: report)
                }
            },
        )
    }

    private var cleanState: some View {
        VStack(spacing: BrewSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.brewStatusSuccess)
                .accessibilityHidden(true)
            Text("Nothing to clean up", bundle: #bundle, comment: "Cleanup empty state title")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text("brew cleanup found no old versions, stale downloads or unneeded dependencies.", bundle: #bundle, comment: "Cleanup empty state body")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.xl)
        .accessibilityElement(children: .combine)
        .axid(.cleanupEmptyState)
    }

    private func removableList(report: CleanupReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                summaryCard(report: report)
                if !report.unneededFormulae.isEmpty {
                    CleanupSectionCard(
                        title: viewModel.unneededFormulaeTitle(for: report),
                        caption: LocalizedStringResource(
                            "Installed only as dependencies of formulae that no longer need them.",
                            bundle: #bundle,
                            comment: "Cleanup section caption for brew autoremove",
                        ),
                    ) {
                        ForEach(report.unneededFormulae, id: \.self) { name in
                            CleanupRow(primary: name, detail: nil)
                                .axid(.cleanupRow(name: name))
                        }
                    }
                }
                if !report.removals.isEmpty {
                    CleanupSectionCard(title: viewModel.removalsTitle(for: report), caption: nil) {
                        ForEach(viewModel.removalItems(for: report)) { item in
                            CleanupRow(primary: item.path, detail: item.detail)
                                .axid(.cleanupRow(name: item.path))
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom], BrewSpacing.lg)
            .brewPaneContentWidth()
        }
    }

    private func summaryCard(report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Text(verbatim: viewModel.headline(for: report))
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            CommandBlockView(
                command: viewModel.cleanupDisplayCommand,
                summaryText: LocalizedStringResource(
                    "Removes everything listed below",
                    bundle: #bundle,
                    comment: "Command block summary above brew cleanup",
                ),
            )
            HStack(spacing: BrewSpacing.sm) {
                Button {
                    viewModel.requestCleanup()
                } label: {
                    if viewModel.isCleaningUp {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Clean Up", bundle: #bundle, comment: "Cleanup: run brew cleanup")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canCleanUp)
                .accessibilityLabel(String(localized: "Clean Up", bundle: #bundle, comment: "Cleanup: run brew cleanup"))
                .axid(.cleanupButton)
                Spacer(minLength: 0)
            }
            if let message = viewModel.cleanupErrorMessage {
                CleanupErrorText(message: message)
            }
        }
        .cleanupCard()
    }
}

/// A titled card of rows, matching the Configuration tab's cards.
private struct CleanupSectionCard<Rows: View>: View {
    let title: String
    let caption: LocalizedStringResource?
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(verbatim: title)
                    .font(.brewSubheadline.weight(.semibold))
                    .foregroundStyle(Color.brewTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let caption {
                    Text(caption)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
            rows()
        }
        .cleanupCard()
    }
}

/// Homebrew's error text, selectable so it can be copied into a report.
private struct CleanupErrorText: View {
    let message: String

    var body: some View {
        Text(verbatim: message)
            .font(.brewCallout)
            .foregroundStyle(Color.brewStatusError)
            .textSelection(.enabled)
    }
}

private extension View {
    /// The Configuration tab's card chrome.
    func cleanupCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.lg)
            .background(Color.brewSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .stroke(Color.brewBorderDefault, lineWidth: 1),
            )
    }
}

/// A monospaced, selectable path or formula name with Homebrew's size beside it.
private struct CleanupRow: View {
    let primary: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.md) {
            Text(verbatim: primary)
                .font(.brewCode)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(verbatim: detail)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview("Cleanup - removable") {
        CleanupView(
            repository: PreviewSupport.makeCleanupRepository(),
            commandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        .frame(width: 720, height: 600)
    }

    #Preview("Cleanup - clean") {
        CleanupView(
            repository: PreviewSupport.makeCleanupRepository(report: PreviewSupport.emptyCleanupReport),
            commandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        .frame(width: 720, height: 600)
    }
#endif
