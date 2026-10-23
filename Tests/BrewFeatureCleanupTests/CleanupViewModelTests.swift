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

    private static func viewModel(
        repository: any CleanupRepository,
        commandCenter: any BrewCommandCenter = StubBrewCommandCenter(),
    ) -> CleanupViewModel {
        CleanupViewModel(repository: repository, commandCenter: commandCenter, commandFactory: StubMutatingCommandFactory())
    }

    private static func recordingCenter(exitCode: Int32, stderr: String = "") -> RecordingSerialBrewCommandCenter {
        let context = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [
                ["cleanup"]: CommandOutput(standardOutput: "", standardError: stderr, terminationStatus: exitCode),
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
        #expect(viewModel.confirmationMessage.contains("libyaml, m4"))
    }

    @Test func `prune all changes the command shown and re-previews with it`() async {
        let repository = StubCleanupRepository(report: Self.report)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.setPruneAll(true)

        #expect(viewModel.cleanupDisplayCommand == "brew cleanup --prune=all")
        #expect(repository.loadedOptions == [true])
    }

    @Test func `requesting a cleanup asks for confirmation first`() {
        let viewModel = Self.viewModel(repository: StubCleanupRepository(report: Self.report))
        viewModel.requestCleanup()
        #expect(viewModel.showsCleanupConfirmation)
    }

    @Test func `cleaning up runs brew cleanup as a mutating maintenance operation`() async {
        let center = Self.recordingCenter(exitCode: 0)
        let repository = StubCleanupRepository(report: Self.report)
        let viewModel = Self.viewModel(repository: repository, commandCenter: center)

        viewModel.cleanUp()
        await waitUntil({ !viewModel.isCleaningUp }, "cleanup finished")

        let entries = await center.recordedSubmitEntries
        #expect(entries.map(\.kind) == [.cleanup])
        #expect(entries.first?.id == .maintenance(token: "cleanup", displayCommand: "brew cleanup"))
    }

    @Test func `a finished cleanup previews again`() async {
        let repository = StubCleanupRepository(report: Self.report)
        let viewModel = Self.viewModel(repository: repository, commandCenter: Self.recordingCenter(exitCode: 0))

        viewModel.cleanUp()
        await waitUntil({ !viewModel.isCleaningUp }, "cleanup finished")

        #expect(repository.loadedOptions == [false])
    }

    @Test func `a failed cleanup shows Homebrew's stderr`() async {
        let viewModel = Self.viewModel(
            repository: StubCleanupRepository(report: Self.report),
            commandCenter: Self.recordingCenter(exitCode: 1, stderr: "Error: Permission denied"),
        )

        viewModel.cleanUp()
        await waitUntil({ !viewModel.isCleaningUp }, "cleanup finished")

        #expect(viewModel.cleanupErrorMessage == "Error: Permission denied")
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    _ description: String,
) async {
    // A deadline rather than a yield count: cleanup awaits the command centre and a reload before it finishes.
    let deadline = ContinuousClock.now + .seconds(5)
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("timed out waiting for \(description)")
}
