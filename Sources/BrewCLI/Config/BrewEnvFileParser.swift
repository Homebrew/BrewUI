//
//  BrewEnvFileParser.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Pure round-trip parser for Homebrew's `brew.env` shell-style `KEY=value` syntax.
///
/// Tolerant by design (`ARCHITECTURE.md` — treat CLI text output as unstable): malformed lines, comments
/// and blanks are preserved as-is so a save with no edits re-emits the original file byte-identically.
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
        let trimmedStart = raw.drop { $0 == " " || $0 == "\t" }
        if trimmedStart.isEmpty {
            return .blank
        }
        if trimmedStart.hasPrefix("#") {
            return .comment(String(raw))
        }

        let body = stripExportPrefix(trimmedStart)
        guard let equalsIndex = body.firstIndex(of: "=") else {
            return .comment(String(raw))
        }

        let key = body[..<equalsIndex].trimmingCharacters(in: .whitespaces)
        guard isValidKey(key) else {
            return .comment(String(raw))
        }

        let rawValue = body[body.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        return .entry(key: key, value: unquote(rawValue))
    }

    private static func stripExportPrefix(_ source: Substring) -> Substring {
        guard source.hasPrefix("export ") || source.hasPrefix("export\t") else {
            return source
        }
        return source.dropFirst("export".count).drop { $0 == " " || $0 == "\t" }
    }

    /// `brew.env` keys are shell-style: must start with a letter or underscore, then alphanumerics
    /// or underscores. We don't require the `HOMEBREW_` prefix here so the parser can faithfully read
    /// any file a user may have written.
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

    /// Strips one matching pair of surrounding single or double quotes. We intentionally don't process
    /// shell escapes — `brew.env` values in practice are simple, and the writer keeps round-trip honest
    /// by re-quoting only what needs quoting.
    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }
        if value.hasPrefix("\""), value.hasSuffix("\"") {
            return String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("'"), value.hasSuffix("'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
