//
//  SecurityPackageRowView.swift
//  BrewFeatureSecurity
//

import BrewUIComponents
import SwiftUI

/// One formula with open advisories: the most severe glyph, its name and how many advisories apply.
struct SecurityPackageRowView: View {
    let item: SecurityPackageItem

    var body: some View {
        HStack(alignment: .center, spacing: BrewSpacing.sm) {
            AdvisorySeverityStyle.glyphImage(item.highestSeverity)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(verbatim: item.name)
                    .font(.brewBodyEmphasized)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(item.advisoryCountText)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer(minLength: 0)
            AdvisorySeverityBadge(severity: item.highestSeverity)
        }
        .padding(.vertical, BrewSpacing.xs)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }
}
