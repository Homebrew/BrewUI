//
//  CleanupSheet.swift
//  BrewFeatureCleanup
//

import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Dependency-composition boundary for the Clean Up sheet: reads app-level dependencies from the
/// environment and hands them to the sheet, which owns the view model (`ARCHITECTURE.md` — root-view ownership).
public struct CleanupSheetRoot: View {
    @Environment(\.cleanupRepository) private var cleanupRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory

    public init() {}

    public var body: some View {
        CleanupSheet(
            repository: cleanupRepository,
            commandCenter: brewCommandCenter,
            commandFactory: mutatingCommandFactory,
        )
    }
}

/// Confirms `brew cleanup`: previews it with a dry run when it opens, lists what a run would remove and
/// runs it only when the user chooses Clean Up. Every opening previews again, since installs and upgrades
/// change the list.
struct CleanupSheet: View {
    @State private var viewModel: CleanupViewModel
    @Environment(\.dismiss) private var dismiss

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
        VStack(alignment: .leading, spacing: BrewSpacing.lg) {
            Text("Clean Up Homebrew", bundle: #bundle, comment: "Clean Up sheet title")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .accessibilityAddTraits(.isHeader)
            pruneAllToggle
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(BrewSpacing.xl)
        .frame(width: BrewLayout.listSheetWidth, height: BrewLayout.listSheetHeight)
        .accessibilityElement(children: .contain)
        .axid(.cleanupSheet)
        .task {
            await viewModel.load()
        }
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
            .disabled(viewModel.isPruneAllToggleDisabled)
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
                    VStack(spacing: BrewSpacing.md) {
                        cleanState
                        // A retained empty report may be re-checking or have failed to re-check.
                        if viewModel.isRefreshing {
                            refreshSpinner
                        }
                        refreshFailureNotice
                    }
                } else {
                    removablePreview(report: report)
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
        .accessibilityElement(children: .combine)
        .axid(.cleanupEmptyState)
    }

    private func removablePreview(report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            HStack(spacing: BrewSpacing.sm) {
                Text(verbatim: viewModel.headline(for: report))
                    .font(.brewTitle3)
                    .foregroundStyle(Color.brewTextPrimary)
                if viewModel.isRefreshing {
                    refreshSpinner
                }
            }
            // Outside the scroll region and short, so it is always visible however long the list grows.
            Text(
                "Old versions and cached downloads are deleted and cannot be restored.",
                bundle: #bundle,
                comment: "Clean Up sheet warning above the list of what will be removed",
            )
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            removalList(report: report)
            CommandBlockView(
                command: viewModel.cleanupDisplayCommand,
                summaryText: LocalizedStringResource(
                    "Removes everything listed above, plus unreferenced cached downloads",
                    bundle: #bundle,
                    comment: "Command block summary below the Clean Up list; the dry run does not list unreferenced downloads",
                ),
            )
            refreshFailureNotice
        }
    }

    private var refreshSpinner: some View {
        ProgressView()
            .controlSize(.small)
            .accessibilityLabel(String(localized: "Checking again", bundle: #bundle, comment: "VoiceOver: Clean Up re-check spinner"))
    }

    /// A failed re-check keeps the previous report on screen, so it needs its own retry.
    @ViewBuilder
    private var refreshFailureNotice: some View {
        if let message = viewModel.refreshFailureMessage {
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                Text(verbatim: message)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewStatusError)
                    .textSelection(.enabled)
                Button(String(localized: "Retry", bundle: #bundle, comment: "Clean Up: re-run the preview after a re-check failed")) {
                    Task { await viewModel.load() }
                }
                .disabled(viewModel.isRefreshing)
            }
        }
    }

    private func removalList(report: CleanupReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                if !report.unneededFormulae.isEmpty {
                    CleanupSection(
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
                    CleanupSection(title: viewModel.removalsTitle(for: report), caption: nil) {
                        ForEach(viewModel.removalItems(for: report)) { item in
                            CleanupRow(primary: item.path, detail: item.detail)
                                .axid(.cleanupRow(name: item.path))
                        }
                    }
                }
                // Inside the scroll region: the message names every unneeded formula, so it can outgrow the sheet.
                if let message = viewModel.uninstallMessage {
                    Text(verbatim: message)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !report.unreadLines.isEmpty {
                    CleanupUnreadOutput(lines: report.unreadLines)
                }
            }
            .padding(BrewSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private var footer: some View {
        HStack(spacing: BrewSpacing.sm) {
            Spacer(minLength: 0)
            if viewModel.showsDoneButton {
                Button(String(localized: "Done", bundle: #bundle, comment: "Clean Up sheet: close when there is nothing to remove")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .axid(.cleanupDoneButton)
            } else {
                Button(String(localized: "Cancel", bundle: #bundle, comment: "Clean Up sheet: close without removing anything"), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .axid(.cleanupCancelButton)
                // Destructive and never the default action, so Return cannot remove anything by accident.
                Button(String(localized: "Clean Up", bundle: #bundle, comment: "Cleanup: run brew cleanup"), role: .destructive) {
                    viewModel.cleanUp()
                    dismiss()
                }
                .disabled(!viewModel.canCleanUp)
                .axid(.cleanupButton)
            }
        }
    }
}

/// A titled group of rows inside the Clean Up list.
private struct CleanupSection<Rows: View>: View {
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
    }
}

/// Lines of the dry run the parser does not read, shown verbatim as a partial error so the list above
/// is never silently incomplete.
private struct CleanupUnreadOutput: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Label {
                Text(
                    "Homebrew also printed lines this list doesn't show, so it may be incomplete:",
                    bundle: #bundle,
                    comment: "Clean Up sheet partial error above dry-run lines the app could not read",
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .font(.brewCallout)
            .foregroundStyle(Color.brewStatusWarning)
            Text(verbatim: lines.joined(separator: "\n"))
                .font(.brewCode)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
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
    #Preview("Clean Up - removable") {
        CleanupSheet(
            repository: PreviewSupport.makeCleanupRepository(),
            commandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
    }

    #Preview("Clean Up - clean") {
        CleanupSheet(
            repository: PreviewSupport.makeCleanupRepository(report: PreviewSupport.emptyCleanupReport),
            commandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
    }
#endif
