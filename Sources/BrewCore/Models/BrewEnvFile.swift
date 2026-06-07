//
//  BrewEnvFile.swift
//  BrewCore
//

import Foundation

/// Round-trip model of a Homebrew `brew.env` file: an ordered list of lines (entries, comments, blanks)
/// preserved so a save with no edits re-emits the file byte-identically.
///
/// `brew.env` is sourced by `brew` itself on every invocation, so this is the single source of truth for
/// persistent `HOMEBREW_*` settings — see [[project-brewui-product-intent]].
public struct BrewEnvFile: Equatable, Sendable {
    public var lines: [BrewEnvFileLine]

    public init(lines: [BrewEnvFileLine] = []) {
        self.lines = lines
    }

    /// Effective value for `key` (last-wins if duplicated). `nil` when not present.
    public func value(forKey key: String) -> String? {
        var result: String?
        for line in lines {
            if case let .entry(entryKey, entryValue) = line, entryKey == key {
                result = entryValue
            }
        }
        return result
    }

    /// Ordered (key, value) pairs across all entry lines, deduplicated last-wins.
    public var entries: [(key: String, value: String)] {
        var seen: Set<String> = []
        var deduplicated: [(String, String)] = []
        for line in lines.reversed() {
            if case let .entry(key, value) = line, !seen.contains(key) {
                seen.insert(key)
                deduplicated.append((key, value))
            }
        }
        return deduplicated.reversed().map { (key: $0.0, value: $0.1) }
    }

    /// Returns a copy with `key` set to `value` — updates the existing entry in place when present
    /// (preserves comments and blank lines), otherwise appends a new entry at the end.
    public func setting(_ key: String, value: String) -> BrewEnvFile {
        var updatedLines = lines
        var didUpdate = false
        for index in updatedLines.indices {
            if case let .entry(entryKey, _) = updatedLines[index], entryKey == key {
                updatedLines[index] = .entry(key: key, value: value)
                didUpdate = true
            }
        }
        if !didUpdate {
            updatedLines.append(.entry(key: key, value: value))
        }
        return BrewEnvFile(lines: updatedLines)
    }

    /// Returns a copy with every entry for `key` removed. Comments and blanks are untouched.
    public func removing(key: String) -> BrewEnvFile {
        BrewEnvFile(lines: lines.filter {
            if case let .entry(entryKey, _) = $0, entryKey == key {
                return false
            }
            return true
        })
    }
}

/// A single line in a `brew.env` file.
public enum BrewEnvFileLine: Equatable, Sendable {
    /// A `KEY=value` entry, decoded to its raw key and value (no quotes).
    case entry(key: String, value: String)
    /// A comment or otherwise non-entry line, preserved verbatim (including any leading `#`).
    case comment(String)
    /// An empty line, preserved so the file round-trips byte-identically.
    case blank
}
