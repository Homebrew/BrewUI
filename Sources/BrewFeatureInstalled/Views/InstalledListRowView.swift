//
//  InstalledListRowView.swift
//  Brew
//

import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Owns ``InstalledListRowViewModel`` for one row and runs ``InstalledListRowViewModel/observeRowUpdates()`` while the row is on screen.
struct InstalledListRowRoot: View {
    let package: InstalledBrewPackage
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.installedPackagesRepository) private var installedPackagesRepository

    var body: some View {
        InstalledListRowView(
            package: package,
            brewCommandCenter: brewCommandCenter,
            fetchRevision: installedPackagesRepository.fetchRevision,
        )
        .id(package.id)
    }
}

struct InstalledListRowView: View {
    let package: InstalledBrewPackage
    /// Settled inventory fetches, fed from the environment by ``InstalledListRowRoot`` (`0` in
    /// previews). A change releases the busy latch when the reconcile settled without changing
    /// this package — see ``InstalledListRowViewModel/releaseLatchedOperationState()``.
    let fetchRevision: Int
    @State private var viewModel: InstalledListRowViewModel

    init(package: InstalledBrewPackage, brewCommandCenter: BrewCommandCenter, fetchRevision: Int = 0) {
        _viewModel = State(
            initialValue: InstalledListRowViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
            ),
        )
        self.package = package
        self.fetchRevision = fetchRevision
    }

    var body: some View {
        Group {
            rowContent(viewModel: viewModel)
        }
        .task(id: viewModel.operationSubject) {
            await viewModel.observeRowUpdates()
        }
        .onChange(of: package) { _, new in
            viewModel.update(package: new)
        }
        .onChange(of: fetchRevision) {
            viewModel.releaseLatchedOperationState()
        }
    }

    private func rowContent(viewModel: InstalledListRowViewModel) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            titleRow(viewModel: viewModel)
            if viewModel.hasDescription {
                Text(viewModel.descriptionText)
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            versionLine(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.rowAccessibilityLabel)
    }

    private func titleRow(viewModel: InstalledListRowViewModel) -> some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewBodyEmphasized)
                .foregroundStyle(Color.brewTextPrimary)
                .lineLimit(1)

            if viewModel.showsOperationBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            Text(viewModel.kind.chrome.badgeLabel)
                .font(.brewCaption2)
                .foregroundStyle(accentColor(viewModel.kind.chrome.accent))
                .padding(.horizontal, BrewSpacing.sm)
                .padding(.vertical, BrewSpacing.xs)
                .background {
                    Capsule()
                        .fill(Color.brewSurfaceElevated)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                        }
                        .brewHiddenWhenRedacted()
                }

            statusBadge(viewModel: viewModel)
                .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func statusBadge(viewModel: InstalledListRowViewModel) -> some View {
        if viewModel.showsUpgradeAvailable {
            InstalledOutdatedBadge()
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(Color.brewStatusSuccess)
        }
    }

    @ViewBuilder
    private func versionLine(viewModel: InstalledListRowViewModel) -> some View {
        switch viewModel.versionPresentation {
        case let .installed(version):
            Text(version)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
        case let .upgrade(current, latest):
            HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.xs) {
                Text(current)
                    .foregroundStyle(Color.brewTextTertiary)
                Text("→")
                    .foregroundStyle(Color.brewTextTertiary)
                Text(latest)
                    .foregroundStyle(Color.brewTextBrand)
            }
            .font(.brewCaption)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func accentColor(_ token: PackageKindAccentToken) -> Color {
        switch token {
        case .brandPrimary:
            Color.brewTextBrand
        case .statusInfo:
            Color.brewStatusInfo
        }
    }
}

#if DEBUG

    #Preview("Formula with upgrade") {
        InstalledListRowView(
            package: PreviewSupport.outdatedFormula,
            brewCommandCenter: PreviewSupport.commandCenter,
        )
        .padding()
        .frame(width: 400)
    }

    #Preview("Cask") {
        InstalledListRowView(
            package: PreviewSupport.currentCask,
            brewCommandCenter: PreviewSupport.commandCenter,
        )
        .padding()
        .frame(width: 400)
    }
#endif
