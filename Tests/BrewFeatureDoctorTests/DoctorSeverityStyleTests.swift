//
//  DoctorSeverityStyleTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureDoctor
import BrewUIComponents
import SwiftUI
import Testing

@MainActor
struct DoctorSeverityStyleTests {
    @Test func `displayName names each severity`() {
        #expect(DoctorSeverityStyle.displayName(.caution) == "Caution")
        #expect(DoctorSeverityStyle.displayName(.danger) == "Danger")
        #expect(DoctorSeverityStyle.displayName(.unsupported) == "Unsupported")
    }

    @Test func `icon is a distinct glyph per severity`() {
        let icons = [
            DoctorSeverityStyle.icon(.caution),
            DoctorSeverityStyle.icon(.danger),
            DoctorSeverityStyle.icon(.unsupported),
        ]
        #expect(icons == ["exclamationmark.triangle.fill", "xmark.octagon.fill", "nosign"])
        #expect(Set(icons).count == 3)
    }

    @Test func `foreground shares the error token for danger and unsupported, distinct from caution`() {
        #expect(DoctorSeverityStyle.foreground(.caution) == .brewStatusWarning)
        #expect(DoctorSeverityStyle.foreground(.danger) == .brewStatusError)
        #expect(DoctorSeverityStyle.foreground(.unsupported) == .brewStatusError)
        #expect(DoctorSeverityStyle.foreground(.caution) != DoctorSeverityStyle.foreground(.danger))
    }

    @Test func `background shares the error-subtle token for danger and unsupported, distinct from caution`() {
        #expect(DoctorSeverityStyle.background(.caution) == .brewStatusWarningSubtle)
        #expect(DoctorSeverityStyle.background(.danger) == .brewStatusErrorSubtle)
        #expect(DoctorSeverityStyle.background(.unsupported) == .brewStatusErrorSubtle)
        #expect(DoctorSeverityStyle.background(.caution) != DoctorSeverityStyle.background(.danger))
    }
}
