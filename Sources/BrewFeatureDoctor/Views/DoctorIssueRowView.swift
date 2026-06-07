//
//  DoctorIssueRowView.swift
//  BrewFeatureDoctor
//

import BrewUIComponents
import SwiftUI

/// One `brew doctor` warning in the issues list: a severity glyph (matching the row's severity), the
/// summary, and a "fix available" hint.
struct DoctorIssueRowView: View {
    let item: DoctorIssueItem

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: DoctorSeverityStyle.icon(item.severity))
                .foregroundStyle(DoctorSeverityStyle.foreground(item.severity))
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(item.title)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextPrimary)
                    .lineLimit(2)
                if item.hasRunnableFix {
                    Label("Fix available", systemImage: "wrench.and.screwdriver")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewBrandPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, BrewSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
    }
}
