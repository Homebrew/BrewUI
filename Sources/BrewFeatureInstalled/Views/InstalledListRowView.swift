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

    var body: some View {
        InstalledListRowView(
            package: package,
            brewCommandCenter: brewCommandCenter,
        )
        .id(package.id)
    }
}

struct InstalledListRowView: View {
    let package: InstalledBrewPackage
    @State private var viewModel: InstalledListRowViewModel

    init(package: InstalledBrewPackage, brewCommandCenter: BrewCommandCenter) {
        _viewModel = State(
            initialValue: InstalledListRowViewModel(
                package: package,
                brewCommandCenter: brewCommandCenter,
            ),
        )
        self.package = package
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
    }

    private func rowContent(viewModel: InstalledListRowViewModel) -> some View {
        HStack(alignment: .center, spacing: BrewSpacing.md) {
            iconBadge(viewModel: viewModel)
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
        }
        .padding(.vertical, BrewSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.rowAccessibilityLabel)
    }

    private func iconBadge(viewModel: InstalledListRowViewModel) -> some View {
        ZStack {
            Circle()
                .strokeBorder(accentColor(viewModel.kind.chrome.accent), lineWidth: 1)
                .frame(width: 36, height: 36)
                .brewHiddenWhenRedacted()
            Image(systemName: "cube.box.fill")
                .font(.body)
                .foregroundStyle(accentColor(viewModel.kind.chrome.accent))
        }
        .accessibilityHidden(true)
    }

    private func titleRow(viewModel: InstalledListRowViewModel) -> some View {
        HStack(spacing: BrewSpacing.sm) {
            Text(viewModel.name)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)

            if viewModel.showsOperationBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            statusIcon(viewModel: viewModel)
                .font(.body)
                .accessibilityHidden(true)

            Text(viewModel.kind.chrome.badgeLabel)
                .font(.brewCaption2)
                .foregroundStyle(accentColor(viewModel.kind.chrome.accent))
                .padding(.horizontal, BrewSpacing.sm)
                .padding(.vertical, BrewSpacing.xs)
                .background {
                    Capsule()
                        .fill(Color.brewSurfaceElevated)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.brewBorderDefault, lineWidth: 1)
                }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func statusIcon(viewModel: InstalledListRowViewModel) -> some View {
        if viewModel.showsUpgradeAvailable {
            Image(systemName: "exclamationmark.circle.fill")
                .brewWarningGlyphStyle()
        } else {
            Image(systemName: "checkmark.circle.fill")
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
