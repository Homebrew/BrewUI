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
                rawBody: "",
            ),
            DoctorIssue(
                title: "Some installed formulae are deprecated.",
                severity: .caution,
                blocks: [
                    DoctorBlock(id: 0, caption: nil, content: .prose(["Find replacements."])),
                    DoctorBlock(id: 1, caption: nil, content: .data(["macvim"])),
                ],
                rawBody: "",
            ),
        ])
    }

    private static func cleanupReport() -> DoctorReport {
        DoctorReport(issues: [
            DoctorIssue(
                title: "Some cached downloads are stale.",
                severity: .caution,
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

    @Test func `projects loaded issues and selects the first`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.issuesReport()))
        await viewModel.load()

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

    // MARK: - DoctorIssueGroup.grouped

    @Test func `grouped buckets and orders issues by descending severity`() {
        let report = DoctorReport(issues: [
            Self.minimal(.caution, "c1"),
            Self.minimal(.danger, "d1"),
            Self.minimal(.caution, "c2"),
            Self.minimal(.unsupported, "u1"),
            Self.minimal(.danger, "d2"),
        ])
        let groups = DoctorIssueGroup.grouped(from: report)
        #expect(groups.map(\.severity) == [.unsupported, .danger, .caution])
        #expect(groups[0].items.map(\.title) == ["u1"])
        #expect(groups[1].items.map(\.title) == ["d1", "d2"])
        #expect(groups[2].items.map(\.title) == ["c1", "c2"])
    }

    @Test func `grouped skips empty severity buckets`() {
        let report = DoctorReport(issues: [Self.minimal(.caution, "c1")])
        let groups = DoctorIssueGroup.grouped(from: report)
        #expect(groups.map(\.severity) == [.caution])
    }

    @Test func `grouped returns no groups for an empty report`() {
        let groups = DoctorIssueGroup.grouped(from: DoctorReport(issues: []))
        #expect(groups.isEmpty)
    }

    // MARK: - Selection sync on load

    @Test func `load on an empty report clears the selection`() async {
        let repository = MutableDoctorRepository(report: DoctorReport(issues: []))
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load()

        #expect(viewModel.activeSelectedIssueID == nil)
    }

    @Test func `load with a stale selection resets to the first issue`() async {
        let initial = DoctorReport(issues: [
            Self.minimal(.caution, "first"),
            Self.minimal(.caution, "second"),
            Self.minimal(.caution, "third"),
        ])
        let repository = MutableDoctorRepository(report: initial)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load()
        viewModel.setSelection(2)
        #expect(viewModel.activeSelectedIssueID == 2)

        repository.replace(report: DoctorReport(issues: [Self.minimal(.caution, "only-survivor")]))
        await viewModel.load()

        #expect(viewModel.activeSelectedIssueID == 0)
    }

    @Test func `load preserves a still-valid selection`() async {
        let report = DoctorReport(issues: [
            Self.minimal(.caution, "first"),
            Self.minimal(.caution, "second"),
        ])
        let repository = MutableDoctorRepository(report: report)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load()
        viewModel.setSelection(1)

        await viewModel.load()

        #expect(viewModel.activeSelectedIssueID == 1)
    }

    private static func minimal(_ severity: DoctorSeverity, _ title: String) -> DoctorIssue {
        DoctorIssue(title: title, severity: severity, blocks: [], rawBody: "")
    }

    // MARK: - Header chrome

    @Test func `showsHeaderControls is hidden while loading and on failure`() {
        let loading = Self.viewModel(repository: LoadingDoctorRepository())
        #expect(loading.showsHeaderControls == false)

        let failed = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )
        #expect(failed.showsHeaderControls == false)
    }

    @Test func `showsHeaderControls is visible once a report is on screen`() {
        let healthy = Self.viewModel(repository: StubDoctorRepository(report: DoctorReport(issues: [])))
        #expect(healthy.showsHeaderControls == true)

        let issues = Self.viewModel(repository: StubDoctorRepository(report: Self.issuesReport()))
        #expect(issues.showsHeaderControls == true)
    }

    // MARK: - Subtitle

    @Test func `subtitle while loading describes the running check`() {
        let viewModel = Self.viewModel(repository: LoadingDoctorRepository())
        #expect(viewModel.subtitle == "Running brew doctor…")
    }

    @Test func `subtitle on healthy reflects refresh state`() {
        let repository = MutableDoctorRepository(report: DoctorReport(issues: []))
        let viewModel = Self.viewModel(repository: repository)

        #expect(viewModel.subtitle == "No problems found")

        repository.setRefreshing(true)
        #expect(viewModel.subtitle == "Re-checking…")
    }

    @Test func `subtitle on issues falls back to the issue count when not refreshing`() {
        let repository = MutableDoctorRepository(report: Self.issuesReport())
        let viewModel = Self.viewModel(repository: repository)

        #expect(viewModel.subtitle == "2 issues found")

        repository.setRefreshing(true)
        #expect(viewModel.subtitle == "Re-checking…")
    }

    @Test func `subtitle on failure shows a generic could-not-complete message`() {
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )
        #expect(viewModel.subtitle == "The check could not be completed")
    }
}

/// Test-scoped doctor repository pinned in the `.loading` state. Used to exercise the loading branches of
/// view-model derived state without driving an async load.
@Observable
@MainActor
private final class LoadingDoctorRepository: DoctorRepository {
    let state: LoadState<DoctorReport, any Error> = .loading
    let isRefreshing = false
    func load() async {}
}

/// Test-scoped doctor repository that lets the test swap in a new report between `load()` calls.
/// `load()` is a no-op (the report is supplied directly) so the view model's selection-sync logic
/// runs against whatever state the test has staged.
@Observable
@MainActor
private final class MutableDoctorRepository: DoctorRepository {
    private(set) var state: LoadState<DoctorReport, any Error>
    private(set) var isRefreshing = false

    init(report: DoctorReport) {
        state = .loaded(report)
    }

    func load() async {}

    func replace(report: DoctorReport) {
        state = .loaded(report)
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
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
