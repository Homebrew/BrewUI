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

    @MainActor
    private func makeRepository(homeDirectory: URL) -> BrewEnvFileRepository {
        let locator = BrewEnvFileLocator(environment: ["HOME": homeDirectory.path])
        return BrewEnvFileRepository(locator: locator)
    }

    @Test @MainActor func `load returns an empty file when brew_env does not exist`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        await repository.load(forceRefresh: false)

        #expect(repository.state.value?.lines.isEmpty == true)
    }

    @Test @MainActor func `save round-trips through a forced reload`() async throws {
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
        await repository.load(forceRefresh: true)

        // The reloaded file carries `raw` on each entry (the parser captures the on-disk substring).
        // Compare on the user-visible (key, value) shape rather than the raw-bearing line array.
        let reloaded = try #require(repository.state.value)
        #expect(reloaded.entries.map(\.key) == original.entries.map(\.key))
        #expect(reloaded.entries.map(\.value) == original.entries.map(\.value))
    }

    @Test @MainActor func `save updates the cached state immediately`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        let original = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")])

        try await repository.save(original)

        // No `load()` call between save and read — the cache should reflect the in-memory file
        // exactly (no parser round-trip → no `raw` set on the entries).
        #expect(repository.state.value == original)
    }

    @Test @MainActor func `save creates parent directories for a fresh home`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")]))

        let expectedFile = home
            .appendingPathComponent(".homebrew/brew.env")
        #expect(Self.fileManager.fileExists(atPath: expectedFile.path))
    }

    @Test @MainActor func `save sets the file mode to 0600 to protect tokens`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_GITHUB_API_TOKEN", value: "ghp_secret")]))

        let expectedFile = home.appendingPathComponent(".homebrew/brew.env")
        let attributes = try Self.fileManager.attributesOfItem(atPath: expectedFile.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    @Test @MainActor func `existing ~/.homebrew/brew.env is read in place`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let envDir = home.appendingPathComponent(".homebrew")
        try Self.fileManager.createDirectory(at: envDir, withIntermediateDirectories: true)
        let envFile = envDir.appendingPathComponent("brew.env")
        try Data("HOMEBREW_NO_ANALYTICS=1\n".utf8).write(to: envFile)

        let repository = makeRepository(homeDirectory: home)
        await repository.load(forceRefresh: false)

        #expect(repository.state.value?.value(forKey: "HOMEBREW_NO_ANALYTICS") == "1")
    }

    @Test @MainActor func `save replaces an existing file atomically without corruption on overwrite`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")]))

        await repository.load(forceRefresh: true)
        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
    }

    @Test @MainActor func `first save does not create a backup file`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")]))

        let backup = home.appendingPathComponent(".homebrew/brew.env.bak")
        #expect(Self.fileManager.fileExists(atPath: backup.path) == false)
    }

    @Test @MainActor func `subsequent save writes the prior content to a sibling .bak`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))
        let envFile = home.appendingPathComponent(".homebrew/brew.env")
        let firstContents = try String(contentsOf: envFile, encoding: .utf8)

        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")]))

        let backup = home.appendingPathComponent(".homebrew/brew.env.bak")
        let backupContents = try String(contentsOf: backup, encoding: .utf8)
        #expect(backupContents == firstContents)
    }

    @Test @MainActor func `backup file is single-generation and overwrites the previous .bak`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")]))
        let envFile = home.appendingPathComponent(".homebrew/brew.env")
        let secondContents = try String(contentsOf: envFile, encoding: .utf8)

        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "16")]))

        // The .bak should now match the second-save contents, not the first.
        let backup = home.appendingPathComponent(".homebrew/brew.env.bak")
        let backupContents = try String(contentsOf: backup, encoding: .utf8)
        #expect(backupContents == secondContents)
    }

    @Test @MainActor func `save still succeeds when the .bak write fails`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))

        // Pre-occupy brew.env.bak with a directory at the same path so the next save's backup
        // step (a file write) cannot succeed. The main save of brew.env should still go through.
        let backup = home.appendingPathComponent(".homebrew/brew.env.bak")
        try Self.fileManager.createDirectory(at: backup, withIntermediateDirectories: false)

        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")]))

        let envFile = home.appendingPathComponent(".homebrew/brew.env")
        let contents = try String(contentsOf: envFile, encoding: .utf8)
        #expect(contents.contains("HOMEBREW_MAKE_JOBS=8"))
        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")

        // The directory we planted is still there — the failed backup didn't clobber it either.
        var isDirectory: ObjCBool = false
        #expect(Self.fileManager.fileExists(atPath: backup.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
    }

    @Test @MainActor func `backup file is written with 0600 to protect any token in the prior content`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(
            BrewEnvFile(lines: [.entry(key: "HOMEBREW_GITHUB_API_TOKEN", value: "ghp_secret_v1")]),
        )
        try await repository.save(
            BrewEnvFile(lines: [.entry(key: "HOMEBREW_GITHUB_API_TOKEN", value: "ghp_secret_v2")]),
        )

        let backup = home.appendingPathComponent(".homebrew/brew.env.bak")
        let attributes = try Self.fileManager.attributesOfItem(atPath: backup.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.int16Value == 0o600)
    }

    @Test @MainActor func `load is a no-op when state is already loaded and forceRefresh is false`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        // Seed via save (writes the file + updates state).
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))

        // Now overwrite the on-disk file directly behind the repository's back.
        let envFile = home.appendingPathComponent(".homebrew/brew.env")
        try Data("HOMEBREW_MAKE_JOBS=99\n".utf8).write(to: envFile)

        // Cache-first load: shouldn't pick up the external change.
        await repository.load(forceRefresh: false)
        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "4")

        // forceRefresh: picks up the external change.
        await repository.load(forceRefresh: true)
        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "99")
    }

    @Test @MainActor func `invalidate makes the next load refetch without forceRefresh`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))

        // External change.
        let envFile = home.appendingPathComponent(".homebrew/brew.env")
        try Data("HOMEBREW_MAKE_JOBS=99\n".utf8).write(to: envFile)

        repository.invalidate()
        await repository.load(forceRefresh: false)

        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "99")
    }

    @Test @MainActor func `invalidate leaves the cached state visible until the next load`() async throws {
        let home = try makeTempHome()
        defer { try? Self.fileManager.removeItem(at: home) }

        let repository = makeRepository(homeDirectory: home)
        try await repository.save(BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")]))

        repository.invalidate()

        // No load called yet — the previously cached value is still visible.
        #expect(repository.state.value?.value(forKey: "HOMEBREW_MAKE_JOBS") == "4")
    }
}
