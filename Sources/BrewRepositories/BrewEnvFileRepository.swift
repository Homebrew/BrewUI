//
//  BrewEnvFileRepository.swift
//  BrewRepositories
//

import BrewCLI
import BrewCore
import BrewRepositoryInterfaces
import Foundation

/// Live `EnvFileRepository`: reads `brew.env` from the path Homebrew itself sources, and persists
/// edits atomically (temp file + rename). A missing file is **not** an error — it's an empty
/// `BrewEnvFile`, so the editor opens on a clean slate rather than a failure state.
public struct BrewEnvFileRepository: EnvFileRepository {
    private let locator: BrewEnvFileLocator

    public init(locator: BrewEnvFileLocator) {
        self.locator = locator
    }

    public static func live() -> BrewEnvFileRepository {
        BrewEnvFileRepository(locator: BrewEnvFileLocator())
    }

    public func loadEnvFile() async throws -> BrewEnvFile {
        let url = locator.locate()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BrewEnvFile()
        }
        let data = try Data(contentsOf: url)
        let source = String(bytes: data, encoding: .utf8) ?? ""
        return BrewEnvFileParser.parse(source)
    }

    public func save(_ file: BrewEnvFile) async throws {
        let url = locator.locate()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700],
        )

        let rendered = BrewEnvFileWriter.render(file)
        let data = Data(rendered.utf8)
        // `Data.write(options: .atomic)` writes to a temp sibling and renames into place, so a partial
        // write never overwrites the original — the guarantee the editor relies on. We follow up with a
        // chmod to 0600 since the file may hold `HOMEBREW_GITHUB_API_TOKEN`.
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
