//
//  BrewEnvFileWriter.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Renders a ``BrewEnvFile`` back to its on-disk shell representation. Quoting is applied only when
/// the value would otherwise be ambiguous to shell parsing, so an unmodified file round-trips
/// byte-identically through ``BrewEnvFileParser`` ↔ ``BrewEnvFileWriter``.
public enum BrewEnvFileWriter {
    public static func render(_ file: BrewEnvFile) -> String {
        let rendered = file.lines.map(render(line:)).joined(separator: "\n")
        return rendered.isEmpty ? "" : rendered + "\n"
    }

    private static func render(line: BrewEnvFileLine) -> String {
        switch line {
        case .blank:
            ""
        case let .comment(text):
            text
        case let .entry(key, value):
            "\(key)=\(quoteIfNeeded(value))"
        }
    }

    /// Wraps `value` in double quotes when it contains characters that would change shell parsing —
    /// whitespace, comment markers, or syntax that initiates substitution / globbing. Inner double
    /// quotes and backslashes are escaped. An empty value renders as `""`.
    private static func quoteIfNeeded(_ value: String) -> String {
        if value.isEmpty {
            return "\"\""
        }
        if value.unicodeScalars.allSatisfy(isUnquotedSafe) {
            return value
        }
        var escaped = ""
        escaped.reserveCapacity(value.count + 2)
        escaped.append("\"")
        for character in value {
            if character == "\\" || character == "\"" {
                escaped.append("\\")
            }
            escaped.append(character)
        }
        escaped.append("\"")
        return escaped
    }

    private static func isUnquotedSafe(_ scalar: Unicode.Scalar) -> Bool {
        let character = Character(scalar)
        if character.isLetter || character.isNumber {
            return true
        }
        switch character {
        case "_", "-", ".", "/", ":", "@", "+", ",", "=":
            return true
        default:
            return false
        }
    }
}
