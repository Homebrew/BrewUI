//
//  UpgradesHeaderView.swift
//  BrewFeatureInstalled
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// 升级页先呈现筛选范围和操作，再展示对应的终端命令。
struct UpgradesHeaderView: View {
    let viewModel: UpgradesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaneHeader {
                Text(viewModel.outdatedSubtitle)
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
            } actions: {
                if viewModel.state.isLoaded {
                    HStack(spacing: BrewSpacing.sm) {
                        if viewModel.outdatedCount > 0 {
                            upgradeAllButton
                        }
                        refreshButton
                    }
                }
            }
            .accessibilityLabel(Text("Available upgrades", bundle: #bundle, comment: "Upgrades tab heading"))
            .accessibilityHeading(.h1)

            if viewModel.outdatedCount > 0 || (
                viewModel.totalOutdatedCount == 0
                    && viewModel.state.isLoaded
                    && !viewModel.showsUpgradeCheckFailure
            ) {
                CommandBlockView(
                    command: viewModel.bulkUpgradeDisplayCommand,
                    summaryText: viewModel.bulkUpgradeSummary,
                )
                .padding(.horizontal, BrewLayout.paneContentInset)
                .padding(.bottom, viewModel.totalOutdatedCount > 0 ? BrewSpacing.xl : BrewSpacing.md)
            }
        }
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
            Label {
                Text("Refresh", bundle: #bundle, comment: "Upgrades tab: re-check for upgrades button")
            } icon: {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .controlSize(.regular)
        .disabled(viewModel.isRefreshing)
        .accessibilityLabel(String(localized: "Check for upgrades again", bundle: #bundle, comment: "VoiceOver: upgrades refresh button"))
        .axid(.upgradesRefreshButton)
    }
}
