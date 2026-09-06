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

    /// The issue items in the order the view renders them — grouped by descending severity — mirroring
    /// `DoctorView`'s `DoctorIssueGroup.grouped(from:)` call. Tests assert against this production
    /// projection rather than a raw `report.issues` mapping.
    private static func displayedItems(_ report: DoctorReport) -> [DoctorIssueItem] {
        DoctorIssueGroup.grouped(from: report).flatMap(\.items)
    }

    @Test func `projects loaded issues and selects the first`() async {
        let report = Self.issuesReport()
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: report))
        await viewModel.load(forceRefresh: true)
        let items = Self.displayedItems(report)

        #expect(viewModel.presentation == .issues)
        #expect(items.count == 2)
        #expect(items.first?.title == "You have unlinked kegs in your Cellar.")
        #expect(items.first?.hasRunnableFix == true)
        #expect(items.last?.hasRunnableFix == false)
        #expect(viewModel.selectedIssueID == items.first?.id)
    }

    @Test func `projects healthy report`() {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: DoctorReport(issues: [])))
        #expect(viewModel.presentation == .healthy)
        #expect(viewModel.orderedIssueIDs.isEmpty)
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
        let report = Self.issuesReport()
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: report))
        let secondID = Self.displayedItems(report)[1].id
        viewModel.setSelection(secondID)
        #expect(viewModel.selectedIssueID == secondID)
        #expect(viewModel.selectedIssue?.title == "Some installed formulae are deprecated.")
    }

    @Test func `runFix submits a doctorFix maintenance operation`() async {
        let report = Self.cleanupReport()
        let center = Self.recordingCenter(cleanupExitCode: 0)
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: report),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )

        viewModel.runFix(for: Self.displayedItems(report)[0])
        let entries = await waitForSubmitEntries(on: center)

        #expect(entries.count == 1)
        #expect(entries.first?.kind == .doctorFix)
        #expect(entries.first?.id == .maintenance(token: "brew cleanup", displayCommand: "brew cleanup"))
    }

    @Test func `isFixRunning is false for an item without a runnable fix`() {
        let report = Self.issuesReport()
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: report))
        // The deprecated-formulae issue (index 1) has no runnable block, so no fix token to track.
        let nonRunnable = Self.displayedItems(report)[1]
        #expect(nonRunnable.fixToken == nil)
        #expect(viewModel.isFixRunning(nonRunnable) == false)
    }

    @Test func `fixError is nil for an item without a runnable fix`() {
        let report = Self.issuesReport()
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: report))
        #expect(viewModel.fixError(Self.displayedItems(report)[1]) == nil)
    }

    @Test func `runFix surfaces an inline error when the fix fails`() async {
        let report = Self.cleanupReport()
        let center = Self.recordingCenter(cleanupExitCode: 1, stderr: "could not clean")
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: report),
            commandCenter: center,
            commandFactory: LiveBrewMutatingCommandFactory(),
        )
        let item = Self.displayedItems(report)[0]

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

        await viewModel.load(forceRefresh: true)

        #expect(viewModel.selectedIssueID == nil)
    }

    @Test func `load with a stale selection resets to the first issue`() async {
        let initial = DoctorReport(issues: [
            Self.minimal(.caution, "first"),
            Self.minimal(.caution, "second"),
            Self.minimal(.caution, "third"),
        ])
        let repository = MutableDoctorRepository(report: initial)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load(forceRefresh: true)
        let thirdID = Self.displayedItems(initial)[2].id
        viewModel.setSelection(thirdID)
        #expect(viewModel.selectedIssueID == thirdID)

        let survivor = Self.minimal(.caution, "only-survivor")
        repository.replace(report: DoctorReport(issues: [survivor]))
        await viewModel.load(forceRefresh: true)

        #expect(viewModel.selectedIssueID == DoctorIssueItem.contentID(for: survivor))
    }

    @Test func `load preserves a still-valid selection`() async {
        let report = DoctorReport(issues: [
            Self.minimal(.caution, "first"),
            Self.minimal(.caution, "second"),
        ])
        let repository = MutableDoctorRepository(report: report)
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load(forceRefresh: true)
        let secondID = Self.displayedItems(report)[1].id
        viewModel.setSelection(secondID)

        await viewModel.load(forceRefresh: true)

        #expect(viewModel.selectedIssueID == secondID)
    }

    @Test func `load follows the selected issue when a different issue is removed`() async {
        let first = Self.minimal(.caution, "first")
        let middle = Self.minimal(.caution, "middle")
        let last = Self.minimal(.caution, "last")
        let repository = MutableDoctorRepository(report: DoctorReport(issues: [first, middle, last]))
        let viewModel = Self.viewModel(repository: repository)

        await viewModel.load(forceRefresh: true)
        let middleID = DoctorIssueItem.contentID(for: middle)
        viewModel.setSelection(middleID)

        // Resolve the first issue; "middle" shifts to index 0 but the selection should follow it.
        repository.replace(report: DoctorReport(issues: [middle, last]))
        await viewModel.load(forceRefresh: true)

        #expect(viewModel.selectedIssueID == middleID)
        #expect(viewModel.selectedIssue?.title == "middle")
    }

    private static func minimal(_ severity: DoctorSeverity, _ title: String) -> DoctorIssue {
        DoctorIssue(title: title, severity: severity, blocks: [], rawBody: "")
    }

    // MARK: - Keyboard navigation

    @Test func `orderedIssueIDs follows grouped descending-severity order`() async {
        let caution = Self.minimal(.caution, "c1")
        let danger = Self.minimal(.danger, "d1")
        let unsupported = Self.minimal(.unsupported, "u1")
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: DoctorReport(issues: [caution, danger, unsupported])),
        )
        await viewModel.load(forceRefresh: true)

        #expect(viewModel.orderedIssueIDs == [
            DoctorIssueItem.contentID(for: unsupported),
            DoctorIssueItem.contentID(for: danger),
            DoctorIssueItem.contentID(for: caution),
        ])
    }

    @Test func `selectNext steps through issues in grouped order and stops at the last`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.threeSeverityReport()))
        await viewModel.load(forceRefresh: true)
        let ordered = viewModel.orderedIssueIDs
        #expect(ordered.count == 3)

        viewModel.setSelection(ordered[0])
        viewModel.selectNext()
        #expect(viewModel.selectedIssueID == ordered[1])
        viewModel.selectNext()
        #expect(viewModel.selectedIssueID == ordered[2])
        // Clamps at the final issue.
        viewModel.selectNext()
        #expect(viewModel.selectedIssueID == ordered[2])
    }

    @Test func `selectPrevious steps backward through issues and stops at the first`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.threeSeverityReport()))
        await viewModel.load(forceRefresh: true)
        let ordered = viewModel.orderedIssueIDs

        viewModel.setSelection(ordered[2])
        viewModel.selectPrevious()
        #expect(viewModel.selectedIssueID == ordered[1])
        viewModel.selectPrevious()
        #expect(viewModel.selectedIssueID == ordered[0])
        // Clamps at the first issue.
        viewModel.selectPrevious()
        #expect(viewModel.selectedIssueID == ordered[0])
    }

    @Test func `selectNext from no selection selects the first issue`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.threeSeverityReport()))
        await viewModel.load(forceRefresh: true)
        viewModel.setSelection(nil)

        viewModel.selectNext()

        #expect(viewModel.selectedIssueID == viewModel.orderedIssueIDs.first)
    }

    @Test func `selectPrevious from no selection selects the last issue`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.threeSeverityReport()))
        await viewModel.load(forceRefresh: true)
        viewModel.setSelection(nil)

        viewModel.selectPrevious()

        #expect(viewModel.selectedIssueID == viewModel.orderedIssueIDs.last)
    }

    @Test func `selectNext is a no-op on a healthy report`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: DoctorReport(issues: [])))
        await viewModel.load(forceRefresh: true)
        #expect(viewModel.selectedIssueID == nil)

        viewModel.selectNext()
        #expect(viewModel.selectedIssueID == nil)
        viewModel.selectPrevious()
        #expect(viewModel.selectedIssueID == nil)
    }

    private static func threeSeverityReport() -> DoctorReport {
        DoctorReport(issues: [
            minimal(.caution, "c1"),
            minimal(.danger, "d1"),
            minimal(.unsupported, "u1"),
        ])
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

    @Test func `subtitle on issues shows "Warnings found" when not refreshing`() {
        let repository = MutableDoctorRepository(report: Self.issuesReport())
        let viewModel = Self.viewModel(repository: repository)

        #expect(viewModel.subtitle == "Warnings found")

        repository.setRefreshing(true)
        #expect(viewModel.subtitle == "Re-checking…")
    }

    @Test func `subtitle on failure shows a generic could-not-complete message`() {
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )
        #expect(viewModel.subtitle == "The check could not be completed")
    }

    // MARK: - shouldFocusList

    @Test func `shouldFocusList is false while the doctor check is running`() {
        let viewModel = Self.viewModel(repository: LoadingDoctorRepository())
        #expect(!viewModel.shouldFocusList)
    }

    @Test func `shouldFocusList is true once a report with issues has loaded`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: Self.issuesReport()))

        await viewModel.load(forceRefresh: true)

        #expect(viewModel.shouldFocusList)
    }

    @Test func `shouldFocusList is true on a healthy report`() async {
        let viewModel = Self.viewModel(repository: StubDoctorRepository(report: DoctorReport(issues: [])))

        await viewModel.load(forceRefresh: true)

        #expect(viewModel.shouldFocusList)
    }

    @Test func `shouldFocusList is false when the doctor check fails`() {
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )

        #expect(!viewModel.shouldFocusList)
    }

    // MARK: - lastCheckedAt

    @Test func `lastCheckedAt dates the report the repository holds`() {
        let checkedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(report: Self.issuesReport(), reportedAt: checkedAt),
        )

        #expect(viewModel.lastCheckedAt == checkedAt)
    }

    @Test func `lastCheckedAt is nil while the first check runs`() {
        #expect(Self.viewModel(repository: LoadingDoctorRepository()).lastCheckedAt == nil)
    }

    /// A failed check dates nothing: the header would otherwise stamp a time on a report that is not there.
    @Test func `lastCheckedAt is nil when the check failed`() {
        let viewModel = Self.viewModel(
            repository: StubDoctorRepository(error: BrewLookupError.executableNotFound),
        )

        #expect(viewModel.lastCheckedAt == nil)
    }
}

/// Test-scoped doctor repository pinned in the `.loading` state. Used to exercise the loading branches of
/// view-model derived state without driving an async load.
@Observable
@MainActor
private final class LoadingDoctorRepository: DoctorRepository {
    let state: LoadState<DoctorReport, any Error> = .loading
    let isRefreshing = false
    let reportedAt: Date? = nil
    func load(forceRefresh _: Bool) async {}
}

/// Test-scoped doctor repository whose report the test can swap between load calls.
@Observable
@MainActor
private final class MutableDoctorRepository: DoctorRepository {
    private(set) var state: LoadState<DoctorReport, any Error>
    private(set) var isRefreshing = false
    private(set) var reportedAt: Date?

    init(report: DoctorReport, reportedAt: Date? = nil) {
        state = .loaded(report)
        self.reportedAt = reportedAt
    }

    func load(forceRefresh _: Bool) async {}

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
