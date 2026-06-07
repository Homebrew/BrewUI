//
//  BrewEnvFile.swift
//  BrewCore
//

import Foundation

/// Round-trip model of a Homebrew `brew.env` file: an ordered list of lines (entries, inert lines,
/// comments, blanks).
///
/// Lines that were not edited round-trip verbatim — `BrewEnvFileParser` stashes the original on-disk
/// substring on each `.entry`, and `BrewEnvFileWriter` re-emits that substring when present. Edited
/// entries are re-rendered in the unquoted `KEY=value` form `brew` expects.
public struct BrewEnvFile: Equatable, Sendable {
    public var lines: [BrewEnvFileLine]

    public init(lines: [BrewEnvFileLine] = []) {
        self.lines = lines
    }

    /// Effective value `brew` would see for `key` (last-wins if duplicated). `nil` when not present.
    /// Only `.entry` lines count — `.inert` lines exist on disk but `brew` won't load them.
    public func value(forKey key: String) -> String? {
        var result: String?
        for line in lines {
            if case let .entry(entryKey, entryValue, _) = line, entryKey == key {
                result = entryValue
            }
        }
        return result
    }

    /// Ordered (key, value) pairs across all `.entry` lines, deduplicated last-wins. Inert lines are
    /// excluded — they exist on disk but `brew` won't load them.
    public var entries: [(key: String, value: String)] {
        var seen: Set<String> = []
        var deduplicated: [(String, String)] = []
        for line in lines.reversed() {
            if case let .entry(key, value, _) = line, !seen.contains(key) {
                seen.insert(key)
                deduplicated.append((key, value))
            }
        }
        return deduplicated.reversed().map { (key: $0.0, value: $0.1) }
    }

    /// Returns a copy with `key` set to `value` — updates the existing entry in place when present
    /// (preserves comments, blanks, and inert lines), otherwise appends a new entry at the end.
    ///
    /// When the value actually changes, the entry's cached `raw` is cleared so the writer re-renders
    /// the line in canonical form. When the value is unchanged, `raw` is preserved so the file stays
    /// byte-identical on disk.
    public func setting(_ key: String, value: String) -> BrewEnvFile {
        var updatedLines = lines
        var didUpdate = false
        for index in updatedLines.indices {
            if case let .entry(entryKey, oldValue, oldRaw) = updatedLines[index], entryKey == key {
                let preservedRaw: String? = (oldValue == value) ? oldRaw : nil
                updatedLines[index] = .entry(key: key, value: value, raw: preservedRaw)
                didUpdate = true
            }
        }
        if !didUpdate {
            updatedLines.append(.entry(key: key, value: value, raw: nil))
        }
        return BrewEnvFile(lines: updatedLines)
    }

    /// Returns a copy with every `.entry` for `key` removed. Comments, blanks, and inert lines are
    /// untouched.
    public func removing(key: String) -> BrewEnvFile {
        BrewEnvFile(lines: lines.filter {
            if case let .entry(entryKey, _, _) = $0, entryKey == key {
                return false
            }
            return true
        })
    }
}

/// A single line in a `brew.env` file.
public enum BrewEnvFileLine: Equatable, Sendable {
    /// A `KEY=value` line that `brew` will load. `raw` is the original on-disk line when the entry
    /// came from the parser; `nil` after a programmatic edit so the writer re-renders canonical form.
    case entry(key: String, value: String, raw: String? = nil)
    /// A `KEY=value`-shaped line that `brew` will *not* load. Preserved verbatim so saving a
    /// hand-edited file doesn't silently drop content — see ``InertReason``.
    case inert(rawText: String, reason: InertReason)
    /// A comment or otherwise malformed line, preserved verbatim (including any leading `#`).
    case comment(String)
    /// An empty line, preserved so the file round-trips verbatim.
    case blank
}

/// Why a line is inert from `brew`'s perspective. `brew` master filters each line with
/// `^(HOMEBREW_|SUDO_ASKPASS=|(all|no|ftp|https?)_proxy=)` before exporting — note the `^` anchor.
/// Anything not matching that exact start is on disk but never effective. We surface the distinction
/// so the UI can suggest a fix.
public enum InertReason: Equatable, Sendable {
    /// Line starts with `export …`. brew's regex rejects it; the user almost always meant to drop the
    /// prefix.
    case hasExportPrefix
    /// Key isn't `HOMEBREW_…`, `SUDO_ASKPASS`, or one of the lowercase proxy vars brew loads.
    case nonHomebrewKey
    /// Line starts with whitespace before the key. brew's regex is `^`-anchored, so any leading space
    /// or tab fails the match — the line never reaches `export`. Dropping the indent is the fix.
    case leadingWhitespace
}
