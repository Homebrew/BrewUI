@testable import BrewCLI
import BrewCore
import Foundation
import Testing

struct BrewConfigParserTests {
    /// Captured from a real `brew config` run; covers the header, taps, paths, build settings and system rows.
    private static let fixture = """
    HOMEBREW_VERSION: >=4.3.0 (shallow or no git repository)
    ORIGIN: (none)
    HEAD: (none)
    Last commit: never
    Branch: (none)
    Core tap JSON: 28 May 11:51 UTC
    Core cask tap JSON: 28 May 11:51 UTC
    HOMEBREW_PREFIX: /opt/homebrew
    HOMEBREW_CASK_OPTS: []
    HOMEBREW_DOWNLOAD_CONCURRENCY: 32
    HOMEBREW_FORBID_PACKAGES_FROM_PATHS: set
    HOMEBREW_MAKE_JOBS: 16
    Homebrew Ruby: 4.0.5 => /opt/homebrew/Library/Homebrew/vendor/portable-ruby/4.0.5_1/bin/ruby
    CPU: 16-core 64-bit arm_brava
    Clang: 17.0.0 build 1700
    Git: 2.50.1 => /Applications/Xcode.app/Contents/Developer/usr/bin/git
    Curl: 8.7.1 => /usr/bin/curl
    macOS: 26.5-arm64
    CLT: 16.4.0.0.1.1747106510
    Xcode: 26.3
    Metal Toolchain: N/A
    Rosetta 2: false
    """

    @Test func `parses every key value pair in source order`() {
        let snapshot = BrewConfigParser.parse(Self.fixture)

        #expect(snapshot.entries.count == 22)
        #expect(snapshot.entries.first == BrewConfigEntry(
            key: "HOMEBREW_VERSION",
            value: ">=4.3.0 (shallow or no git repository)",
        ))
        #expect(snapshot.entries.last == BrewConfigEntry(key: "Rosetta 2", value: "false"))
        #expect(snapshot.entries.map(\.key).prefix(3) == ["HOMEBREW_VERSION", "ORIGIN", "HEAD"])
    }

    @Test func `splits on the first colon so values keep their own colons`() {
        let snapshot = BrewConfigParser.parse(Self.fixture)
        let coreTap = try? #require(snapshot.entries.first { $0.key == "Core tap JSON" })

        #expect(coreTap?.value == "28 May 11:51 UTC")
    }

    @Test func `preserves arrow separated tool paths verbatim`() {
        let snapshot = BrewConfigParser.parse(Self.fixture)
        let git = snapshot.entries.first { $0.key == "Git" }

        #expect(git?.value == "2.50.1 => /Applications/Xcode.app/Contents/Developer/usr/bin/git")
    }

    @Test func `keeps unknown and extra keys`() {
        let snapshot = BrewConfigParser.parse(Self.fixture)

        #expect(snapshot.entries.contains(BrewConfigEntry(key: "Metal Toolchain", value: "N/A")))
    }

    @Test func `skips blank lines and lines without a colon`() {
        let output = """
        HOMEBREW_PREFIX: /opt/homebrew

        a malformed line with no separator
        CPU: 8-core
        """

        let snapshot = BrewConfigParser.parse(output)

        #expect(snapshot.entries == [
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
            BrewConfigEntry(key: "CPU", value: "8-core"),
        ])
    }

    @Test func `tolerates missing values`() {
        let snapshot = BrewConfigParser.parse("HEAD:\nBranch: (none)")

        #expect(snapshot.entries == [
            BrewConfigEntry(key: "HEAD", value: ""),
            BrewConfigEntry(key: "Branch", value: "(none)"),
        ])
    }

    @Test func `empty output yields no entries`() {
        #expect(BrewConfigParser.parse("").entries.isEmpty)
    }

    @Test func `parser does not populate environment`() {
        // The repository merges the HOMEBREW_* process environment; the parser only reads stdout.
        #expect(BrewConfigParser.parse(Self.fixture).environment.isEmpty)
    }
}
