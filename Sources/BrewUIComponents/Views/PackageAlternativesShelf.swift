//
//  PackageAlternativesShelf.swift
//  BrewUIComponents
//
//

import BrewCore
import SwiftUI

/// Shelf displaying modern alternative CLI tools or complementary utilities.
public struct PackageAlternativesShelf: View {
    public let alternatives: [AIPackageAlternative]
    public let onSelectPackage: ((String) -> Void)?
    public let onComparePackage: ((String) -> Void)?
    public let onInstallPackage: ((String) -> Void)?

    public init(
        alternatives: [AIPackageAlternative],
        onSelectPackage: ((String) -> Void)? = nil,
        onComparePackage: ((String) -> Void)? = nil,
        onInstallPackage: ((String) -> Void)? = nil
    ) {
        self.alternatives = alternatives
        self.onSelectPackage = onSelectPackage
        self.onComparePackage = onComparePackage
        self.onInstallPackage = onInstallPackage
    }

    public var body: some View {
        if !alternatives.isEmpty {
            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                HStack(spacing: BrewSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.brewBrandPrimary)
                    Text("Modern Alternatives & Complements", bundle: #bundle, comment: "Title for modern alternatives shelf in package detail")
                        .font(.brewSubheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.brewTextPrimary)

                    Spacer()

                    Text("AI Suggested", bundle: #bundle, comment: "Badge for AI suggested alternatives")
                        .font(.brewCaption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, BrewSpacing.sm)
                        .padding(.vertical, BrewSpacing.xxs)
                        .background(Color.brewBrandPrimary.opacity(0.12))
                        .foregroundStyle(Color.brewBrandPrimary)
                        .clipShape(Capsule())
                }

                VStack(spacing: BrewSpacing.sm) {
                    ForEach(alternatives) { alt in
                        alternativeRow(alt)
                    }
                }
            }
            .padding(BrewSpacing.md)
            .background(Color.brewSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: BrewRadius.lg)
                    .stroke(Color.brewBorderDefault, lineWidth: 1)
            )
        }
    }

    private func alternativeRow(_ alt: AIPackageAlternative) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            HStack(alignment: .center, spacing: BrewSpacing.sm) {
                Text(verbatim: alt.name)
                    .font(.brewBodyEmphasized)
                    .foregroundStyle(Color.brewTextPrimary)

                Text(verbatim: alt.relationship)
                    .font(.brewCaption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, BrewSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.brewSurface)
                    .foregroundStyle(Color.brewTextSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))

                Spacer()

                if let onSelectPackage {
                    Button {
                        onSelectPackage(alt.name)
                    } label: {
                        Text("Inspect", bundle: #bundle, comment: "Button to inspect alternative package")
                            .font(.brewCaption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let onComparePackage {
                    Button {
                        onComparePackage(alt.name)
                    } label: {
                        Text("Compare", bundle: #bundle, comment: "Button to compare alternative package")
                            .font(.brewCaption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let onInstallPackage {
                    Button {
                        onInstallPackage(alt.installCommand)
                    } label: {
                        Text("Install", bundle: #bundle, comment: "Button to install alternative package")
                            .font(.brewCaption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Text(verbatim: alt.headline)
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)

            if !alt.keyAdvantages.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(alt.keyAdvantages, id: \.self) { adv in
                        HStack(alignment: .top, spacing: BrewSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.brewStatusSuccess)
                                .padding(.top, 2)

                            Text(verbatim: adv)
                                .font(.brewCaption2)
                                .foregroundStyle(Color.brewTextSecondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(BrewSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }
}
