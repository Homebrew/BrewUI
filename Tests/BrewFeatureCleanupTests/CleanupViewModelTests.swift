//
//  CleanupViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
@testable import BrewFeatureCleanup
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct CleanupViewModelTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    private static let report = CleanupReport(
        pruneAll: false,
        unneededFormulae: ["libyaml", "m4"],
        removals: [
            CleanupRemoval(path: "/cache/a.tar.gz", kind: .file, size: "12.7MB"),
            CleanupRemoval(path: "/opt/homebrew/bin/old-tool", kind: .brokenLink),
        ],
        reclaimableSpace: "12.7MB",
    )

    private static let emptyReport = CleanupReport(pruneAll: false, unneededFormulae: [], removals: [], reclaimableSpace: nil)

    private static let cacheOnlyReport = CleanupReport(
        pruneAll: false,
        unneededFormulae: [],
        removals: [CleanupRemoval(path: "/cache/a.tar.gz", kind: .file, size: "12.7MB")],
        reclaimableSpace: "12.7MB",
    )

    private static func viewModel(
        repository: any CleanupRepository,
        commandCenter: any BrewCommandCenter = StubBrewCommandCenter(),
    ) -> CleanupViewModel {
        CleanupViewModel(repository: repository, commandCenter: commandCenter, commandFactory: StubMutatingCommandFactory())
    }

    private static func recordingCenter(
        exitCode: Int32,
        stderr: String = "",
        arguments: [String] = ["cleanup"],
    ) -> RecordingSerialBrewCommandCenter {
        let context = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [
                arguments: CommandOutput(standardOutput: "", standardError: stderr, terminationStatus: exitCode),
            ]),
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        return RecordingSerialBrewCommandCenter(executionContext: context)
    }

    @Test func `a report with items is removable`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        #expect(viewModel.presentation == .removable && viewModel.canCleanUp)
    }

    @Test func `an empty report is clean and cannot be cleaned up`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.emptyReport))
        #expect(viewModel.presentation == .clean && !viewModel.canCleanUp)
    }

    @Test func `a failure is worded for the user`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(error: BrewLookupError.executableNotFound))
        #expect(viewModel.presentation == .failed(
            "Could not find Homebrew. Install it or ensure brew is in the default location.",
        ))
    }

    @Test func `the headline quotes Homebrew's total`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        #expect(viewModel.headline(for: Self.report) == "About 12.7MB can be freed")
    }

    @Test func `section titles pick singular or plural copy`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        let single = CleanupReport(
            pruneAll: false,
            unneededFormulae: ["libyaml"],
            removals: [CleanupRemoval(path: "/cache/a.tar.gz", kind: .file)],
            reclaimableSpace: nil,
        )
        #expect([
            viewModel.unneededFormulaeTitle(for: Self.report),
            viewModel.removalsTitle(for: Self.report),
            viewModel.unneededFormulaeTitle(for: single),
            viewModel.removalsTitle(for: single),
        ] == [
            "2 unneeded dependencies",
            "2 old versions, downloads and logs",
            "1 unneeded dependency",
            "1 old version, download or log",
        ])
    }

    @Test func `sizeless rows say why the path is going`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        #expect(viewModel.removalItems(for: Self.report).map(\.detail) == ["12.7MB", "Broken link"])
    }

    @Test func `the confirmation names the formulae it will uninstall`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        #expect(viewModel.uninstallMessage == "This also uninstalls libyaml, m4.")
    }

    @Test func `the confirmation is absent when no formulae are uninstalled`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.cacheOnlyReport))
        #expect(viewModel.uninstallMessage == nil)
    }

    @Test func `clean up is enabled for a cache-only preview`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.cacheOnlyReport))
        #expect(viewModel.canCleanUp)
    }

    @Test func `prune all changes the command shown and re-previews with it`() async {
        let repository = StubCleanupRepository(report: Self.report)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.setPruneAll(true)

        #expect(viewModel.cleanupDisplayCommand == "brew cleanup --prune=all")
        #expect(repository.loadedOptions == [true])
    }

    @Test func `clean up waits for a refresh to finish`() {
        let repository = StubCleanupRepository(report: Self.report)
        repository.isRefreshing = true
        let viewModel = Self.viewModel(repository: repository)
        #expect(!viewModel.canCleanUp)
    }

    @Test func `clean up stays disabled after a failed refresh`() {
        let repository = StubCleanupRepository(report: Self.report)
        repository.refreshFailure = BrewLookupError.executableNotFound
        let viewModel = Self.viewModel(repository: repository)
        #expect(!viewModel.canCleanUp)
    }

    @Test func `clean up waits for a preview made with prune all`() async {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))

        await viewModel.setPruneAll(true)

        #expect(!viewModel.canCleanUp)
    }

    @Test func `prune all runs brew cleanup with --prune=all when the preview matches`() async throws {
        let report = CleanupReport(
            pruneAll: true,
            unneededFormulae: Self.report.unneededFormulae,
            removals: Self.report.removals,
            reclaimableSpace: Self.report.reclaimableSpace,
        )
        let center = Self.recordingCenter(exitCode: 0, arguments: ["cleanup", "--prune=all"])
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: report), commandCenter: center)
        await viewModel.setPruneAll(true)

        try await #require(viewModel.cleanUp()).value

        let entries = await center.recordedSubmitEntries
        #expect(entries.first?.id == .maintenance(token: "cleanup", displayCommand: "brew cleanup --prune=all"))
    }

    @Test func `an empty report offers only Done`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.emptyReport))
        #expect(viewModel.showsDoneButton)
    }

    @Test func `cleaning up runs brew cleanup as a mutating maintenance operation`() async throws {
        let center = Self.recordingCenter(exitCode: 0)
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report), commandCenter: center)

        try await #require(viewModel.cleanUp()).value

        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.kind) == [.cleanup])
        #expect(entries.first?.id == .maintenance(token: "cleanup", displayCommand: "brew cleanup"))
    }

    @Test func `a cache-only preview runs brew cleanup`() async throws {
        let center = Self.recordingCenter(exitCode: 0)
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.cacheOnlyReport), commandCenter: center)

        try await #require(viewModel.cleanUp()).value

        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.kind) == [.cleanup])
    }

    @Test func `an empty report never runs brew cleanup`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.emptyReport))
        #expect(viewModel.cleanUp() == nil)
    }
}
