//
//  UpgradesHeaderView.swift
//  BrewFeatureInstalled
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Top of the Upgrades tab: title, inventory subtitle, the `brew upgrade` command that "Upgrade All"
/// would run, and the header action row.
struct UpgradesHeaderView: View {
    let viewModel: UpgradesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Available upgrades")
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

    /// Upgrade All is conditional on there being something to upgrade; Refresh is not — re-checking is
    /// exactly what a user wants when the list looks wrong or empty.
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
            Text("Upgrade All (\(viewModel.outdatedCount))")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .keyboardShortcut("u", modifiers: [.command, .shift])
        .disabled(viewModel.isUpgradingAny)
        .accessibilityLabel("Upgrade all \(viewModel.outdatedCount) packages")
    }

    private var refreshButton: some View {
        Button {
            Task { await viewModel.refresh() }
        } label: {
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .controlSize(.regular)
        .keyboardShortcut("r", modifiers: .command)
        .disabled(viewModel.isRefreshing)
        .accessibilityLabel("Check for upgrades again")
        .axid(.upgradesRefreshButton)
    }

    /// A green tick is a claim that nothing needs upgrading. When the check itself failed the app has
    /// no such claim to make, so the same slot warns instead.
    private var nothingToUpgradeIndicator: some View {
        let didCheckFail = viewModel.showsUpgradeCheckFailure
        return HStack {
            Image(systemName: didCheckFail ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(didCheckFail ? Color.brewStatusWarning : Color.brewStatusSuccess)
                .accessibilityHidden(true)
            Text(viewModel.emptyUpgradeActionTitle)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .font(.brewBody)
    }
}
