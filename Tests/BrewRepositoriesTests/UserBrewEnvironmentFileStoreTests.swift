//
//  UserBrewEnvironmentFileStoreTests.swift
//  BrewRepositoriesTests
//

import BrewCLI
import BrewCore
@testable import BrewRepositories
import BrewRepositoryInterfaces
import Foundation
import Testing

struct UserBrewEnvironmentFileStoreTests {
    private func makeStore() throws -> (UserBrewEnvironmentFileStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("brew.env tests \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("brew.env")
        return (UserBrewEnvironmentFileStore(fileURL: fileURL), fileURL)
    }

    private func read(_ fileURL: URL) throws -> String {
        try String(contentsOf: fileURL, encoding: .utf8)
    }

    // MARK: - Reading

    @Test func `missing file reads as no proxy`() throws {
        let (store, _) = try makeStore()

        let settings = try store.loadProxySettings()

        #expect(settings == .empty)
    }

    @Test func `manual http proxy keys load as an http manual entry`() throws {
        let (store, fileURL) = try makeStore()
        try """
        # personal settings
        HOMEBREW_NO_ANALYTICS=1
        https_proxy=http://127.0.0.1:7890
        no_proxy=localhost,127.0.0.1
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let settings = try store.loadProxySettings()

        #expect(settings.mode == .manual)
        #expect(settings.type == .http)
        #expect(settings.host == "127.0.0.1")
        #expect(settings.port == "7890")
        #expect(settings.noProxy == "localhost,127.0.0.1")
    }

    @Test func `socks proxy keys load as a socks manual entry`() throws {
        let (store, fileURL) = try makeStore()
        try "all_proxy=socks5://127.0.0.1:1080\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let settings = try store.loadProxySettings()

        #expect(settings.mode == .manual)
        #expect(settings.type == .socks)
        #expect(settings.host == "127.0.0.1")
        #expect(settings.port == "1080")
    }

    @Test func `documented lowercase keys win over legacy spellings`() throws {
        let (store, fileURL) = try makeStore()
        try """
        https_proxy=http://standard:1
        HOMEBREW_HTTPS_PROXY=http://prefixed:2
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let settings = try store.loadProxySettings()

        #expect(settings.host == "standard")
        #expect(settings.port == "1")
    }

    // MARK: - Writing

    @Test func `manual http save writes both scheme keys and keeps unrelated lines`() throws {
        let (store, fileURL) = try makeStore()
        try """
        # keep me
        HOMEBREW_NO_ANALYTICS=1
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
            noProxy: "localhost",
        ))

        let body = try read(fileURL)
        #expect(body.contains("# keep me"))
        #expect(body.contains("HOMEBREW_NO_ANALYTICS=1"))
        #expect(body.contains("http_proxy=http://127.0.0.1:7890"))
        #expect(body.contains("https_proxy=http://127.0.0.1:7890"))
        #expect(body.contains("no_proxy=localhost"))
        #expect(body.contains("all_proxy=\n"))
        #expect(!body.contains("HOMEBREW_HTTP"))
    }

    @Test func `manual socks save clears inherited protocol proxies`() throws {
        let (store, fileURL) = try makeStore()

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .socks,
            host: "127.0.0.1",
            port: "1080",
        ))

        let body = try read(fileURL)
        #expect(body.contains("all_proxy=socks5://127.0.0.1:1080"))
        #expect(body.contains("http_proxy=\n"))
        #expect(body.contains("https_proxy=\n"))
    }

    @Test func `switching to no proxy deletes every managed key`() throws {
        let (store, fileURL) = try makeStore()
        try """
        http_proxy=http://127.0.0.1:7890
        https_proxy=http://127.0.0.1:7890
        all_proxy=socks5://127.0.0.1:1080
        no_proxy=localhost
        HOMEBREW_HTTPS_PROXY=http://old:1
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try store.saveProxySettings(.empty)

        let body = try read(fileURL)
        #expect(body.isEmpty || body == "\n")
    }

    @Test func `saving consolidates prefixed twins into standard keys`() throws {
        let (store, fileURL) = try makeStore()
        try """
        HOMEBREW_HTTPS_PROXY=http://old:1
        https_proxy=http://old:2
        HOMEBREW_ALL_PROXY=socks5://old:3
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "new",
            port: "9",
        ))

        let body = try read(fileURL)
        #expect(body.contains("http_proxy=http://new:9"))
        #expect(body.contains("https_proxy=http://new:9"))
        #expect(!body.contains("HOMEBREW_"))
        #expect(body.contains("all_proxy=\n"))
    }

    @Test func `duplicate managed keys collapse to one written value`() throws {
        let (store, fileURL) = try makeStore()
        try """
        https_proxy=http://first:1
        https_proxy=http://second:2
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "third",
            port: "3",
        ))

