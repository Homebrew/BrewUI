//
//  InstalledPackagesParser.swift
//  Brew
//

import Foundation

/// Tolerant parsing of `brew list --versions` stdout (`ARCHITECTURE.md` — CLI text is unstable).
enum InstalledPackagesParser {
    static func parseListVersionsOutput(_ output: String) -> [InstalledPackageInfo] {
        var rows: [InstalledPackageInfo] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let name = parts.first else {
                continue
            }
            let version: String? = if parts.count > 1 {
                parts.dropFirst().joined(separator: " ")
            } else {
                nil
            }
            rows.append(InstalledPackageInfo(name: name, version: version))
        }
        return rows.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
