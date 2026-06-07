import BrewCLI
import BrewCore
@testable import BrewRepositories
import Foundation
import Testing

struct BrewEnvFileRepositoryTests {
    private static let fileManager = FileManager.default

    private func makeTempHome() throws -> URL {
        let tempHome = Self.fileManager
            .temporaryDirectory
            .appendingPathComponent("brewui-envfile-tests-\(UUID().uuidString)", isDirectory: true)
        try Self.fileManager.createDirectory(at: tempHome, withIntermediateDirectories: true)
        return tempHome
    }

    private func makeRepository(homeDirectory: URL) -> BrewEnvFileRepository {
        let locator = BrewEnvFileLocator(environment: ["HOME": homeDirectory.path])
        return BrewEnvFileRepository(locator: locator)
    }

    @Test func `loadEnvFile returns an empty file when brew_env does not exist`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        let file = try await repository.loadEnvFile()

        #expect(file.lines.isEmpty)
    }

    @Test func `save round-trips through loadEnvFile`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        let original = BrewEnvFile(lines: [
            .comment("# header"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
            .blank,
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
        ])

        try await repository.save(original)
        let reloaded = try await repository.loadEnvFile()

        #expect(reloaded == original)
    }

    @Test func `save creates parent directories for a fresh home`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")]))

        let expectedFile = home
            .appendingPathComponent(".config/homebrew/brew.env")
        #expect(Self.fileManager.fileExists(atPath: expectedFile.path))
    }

    @Test func `save sets the file mode to 0600 to protect tokens`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_GITHUB_API_TOKEN", value: "ghp_secret")]))

        let expectedFile = home.appendingPathComponent(".config/homebrew/brew.env")
        let attributes = try Self.fileManager.attributesOfItem(atPath: expectedFile.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    @Test func `existing legacy ~/.homebrew/brew.env is read in place`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let legacyDir = home.appendingPathComponent(".homebrew")
        try Self.fileManager.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let legacyFile = legacyDir.appendingPathComponent("brew.env")
        try Data("HOMEBREW_NO_ANALYTICS=1\n".utf8).write(to: legacyFile)

        let repository = makeRepository(homeDirectory: home)
        let file = try await repository.loadEnvFile()

        #expect(file.lines == [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
    }

    @Test func `save replaces an existing file atomically without corruption on overwrite`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")]))

        let reloaded = try await repository.loadEnvFile()
        #expect(reloaded.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
    }
}
