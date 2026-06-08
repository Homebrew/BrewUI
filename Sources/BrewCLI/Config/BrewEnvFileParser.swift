//
//  BrewEnvFileParser.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Round-trip parser for Homebrew's `brew.env` shell-style `KEY=value` syntax.
///
/// Lines unchanged by the user round-trip verbatim — each `.entry` carries the original on-disk
/// substring as `raw`, and the writer emits it as-is. Values are taken verbatim from the substring
/// after the first `=` — `brew` runs `export "${line?}"` without shell-evaluating the value. Lines
/// that don't match `brew`'s load filter (`^(HOMEBREW_|SUDO_ASKPASS=|(all|no|ftp|https?)_proxy=)`)
/// are surfaced as ``BrewEnvFileLine/inert`` — preserved on disk but not exposed as live settings.
public enum BrewEnvFileParser {
    public static func parse(_ source: String) -> BrewEnvFile {
        guard !source.isEmpty else {
            return BrewEnvFile()
        }
        // Strip a single trailing newline so a normal file (which ends with \n) doesn't produce a stray
        // `.blank` line at the end. Multiple trailing newlines are preserved.
        let trimmed = source.hasSuffix("\n") ? String(source.dropLast()) : source
        let rawLines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        return BrewEnvFile(lines: rawLines.map(line(from:)))
    }

    private static func line(from raw: Substring) -> BrewEnvFileLine {
        let hadLeadingWhitespace = raw.first.map { $0 == " " || $0 == "\t" } ?? false
        let trimmedStart = raw.drop { $0 == " " || $0 == "\t" }
        if trimmedStart.isEmpty {
            return .blank
        }
        if trimmedStart.hasPrefix("#") {
            return .comment(String(raw))
        }
        if hasExportPrefix(trimmedStart) {
            return .inert(rawText: String(raw), reason: .hasExportPrefix)
        }
        guard let equalsIndex = trimmedStart.firstIndex(of: "=") else {
            return .comment(String(raw))
        }
        let key = String(trimmedStart[..<equalsIndex])
        guard isValidKey(key) else {
            return .comment(String(raw))
        }
        // Value is taken verbatim from the byte after `=` — `brew` runs `export "${line?}"` without
        // shell-evaluating the value, so any surrounding quotes become *part* of the value.
        let value = String(trimmedStart[trimmedStart.index(after: equalsIndex)...])
        // brew's filter is `^`-anchored, so any leading whitespace fails the match outright — even on
        // an otherwise valid `HOMEBREW_…` line. Classify before the brew-key check so the UI can offer
        // the targeted "drop the indent" remedy rather than the misleading "non-HOMEBREW key" one.
        if hadLeadingWhitespace {
            return .inert(rawText: String(raw), reason: .leadingWhitespace)
        }
        guard matchesBrewLoadFilter(key: key) else {
            return .inert(rawText: String(raw), reason: .nonHomebrewKey)
        }
        return .entry(key: key, value: value, raw: String(raw))
    }

    private static func hasExportPrefix(_ source: Substring) -> Bool {
        source.hasPrefix("export ") || source.hasPrefix("export\t")
    }

    /// `brew.env` keys are shell-style: must start with a letter or underscore, then alphanumerics
    /// or underscores. The brew-load filter is applied separately so that a syntactically-valid line
    /// like `FOO=bar` is still surfaced (as `.inert(.nonHomebrewKey)`) rather than silently dropped.
    private static func isValidKey(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, first.isASCII else {
            return false
        }
        let firstChar = Character(first)
        guard firstChar.isLetter || firstChar == "_" else {
            return false
        }
        return key.unicodeScalars.allSatisfy { scalar in
            guard scalar.isASCII else {
                return false
            }
            let character = Character(scalar)
            return character.isLetter || character.isNumber || character == "_"
        }
    }

    /// Mirrors brew's `^(HOMEBREW_|SUDO_ASKPASS=|(all|no|ftp|https?)_proxy=)` filter, applied to the
    /// parsed key (the `=` portion is implicit — we know we hit `KEY=value` shape).
    private static func matchesBrewLoadFilter(key: String) -> Bool {
        if key.hasPrefix("HOMEBREW_") {
            return true
        }
        switch key {
        case "SUDO_ASKPASS", "all_proxy", "no_proxy", "ftp_proxy", "http_proxy", "https_proxy":
            return true
        default:
            return false
        }
    }
}
