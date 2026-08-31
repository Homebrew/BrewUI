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

        #expect(events == [.revised(line("partial"), rowOffset: 0)])
    }

    // MARK: - Carriage returns

    @Test func `a carriage return overwrites from the start of the line`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("first\rX")

        #expect(events.last == .revised(line("Xirst"), rowOffset: 0))
    }

    @Test func `a full-width redraw replaces the previous one entirely`() {
        // curl pads each redraw to the terminal width so it covers what came before.
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("##        6.3%\r######   50.0%")

        #expect(events.last == .revised(line("######   50.0%"), rowOffset: 0))
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

        #expect(events.last == .revised(line("shortr text"), rowOffset: 0))
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

        #expect(events.last == .revised(line("short"), rowOffset: 0))
    }

    @Test func `erase whole line empties it`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("content\u{1B}[2K")

        #expect(events.last == .revised(line(""), rowOffset: 0))
    }

    @Test func `backspace steps the cursor back one column`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abc\u{08}X")

        #expect(events.last == .revised(line("abX"), rowOffset: 0))
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

        #expect(events == [.revised(line("5%"), rowOffset: 0)])
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
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("\u{1B}[31mred\u{1B}[0m\u{1B}[1K\n")

        #expect(events.compactMap(\.committedLine).first?.spans == [
            ANSISpan(text: "   ", style: .default),
        ])
    }

    @Test func `erasing to the start blanks cells without moving the cursor`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcde\r\u{1B}[2C\u{1B}[1KX\n")

        // Blanks columns 0-2; the cursor stays at column 2, where X then lands.
        #expect(events.compactMap(\.committedText) == ["  Xde"])
    }

    // MARK: - Multi-row progress blocks

    /// One frame of Homebrew's download block: N rows, the last newline-less, then `ESC[<N-1>F`.
    private static func downloadFrame(_ rows: [String]) -> String {
        let body = rows.enumerated()
            .map { index, row in "\(row)\u{1B}[K\(index == rows.count - 1 ? "" : "\n")" }
            .joined()
        return "\u{1B}[?2026h" + body + "\u{1B}[\(rows.count - 1)F" + "\u{1B}[?2026l"
    }

    private static func downloadFrame(tick: Int) -> String {
        downloadFrame([
            "Cask alpha  # Downloading \(tick)MB/10MB",
            "Cask beta   # Downloading \(tick)MB/20MB",
            "Cask gamma  # Downloading \(tick)MB/30MB",
        ])
    }

    @Test func `a redrawn download block revises its rows instead of repeating them`() {
        var assembler = TerminalLineAssembler()
        var committed = 0

        for tick in 1 ... 5 {
            committed += assembler.consume(Self.downloadFrame(tick: tick)).compactMap(\.committedText).count
        }

        // Two rows commit; the third stays pending.
        #expect(committed == 2)
    }

    @Test func `a redrawn download block does not splice two rows together`() {
        var assembler = TerminalLineAssembler()
        var texts: [String] = []

        for tick in 1 ... 5 {
            for event in assembler.consume(Self.downloadFrame(tick: tick)) {
                switch event {
                case let .committed(line): texts.append(line.text)
                case let .revised(line, _): texts.append(line.text)
                }
            }
        }

        #expect(!texts.contains { $0.components(separatedBy: "Cask").count > 2 })
    }

    @Test func `a redrawn download block reports each row at its own offset`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume(Self.downloadFrame(tick: 1))

        let revisions = assembler.consume(Self.downloadFrame(tick: 2)).compactMap(\.revision)

        // Top row of the block is two rows above the one still being written.
        #expect(revisions.contains { $0.offset == 2 && $0.text.contains("alpha") && $0.text.contains("2MB") })
        #expect(revisions.contains { $0.offset == 1 && $0.text.contains("beta") && $0.text.contains("2MB") })
        #expect(revisions.contains { $0.offset == 0 && $0.text.contains("gamma") && $0.text.contains("2MB") })
    }

    @Test func `each row is revised at most once per chunk`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume(Self.downloadFrame(tick: 1))

        // Two whole frames in one read.
        let events = assembler.consume(Self.downloadFrame(tick: 2) + Self.downloadFrame(tick: 3))
        let offsets = events.compactMap(\.revision).map(\.offset)

        #expect(offsets.count == Set(offsets).count)
    }

    @Test func `the final frame is what settles`() {
        var assembler = TerminalLineAssembler()
        for tick in 1 ... 4 {
            _ = assembler.consume(Self.downloadFrame(tick: tick))
        }

        let settled = assembler.consume(Self.downloadFrame(tick: 9)).compactMap(\.revision)

        #expect(settled.allSatisfy { $0.text.contains("9MB") })
    }

    // MARK: - Vertical cursor movement

    @Test func `cursor previous line returns to column zero`() {
        var assembler = TerminalLineAssembler()

        // Column 0, so X lands over the "a".
        let events = assembler.consume("abc\ndef\u{1B}[1FX")

        #expect(events.compactMap(\.revision).contains { $0.offset == 1 && $0.text == "Xbc" })
    }

    @Test func `cursor up keeps the column`() {
        var assembler = TerminalLineAssembler()

        // Stays at column 3, past the end of "ab", so it pads.
        let events = assembler.consume("ab\nxyz\u{1B}[1AX")

        #expect(events.compactMap(\.revision).contains { $0.offset == 1 && $0.text == "ab X" })
    }

    @Test func `cursor down returns toward the newest row`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("one\ntwo\nthree\u{1B}[2F\u{1B}[1BX")

        // Up two rows then back down one lands on "two".
        #expect(events.compactMap(\.revision).contains { $0.offset == 1 && $0.text == "Xwo" })
    }

    @Test func `a newline inside a block steps down rather than opening a row`() {
        var assembler = TerminalLineAssembler()
        _ = assembler.consume("one\ntwo\nthree")

        let events = assembler.consume("\u{1B}[2FA\nB\nC")

        #expect(events.compactMap(\.committedText).isEmpty)
        #expect(events.compactMap(\.revision).map(\.text).sorted() == ["Ane", "Bwo", "Chree"])
    }

    @Test func `moving above the window is ignored rather than writing to the wrong row`() {
        // The move is dropped, so X lands on the pending row rather than an unrelated one.
        var assembler = TerminalLineAssembler(windowDepth: 2)
        _ = assembler.consume("one\ntwo\nthree\nfour")

        let events = assembler.consume("\u{1B}[9FX")

        #expect(events.compactMap(\.revision).contains { $0.offset == 0 && $0.text == "Xour" })
    }

    @Test func `rows that scroll out of the window are settled`() {
        var assembler = TerminalLineAssembler(windowDepth: 1)
        _ = assembler.consume("keep\ndrop\nlast")

        // Only one row of history is retained, so the row two back is out of reach.
        let events = assembler.consume("\u{1B}[2FX")

        #expect(!events.compactMap(\.revision).contains { $0.offset == 2 })
    }

    @Test func `erasing applies to the row the cursor is on`() {
        var assembler = TerminalLineAssembler()

        let events = assembler.consume("abcdef\nghi\u{1B}[1F\u{1B}[3C\u{1B}[K")

        #expect(events.compactMap(\.revision).contains { $0.offset == 1 && $0.text == "abc" })
    }

    @Test func `a single-line progress bar is unaffected by the window`() {
        var assembler = TerminalLineAssembler()

        var events: [TerminalLineEvent] = []
        for percent in stride(from: 0, through: 100, by: 20) {
            events += assembler.consume("#\(percent)%\r")
        }
        events += assembler.consume("\n")

        #expect(events.compactMap(\.committedText) == ["#100%"])
        #expect(events.compactMap(\.revision).allSatisfy { $0.offset == 0 })
    }

    @Test func `flushing settles the row still being drawn, not the one the cursor sits on`() {
        var assembler = TerminalLineAssembler()

        // The cursor is parked two rows up, so X revises "one" and "three" stays pending.
        let events = assembler.consume("one\ntwo\nthree\u{1B}[2FX")

        #expect(events.compactMap(\.revision).contains { $0.offset == 2 && $0.text == "Xne" })
        #expect(assembler.flush()?.text == "three")
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
        revision?.text
    }

    var revision: (text: String, offset: Int)? {
        if case let .revised(line, rowOffset) = self { return (line.text, rowOffset) }
        return nil
    }
}
