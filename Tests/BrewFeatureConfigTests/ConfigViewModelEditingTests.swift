import BrewCore
@testable import BrewFeatureConfig
import BrewRepositoryInterfaces
import Foundation
import Testing

struct ConfigViewModelEditingTests {
    private static let snapshot = BrewConfigSnapshot(
        entries: [
            BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
        ],
        environment: [
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
        ],
    )

    private func makeViewModel(
        envFile: BrewEnvFile = BrewEnvFile(),
        processEnvironment: [String: String] = ["SHELL": "/bin/zsh"],
    ) -> (ConfigViewModel, StubEnvFileRepository) {
        let envRepo = StubEnvFileRepository(file: envFile)
        let viewModel = ConfigViewModel(
            repository: StubConfigRepository(snapshot: Self.snapshot),
            envFileRepository: envRepo,
            processEnvironment: processEnvironment,
        )
        return (viewModel, envRepo)
    }

    // MARK: - pageState

    @Test @MainActor func `pageState bundles the snapshot and env file when both are loaded`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")])
        let (viewModel, _) = makeViewModel(envFile: envFile)

        await viewModel.load()

        guard case let .loaded(payload) = viewModel.pageState else {
            Issue.record("expected pageState .loaded")
            return
        }
        #expect(payload.snapshot == Self.snapshot)
        #expect(payload.envFile == envFile)
    }

    @Test @MainActor func `pageState is loading until both halves have loaded`() {
        let viewModel = ConfigViewModel(
            repository: StubConfigRepository(state: .loading),
            envFileRepository: StubEnvFileRepository(state: .loading),
            processEnvironment: [:],
        )

        guard case .loading = viewModel.pageState else {
            Issue.record("expected pageState .loading")
            return
        }
    }

    @Test @MainActor func `pageState surfaces a config load failure as a user-facing message`() async {
        let viewModel = ConfigViewModel(
            repository: ThrowingPageStateConfigRepository(
                error: BrewCommandError.failed(exitCode: 1, stderr: "boom"),
            ),
            envFileRepository: StubEnvFileRepository(),
        )

        await viewModel.load()

        guard case let .failed(message) = viewModel.pageState else {
            Issue.record("expected pageState .failed")
            return
        }
        #expect(message == "boom")
    }

    @Test @MainActor func `sections(for:) is cache-independent so AsyncContentView placeholders render`() async {
        let viewModel = ConfigViewModel(
            repository: StubConfigRepository(state: .loading),
            envFileRepository: StubEnvFileRepository(state: .loading),
            processEnvironment: [:],
        )

        // No load called — state is .loading, but feeding the placeholder snapshot still produces rows.
        let rows = viewModel.sections(for: ConfigPagePayload.placeholder.snapshot)
        #expect(!rows.isEmpty)
        #expect(rows.contains { $0.id == "homebrew" })
    }

    // MARK: - Cache integration

    @Test @MainActor func `draft is seeded from the cached env file on init`() async {
        // Mirrors the "user switches back to the Configuration tab during a session" case where the
        // repository already holds a `.loaded` value before the view re-creates the VM. The editor
        // shouldn't render a transiently empty draft while .task is still in flight.
        let envFile = BrewEnvFile(lines: [
            .entry(key: "HOMEBREW_MAKE_JOBS", value: "8"),
            .entry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ])
        let viewModel = ConfigViewModel(
            repository: StubConfigRepository(snapshot: Self.snapshot),
            envFileRepository: StubEnvFileRepository(file: envFile),
            processEnvironment: ["SHELL": "/bin/zsh"],
        )

        #expect(viewModel.draft == envFile)
        #expect(!viewModel.isDirty)
    }

    // MARK: - Row classification

    @Test @MainActor func `allowlist row with no shell override is editable with its descriptor kind`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()

        let row = try? #require(viewModel.envRows.first { $0.key == "HOMEBREW_NO_ANALYTICS" })
        #expect(row?.status == .editable(.toggle))
        #expect(row?.provenance == .defaultValue)
        #expect(row?.descriptor?.label == "Disable analytics")
    }

    @Test @MainActor func `allowlist row shadowed by shell is read-only with rc hint`() async {
        let (viewModel, _) = makeViewModel(
            processEnvironment: ["SHELL": "/bin/zsh", "HOMEBREW_NO_ANALYTICS": "1"],
        )

        await viewModel.load()

        let row = try? #require(viewModel.envRows.first { $0.key == "HOMEBREW_NO_ANALYTICS" })
        #expect(row?.status == .readOnlyShellOverridden(rcHint: "~/.zshrc"))
        #expect(row?.provenance == .shell)
        // The descriptor stays attached so the UI keeps the label and help copy.
        #expect(row?.descriptor != nil)
        #expect(row?.value == "1")
    }

    @Test @MainActor func `install-time row is read-only regardless of shell or file state`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_PREFIX", value: "/nope")])
        let (viewModel, _) = makeViewModel(
            envFile: envFile,
            processEnvironment: ["SHELL": "/bin/zsh", "HOMEBREW_PREFIX": "/opt/homebrew"],
        )

        await viewModel.load()

        let row = try? #require(viewModel.envRows.first { $0.key == "HOMEBREW_PREFIX" })
        #expect(row?.status == .readOnlyInstallTime)
    }

    @Test @MainActor func `shell rc hint maps zsh to .zshrc`() async {
        let (viewModel, _) = makeViewModel(
            processEnvironment: ["SHELL": "/bin/zsh", "HOMEBREW_NO_AUTO_UPDATE": "1"],
        )
        await viewModel.load()
        let row = viewModel.envRows.first { $0.key == "HOMEBREW_NO_AUTO_UPDATE" }
        #expect(row?.status == .readOnlyShellOverridden(rcHint: "~/.zshrc"))
    }

    @Test @MainActor func `shell rc hint maps bash to .bash_profile`() async {
        let (viewModel, _) = makeViewModel(
            processEnvironment: ["SHELL": "/bin/bash", "HOMEBREW_NO_AUTO_UPDATE": "1"],
        )
        await viewModel.load()
        let row = viewModel.envRows.first { $0.key == "HOMEBREW_NO_AUTO_UPDATE" }
        #expect(row?.status == .readOnlyShellOverridden(rcHint: "~/.bash_profile"))
    }

    @Test @MainActor func `shell rc hint maps fish to config.fish`() async {
        let (viewModel, _) = makeViewModel(
            processEnvironment: ["SHELL": "/opt/homebrew/bin/fish", "HOMEBREW_NO_AUTO_UPDATE": "1"],
        )
        await viewModel.load()
        let row = viewModel.envRows.first { $0.key == "HOMEBREW_NO_AUTO_UPDATE" }
        #expect(row?.status == .readOnlyShellOverridden(rcHint: "~/.config/fish/config.fish"))
    }

    // MARK: - Editing

    @Test @MainActor func `setValue mutates the draft and flips isDirty`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        #expect(!viewModel.isDirty)

        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")

        #expect(viewModel.isDirty)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
    }

    @Test @MainActor func `setValue is a no-op on shell-overridden keys`() async {
        let (viewModel, _) = makeViewModel(
            processEnvironment: ["SHELL": "/bin/zsh", "HOMEBREW_NO_ANALYTICS": "1"],
        )

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_NO_ANALYTICS", to: "0")

        #expect(!viewModel.isDirty)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_NO_ANALYTICS") == nil)
    }

    @Test @MainActor func `setValue is a no-op on install-time keys`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_PREFIX", to: "/somewhere")

        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `removeRow drops the entry from the draft`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")])
        let (viewModel, _) = makeViewModel(envFile: envFile)

        await viewModel.load()
        viewModel.removeRow(forKey: "HOMEBREW_MAKE_JOBS")

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == nil)
        #expect(viewModel.isDirty)
    }

    @Test @MainActor func `addCustomRow accepts a fresh HOMEBREW key`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let outcome = viewModel.addCustomRow(key: "HOMEBREW_SOMETHING_EXOTIC", value: "yes")

        #expect(outcome == .added)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_SOMETHING_EXOTIC") == "yes")
        #expect(viewModel.envRows.contains { $0.key == "HOMEBREW_SOMETHING_EXOTIC" && $0.provenance == .custom })
    }

    @Test @MainActor func `addCustomRow rejects keys without the HOMEBREW prefix`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let outcome = viewModel.addCustomRow(key: "PATH", value: "/usr/bin")

        #expect(outcome == .rejected)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `addCustomRow rejects keys already covered by the curated allowlist`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let outcome = viewModel.addCustomRow(key: "HOMEBREW_NO_ANALYTICS", value: "1")

        #expect(outcome == .rejected)
    }

    @Test @MainActor func `addCustomRow holds explicitly-dangerous keys for confirmation`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "HOMEBREW_BOTTLE_DOMAIN", value: "https://evil.example.com")

        #expect(outcome == .needsConfirmation)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_BOTTLE_DOMAIN") == nil)
        #expect(!viewModel.isDirty)
        #expect(viewModel.pendingDangerousCustomRow?.key == "HOMEBREW_BOTTLE_DOMAIN")
        #expect(viewModel.pendingDangerousCustomRow?.value == "https://evil.example.com")
    }

    @Test @MainActor func `addCustomRow holds suffix-classified _DOMAIN keys for confirmation`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "HOMEBREW_SOME_NEW_DOMAIN", value: "https://x")

        #expect(outcome == .needsConfirmation)
        #expect(viewModel.pendingDangerousCustomRow?.key == "HOMEBREW_SOME_NEW_DOMAIN")
    }

    @Test @MainActor func `addCustomRow holds suffix-classified _PATH keys for confirmation`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "HOMEBREW_CURL_PATH", value: "/tmp/curl")

        #expect(outcome == .needsConfirmation)
        #expect(viewModel.pendingDangerousCustomRow?.key == "HOMEBREW_CURL_PATH")
    }

    @Test @MainActor func `confirmPendingCustomRow commits the staged row to the draft`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()
        _ = viewModel.addCustomRow(key: "HOMEBREW_BOTTLE_DOMAIN", value: "https://example.com")

        viewModel.confirmPendingCustomRow()

        #expect(viewModel.pendingDangerousCustomRow == nil)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_BOTTLE_DOMAIN") == "https://example.com")
        #expect(viewModel.isDirty)
    }

    @Test @MainActor func `cancelPendingCustomRow drops the staged row without writing`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()
        _ = viewModel.addCustomRow(key: "HOMEBREW_BOTTLE_DOMAIN", value: "https://example.com")

        viewModel.cancelPendingCustomRow()

        #expect(viewModel.pendingDangerousCustomRow == nil)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_BOTTLE_DOMAIN") == nil)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `revert restores the draft to the loaded file`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")
        viewModel.revert()

        #expect(!viewModel.isDirty)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == nil)
    }

    // MARK: - envFileStateDidChange

    @Test @MainActor func `envFileStateDidChange syncs the draft when clean`() async {
        let envRepo = RecordingEnvFileRepository(file: BrewEnvFile())
        let viewModel = ConfigViewModel(
            repository: RecordingConfigRepository(snapshot: Self.snapshot),
            envFileRepository: envRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )
        await viewModel.load()

        // SwiftUI observes the repository state changing (background revalidation completed).
        let updated = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "4")])
        envRepo.externallySet(file: updated)
        viewModel.envFileStateDidChange()

        #expect(viewModel.draft == updated)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `envFileStateDidChange leaves the draft alone when dirty`() async {
        let envRepo = RecordingEnvFileRepository(file: BrewEnvFile())
        let viewModel = ConfigViewModel(
            repository: RecordingConfigRepository(snapshot: Self.snapshot),
            envFileRepository: envRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )
        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")

        envRepo.externallySet(file: BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")]))
        viewModel.envFileStateDidChange()

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
        #expect(viewModel.draft.value(forKey: "HOMEBREW_NO_ANALYTICS") == nil)
        #expect(viewModel.isDirty)
    }

    // MARK: - Refresh

    @Test @MainActor func `refresh forces a fresh fetch on both repos`() async {
        let configRepo = RecordingConfigRepository(snapshot: Self.snapshot)
        let envRepo = RecordingEnvFileRepository(file: BrewEnvFile())
        let viewModel = ConfigViewModel(
            repository: configRepo,
            envFileRepository: envRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )

        await viewModel.refresh()

        #expect(configRepo.loadCalls == [true])
        #expect(envRepo.loadCalls == [true])
    }

    @Test @MainActor func `refresh syncs the draft when the user has no pending edits`() async {
        let envRepo = RecordingEnvFileRepository(file: BrewEnvFile())
        let viewModel = ConfigViewModel(
            repository: RecordingConfigRepository(snapshot: Self.snapshot),
            envFileRepository: envRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )
        await viewModel.load()
        #expect(viewModel.draft == BrewEnvFile())

        // External change: a different process rewrote brew.env between tab visits.
        let updated = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "12")])
        envRepo.stage(file: updated)

        await viewModel.refresh()

        #expect(viewModel.draft == updated)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `refresh preserves pending edits even when the file changed externally`() async {
        let envRepo = RecordingEnvFileRepository(file: BrewEnvFile())
        let viewModel = ConfigViewModel(
            repository: RecordingConfigRepository(snapshot: Self.snapshot),
            envFileRepository: envRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )
        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")
        envRepo.stage(file: BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")]))

        await viewModel.refresh()

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
        #expect(viewModel.isDirty)
    }

    // MARK: - Binding sinks

    @Test @MainActor func `setToggle on writes the truthy value`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setToggle(forKey: "HOMEBREW_NO_ANALYTICS", on: true)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_NO_ANALYTICS") == "1")
    }

    @Test @MainActor func `setToggle off removes the row`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
        let (viewModel, _) = makeViewModel(envFile: envFile)
        await viewModel.load()

        viewModel.setToggle(forKey: "HOMEBREW_NO_ANALYTICS", on: false)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_NO_ANALYTICS") == nil)
    }

    @Test @MainActor func `setString writes non-empty values`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setString(forKey: "HOMEBREW_CASK_OPTS", to: "--no-quarantine")

        #expect(viewModel.draft.value(forKey: "HOMEBREW_CASK_OPTS") == "--no-quarantine")
    }

    @Test @MainActor func `setString empty removes the row`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine")])
        let (viewModel, _) = makeViewModel(envFile: envFile)
        await viewModel.load()

        viewModel.setString(forKey: "HOMEBREW_CASK_OPTS", to: "")

        #expect(viewModel.draft.value(forKey: "HOMEBREW_CASK_OPTS") == nil)
    }

    @Test @MainActor func `setInteger passes through in-range values`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setInteger(forKey: "HOMEBREW_MAKE_JOBS", rawText: "8", minimum: 1, maximum: 64)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
    }

    @Test @MainActor func `setInteger clamps values above the maximum`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setInteger(forKey: "HOMEBREW_MAKE_JOBS", rawText: "999", minimum: 1, maximum: 64)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "64")
    }

    @Test @MainActor func `setInteger clamps values below the minimum`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setInteger(forKey: "HOMEBREW_MAKE_JOBS", rawText: "0", minimum: 1, maximum: 64)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "1")
    }

    @Test @MainActor func `setInteger filters non-digit characters`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setInteger(forKey: "HOMEBREW_MAKE_JOBS", rawText: "12 jobs", minimum: 1, maximum: 64)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "12")
    }

    @Test @MainActor func `setInteger with no digits removes the row`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_MAKE_JOBS", value: "8")])
        let (viewModel, _) = makeViewModel(envFile: envFile)
        await viewModel.load()

        viewModel.setInteger(forKey: "HOMEBREW_MAKE_JOBS", rawText: "abc", minimum: 1, maximum: 64)

        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == nil)
    }

    @Test @MainActor func `isToggleOn reads the truthy value from the draft`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_NO_ANALYTICS", value: "1")])
        let (viewModel, _) = makeViewModel(envFile: envFile)
        await viewModel.load()

        #expect(viewModel.isToggleOn(forKey: "HOMEBREW_NO_ANALYTICS"))
    }

    @Test @MainActor func `textValue returns the empty string for unset keys`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        #expect(viewModel.textValue(forKey: "HOMEBREW_CASK_OPTS") == "")
    }

    // MARK: - Save

    @Test @MainActor func `save persists the draft and resets isDirty`() async {
        let (viewModel, envRepo) = makeViewModel()

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")
        await viewModel.save()

        #expect(!viewModel.isDirty)
        let saved = envRepo.currentFile
        #expect(saved.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
        #expect(envRepo.saveCount == 1)
    }

    @Test @MainActor func `save is a no-op when nothing has changed`() async {
        let (viewModel, envRepo) = makeViewModel()

        await viewModel.load()
        await viewModel.save()

        #expect(envRepo.saveCount == 0)
        #expect(viewModel.saveError == nil)
    }

    @Test @MainActor func `save failure populates saveError without losing the draft`() async {
        let throwingRepo = ThrowingEnvFileRepository()
        let viewModel = ConfigViewModel(
            repository: StubConfigRepository(snapshot: Self.snapshot),
            envFileRepository: throwingRepo,
            processEnvironment: ["SHELL": "/bin/zsh"],
        )

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")
        await viewModel.save()

        #expect(viewModel.saveError != nil)
        #expect(viewModel.isDirty)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
    }
}

