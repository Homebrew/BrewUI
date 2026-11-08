//
//  PackageComparisonSheet.swift
//  BrewUIComponents
//
//

import BrewCore
import SwiftUI

/// Modal sheet for comparing two Homebrew packages side by side with AI synthesis.
public struct PackageComparisonSheet: View {
    public let comparison: AIPackageComparison
    public let packageA: BrewPackage
    public let packageB: BrewPackage
    public let isPackageAInstalled: Bool
    public let isPackageBInstalled: Bool
    public let onInstall: ((BrewPackage) -> Void)?
    public let onDismiss: () -> Void

    public init(
        comparison: AIPackageComparison,
        packageA: BrewPackage,
        packageB: BrewPackage,
        isPackageAInstalled: Bool = false,
        isPackageBInstalled: Bool = false,
        onInstall: ((BrewPackage) -> Void)? = nil,
        onDismiss: @escaping () -> Void,
    ) {
        self.comparison = comparison
        self.packageA = packageA
        self.packageB = packageB
        self.isPackageAInstalled = isPackageAInstalled
        self.isPackageBInstalled = isPackageBInstalled
        self.onInstall = onInstall
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                    versusHeader
                    verdictCard
                    strengthsComparison
                    bestForComparison
                    matrixSection
                }
                .padding(BrewSpacing.xl)
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 520)
        .background(Color.brewWindowBase)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewBrandPrimary)
            Text("Package Comparison", bundle: #bundle, comment: "Title of package comparison sheet")
                .font(.brewTitle3)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(BrewSpacing.lg)
    }

    private var versusHeader: some View {
        HStack(spacing: BrewSpacing.md) {
            PackageComparisonCard(package: packageA, isInstalled: isPackageAInstalled, onInstall: onInstall)
            Text("VS", bundle: #bundle, comment: "Versus label between two packages")
                .font(.brewSubheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextSecondary)
                .padding(BrewSpacing.xs)
                .background(Color.brewSurface)
                .clipShape(Circle())
            PackageComparisonCard(package: packageB, isInstalled: isPackageBInstalled, onInstall: onInstall)
        }
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            HStack(spacing: BrewSpacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.brewStatusWarning)
                Text("AI Verdict & Summary", bundle: #bundle, comment: "Package comparison AI verdict label")
                    .font(.brewSubheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewTextPrimary)
            }
            Text(verbatim: comparison.verdictSummary)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
        }
        .padding(BrewSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewBrandPrimary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBrandPrimary.opacity(0.2), lineWidth: 1),
        )
    }

    private var strengthsComparison: some View {
        HStack(alignment: .top, spacing: BrewSpacing.md) {
            strengthsColumn(
                title: String(localized: "Strengths of \(comparison.packageAName)", bundle: #bundle, comment: "Strengths heading for package A"),
                strengths: comparison.strengthsA,
            )
            strengthsColumn(
                title: String(localized: "Strengths of \(comparison.packageBName)", bundle: #bundle, comment: "Strengths heading for package B"),
                strengths: comparison.strengthsB,
            )
        }
    }

    private func strengthsColumn(title: String, strengths: [String]) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text(verbatim: title)
                .font(.brewCaption)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            ForEach(strengths, id: \.self) { item in
                HStack(alignment: .top, spacing: BrewSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.brewStatusSuccess)
                        .padding(.top, 2)
                    Text(verbatim: item)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
        .padding(BrewSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }

    private var bestForComparison: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("Recommendation Guidelines", bundle: #bundle, comment: "Heading for recommendation guidelines")
                .font(.brewSubheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            HStack(alignment: .top, spacing: BrewSpacing.md) {
                VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                    Text("Choose \(comparison.packageAName) if:", bundle: #bundle, comment: "Package comparison: condition heading; %@ is package name")
                        .font(.brewCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)
                    Text(verbatim: comparison.bestForA)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
                .padding(BrewSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brewSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))

                VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                    Text("Choose \(comparison.packageBName) if:", bundle: #bundle, comment: "Package comparison: condition heading; %@ is package name")
                        .font(.brewCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)
                    Text(verbatim: comparison.bestForB)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
                .padding(BrewSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brewSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
            }
        }
    }

    private var matrixSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Feature Comparison Matrix", bundle: #bundle, comment: "Matrix section heading")
                .font(.brewSubheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.brewTextPrimary)

            VStack(spacing: 0) {
                HStack {
                    Text("Feature", bundle: #bundle, comment: "Comparison matrix feature column")
                        .font(.brewCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brewTextSecondary)
                        .frame(width: 140, alignment: .leading)
                    Text(verbatim: comparison.packageAName)
                        .font(.brewCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brewTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: comparison.packageBName)
                        .font(.brewCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brewTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(BrewSpacing.sm)
                .background(Color.brewSurfaceElevated)

                Divider()

                ForEach(comparison.matrix) { row in
                    HStack {
                        Text(verbatim: row.feature)
                            .font(.brewCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.brewTextPrimary)
                            .frame(width: 140, alignment: .leading)
                        Text(verbatim: row.packageAValue)
                            .font(.brewCaption)
                            .foregroundStyle(Color.brewTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: row.packageBValue)
                            .font(.brewCaption)
                            .foregroundStyle(Color.brewTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(BrewSpacing.sm)
                    Divider()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrewRadius.md)
                    .stroke(Color.brewBorderDefault, lineWidth: 1),
            )
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("Done", bundle: #bundle, comment: "Close comparison sheet")
                    .frame(minWidth: 70)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(BrewSpacing.lg)
    }
}

private struct PackageComparisonCard: View {
    let package: BrewPackage
    let isInstalled: Bool
    let onInstall: ((BrewPackage) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            HStack {
                Text(verbatim: package.displayName)
                    .font(.brewTitle3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewTextPrimary)
                Spacer()
                if isInstalled {
                    Text("Installed", bundle: #bundle, comment: "Package comparison card installed badge")
                        .font(.brewCaption2)
                        .padding(.horizontal, BrewSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.brewStatusSuccess.opacity(0.15))
                        .foregroundStyle(Color.brewStatusSuccess)
                        .clipShape(Capsule())
                }
            }

            Text(kindLabel)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)

            if !package.description.isEmpty {
                Text(verbatim: package.description)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                    .lineLimit(2)
            }

            HStack {
                Text(verbatim: "v\(package.latestVersion)")
                    .font(.brewCaption2)
                    .foregroundStyle(Color.brewTextTertiary)

                Spacer()

                if !isInstalled, let onInstall {
                    Button {
                        onInstall(package)
                    } label: {
                        Text("Install", bundle: #bundle, comment: "Package comparison install button")
                            .font(.brewCaption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.top, BrewSpacing.xxs)
        }
        .padding(BrewSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private var kindLabel: String {
        switch package.kind {
        case .cask:
            String(localized: "GUI Application", bundle: #bundle, comment: "Package comparison: cask kind label")
        case .formula:
            String(localized: "CLI Utility", bundle: #bundle, comment: "Package comparison: formula kind label")
        }
    }
}
