//
//  DoctorIssueRowView.swift
//  BrewFeatureDoctor
//

import BrewUIComponents
import SwiftUI

/// One `brew doctor` warning in the issues list: a warning glyph, the summary, and a "fix available" hint.
struct DoctorIssueRowView: View {
    let item: DoctorIssueItem

    var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.brewStatusWarning)
                .imageScale(.medium)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(item.title)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextPrimary)
                    .lineLimit(2)
                if item.hasFix {
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
        .accessibilityLabel(item.title)
    }
}
