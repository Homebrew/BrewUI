//
//  ConsoleTranscriptTests.swift
//  BrewFeatureConsoleTests
//

import BrewCore
@testable import BrewFeatureConsole
import Foundation
import Testing

@MainActor
struct ConsoleTranscriptTests {
    @Test func `document is the visible text of every line, newline terminated`() {
        var transcript = ConsoleTranscript()

        _ = transcript.update(to: [line("==> Fetching"), line("\u{1B}[32mPoured\u{1B}[0m gh")])

        #expect(transcript.text == "==> Fetching\nPoured gh\n")
    }

    @Test func `an unchanged buffer produces no edit`() {
        var transcript = ConsoleTranscript()
        let lines = [line("==> Fetching")]
        _ = transcript.update(to: lines)

        #expect(transcript.update(to: lines) == nil)
    }

    @Test func `an appended line is inserted after the lines already rendered`() {
        var transcript = ConsoleTranscript()
        let first = line("==> Fetching")
        _ = transcript.update(to: [first])

        let edit = transcript.update(to: [first, line("==> Pouring")])

        #expect(EditSummary(edit) == EditSummary(
            location: "==> Fetching\n".utf16.count,
            length: 0,
            texts: ["==> Pouring"],
        ))
    }

    /// A progress row is rewritten many times a second; replacing more would throw away the selection.
    @Test func `a revised last line replaces only itself`() {
        var transcript = ConsoleTranscript()
        let settled = line("==> Fetching")
        let progress = line("#### 40%", isComplete: false)
        _ = transcript.update(to: [settled, progress])

        let edit = transcript.update(to: [
            settled,
            BrewCommandOutputLine(stream: .stdout, text: "######## 80%", id: progress.id, isComplete: false),
        ])

        #expect(EditSummary(edit) == EditSummary(
            location: "==> Fetching\n".utf16.count,
            length: "#### 40%\n".utf16.count,
            texts: ["######## 80%"],
        ))
    }

    /// `CommandJob` trims the front past `maxOutputLines`, which leaves no shared prefix.
    @Test func `trimming the front of the buffer replaces the whole document`() {
        var transcript = ConsoleTranscript()
        _ = transcript.update(to: [line("first"), line("second")])

        let edit = transcript.update(to: [line("second"), line("third")])

        #expect(EditSummary(edit) == EditSummary(
            location: 0,
            length: "first\nsecond\n".utf16.count,
            texts: ["second", "third"],
        ))
    }

    @Test func `dropping trailing lines deletes them without rendering anything`() {
        var transcript = ConsoleTranscript()
        let kept = line("first")
        _ = transcript.update(to: [kept, line("second")])

        let edit = transcript.update(to: [kept])

        #expect(EditSummary(edit) == EditSummary(
            location: "first\n".utf16.count,
            length: "second\n".utf16.count,
            texts: [],
        ))
    }

    /// Stream decides the line's colour, so it matters even when the text is unchanged.
    @Test func `lines differing only in stream are re-rendered`() {
        var transcript = ConsoleTranscript()
        _ = transcript.update(to: [BrewCommandOutputLine(stream: .stdout, text: "Warning")])

        let edit = transcript.update(to: [BrewCommandOutputLine(stream: .stderr, text: "Warning")])

        #expect(edit?.lines.first?.stream == .stderr)
    }

    /// Replays a streaming run against a string that indexes the way `NSTextStorage` does.
    @Test func `applying each edit in turn reproduces the document`() {
        var transcript = ConsoleTranscript()
        let rendered = NSMutableString()
        let fetching = line("==> Fetching gh")
        let progress = line("#### 40%", isComplete: false)
        let done = BrewCommandOutputLine(stream: .stdout, text: "######## 100%", id: progress.id)
        let warning = BrewCommandOutputLine(stream: .stderr, text: "Warning: brew is out of date")

        for buffer in [
            [fetching],
            [fetching, progress],
            [fetching, done],
            [fetching, done, warning],
            [done, warning],
        ] {
            guard let edit = transcript.update(to: buffer) else {
                continue
            }
            rendered.replaceCharacters(
                in: NSRange(location: edit.location, length: edit.length),
                with: edit.lines.map(ConsoleTranscript.text(of:)).joined(),
            )
        }

        #expect(rendered as String == transcript.text)
    }

    @Test func `length matches the rendered document`() {
        var transcript = ConsoleTranscript()

        _ = transcript.update(to: [line("==> Fetching"), line("\u{1B}[32mPoured\u{1B}[0m gh")])

        #expect(transcript.length == transcript.text.utf16.count)
    }

    private func line(_ text: String, isComplete: Bool = true) -> BrewCommandOutputLine {
        BrewCommandOutputLine(stream: .stdout, text: text, isComplete: isComplete)
    }

    /// Asserts on position and visible content; identity and timestamps aren't the document's business.
    private struct EditSummary: Equatable {
        let location: Int
        let length: Int
        let texts: [String]

        init(location: Int, length: Int, texts: [String]) {
            self.location = location
            self.length = length
            self.texts = texts
        }

        init?(_ edit: ConsoleTranscript.Edit?) {
            guard let edit else {
                return nil
            }
            location = edit.location
            length = edit.length
            texts = edit.lines.map(\.text)
        }
    }
}