@Observable
@MainActor
private final class ThrowingPageStateConfigRepository: ConfigRepository {
    private(set) var state: LoadState<BrewConfigSnapshot, any Error> = .loading
    private let error: any Error

    init(error: any Error) {
        self.error = error
    }

    func load(forceRefresh _: Bool) async {
        state = .failed(error)
    }

    func invalidate() {}
}

@Observable
@MainActor
private final class RecordingConfigRepository: ConfigRepository {
    private(set) var state: LoadState<BrewConfigSnapshot, any Error>
    private(set) var loadCalls: [Bool] = []
    private let snapshot: BrewConfigSnapshot

    init(snapshot: BrewConfigSnapshot) {
        self.snapshot = snapshot
        state = .loaded(snapshot)
    }

    func load(forceRefresh: Bool) async {
        loadCalls.append(forceRefresh)
        state = .loaded(snapshot)
    }

    func invalidate() {}
}

/// Recording env-file fake that lets a test stage a new `BrewEnvFile` to be returned on the next
/// `load` — mimics an external rewrite between tab visits without touching disk.
@Observable
@MainActor
private final class RecordingEnvFileRepository: EnvFileRepository {
    private(set) var state: LoadState<BrewEnvFile, any Error>
    private(set) var loadCalls: [Bool] = []
    private var nextFile: BrewEnvFile?

    init(file: BrewEnvFile) {
        state = .loaded(file)
    }

    func load(forceRefresh: Bool) async {
        loadCalls.append(forceRefresh)
        if let nextFile {
            state = .loaded(nextFile)
            self.nextFile = nil
        }
    }

    func save(_ newFile: BrewEnvFile) async throws {
        state = .loaded(newFile)
    }

    func invalidate() {}

    func stage(file: BrewEnvFile) {
        nextFile = file
    }

    /// Simulates the View's observation path: SwiftUI sees a `state` change (e.g. because the
    /// repository's foreground revalidation completed) and forwards the new value into the VM via
    /// `envFileStateDidChange()`.
    func externallySet(file: BrewEnvFile) {
        state = .loaded(file)
    }
}

@Observable
@MainActor
private final class ThrowingEnvFileRepository: EnvFileRepository {
    private(set) var state: LoadState<BrewEnvFile, any Error> = .loaded(BrewEnvFile())

    func load(forceRefresh _: Bool) async {}

    func save(_: BrewEnvFile) async throws {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
    }

    func invalidate() {}
}
