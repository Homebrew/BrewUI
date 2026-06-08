//
//  BrewConfigParser.swift
//  BrewCLI
//

import BrewCore
import Foundation

/// Turns `brew config` stdout (`Key: Value` lines) into ordered ``BrewConfigEntry`` values.
///
/// Tolerant by design (`ARCHITECTURE.md` — treat CLI text output as unstable): unknown keys are kept,
/// blank lines and lines without a separating colon are skipped, and only the first colon splits a line
/// so values that themselves contain colons (timestamps, `=>` paths) survive intact.
public enum BrewConfigParser {
    public static func parse(_ output: String) -> BrewConfigSnapshot {
        var entries: [BrewConfigEntry] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colonIndex = line.firstIndex(of: ":") else {
                continue
            }
            let key = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                continue
            }
            entries.append(BrewConfigEntry(key: key, value: value))
        }
        return BrewConfigSnapshot(entries: entries)
    }
}