        let body = try read(fileURL)
        #expect(body.components(separatedBy: "https_proxy=").count == 2)
        #expect(body.contains("https_proxy=http://third:3"))
    }

    @Test func `credentials land in the written URL`() throws {
        let (store, fileURL) = try makeStore()

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
            usesAuthentication: true,
            username: "user",
            password: "pass",
        ))

        let body = try read(fileURL)
        #expect(body.contains("https_proxy=http://user:pass@127.0.0.1:7890"))
    }

    @Test func `invalid ports are rejected and the file is left alone`() throws {
        let (store, fileURL) = try makeStore()
        let original = "https_proxy=http://keep:1\n"
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(throws: UserBrewEnvironmentError.self) {
            try store.saveProxySettings(BrewProxySettings(mode: .manual, host: "127.0.0.1", port: "abc"))
        }

        #expect(try read(fileURL) == original)
    }

    @Test func `newlines in a field are rejected`() throws {
        let (store, _) = try makeStore()

        #expect(throws: UserBrewEnvironmentError.self) {
            try store.saveProxySettings(BrewProxySettings(
                mode: .manual,
                host: "ok",
                port: "1",
                noProxy: "a\nb",
            ))
        }
    }

    @Test func `round trip preserves a complete manual configuration`() throws {
        let (store, _) = try makeStore()
        let settings = BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
            noProxy: "localhost,127.0.0.1,.internal",
            usesAuthentication: true,
            username: "user",
            password: "pass",
        )

        try store.saveProxySettings(settings)

        let loaded = try store.loadProxySettings()
        #expect(loaded.mode == settings.mode)
        #expect(loaded.type == settings.type)
        #expect(loaded.host == settings.host)
        #expect(loaded.port == settings.port)
        #expect(loaded.noProxy == settings.noProxy)
        #expect(loaded.usesAuthentication == settings.usesAuthentication)
        #expect(loaded.username == settings.username)
        #expect(loaded.password == settings.password)
    }

    @Test func `save creates the parent directory when missing`() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing parent \(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("homebrew/brew.env")
        let store = UserBrewEnvironmentFileStore(fileURL: fileURL)

        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: .http,
            host: "127.0.0.1",
            port: "7890",
        ))

        #expect(try store.loadProxySettings().host == "127.0.0.1")
    }

    @Test func `removing user proxies clears lowercase and legacy keys including exclusions`() throws {
        let (store, fileURL) = try makeStore()
        try """
        http_proxy=http://old:1
        https_proxy=http://old:2
        all_proxy=socks5://old:3
        no_proxy=localhost
        HTTPS_PROXY=http://legacy:4
        HOMEBREW_HTTPS_PROXY=http://legacy:5
        # keep this comment
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        try store.saveProxySettings(BrewProxySettings(mode: .none, noProxy: "stale"))

        #expect(try read(fileURL) == "# keep this comment\n")
    }

    @Test(arguments: [BrewProxySettings.ProxyType.http, .socks])
    func `generated proxy files are consumed by the Homebrew loader`(type: BrewProxySettings.ProxyType) async throws {
        let (store, fileURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        try store.saveProxySettings(BrewProxySettings(
            mode: .manual,
            type: type,
            host: "127.0.0.1",
            port: "7890",
            noProxy: "localhost",
        ))

        // Homebrew/brew bin/brew's environment-file contract: lowercase proxy keys and read -r.
        // Run only the loader against a temporary file, never a real Homebrew executable.
        let script = #"""
        export http_proxy=http://inherited:1 https_proxy=http://inherited:2
        export all_proxy=socks5://inherited:3 no_proxy=inherited
        while read -r line; do
            [[ "${line}" =~ ^(HOMEBREW_|SUDO_ASKPASS=|(all|no|ftp|https?)_proxy=) ]] || continue
            export "${line}"
        done <"$1"
        printf '%s\n' "${http_proxy-}" "${https_proxy-}" "${all_proxy-}" "${no_proxy-}"
        """#
        let output = try await BrewCommandService().run(
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            arguments: ["-c", script, "proxy-contract", fileURL.path],
        )
        let expected = type == .http
            ? "http://127.0.0.1:7890\nhttp://127.0.0.1:7890\n\nlocalhost\n"
            : "\n\nsocks5://127.0.0.1:7890\nlocalhost\n"

        #expect(output.terminationStatus == 0)
        #expect(output.standardOutput == expected)
    }

    @Test func `new socks files end with a newline`() throws {
        let (store, fileURL) = try makeStore()
        try store.saveProxySettings(BrewProxySettings(mode: .manual, type: .socks, host: "localhost", port: "1080"))

        #expect(try read(fileURL) == "http_proxy=\nhttps_proxy=\nall_proxy=socks5://localhost:1080\nno_proxy=\n")
    }
}
