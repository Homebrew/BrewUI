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
        report: DoctorReport,
        commandCenter: any BrewCommandCenter = StubBrewCommandCenter(),
        commandFactory: any BrewMutatingCommandFactory = StubMutatingCommandFactory(),
    ) -> DoctorViewModel {
        DoctorViewModel(
            doctorRepository: StubDoctorRepository(report: report),
            brewCommandCenter: commandCenter,
            commandFactory: commandFactory,
        )
    }

    @Test func `initial state is idle`() {
        let viewModel = Self.viewModel(report: Self.issuesReport())
        #expect(viewModel.presentation == .idle)
        #expect(viewModel.issueItems.isEmpty)
    }

    @Test func `run loads issues and selects the first`() async {
        let viewModel = Self.viewModel(report: Self.issuesReport())
        viewModel.run()
        await waitUntil({ viewModel.presentation == .issues }, "issues loaded")

        #expect(viewModel.issueItems.count == 2)
        #expect(viewModel.issueItems.first?.title == "You have unlinked kegs in your Cellar.")
        #expect(viewModel.issueItems.first?.hasFix == true)
        #expect(viewModel.issueItems.last?.hasFix == false)
        #expect(viewModel.activeSelectedIssueID == 0)
        #expect(viewModel.issueCountSubtitle == "2 issues found")
    }

    @Test func `run with healthy report shows healthy state`() async {
        let viewModel = Self.viewModel(report: DoctorReport(issues: []))
        viewModel.run()
        await waitUntil({ viewModel.presentation == .healthy }, "healthy state")
        #expect(viewModel.issueItems.isEmpty)
    }

    @Test func `run failure surfaces a user-facing message`() async {
        let viewModel = DoctorViewModel(
            doctorRepository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )
        viewModel.run()
        await waitUntil({ isFailed(viewModel.presentation) }, "failure")
        #expect(viewModel.presentation == .failed(
            "Could not find Homebrew. Install it or ensure brew is in the default location.",
        ))
    }

    @Test func `setSelection changes the selected issue`() async {
        let viewModel = Self.viewModel(report: Self.issuesReport())
        viewModel.run()
        await waitUntil({ viewModel.presentation == .issues }, "issues loaded")

        viewModel.setSelection(1)
        #expect(viewModel.activeSelectedIssueID == 1)
        #expect(viewModel.selectedIssue?.title == "Some installed formulae are deprecated.")
    }

    @Test func `runFix submits a doctorFix maintenance operation`() async {
        let center = Self.recordingCenter(cleanupExitCode: 0)
        let viewModel = Self.viewModel(
            report: Self.cleanupReport(),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )
        viewModel.run()
        await waitUntil({ viewModel.presentation == .issues }, "issues loaded")

        viewModel.runFix(for: viewModel.issueItems[0])
        let entries = await waitForSubmitEntries(on: center)

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .doctorFix)
        #expect(entries.first?.id == .maintenance(token: "brew cleanup", displayCommand: "brew cleanup"))
    }

    @Test func `runFix surfaces an inline error when the fix fails`() async {
        let center = Self.recordingCenter(cleanupExitCode: 1, stderr: "could not clean")
        let viewModel = Self.viewModel(
            report: Self.cleanupReport(),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )
        viewModel.run()
        await waitUntil({ viewModel.presentation == .issues }, "issues loaded")
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

private func isFailed(_ presentation: DoctorPresentation) -> Bool {
    if case .failed = presentation {
        return true
    }
    return false
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
