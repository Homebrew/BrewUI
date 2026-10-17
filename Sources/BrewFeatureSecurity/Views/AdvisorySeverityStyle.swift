//
//  AdvisorySeverityStyle.swift
//  BrewFeatureSecurity
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Single source of truth for the label, icon and colour of an ``AdvisorySeverity``. Every severity
/// carries a distinct icon and its name, so it never relies on colour alone.
enum AdvisorySeverityStyle {
    static func displayName(_ severity: AdvisorySeverity) -> String {
        switch severity {
        case .critical: String(localized: "Critical", bundle: #bundle, comment: "Security advisory severity name")
        case .high: String(localized: "High", bundle: #bundle, comment: "Security advisory severity name")
        case .medium: String(localized: "Medium", bundle: #bundle, comment: "Security advisory severity name")
        case .low: String(localized: "Low", bundle: #bundle, comment: "Security advisory severity name")
        case .unknown: String(localized: "Unscored", bundle: #bundle, comment: "Security advisory severity name when OSV gives no score")
        }
    }

    static func icon(_ severity: AdvisorySeverity) -> String {
        switch severity {
        case .critical: "xmark.octagon.fill"
        case .high: "exclamationmark.octagon.fill"
        case .medium: "exclamationmark.triangle.fill"
        case .low: "info.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    static func foreground(_ severity: AdvisorySeverity) -> Color {
        switch severity {
        case .critical, .high: .brewStatusError
        case .medium: .brewStatusWarning
        case .low, .unknown: .brewTextSecondary
        }
    }

    static func background(_ severity: AdvisorySeverity) -> Color {
        switch severity {
        case .critical, .high: .brewStatusErrorSubtle
        case .medium: .brewStatusWarningSubtle
        case .low, .unknown: .brewSurfaceRecessed
        }
    }

    /// Medium keeps the vivid warning yellow for its glyph rather than the darker text amber.
    @ViewBuilder
    static func glyphImage(_ severity: AdvisorySeverity) -> some View {
        let image = Image(systemName: icon(severity))
        switch severity {
        case .medium:
            image.brewWarningGlyphStyle()
        case .critical, .high, .low, .unknown:
            image.foregroundStyle(foreground(severity))
        }
    }
}

/// Capsule naming a severity, used in the list and the detail pane.
struct AdvisorySeverityBadge: View {
    let severity: AdvisorySeverity

    var body: some View {
        Label(AdvisorySeverityStyle.displayName(severity), systemImage: AdvisorySeverityStyle.icon(severity))
            .font(.brewCaption.weight(.semibold))
            .foregroundStyle(AdvisorySeverityStyle.foreground(severity))
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
            .background(AdvisorySeverityStyle.background(severity), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                localized: "Severity: \(AdvisorySeverityStyle.displayName(severity))",
                bundle: #bundle,
                comment: "VoiceOver: security advisory severity badge; %@ is the severity name",
            ))
    }
}
