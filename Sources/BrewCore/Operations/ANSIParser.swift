//
//  ANSIParser.swift
//  BrewCore
//

import Foundation

/// One of the sixteen terminal palette colours a `brew` line can request via an SGR escape.
///
/// Kept as a semantic enum rather than a concrete colour so `BrewCore` stays UI-free — the console
/// view layer maps these onto its own palette (`ARCHITECTURE.md` — transparency; command execution).
public enum ANSIColor: Equatable, Sendable {
    case black, red, green, yellow, blue, magenta, cyan, white
    case brightBlack, brightRed, brightGreen, brightYellow
    case brightBlue, brightMagenta, brightCyan, brightWhite
}

/// The visual attributes accumulated from SGR codes seen so far on a line.
///
/// Only the attributes `brew` actually emits (foreground colour + bold) are modelled; background,
/// underline, and 256-colour/truecolour codes are consumed but not represented (they degrade to the
/// default appearance rather than rendering as garbage).
public struct ANSIStyle: Equatable, Sendable {
    public var foreground: ANSIColor?
    public var bold: Bool

    public init(foreground: ANSIColor? = nil, bold: Bool = false) {
        self.foreground = foreground
        self.bold = bold
    }

    /// The appearance at the start of a line, before any SGR code is applied.
    public static let `default` = ANSIStyle()
}

/// A run of visible text that shares a single ``ANSIStyle``.
public struct ANSISpan: Equatable, Sendable {
    public let text: String
    public let style: ANSIStyle

    public init(text: String, style: ANSIStyle) {
        self.text = text
        self.style = style
    }
}

/// Parses ANSI SGR (Select Graphic Rendition) escape sequences out of a line of `brew` output into
/// styled spans the console can render.
///
/// Scope is deliberately per-line: each line is parsed from the default style, matching how the
/// console renders one discrete row per ``BrewCommandOutputLine``. Cursor-movement and screen-control
/// sequences (the live progress "UI") are stripped here — interpreting them is a later, TTY-backed
/// step. Malformed or unsupported sequences are dropped so they never surface as literal text.
public enum ANSIParser {
    private static let escape: Unicode.Scalar = "\u{1B}"

    /// Splits `input` into styled spans. Returns an empty array for empty input; input with no escape
    /// sequences yields a single default-styled span.
    public static func parse(_ input: String) -> [ANSISpan] {
        guard !input.isEmpty else {
            return []
        }

        var spans: [ANSISpan] = []
        var style = ANSIStyle.default
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else {
                return
            }
            spans.append(ANSISpan(text: buffer, style: style))
            buffer = ""
        }

        let scalars = Array(input.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            guard scalar == escape else {
                buffer.unicodeScalars.append(scalar)
                index += 1
                continue
            }

            let (next, sgrParameters) = skipEscape(scalars, from: index)
            if let sgrParameters {
                let newStyle = apply(sgrParameters, to: style)
                if newStyle != style {
                    flush()
                    style = newStyle
                }
            }
            index = next
        }

        flush()
        return spans
    }

    /// The visible text of `input` with every escape sequence removed. Convenience over
    /// ``parse(_:)`` for clipboard / file export where styling is irrelevant.
    public static func plainText(_ input: String) -> String {
        parse(input).map(\.text).joined()
    }

    private static func skipEscape(
        _ scalars: [Unicode.Scalar],
        from start: Int,
    ) -> (next: Int, sgrParameters: String?) {
        let afterEscape = start + 1
        guard afterEscape < scalars.count else {
            return (next: scalars.count, sgrParameters: nil)
        }

        switch scalars[afterEscape] {
        case "[":
            return skipControlSequence(scalars, paramsStart: afterEscape + 1)
        case "]":
            return (next: skipOperatingSystemCommand(scalars, from: afterEscape + 1), sgrParameters: nil)
        default:
            // Two-byte escape such as ESC ( or ESC =; drop ESC and the byte that follows it.
            return (next: afterEscape + 1, sgrParameters: nil)
        }
    }

    private static func skipControlSequence(
        _ scalars: [Unicode.Scalar],
        paramsStart: Int,
    ) -> (next: Int, sgrParameters: String?) {
        var cursor = paramsStart
        var parameters = ""
        while cursor < scalars.count {
            let scalar = scalars[cursor]
            // Final bytes are in 0x40...0x7E; parameter/intermediate bytes (digits, ';', ' ', etc.) precede them.
            if scalar.value >= 0x40, scalar.value <= 0x7E {
                let isSGR = scalar == "m"
                return (next: cursor + 1, sgrParameters: isSGR ? parameters : nil)
            }
            parameters.unicodeScalars.append(scalar)
            cursor += 1
        }
        return (next: scalars.count, sgrParameters: nil)
    }

    /// Skips an OSC sequence, which runs until BEL (0x07) or the ST terminator (ESC `\`).
    private static func skipOperatingSystemCommand(_ scalars: [Unicode.Scalar], from start: Int) -> Int {
        var cursor = start
        while cursor < scalars.count {
            if scalars[cursor] == "\u{07}" {
                return cursor + 1
            }
            if scalars[cursor] == escape, cursor + 1 < scalars.count, scalars[cursor + 1] == "\\" {
                return cursor + 2
            }
            cursor += 1
        }
        return scalars.count
    }

    /// Applies one SGR parameter string to `style`. An empty parameter string is treated as a reset
    /// (`ESC[m` == `ESC[0m`).
    private static func apply(_ parameters: String, to style: ANSIStyle) -> ANSIStyle {
        let codes = parameters.isEmpty
            ? [0]
            : parameters.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }

        var result = style
        var index = 0
        while index < codes.count {
            let code = codes[index]
            switch code {
            case 0:
                result = .default
            case 1:
                result.bold = true
            case 22:
                result.bold = false
            case 30...37:
                result.foreground = standardColor(forOffset: code - 30)
            case 39:
                result.foreground = nil
            case 90...97:
                result.foreground = brightColor(forOffset: code - 90)
            case 38:
                // Extended foreground (256-colour/truecolour): consume the introducer's arguments so the
                // following codes aren't misread, but leave the foreground at default rather than approximate.
                index += extendedColorArgumentCount(after: codes, from: index)
                result.foreground = nil
            default:
                break
            }
            index += 1
        }
        return result
    }

    /// The number of parameters the caller should skip past a `38`/`48` extended-colour introducer,
    /// based on its selector (`5` = 256-colour, one arg; `2` = truecolour, three args).
    private static func extendedColorArgumentCount(after codes: [Int], from index: Int) -> Int {
        guard index + 1 < codes.count else {
            return 0
        }
        switch codes[index + 1] {
        case 5:
            return 2
        case 2:
            return 4
        default:
            return 1
        }
    }

    private static func standardColor(forOffset offset: Int) -> ANSIColor? {
        [.black, .red, .green, .yellow, .blue, .magenta, .cyan, .white][safe: offset]
    }

    private static func brightColor(forOffset offset: Int) -> ANSIColor? {
        [
            .brightBlack, .brightRed, .brightGreen, .brightYellow,
            .brightBlue, .brightMagenta, .brightCyan, .brightWhite,
        ][safe: offset]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
