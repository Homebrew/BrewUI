//
//  ANSIConsoleTextTests.swift
//  BrewFeatureConsoleTests
//

import AppKit
import BrewCore
@testable import BrewFeatureConsole
import BrewUIComponents
import Foundation
import SwiftUI
import Testing

@MainActor
struct ANSIConsoleTextTests {
    @Test func `uncoloured line renders as a single run in its stream's colour`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "Pouring gh")

        let runs = runs(of: ANSIConsoleText.attributed(for: line))

        #expect(runs == [Run(text: "Pouring gh\n", color: NSColor(.brewTextPrimary), bold: false)])
    }

    @Test func `coloured and default spans produce distinct runs`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[34m==>\u{1B}[0m Downloading")

        let runs = runs(of: ANSIConsoleText.attributed(for: line))

        #expect(runs == [
            Run(text: "==>", color: NSColor(.brewStatusInfo), bold: false),
            Run(text: " Downloading\n", color: NSColor(.brewTextPrimary), bold: false),
        ])
    }

    @Test func `stderr default colour is applied to uncoloured spans`() {
        let line = BrewCommandOutputLine(stream: .stderr, text: "Warning: something")

        let runs = runs(of: ANSIConsoleText.attributed(for: line))

        #expect(runs == [Run(text: "Warning: something\n", color: NSColor(.brewStatusError), bold: false)])
    }

    @Test func `a run whose normal output is stderr does not paint it in the error role`() {
        let line = BrewCommandOutputLine(stream: .stderr, text: "Checking your system")

        let runs = runs(of: ANSIConsoleText.attributed(for: line, standardErrorIsNormalOutput: true))

        #expect(runs == [Run(text: "Checking your system\n", color: NSColor(.brewTextPrimary), bold: false)])
    }

    @Test func `brew's own ANSI colours still win on a normal-output-on-stderr run`() {
        let line = BrewCommandOutputLine(stream: .stderr, text: "\u{1B}[31mError: broken")

        let runs = runs(of: ANSIConsoleText.attributed(for: line, standardErrorIsNormalOutput: true))

        #expect(runs.first == Run(text: "Error: broken", color: NSColor(.brewStatusError), bold: false))
    }

    @Test func `bold span carries a bold monospaced font`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[1;32mSUCCESS")

        // The terminator is its own run: it carries the line's default style, not the span's.
        let runs = runs(of: ANSIConsoleText.attributed(for: line))

        #expect(runs.first == Run(text: "SUCCESS", color: NSColor(.brewStatusSuccess), bold: true))
    }

    @Test func `empty line renders as its terminator alone`() {
        let line = BrewCommandOutputLine(stream: .stdout, text: "")

        let attributed = ANSIConsoleText.attributed(for: line)

        #expect(attributed.string == "\n")
    }

    @Test func `a buffer renders as its lines in order`() {
        let lines = [
            BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[34m==>\u{1B}[0m Fetching"),
            BrewCommandOutputLine(stream: .stderr, text: "Warning: something"),
        ]

        let attributed = ANSIConsoleText.attributed(for: lines)

        #expect(attributed.string == "==> Fetching\nWarning: something\n")
    }

    /// The transcript's offsets address this text, and nothing checks that agreement at compile time.
    @Test func `rendered length matches what the transcript measures`() {
        let lines = [
            BrewCommandOutputLine(stream: .stdout, text: "\u{1B}[34m==>\u{1B}[0m Fetching gh"),
            BrewCommandOutputLine(stream: .stdout, text: ""),
            BrewCommandOutputLine(stream: .stderr, text: "Warning: brew is out of date"),
        ]
        var transcript = ConsoleTranscript()
        _ = transcript.update(to: lines)

        #expect(ANSIConsoleText.attributed(for: lines).length == transcript.length)
    }

    @Test func `ANSI colours map onto the console palette`() {
        let mapped = [ANSIColor.blue, .brightBlue, .red, .green, .yellow, .black, .white]
            .map(ANSIConsoleText.color(for:))

        #expect(mapped == [
            .brewStatusInfo,
            .brewStatusInfo,
            .brewStatusError,
            .brewStatusSuccess,
            .brewStatusWarning,
            .brewTextSecondary,
            .brewTextPrimary,
        ])
    }

    private struct Run: Equatable {
        let text: String
        let color: NSColor
        let bold: Bool
    }

    private func runs(of attributed: NSAttributedString) -> [Run] {
        var runs: [Run] = []
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attributes, range, _ in
            runs.append(Run(
                text: attributed.attributedSubstring(from: range).string,
                color: attributes[.foregroundColor] as? NSColor ?? .clear,
                bold: attributes[.font] as? NSFont == ANSIConsoleText.boldFont,
            ))
        }
        return runs
    }
}
