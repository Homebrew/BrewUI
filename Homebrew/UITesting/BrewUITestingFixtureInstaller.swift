//
//  BrewUITestingFixtureInstaller.swift
//  Homebrew
//

import BrewUITestContract
import Foundation

/// Writes the UI-test fixture tree into the app's own temporary directory at launch, so the process
/// that executes the fake `brew` is the one that created it (see ``BrewUITestingFixturePayload``).
nonisolated enum BrewUITestingFixtureInstaller {
    struct Installation {
        let rootURL: URL
        let fakeBrewURL: URL?
        let containerURL: URL
    }

    /// Returns `nil` when the launch carried no payload, keeping callers one `guard` from production.
    static func install(
        payload encoded: String?,
        scenario: String?,
    ) throws -> Installation? {
        guard let encoded, let scenario else {
            return nil
        }
        let payload = try BrewUITestingFixturePayload.decoded(from: encoded)

        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("BrewUITests-\(UUID().uuidString)", isDirectory: true)
        let containerURL = rootURL.appendingPathComponent("container", isDirectory: true)
        try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)

        for (relativePath, contents) in payload.files {
            let fileURL = rootURL.appendingPathComponent(relativePath)
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try contents.write(to: fileURL, options: .atomic)
        }

        var fakeBrewURL: URL?
        if let executable = payload.executable {
            let executableURL = rootURL.appendingPathComponent(executable)
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executableURL.path,
            )
            fakeBrewURL = executableURL
        }

        publish(rootURL: rootURL, scenario: scenario)
        return Installation(rootURL: rootURL, fakeBrewURL: fakeBrewURL, containerURL: containerURL)
    }

    /// `setenv` rather than a stored property: the fake `brew` inherits these as a subprocess, and the
    /// stub `URLProtocol` reads them from a `URLSession` loading thread. Called once, before either runs.
    private static func publish(rootURL: URL, scenario: String) {
        setenv(BrewUITestingEnvironmentKey.fixturesRoot, rootURL.path, 1)
        setenv(BrewUITestingEnvironmentKey.scenario, scenario, 1)
    }
}
