import BrewCore

public extension PreviewSupport {
    @MainActor
    static func makeCleanupRepository(report: CleanupReport = cleanupReport) -> any CleanupRepository {
        StubCleanupRepository(report: report)
    }

    static let cleanupReport = CleanupReport(
        pruneAll: false,
        unneededFormulae: ["libyaml"],
        removals: [
            CleanupRemoval(path: "/Users/me/Library/Caches/Homebrew/portable-ruby-4.0.7.arm64_big_sur.bottle.tar.gz", kind: .file, size: "12.7MB"),
            CleanupRemoval(path: "/opt/homebrew/Cellar/git/2.45.0", kind: .file, size: "1,632 files, 54.8MB"),
            CleanupRemoval(path: "/opt/homebrew/bin/old-tool", kind: .brokenLink),
        ],
        reclaimableSpace: "67.5MB",
    )

    static let emptyCleanupReport = CleanupReport(pruneAll: false, unneededFormulae: [], removals: [], reclaimableSpace: nil)
}
