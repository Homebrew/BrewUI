//
//  DoctorSeverityStyleTests.swift
//  BrewTests
//

import BrewCore
@testable import BrewFeatureDoctor
import BrewUIComponents
import Foundation
import SwiftUI
import Testing

@MainActor
struct DoctorSeverityStyleTests {
    @Test func `severity names resolve the supplied language snapshot`() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DoctorLocalization-\(UUID().uuidString).bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("zh-Hans.lproj")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["Warning": "警告", "Danger": "危险", "Unsupported": "不受支持"],
            format: .xml,
            options: 0,
        )
        try data.write(to: directory.appendingPathComponent("Localizable.strings"))
        let localization = try AppLocalization(language: "zh-Hans", bundle: #require(Bundle(url: root)))
        #expect([
            DoctorSeverityStyle.displayName(.caution, localization: localization),
            DoctorSeverityStyle.displayName(.danger, localization: localization),
            DoctorSeverityStyle.displayName(.unsupported, localization: localization),
        ] == ["警告", "危险", "不受支持"])
    }

    @Test func `displayName names each severity`() {
        #expect(DoctorSeverityStyle.displayName(.caution) == "Warning")
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
