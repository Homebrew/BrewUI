//
//  UserBrewEnvironmentFileStore.swift
//  BrewRepositories
//

import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Line-oriented `brew.env` store for the proxy keys the Configuration tab edits.
///
/// Homebrew's environment files are literal `NAME=value` lines. This store preserves comments,
/// blank lines and unrelated keys, collapses duplicate managed keys to a single entry and writes
/// atomically through a temporary file in the same directory.
public struct UserBrewEnvironmentFileStore: UserBrewEnvironmentStoring, Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/.homebrew/brew.env` — the user-scope file Homebrew documents for personal settings.
    public static func userDefault() -> UserBrewEnvironmentFileStore {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return UserBrewEnvironmentFileStore(
            fileURL: home.appendingPathComponent(".homebrew/brew.env", isDirectory: false),
        )
    }

    /// Homebrew loads lowercase proxy keys from `brew.env`. Legacy spellings are read for migration
    /// and removed on save so they cannot leave a second source of proxy settings behind.
    static let managedKeys: Set<String> = [
        "http_proxy", "HTTP_PROXY", "HOMEBREW_HTTP_PROXY",
        "https_proxy", "HTTPS_PROXY", "HOMEBREW_HTTPS_PROXY",
        "ftp_proxy", "FTP_PROXY", "HOMEBREW_FTP_PROXY",
        "all_proxy", "ALL_PROXY", "HOMEBREW_ALL_PROXY",
        "no_proxy", "NO_PROXY", "HOMEBREW_NO_PROXY",
    ]

    public func loadProxySettings() throws -> BrewProxySettings {
        try Self.proxySettings(from: readLines())
    }

    public func saveProxySettings(_ settings: BrewProxySettings) throws {
        guard let failure = settings.validate().first else {
            let existing = try readLines()
            let rewritten = Self.rewriting(existing, with: settings)
            try writeAtomically(rewritten)
            return
        }
        switch failure {
        case let .newlineInValue(field):
            throw UserBrewEnvironmentError.rejectedValue(field: field)
        case .missingHost, .invalidHost:
            throw UserBrewEnvironmentError.rejectedValue(field: .host)
        case .missingUsername:
            throw UserBrewEnvironmentError.rejectedValue(field: .username)
        case .invalidPort:
            throw UserBrewEnvironmentError.rejectedValue(field: .port)
        }
    }

    // MARK: - Parsing

    private func readLines() throws -> [String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            return raw.components(separatedBy: .newlines)
        } catch {
            throw UserBrewEnvironmentError.unreadable(path: fileURL.path)
        }
    }

    static func proxySettings(from lines: [String]) -> BrewProxySettings {
        var values: [String: String] = [:]
        for line in lines {
            guard let (key, value) = parseAssignment(line) else { continue }
            values[key] = value
        }

        let noProxy = values["no_proxy"] ?? values["NO_PROXY"] ?? values["HOMEBREW_NO_PROXY"] ?? ""
        let httpsProxy: String? = values["https_proxy"] ?? values["HTTPS_PROXY"] ?? values["HOMEBREW_HTTPS_PROXY"]
        let httpProxy: String? = values["http_proxy"] ?? values["HTTP_PROXY"] ?? values["HOMEBREW_HTTP_PROXY"]
        let allProxy: String? = values["all_proxy"] ?? values["ALL_PROXY"] ?? values["HOMEBREW_ALL_PROXY"]
        let ftpProxy: String? = values["ftp_proxy"] ?? values["FTP_PROXY"] ?? values["HOMEBREW_FTP_PROXY"]
        let proxyURLs: [String?] = [httpsProxy, httpProxy, allProxy, ftpProxy]
        let candidates = proxyURLs.compactMap(\.self).filter { !$0.isEmpty }

        guard let primary = candidates.compactMap(BrewProxySettings.parsing(proxyURL:)).first else {
            return BrewProxySettings(mode: .none, noProxy: noProxy)
        }
        var settings = primary
        settings.noProxy = noProxy
        return settings
    }

    private static func parseAssignment(_ line: String) -> (key: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        guard let equals = trimmed.firstIndex(of: "=") else { return nil }
        let key = String(trimmed[..<equals]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        let valueStart = trimmed.index(after: equals)
        return (key, String(trimmed[valueStart...]))
    }

    // MARK: - Rewriting

    /// Replaces the first managed assignment in place, drops later duplicates and appends missing
    /// lowercase keys at the end. Unmanaged lines keep their original text and order.
    static func rewriting(_ lines: [String], with settings: BrewProxySettings) -> [String] {
        var targetValues = managedValues(for: settings)
        var result: [String] = []
        var written = Set<String>()

        for line in lines {
            guard let (key, _) = parseAssignment(line), managedKeys.contains(key) else {
                result.append(line)
                continue
            }
            let standardKey = key.replacingOccurrences(of: "HOMEBREW_", with: "").lowercased()
            guard !written.contains(standardKey), let replacement = targetValues.removeValue(forKey: standardKey) else {
                continue
            }
            written.insert(standardKey)
            result.append("\(standardKey)=\(replacement)")
        }

        for key in ["http_proxy", "https_proxy", "ftp_proxy", "all_proxy", "no_proxy"] {
            guard let value = targetValues.removeValue(forKey: key) else { continue }
            result.append("\(key)=\(value)")
        }
        return result
    }

    /// Standard env keys that should end up in the file for this configuration.
    static func managedValues(for settings: BrewProxySettings) -> [String: String] {
        guard let url = settings.composedURL else {
            return [:]
        }
        var values = ["http_proxy": "", "https_proxy": "", "ftp_proxy": "", "all_proxy": "", "no_proxy": ""]
        values["no_proxy"] = settings.noProxy.trimmingCharacters(in: .whitespacesAndNewlines)
        // Clear inherited protocol-specific proxies before choosing SOCKS, and clear inherited
        // exclusions so the manual form describes every proxy key it writes.
        switch settings.type {
        case .http:
            values["http_proxy"] = url
            values["https_proxy"] = url
            values["ftp_proxy"] = url
        case .socks:
            values["all_proxy"] = url
        }
        return values
    }

    // MARK: - Writing

    private func writeAtomically(_ lines: [String]) throws {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var body = lines.joined(separator: "\n")
            // Homebrew uses `while read -r`, which skips a final line without a newline.
            if !body.isEmpty, !body.hasSuffix("\n") {
                body.append("\n")
            }
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw UserBrewEnvironmentError.unwritable(path: fileURL.path)
        }
    }
}
