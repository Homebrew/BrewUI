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
        let accepted = viewModel.addCustomRow(key: "HOMEBREW_SOMETHING_EXOTIC", value: "yes")

        #expect(accepted)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_SOMETHING_EXOTIC") == "yes")
        #expect(viewModel.envRows.contains { $0.key == "HOMEBREW_SOMETHING_EXOTIC" && $0.provenance == .custom })
    }

    @Test @MainActor func `addCustomRow rejects keys without the HOMEBREW prefix`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let accepted = viewModel.addCustomRow(key: "PATH", value: "/usr/bin")

        #expect(!accepted)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `addCustomRow rejects keys already covered by the curated allowlist`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let accepted = viewModel.addCustomRow(key: "HOMEBREW_NO_ANALYTICS", value: "1")

        #expect(!accepted)
    }

    @Test @MainActor func `revert restores the draft to the loaded file`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        viewModel.setValue(forKey: "HOMEBREW_MAKE_JOBS", to: "8")
        viewModel.revert()

        #expect(!viewModel.isDirty)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_MAKE_JOBS") == nil)
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
        let saved = await envRepo.currentFile()
        #expect(saved.value(forKey: "HOMEBREW_MAKE_JOBS") == "8")
        #expect(await envRepo.saveCount == 1)
    }

    @Test @MainActor func `save is a no-op when nothing has changed`() async {
        let (viewModel, envRepo) = makeViewModel()

        await viewModel.load()
        await viewModel.save()

        #expect(await envRepo.saveCount == 0)
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

private struct ThrowingEnvFileRepository: EnvFileRepository {
    func loadEnvFile() async throws -> BrewEnvFile {
        BrewEnvFile()
    }

    func save(_: BrewEnvFile) async throws {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "disk full"])
    }
}
