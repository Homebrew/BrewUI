//
//  SelfUpgradeBanner.swift
//  BrewFeatureSelfUpgrade
//

import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Pins ``SelfUpgradeBannerContent`` above a package list, outside the filtered dataset, so it survives the
/// All/Formulae/Casks scopes and search. The app shell puts it in the lists' `\.packageListBanner` slot —
/// they render it without naming it — and it reads the coordinator itself, so nothing plumbs one through.
public struct SelfUpgradeBanner: View {
    @Environment(\.selfUpgradeCoordinator) private var coordinator

    public init() {}

    public var body: some View {
        if let coordinator, coordinator.isBannerVisible {
            SelfUpgradeBannerContent(coordinator: coordinator)
                .padding(.horizontal, BrewSpacing.lg)
                .padding(.top, BrewSpacing.lg)
        }
    }
}

/// There is no detail pane to open, so Upgrade and Later sit on the banner itself.
struct SelfUpgradeBannerContent: View {
    let coordinator: SelfUpgradeCoordinator

    private var presentation: SelfUpgradePresentation {
        SelfUpgradePresentation(status: coordinator.status)
    }

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            icon
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                summary
                actions
                    .padding(.top, BrewSpacing.sm)
                if let failureMessage = coordinator.failureMessage {
                    Text(failureMessage)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewStatusError)
                        .accessibilityLabel("Upgrade failed: \(failureMessage)")
                }
            }
        }
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.vertical, BrewSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrewRadius.lg, style: .continuous)
                .fill(Color.brewBrandTint),
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg, style: .continuous)
                .strokeBorder(Color.brewBorderBrand, lineWidth: 1),
        )
        .accessibilityElement(children: .contain)
        .axid(.selfUpgradeBanner)
    }

    private var icon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.brewTextOnBrand)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                    .fill(Color.brewBrandPrimary),
            )
            .accessibilityHidden(true)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            // Not brand amber: it is 2.4:1 on this tint and barely legible at caption size.
            Text(presentation.eyebrow.uppercased())
                .font(.brewCaption2.weight(.bold))
                .foregroundStyle(Color.brewTextPrimary)
            Text(presentation.bannerTitle)
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(Color.brewTextPrimary)
            Text(presentation.versionSummary)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.bannerTitle), \(presentation.versionSummary)")
    }

    private var actions: some View {
        HStack(spacing: BrewSpacing.sm) {
            Button {
                Task { await coordinator.beginUpgrade() }
            } label: {
                if coordinator.isUpgradeInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(presentation.upgradeActionTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!coordinator.isUpgradeActionEnabled)
            // The command is what the helper actually runs, so it belongs somewhere the user can find it;
            // the banner has no room to spell it out.
            .help(SelfUpgradeIdentity.displayCommand)
            .accessibilityLabel(presentation.upgradeActionTitle)
            .axid(.selfUpgradeUpgradeButton)

            Button("Later") {
                coordinator.dismiss()
            }
            .disabled(!coordinator.isUpgradeActionEnabled)
            .axid(.selfUpgradeLaterButton)
        }
    }
}

#if DEBUG

    @MainActor
    private func previewCoordinator(handoffError: (any Error)? = nil) -> SelfUpgradeCoordinator {
        SelfUpgradeCoordinator(
            statusProvider: StubSelfUpgradeStatusProvider(
                selfUpgradeStatus: SelfUpgradeStatus(
                    runningVersion: "1.4.2",
                    latestVersion: "1.5.0",
                    homepageURL: SelfUpgradeIdentity.homepageURL,
                    isUpgradeAvailable: true,
                ),
            ),
            preferences: StubSelfUpgradePreferences(),
            handoff: RecordingSelfUpgradeHandoff(error: handoffError),
        )
    }

    #Preview("Upgrade available") {
        SelfUpgradeBannerContent(coordinator: previewCoordinator())
            .frame(width: 520)
            .padding()
    }

    #Preview("Handoff failed") {
        let coordinator = previewCoordinator(handoffError: URLError(.cannotFindHost))
        SelfUpgradeBannerContent(coordinator: coordinator)
            .frame(width: 520)
            .padding()
            .task { await coordinator.beginUpgrade() }
    }
#endif
