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
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [
                    DoctorBlock(id: 0, caption: nil, content: .prose(["Run brew link on these:"])),
                    DoctorBlock(
                        id: 1,
                        caption: "Run brew link on these:",
                        content: .command([
                            DoctorFixStep(
                                displayCommand: "brew link openssl@3",
                                arguments: ["link", "openssl@3"],
                                needsAdmin: false,
                            ),
                        ]),
                    ),
                ],
                inlineChips: [DoctorBacktickChip(displayCommand: "brew link", arguments: ["link"])],
                rawBody: "",
            ),
            DoctorIssue(
                title: "Some installed formulae are deprecated.",
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [
                    DoctorBlock(id: 0, caption: nil, content: .prose(["Find replacements."])),
                    DoctorBlock(id: 1, caption: nil, content: .data(["macvim"])),
                ],
                inlineChips: [],
                rawBody: "",
            ),
        ])
    }

    private static func cleanupReport() -> DoctorReport {
        DoctorReport(issues: [
            DoctorIssue(
                title: "Some cached downloads are stale.",
                severity: .caution,
                section: .systemAndFormulae,
                blocks: [
                    DoctorBlock(
                        id: 0,
                        caption: nil,
                        content: .command([
                            DoctorFixStep(
                                displayCommand: "brew cleanup",
                                arguments: ["cleanup"],
                                needsAdmin: false,
                            ),
                        ]),
                    ),
                ],
                inlineChips: [],
                rawBody: "",
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
        #expect(viewModel.issueItems.first?.hasRunnableFix == true)
        #expect(viewModel.issueItems.last?.hasRunnableFix == false)
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
