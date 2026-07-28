//
//  ANSIParserTests.swift
//  BrewCoreTests
//

@testable import BrewCore
import Foundation
import Testing

struct ANSIParserTests {
    // MARK: - Degenerate input

    @Test func `empty input yields no spans`() {
        #expect(ANSIParser.parse("").isEmpty)
    }

    @Test func `plain text yields a single default-styled span`() {
        let spans = ANSIParser.parse("Pouring gh--2.0.0.bottle")

        #expect(spans == [ANSISpan(text: "Pouring gh--2.0.0.bottle", style: .default)])
    }

    // MARK: - Foreground colours

    @Test func `standard foreground colour applies to following text`() {
        let spans = ANSIParser.parse("\u{1B}[34m==>\u{1B}[0m Downloading")

        #expect(spans == [
            ANSISpan(text: "==>", style: ANSIStyle(foreground: .blue)),
            ANSISpan(text: " Downloading", style: .default),
        ])
    }

    @Test func `each standard foreground code maps to its palette colour`() {
        let expected: [(Int, ANSIColor)] = [
            (30, .black), (31, .red), (32, .green), (33, .yellow),
            (34, .blue), (35, .magenta), (36, .cyan), (37, .white),
        ]
        for (code, color) in expected {
            let spans = ANSIParser.parse("\u{1B}[\(code)mX")
            #expect(spans == [ANSISpan(text: "X", style: ANSIStyle(foreground: color))])
        }
    }

    @Test func `each bright foreground code maps to its palette colour`() {
        let expected: [(Int, ANSIColor)] = [
            (90, .brightBlack), (91, .brightRed), (92, .brightGreen), (93, .brightYellow),
            (94, .brightBlue), (95, .brightMagenta), (96, .brightCyan), (97, .brightWhite),
        ]
        for (code, color) in expected {
            let spans = ANSIParser.parse("\u{1B}[\(code)mX")
            #expect(spans == [ANSISpan(text: "X", style: ANSIStyle(foreground: color))])
        }
    }

    @Test func `code 39 resets foreground to default`() {
        let spans = ANSIParser.parse("\u{1B}[31mred\u{1B}[39mplain")

        #expect(spans == [
            ANSISpan(text: "red", style: ANSIStyle(foreground: .red)),
            ANSISpan(text: "plain", style: .default),
        ])
    }

    // MARK: - Bold

    @Test func `bold applies and combines with a colour`() {
        let spans = ANSIParser.parse("\u{1B}[1;32mSUCCESS")

        #expect(spans == [ANSISpan(text: "SUCCESS", style: ANSIStyle(foreground: .green, bold: true))])
    }

    @Test func `code 22 clears bold but keeps colour`() {
        let spans = ANSIParser.parse("\u{1B}[1;31mA\u{1B}[22mB")

        #expect(spans == [
            ANSISpan(text: "A", style: ANSIStyle(foreground: .red, bold: true)),
            ANSISpan(text: "B", style: ANSIStyle(foreground: .red, bold: false)),
        ])
    }

    // MARK: - Reset

    @Test func `empty SGR parameters reset like an explicit zero`() {
        let spans = ANSIParser.parse("\u{1B}[1;33mwarn\u{1B}[mtail")

        #expect(spans == [
            ANSISpan(text: "warn", style: ANSIStyle(foreground: .yellow, bold: true)),
            ANSISpan(text: "tail", style: .default),
        ])
    }

    // MARK: - Span coalescing

    @Test func `adjacent codes producing the same style do not split the run`() {
        // Setting red twice with text between should still be a single span.
        let spans = ANSIParser.parse("\u{1B}[31mfoo\u{1B}[31mbar")

        #expect(spans == [ANSISpan(text: "foobar", style: ANSIStyle(foreground: .red))])
    }

    @Test func `leading text before any code keeps the default style`() {
        let spans = ANSIParser.parse("plain\u{1B}[32mgreen")

        #expect(spans == [
            ANSISpan(text: "plain", style: .default),
            ANSISpan(text: "green", style: ANSIStyle(foreground: .green)),
        ])
    }

    // MARK: - Unsupported / malformed sequences

    @Test func `unsupported SGR codes are consumed without emitting text`() {
        // 4 = underline, 7 = reverse — neither modelled; text renders with the default style.
        let spans = ANSIParser.parse("\u{1B}[4;7mtext")

        #expect(spans == [ANSISpan(text: "text", style: .default)])
    }

    @Test func `256-colour introducer is consumed and following codes still parse`() {
        // 38;5;12 selects a palette colour we don't model; the trailing bold must still apply.
        let spans = ANSIParser.parse("\u{1B}[38;5;12;1mX")

        #expect(spans == [ANSISpan(text: "X", style: ANSIStyle(foreground: nil, bold: true))])
    }

    @Test func `truecolour introducer consumes its three arguments`() {
        // 38;2;255;0;0 is truecolour red; the following 32 (green) must not be swallowed as an argument.
        let spans = ANSIParser.parse("\u{1B}[38;2;255;0;0;32mX")

        #expect(spans == [ANSISpan(text: "X", style: ANSIStyle(foreground: .green))])
    }

    @Test func `non-SGR CSI sequences are stripped`() {
        // ESC[2K clears the line, ESC[1A moves the cursor up — both dropped, leaving only visible text.
        let spans = ANSIParser.parse("\u{1B}[2K\u{1B}[1Aprogress")

        #expect(spans == [ANSISpan(text: "progress", style: .default)])
    }

    @Test func `operating system command sequence is stripped`() {
        // ESC]0;title BEL sets the window title; nothing should render from it.
        let spans = ANSIParser.parse("\u{1B}]0;my title\u{07}done")

        #expect(spans == [ANSISpan(text: "done", style: .default)])
    }

    @Test func `unterminated escape at end of line is dropped`() {
        let spans = ANSIParser.parse("tail\u{1B}[")

        #expect(spans == [ANSISpan(text: "tail", style: .default)])
    }

    @Test func `lone escape at end of line is dropped`() {
        let spans = ANSIParser.parse("tail\u{1B}")

        #expect(spans == [ANSISpan(text: "tail", style: .default)])
    }

    // MARK: - Unicode

    @Test func `multi-scalar graphemes survive parsing`() {
        let spans = ANSIParser.parse("\u{1B}[32m✅ 🍺 café")

        #expect(spans == [ANSISpan(text: "✅ 🍺 café", style: ANSIStyle(foreground: .green))])
    }

    // MARK: - plainText

    @Test func `plainText strips every escape sequence`() {
        let input = "\u{1B}[1;34m==>\u{1B}[0m \u{1B}[32mPouring\u{1B}[0m gh"

        #expect(ANSIParser.plainText(input) == "==> Pouring gh")
    }

    @Test func `plainText on unstyled input is identity`() {
        #expect(ANSIParser.plainText("no codes here") == "no codes here")
    }

    @Test func `plainText on empty input is empty`() {
        #expect(ANSIParser.plainText("") == "")
    }
}
