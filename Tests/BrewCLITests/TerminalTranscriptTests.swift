//
//  TerminalTranscriptTests.swift
//  BrewTests
//

@testable import BrewCLI
import BrewCore
import Testing

struct TerminalTranscriptTests {
    @Test func `an untouched transcript is empty`() {
        #expect(TerminalTranscript().text.isEmpty)
    }

    @Test func `committed rows are newline separated and newline terminated`() {
        var transcript = TerminalTranscript()

        transcript.apply(.committed(line("one")))
        transcript.apply(.committed(line("two")))

        #expect(transcript.text == "one\ntwo\n")
    }

    // MARK: - Trailing newlines

    @Test func `a settled row does not gain a trailing newline`() {
        // Output that stopped without a newline must not grow one: `printf 'tty'` is exactly `tty`.
        var transcript = TerminalTranscript()

        transcript.settle("tty")

        #expect(transcript.text == "tty")
    }

    @Test func `a settled row after committed ones ends the transcript without a newline`() {
        var transcript = TerminalTranscript()
        transcript.apply(.committed(line("one")))

        transcript.settle("partial")

        #expect(transcript.text == "one\npartial")
    }

    @Test func `settling replaces the row it was still drawing`() {
        var transcript = TerminalTranscript()
        transcript.apply(.revised(line("50%"), rowOffset: 0))

        transcript.settle("100%")

        #expect(transcript.text == "100%")
    }

    // MARK: - Offset zero

    @Test func `revisions at offset zero replace rather than accumulate`() {
        var transcript = TerminalTranscript()

        for percent in stride(from: 0, through: 100, by: 25) {
            transcript.apply(.revised(line("#### \(percent)%"), rowOffset: 0))
        }

        #expect(transcript.text == "#### 100%")
    }

    @Test func `committing settles the row being revised instead of appending`() {
        var transcript = TerminalTranscript()
        transcript.apply(.revised(line("50%"), rowOffset: 0))

        transcript.apply(.committed(line("100%")))
        transcript.apply(.committed(line("Downloaded")))

        #expect(transcript.text == "100%\nDownloaded\n")
    }

    // MARK: - Positive offsets

    @Test func `a positive offset rewrites that many rows back`() {
        var transcript = TerminalTranscript()
        for text in ["alpha", "beta", "gamma"] {
            transcript.apply(.committed(line(text)))
        }

        transcript.apply(.revised(line("ALPHA"), rowOffset: 2))

        #expect(transcript.text == "ALPHA\nbeta\ngamma\n")
    }

    @Test func `a positive offset leaves the target's newline alone`() {
        // The row already ended; only its content can change.
        var transcript = TerminalTranscript()
        transcript.apply(.committed(line("alpha")))
        transcript.settle("gamma")

        transcript.apply(.revised(line("ALPHA"), rowOffset: 1))

        #expect(transcript.text == "ALPHA\ngamma")
    }

    @Test func `an offset past the start is dropped`() {
        var transcript = TerminalTranscript()
        transcript.apply(.committed(line("only")))

        transcript.apply(.revised(line("nowhere"), rowOffset: 9))

        #expect(transcript.text == "only\n")
    }

    @Test func `an offset into an empty transcript is dropped`() {
        var transcript = TerminalTranscript()

        transcript.apply(.revised(line("nowhere"), rowOffset: 3))

        #expect(transcript.text.isEmpty)
    }

    // MARK: - Redrawn blocks

    @Test func `a redrawn block records its settled rows, not every frame`() {
        var transcript = TerminalTranscript()
        transcript.apply(.committed(line("alpha 1MB")))
        transcript.apply(.committed(line("beta 1MB")))
        transcript.apply(.revised(line("gamma 1MB"), rowOffset: 0))

        for tick in 2 ... 20 {
            transcript.apply(.revised(line("alpha \(tick)MB"), rowOffset: 2))
            transcript.apply(.revised(line("beta \(tick)MB"), rowOffset: 1))
            transcript.apply(.revised(line("gamma \(tick)MB"), rowOffset: 0))
        }
        transcript.settle("gamma 20MB")

        #expect(transcript.text == "alpha 20MB\nbeta 20MB\ngamma 20MB")
    }
}

private func line(_ text: String) -> TerminalLine {
    TerminalLine(spans: text.isEmpty ? [] : [ANSISpan(text: text, style: .default)])
}
