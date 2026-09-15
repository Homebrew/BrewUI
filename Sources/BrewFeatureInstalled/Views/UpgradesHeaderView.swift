//
//  UpgradesHeaderView.swift
//  BrewFeatureInstalled
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Top of the Upgrades tab: title, subtitle, the bulk `brew upgrade` command, and the action row.
struct UpgradesHeaderView: View {
    let viewModel: UpgradesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Available upgrades", bundle: #bundle, comment: "Upgrades tab heading")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.outdatedSubtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityHeading(.h1)

            if viewModel.state.isLoaded {
                CommandBlockView(
                    command: viewModel.bulkUpgradeDisplayCommand,
                    summaryText: viewModel.bulkUpgradeSummary,
                )

                actionRow
            }
        }
        .padding(BrewSpacing.lg)
    }

    private var actionRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            if viewModel.outdatedCount > 0 {
                upgradeAllButton
            } else {
                nothingToUpgradeIndicator
            }
            Spacer(minLength: 0)
            refreshButton
        }
        .frame(height: BrewLayout.headerActionHeight)
    }

    private var upgradeAllButton: some View {
        Button {
            viewModel.upgradeAll()
        } label: {
            Text("Upgrade All (\(viewModel.outdatedCount))", bundle: #bundle, comment: "Upgrades tab button; %lld is the outdated count")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .keyboardShortcut("u", modifiers: [.command, .shift])
        .disabled(viewModel.isUpgradingAny)
        .accessibilityLabel(String(
            localized: "Upgrade all \(viewModel.outdatedCount) packages",
            bundle: #bundle,
            comment: "VoiceOver: upgrade-all button; %lld is the outdated count",
        ))
    }

    /// ⌘R is the window-wide refresh (``RefreshCommands``); this button is the upgrades-only one.
    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            // The label stays laid out while hidden, so swapping in the spinner cannot resize the button.
            Label(String(localized: "Refresh", bundle: #bundle, comment: "Upgrades tab: re-check for upgrades button"), systemImage: "arrow.clockwise")
                .opacity(viewModel.isRefreshing ? 0 : 1)
                .overlay {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
        }
        .controlSize(.regular)
        .disabled(viewModel.isRefreshing)
        .accessibilityLabel(String(localized: "Check for upgrades again", bundle: #bundle, comment: "VoiceOver: upgrades refresh button"))
        .axid(.upgradesRefreshButton)
    }

    /// A green tick claims nothing needs upgrading; a failed check has no such claim to make.
    private var nothingToUpgradeIndicator: some View {
        HStack {
            statusGlyph
                .accessibilityHidden(true)
            Text(viewModel.emptyUpgradeActionTitle)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .font(.brewBody)
    }

    @ViewBuilder
    private var statusGlyph: some View {
        if viewModel.showsUpgradeCheckFailure {
            Image(systemName: "exclamationmark.triangle.fill")
                .brewWarningGlyphStyle()
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.brewStatusSuccess)
        }
    }
}
