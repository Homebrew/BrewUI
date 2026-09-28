//
//  InstalledViewModelBrewfileTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

/// The Installed header's "Save Brewfile…" action: what gates it, what it submits and what it reports.
@MainActor
struct InstalledViewModelBrewfileTests {
    private static let destination = URL(fileURLWithPath: "/tmp/Brewfile")
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    private static func viewModel(
        repository: any InstalledInventoryObserving,
        commandCenter: any BrewCommandCenter = StubBrewCommandCenter(),
        commandFactory: any BrewMutatingCommandFactory = StubMutatingCommandFactory(),
    ) -> InstalledViewModel {
        InstalledViewModel(
            repository: repository,
            preferences: StubInstalledPreferences(),
            brewCommandCenter: commandCenter,
            commandFactory: commandFactory,
        )
    }

    private static func installedRepository() -> StubInstalledPackagesRepository {
        StubInstalledPackagesRepository(packages: [
            InstalledBrewPackage.fixture(name: "wget", kind: .formula),
        ])
    }

    @Test func `save brewfile is offered only once the inventory answered`() {
        #expect(Self.viewModel(repository: Self.installedRepository()).canSaveBrewfile)

        let loading = Self.viewModel(repository: StubInstalledPackagesRepository(state: .loading))
        #expect(!loading.canSaveBrewfile)

        let failed = Self.viewModel(
            repository: StubInstalledPackagesRepository(state: .failed(OddRepositoryError())),
        )
        #expect(!failed.canSaveBrewfile)
    }

    @Test func `save brewfile submits a bundle dump of the chosen file`() async {
        let center = Self.recordingCenter(dumpExitCode: 0)
        let viewModel = Self.viewModel(
            repository: Self.installedRepository(),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.saveBrewfile(to: Self.destination)
        let entries = await waitForSubmitEntries(on: center)

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .bundleDump)
        #expect(entries.first?.id == .maintenance(
            token: "bundleDump",
            displayCommand: "brew bundle dump --file=/tmp/Brewfile --force",
        ))
    }

    @Test func `save brewfile names the destination once the dump succeeds`() async {
        let viewModel = Self.viewModel(
            repository: Self.installedRepository(),
            commandCenter: Self.recordingCenter(dumpExitCode: 0),
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.saveBrewfile(to: Self.destination)
        await waitUntil({ viewModel.brewfileOutcome != nil }, "save outcome")

        #expect(viewModel.brewfileOutcome == .saved(url: Self.destination))
        #expect(!viewModel.isSavingBrewfile)
    }

    @Test func `save brewfile surfaces brew's own stderr when the dump fails`() async {
        let viewModel = Self.viewModel(
            repository: Self.installedRepository(),
            commandCenter: Self.recordingCenter(dumpExitCode: 1, stderr: "Permission denied"),
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.saveBrewfile(to: Self.destination)
        await waitUntil({ viewModel.brewfileOutcome != nil }, "save outcome")

        #expect(viewModel.brewfileOutcome == .failed(message: "Permission denied"))
    }

    @Test func `a second save is ignored while the first dump runs`() async {
        let center = Self.recordingCenter(dumpExitCode: 0)
        let viewModel = Self.viewModel(
            repository: Self.installedRepository(),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.saveBrewfile(to: Self.destination)
        #expect(viewModel.isSavingBrewfile)
        viewModel.saveBrewfile(to: URL(fileURLWithPath: "/tmp/OtherBrewfile"))
        let entries = await waitForSubmitEntries(on: center)

        #expect(entries.count == 1)
    }

    /// Wraps the real serial center so the argv that runs is the one production builds, and the
    /// recorded kind/id prove which operation was submitted.
    private static func recordingCenter(
        dumpExitCode: Int32,
        stderr: String = "",
    ) -> RecordingSerialBrewCommandCenter {
        let ctx = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [
                ["bundle", "dump", "--file=/tmp/Brewfile", "--force"]: CommandOutput(
                    standardOutput: "",
                    standardError: stderr,
                    terminationStatus: dumpExitCode,
                ),
            ]),
            locator: BrewExecutableLocator(overrideURL: brewURL),
        )
        return RecordingSerialBrewCommandCenter(executionContext: ctx)
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool,
    _ description: String,
) async {
    for _ in 0 ..< 500 {
        if condition() {
            return
        }
        await Task.yield()
    }
    Issue.record("timed out waiting for \(description)")
}

@MainActor
private func waitForSubmitEntries(
    on center: RecordingSerialBrewCommandCenter,
) async -> [(id: BrewOperationID, kind: BrewOperationKind)] {
    for _ in 0 ..< 500 {
        let entries = await center.recordedSubmitEntries
        if !entries.isEmpty {
            return entries
        }
        await Task.yield()
    }
    Issue.record("timed out waiting for submit")
    return []
}
