//
//  SudoPAMTouchID.swift
//  BrewCLI
//

import Foundation

/// Touch ID for `sudo` is an uncommented `auth sufficient pam_tid.so` line.
/// macOS ships that line commented out in `/etc/pam.d/sudo_local`, which `/etc/pam.d/sudo` includes.
enum SudoPAMTouchID {
    static let configurationURLs = [
        URL(fileURLWithPath: "/etc/pam.d/sudo_local"),
        URL(fileURLWithPath: "/etc/pam.d/sudo"),
    ]

    /// Missing and unreadable files count as disabled so the askpass prompt stays available.
    static func isEnabled(at urls: [URL] = configurationURLs) -> Bool {
        urls.contains { url in
            guard let configuration = try? String(contentsOf: url, encoding: .utf8) else {
                return false
            }
            return configuration.split(whereSeparator: \.isNewline).contains(where: lineEnablesTouchID)
        }
    }

    private static func lineEnablesTouchID(_ line: Substring) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            return false
        }
        let fields = trimmed.split(whereSeparator: \.isWhitespace).prefix(3).map(String.init)
        return fields == ["auth", "sufficient", "pam_tid.so"]
    }
}
