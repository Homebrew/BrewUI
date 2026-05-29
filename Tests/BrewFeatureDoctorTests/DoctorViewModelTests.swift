//
//  DoctorViewModelTests.swift
//  BrewTests
//

import BrewCLI
import BrewCore
@testable import BrewFeatureDoctor
import BrewRepositoryInterfaces
import BrewServicesTestSupport
import Foundation
import Testing

@MainActor
struct DoctorViewModelTests {
    private static let brewURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")

    private static func issuesReport() -> DoctorReport {
        DoctorReport(issues: [
            DoctorIssue(
                title: "You have unlinked kegs in your Cellar.",
                details: "Run brew link on these:",
                affectedItems: ["openssl@3"],
                suggestedFix: DoctorSuggestedFix(
                    arguments: ["link", "openssl@3"],
                    displayCommand: "brew link openssl@3",
                ),
            ),
            DoctorIssue(
                title: "Some installed formulae are deprecated.",
                details: "Find replacements.",
                affectedItems: ["macvim"],
                suggestedFix: nil,
            ),
        ])
    }

    private static func cleanupReport() -> DoctorReport {
        DoctorReport(issues: [
            DoctorIssue(
                title: "Some cached downloads are stale.",
                details: "Run brew cleanup.",
                affectedItems: [],
                suggestedFix: DoctorSuggestedFix(arguments: ["cleanup"], displayCommand: "brew cleanup"),
            ),
        ])
    }

    private static func viewModel(
        repository: any DoctorRepository,
        commandCenter: any BrewCommandCenter = StubBrewCommandCenter(),
        commandFactory: any BrewMutatingCommandFactory = StubMutatingCommandFactory(),
    ) -> DoctorViewModel {
        DoctorViewModel(
            doctorRepository: repository,
            brewCommandCenter: commandCenter,
            commandFactory: commandFactory,
        )
    }

    @Test func `projects loaded issues and selects the first`() {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.issuesReport()))

        #expect(viewModel.presentation == .issues)
        #expect(viewModel.issueItems.count == 2)
        #expect(viewModel.issueItems.first?.title == "You have unlinked kegs in your Cellar.")
        #expect(viewModel.issueItems.first?.hasFix == true)
        #expect(viewModel.issueItems.last?.hasFix == false)
        #expect(viewModel.activeSelectedIssueID == 0)
        #expect(viewModel.issueCountSubtitle == "2 issues found")
    }

    @Test func `projects healthy report`() {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: DoctorReport(issues: [])))
        #expect(viewModel.presentation == .healthy)
        #expect(viewModel.issueItems.isEmpty)
    }

    @Test func `projects a failure into a user-facing message`() {
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )
        #expect(viewModel.presentation == .failed(
            "Could not find Homebrew. Install it or ensure brew is in the default location.",
        ))
    }

    @Test func `setSelection changes the selected issue`() {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.issuesReport()))
        viewModel.setSelection(1)
        #expect(viewModel.activeSelectedIssueID == 1)
        #expect(viewModel.selectedIssue?.title == "Some installed formulae are deprecated.")
    }

    @Test func `runFix submits a doctorFix maintenance operation`() async {
        let center = Self.recordingCenter(cleanupExitCode: 0)
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: Self.cleanupReport()),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.runFix(for: viewModel.issueItems[0])
        let entries = await waitForSubmitEntries(on: center)

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .doctorFix)
        #expect(entries.first?.id == .maintenance(token: "brew cleanup", displayCommand: "brew cleanup"))
    }

    @Test func `runFix surfaces an inline error when the fix fails`() async {
        let center = Self.recordingCenter(cleanupExitCode: 1, stderr: "could not clean")
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: Self.cleanupReport()),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )
        let item = viewModel.issueItems[0]

        viewModel.runFix(for: item)
        await waitUntil({ viewModel.fixError(item) != nil }, "fix error surfaced")
        #expect(viewModel.fixError(item) == "could not clean")
    }

    private static func recordingCenter(
        cleanupExitCode: Int32,
        stderr: String = "",
    ) -> RecordingSerialBrewCommandCenter {
        let ctx = BrewCommandExecutionContext(
            commandRunner: MockBrewCommandRunner(responses: [
                ["cleanup"]: CommandOutput(
                    standardOutput: "",
                    standardError: stderr,
                    terminationStatus: cleanupExitCode,
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
