//
//  ANSIConsoleTextTests.swift
//  BrewFeatureConsoleTests
//

import BrewCore
@testable import BrewFeatureConsole
import BrewUIComponents
import Foundation
import SwiftUI
import Testing

@MainActor
struct ANSIConsoleTextTests {
    @Test func `uncoloured line renders as a single run in the default colour`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "Pouring gh")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewTextPrimary)

        #expect(String(attributed.characters) == "Pouring gh")
        #expect(Array(attributed.runs).count == 1)
        #expect(attributed.runs.first?.foregroundColor == .brewTextPrimary)
    }

    @Test func `visible text preserves ANSI content without the escape codes`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[34m==>\u{1B}[0m Downloading")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewTextPrimary)

        #expect(String(attributed.characters) == "==> Downloading")
    }

    @Test func `coloured and default spans produce distinct runs`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[34m==>\u{1B}[0m Downloading")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewTextPrimary)
        let runs = Array(attributed.runs)

        #expect(runs.count == 2)
        #expect(runs.first?.foregroundColor == .brewStatusInfo)
        #expect(runs.last?.foregroundColor == .brewTextPrimary)
    }

    @Test func `stderr default colour is applied to uncoloured spans`() {
        let line = BrewCommandOutputLine(stream: .stderr, text: "Warning: something")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewStatusError)

        #expect(attributed.runs.first?.foregroundColor == .brewStatusError)
    }

    @Test func `bold span carries a bold monospaced font`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[1;32mSUCCESS")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewTextPrimary)

        #expect(attributed.runs.first?.foregroundColor == .brewStatusSuccess)
        #expect(attributed.runs.first?.font == .system(.body, design: .monospaced).weight(.bold))
    }

    @Test func `empty line yields empty attributed string`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "")

        let attributed = ANSIConsoleText.attributed(for: line, defaultColor: .brewTextPrimary)

        #expect(String(attributed.characters).isEmpty)
    }
}
