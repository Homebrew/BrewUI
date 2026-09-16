//
//  BrewfileExportSheet.swift
//  BrewFeatureInstalled
//

import BrewAccessibilityID
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Confirmation, progress, and result sheet for `brew bundle dump`. Passive: it renders
/// ``BrewfileExportViewModel`` state and forwards intents, including the save-panel and Finder bridges.
struct BrewfileExportSheet: View {
    @Bindable var viewModel: BrewfileExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.lg) {
            Text(BrewfileExportItem.sheetTitle)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(BrewfileExportItem.explainer)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            destinationSection
            commandSection
            statusSection

            Spacer(minLength: 0)
            footer
        }
        .padding(BrewSpacing.xl)
        .frame(width: 540, minHeight: 420)
        .accessibilityElement(children: .contain)
        .axid(.brewfileExportSheet)
        .interactiveDismissDisabled(viewModel.isRunning)
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Button(BrewfileExportItem.chooseLocationButtonTitle) {
                chooseLocation()
            }
            .disabled(!viewModel.canChooseLocation)
            .axid(.brewfileExportChooseLocationButton)

            if let item = viewModel.currentItem {
                Text(item.destinationPath)
                    .font(.brewCode)
                    .foregroundStyle(Color.brewTextPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var commandSection: some View {
        if let item = viewModel.currentItem {
            CommandBlockView(command: item.displayCommand, summaryText: item.commandSummary)
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch viewModel.presentation {
        case .exporting:
            HStack(spacing: BrewSpacing.sm) {
                ProgressView()
                    .controlSize(.small)
                Text(BrewfileExportItem.progressTitle)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .accessibilityElement(children: .combine)
        case let .exported(item):
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                Label(item.successTitle, systemImage: "checkmark.circle.fill")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewStatusSuccess)
                Text(item.successMessage)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
                Button(item.showInFinderButtonTitle) {
                    BrewfileSavePanel.revealInFinder(item.destinationURL)
                }
                .disabled(!viewModel.canRevealInFinder)
            }
        case let .failed(_, message):
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewStatusError)
                .textSelection(.enabled)
        case .awaitingDestination, .ready:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(viewModel.dismissButtonTitle, role: .cancel) {
                viewModel.requestDismiss()
            }
            .disabled(!viewModel.canDismiss)
            Button(BrewfileExportItem.exportButtonTitle) {
                viewModel.export()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canSubmit)
            .axid(.brewfileExportSubmitButton)
        }
    }

    private func chooseLocation() {
        guard viewModel.canChooseLocation else {
            return
        }
        guard let url = BrewfileSavePanel.chooseDestination() else {
            return
        }
        viewModel.acceptDestination(url)
    }
}

#if DEBUG
    private struct BrewfileExportSheetPreviewHost: View {
        @State private var viewModel = BrewfileExportViewModel(
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
        let destination: URL?

        var body: some View {
            BrewfileExportSheet(viewModel: viewModel)
                .onAppear {
                    viewModel.openSheet()
                    if let destination {
                        viewModel.acceptDestination(destination)
                    }
                }
        }
    }

    #Preview("Awaiting destination") {
        BrewfileExportSheetPreviewHost(destination: nil)
    }

    #Preview("Ready") {
        BrewfileExportSheetPreviewHost(
            destination: URL(filePath: "/Users/example/Downloads/Brewfile"),
        )
    }
#endif
