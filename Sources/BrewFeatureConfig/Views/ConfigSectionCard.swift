//
//  ConfigSectionCard.swift
//  BrewFeatureConfig
//

import BrewUIComponents
import SwiftUI

/// A grouped key/value card for one configuration section. Values are monospaced and selectable so the
/// pane reads like a diagnostic report (mirrors the package-detail row style).
struct ConfigSectionCard: View {
    let section: ConfigSectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: section.title)

            if section.rows.isEmpty {
                Text(section.emptyMessage ?? "")
                    .font(.brewCallout)
                    .foregroundStyle(Color.brewTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(section.rows) { row in
                    detailRow(label: row.label, value: row.value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.md) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .frame(width: 240, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(value.isEmpty ? "—" : value)
                .font(.brewCode)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
