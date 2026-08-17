//
//  TerminalLineAssemblerTests.swift
//  BrewTests
//

import BrewCore
import Testing

struct TerminalLineAssemblerTests {
    // MARK: - Newlines

    @Test func `a newline commits the line`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("hello\n")

        #expect(events == [.committed(line("hello"))])
    }

    @Test func `several newlines in one chunk commit several lines`() {
        var assembler = TerminalLineAssembler()

        let committed = assembler.consume("one\ntwo\nthree\n").compactMap(\.committedText)

        #expect(committed == ["one", "two", "three"])
    }

    @Test func `text without a newline is revised, not committed`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("partial")

        #expect(events == [.revised(line("partial"))])
    }

    // MARK: - Carriage returns

    @Test func `a carriage return overwrites from the start of the line`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("first\rX")

        #expect(events.last == .revised(line("Xirst")))
    }

    @Test func `a full-width redraw replaces the previous one entirely`() {
        // curl pads each redraw to the terminal width so it covers what came before.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("##        6.3%\r######   50.0%")

        #expect(events.last == .revised(line("######   50.0%")))
    }

    @Test func `a whole progress bar collapses to one committed line`() {
        var assembler = TerminalLineAssembler()

        var events: [TerminalLineEvent] = []
        for percent in stride(from: 0, through: 100, by: 10) {
            events += assembler.consume("#\(percent)%\r")
        }
        events += assembler.consume("#100%\n")

        #expect(events.compactMap(\.committedText) == ["#100%"])
    }

    @Test func `a shorter redraw leaves the tail of the longer line behind`() {
        // `\r` only moves the cursor, it does not clear: "short" covers the first five columns and
        // "r text" from the original survives underneath.
        var assembler = TerminalLineAssembler()
        let events = assembler.consume("longer text\rshort")

        #expect(events.last == .revised(line("shortr text")))
    }

    @Test func `a carriage return before a newline still commits the overwritten line`() {
        var assembler = TerminalLineAssembler()

        let committed = assembler.consume("aaa\rb\n").compactMap(\.committedText)

        #expect(committed == ["baa"])
    }

    // MARK: - Erase in line

    @Test func `erase to end of line clears the tail a shorter redraw left behind`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("longer text\rshort\u{1B}[K")

        #expect(events.last == .revised(line("short")))
    }

    @Test func `erase whole line empties it`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("content\u{1B}[2K")

        #expect(events.last == .revised(line("")))
    }

    @Test func `backspace steps the cursor back one column`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abc\u{08}X")

        #expect(events.last == .revised(line("abX")))
    }

    // MARK: - Styling

    @Test func `styled text becomes spans carrying the style`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("\u{1B}[31mred\u{1B}[0m\n")

        #expect(events.compactMap(\.committedLine).first?.spans == [
            ANSISpan(text: "red", style: ANSIStyle(foreground: .red)),
        ])
    }

    @Test func `escape sequences do not occupy columns`() {
        // Why styling is per cell: counting escape bytes as columns would misplace every overwrite.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("\u{1B}[31mabcde\u{1B}[0m\rX")

        #expect(events.last?.revisedText == "Xbcde")
    }

    @Test func `style carries across a line boundary until reset`() {
        var assembler = TerminalLineAssembler()

        _ = assembler.consume("\u{1B}[31mfirst\n")
        let events = assembler.consume("second\n")

        #expect(events.compactMap(\.committedLine).first?.spans == [
            ANSISpan(text: "second", style: ANSIStyle(foreground: .red)),
        ])
    }

    @Test func `unsupported cursor movement is consumed rather than rendered`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("a\u{1B}[2Ab\n")

        #expect(events.compactMap(\.committedText) == ["ab"])
    }

    // MARK: - Chunk boundaries

    @Test func `a line split across chunks assembles into one committed line`() {
        var assembler = TerminalLineAssembler()

        _ = assembler.consume("start ")
        _ = assembler.consume("middle ")
        let events = assembler.consume("end\n")

        #expect(events.compactMap(\.committedText) == ["start middle end"])
    }

    @Test func `a redraw split across chunks still overwrites`() {
        var assembler = TerminalLineAssembler()

        _ = assembler.consume("aaaa\r")
        let events = assembler.consume("bb")

        #expect(events.last?.revisedText == "bbaa")
    }

    @Test func `one revision is emitted per chunk, however much it contains`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("1%\r2%\r3%\r4%\r5%")

        #expect(events == [.revised(line("5%"))])
    }

    // MARK: - Flushing

    @Test func `flush commits a trailing line that never got a newline`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume("no trailing newline")

        #expect(assembler.flush()?.text == "no trailing newline")
    }

    @Test func `flush returns nil when nothing is pending`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume("committed\n")

        #expect(assembler.flush() == nil)
    }

    @Test func `an empty chunk produces no events`() {
        var assembler = TerminalLineAssembler()

        #expect(assembler.consume("").isEmpty)
    }

    // MARK: - Within-line cursor movement

    @Test func `absolute column addressing overwrites like a carriage return`() {
        // ESC[1G is what several progress renderers use where curl uses \r.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("10%\u{1B}[1G100%\n")

        #expect(events.compactMap(\.committedText) == ["100%"])
    }

    @Test func `absolute column addressing is one-based`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\u{1B}[3GX\n")

        #expect(events.compactMap(\.committedText) == ["abXde"])
    }

    @Test func `a bare column sequence defaults to the first column`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abc\u{1B}[GX\n")

        #expect(events.compactMap(\.committedText) == ["Xbc"])
    }

    @Test func `cursor back steps over written cells`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\u{1B}[2DXY\n")

        #expect(events.compactMap(\.committedText) == ["abcXY"])
    }

    @Test func `cursor forward skips cells without erasing them`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\r\u{1B}[2CX\n")

        #expect(events.compactMap(\.committedText) == ["abXde"])
    }

    @Test func `cursor forward past the end pads with spaces`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("ab\u{1B}[3CX\n")

        #expect(events.compactMap(\.committedText) == ["ab   X"])
    }

    @Test func `a bare movement sequence defaults to one column`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\r\u{1B}[CX\n")

        #expect(events.compactMap(\.committedText) == ["aXcde"])
    }

    @Test func `cursor back cannot move past the start of the line`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("ab\u{1B}[99DX\n")

        #expect(events.compactMap(\.committedText) == ["Xb"])
    }

    @Test func `an absurd column request cannot blow the line up`() {
        // A malformed sequence would otherwise have the next write pad every cell up to it.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("a\u{1B}[999999999CX\n")

        #expect((events.compactMap(\.committedText).first?.count ?? 0) <= 4097)
    }

    @Test func `moving the cursor alone does not report a revision`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume("abc")

        #expect(assembler.consume("\u{1B}[1G").isEmpty)
    }

    // MARK: - Erasing

    @Test func `erasing to the start of the line uses the current style, not the old one`() {
        // A terminal erases with the active attribute; keeping the old one leaves a stale colour behind.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("\u{1B}[31mred\u{1B}[0m\u{1B}[1K\n")

        #expect(events.compactMap(\.committedLine).first?.spans == [
            ANSISpan(text: "   ", style: .default),
        ])
    }

    @Test func `erasing to the start blanks cells without moving the cursor`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\r\u{1B}[2C\u{1B}[1KX\n")

        // ESC[1K blanks columns 0 through 2 inclusive; the cursor stays at column 2, where X then lands.
        #expect(events.compactMap(\.committedText) == ["  Xde"])
    }
}

private func line(_ text: String) -> TerminalLine {
    TerminalLine(spans: text.isEmpty ? [] : [ANSISpan(text: text, style: .default)])
}

private extension TerminalLineEvent {
    var committedLine: TerminalLine? {
        if case let .committed(line) = self { return line }
        return nil
    }

    var committedText: String? {
        committedLine?.text
    }

    var revisedText: String? {
        if case let .revised(line) = self { return line.text }
        return nil
    }
}
