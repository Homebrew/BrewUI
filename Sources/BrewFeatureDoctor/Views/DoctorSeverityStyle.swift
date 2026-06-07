//
//  DoctorSeverityStyle.swift
//  BrewFeatureDoctor
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Single source of truth for the icon + colour + label used to render a ``DoctorSeverity`` in the
/// Doctor surface (issue list section headers and the detail-pane hero badge). Each case has a
/// distinct icon so a reader can tell severities apart at a glance; Danger and Unsupported share the
/// error colour token because they share the same severity register in the BrewUI palette.
enum DoctorSeverityStyle {
    static func displayName(_ severity: DoctorSeverity) -> String {
        switch severity {
        case .caution: "Caution"
        case .danger: "Danger"
        case .unsupported: "Unsupported"
        }
    }

    static func icon(_ severity: DoctorSeverity) -> String {
        switch severity {
        case .caution: "exclamationmark.triangle.fill"
        case .danger: "xmark.octagon.fill"
        case .unsupported: "nosign"
        }
    }

    static func foreground(_ severity: DoctorSeverity) -> Color {
        switch severity {
        case .caution: .brewStatusWarning
        case .danger, .unsupported: .brewStatusError
        }
    }

    static func background(_ severity: DoctorSeverity) -> Color {
        switch severity {
        case .caution: .brewStatusWarningSubtle
        case .danger, .unsupported: .brewStatusErrorSubtle
        }
    }
}
