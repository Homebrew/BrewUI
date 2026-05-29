@testable import BrewCLI
import BrewCore
import BrewCoreTestSupport
import BrewServicesTestSupport
import Foundation
import Testing

struct BrewExecutableLocatorTests {
    @Test func `findBrewExecutable probes Apple Silicon path before Intel path`() throws {
        let recorder = ProbeRecorder()
        let locator = BrewExecutableLocator { path in
            recorder.append(path)
            return path == "/usr/local/bin/brew"
        }

        let executableURL = try locator.findBrewExecutable()
        let probedPaths = recorder.snapshot()

        #expect(executableURL.path == "/usr/local/bin/brew")
        #expect(probedPaths.first == "/opt/homebrew/bin/brew")
        #expect(probedPaths.contains("/usr/local/bin/brew"))
    }

    @Test func `findBrewExecutable falls back to resolved symlink destination when available`() throws {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]
        guard let originalPath = candidates.first(where: {
            URL(fileURLWithPath: $0).resolvingSymlinksInPath().path != $0
        }) else {
            return
        }

        let resolvedPath = URL(fileURLWithPath: originalPath).resolvingSymlinksInPath().path
        let recorder = ProbeRecorder()
        let locator = BrewExecutableLocator { path in
            recorder.append(path)
            return path == resolvedPath
        }

        let executableURL = try locator.findBrewExecutable()
        let probedPaths = recorder.snapshot()

        #expect(executableURL.path == resolvedPath)
        #expect(probedPaths.contains(originalPath))
        #expect(probedPaths.contains(resolvedPath))
    }

    @Test func `findBrewExecutable throws when neither default path is executable`() {
        let locator = BrewExecutableLocator { _ in false }

        #expect(throws: BrewLookupError.self) {
            try locator.findBrewExecutable()
        }
    }
}

// `paths` is the only mutable state and both accessors take `lock`, so concurrent appends and reads
// are serialised.
// swiftlint:disable:next unchecked_sendable
private final class ProbeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: [String] = []

    func append(_ path: String) {
        lock.lock()
        defer { lock.unlock() }
        paths.append(path)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return paths
    }
}
