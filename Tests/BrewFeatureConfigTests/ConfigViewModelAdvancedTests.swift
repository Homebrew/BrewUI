import BrewCore
@testable import BrewFeatureConfig
import BrewRepositoryInterfaces
import Foundation
import Testing

/// Tests for everything behind the Advanced disclosure: the advanced-row split off the curated
/// allowlist, the `HOMEBREW_CASK_OPTS` advisory, and the custom-row add/confirm/cancel flow.
struct ConfigViewModelAdvancedTests {
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

    private func envRows(_ viewModel: ConfigViewModel) -> [EnvRowItem] {
        viewModel.envRows(envFile: viewModel.envFileState.value ?? BrewEnvFile())
    }

    private func advancedEnvRows(_ viewModel: ConfigViewModel) -> [EnvRowItem] {
        viewModel.advancedEnvRows(envFile: viewModel.envFileState.value ?? BrewEnvFile())
    }

    // MARK: - Advanced rows

    @Test @MainActor func `advanced rows are excluded from the always-visible envRows`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let keys = envRows(viewModel).map(\.key)
        #expect(!keys.contains("HOMEBREW_NO_INSTALL_UPGRADE"))
        #expect(!keys.contains("HOMEBREW_CASK_OPTS"))
    }

    @Test @MainActor func `advancedEnvRows contains the curated weakening keys`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let keys = advancedEnvRows(viewModel).map(\.key)
        #expect(keys == ["HOMEBREW_NO_INSTALL_UPGRADE", "HOMEBREW_CASK_OPTS"])
    }

    @Test @MainActor func `an advanced key set on disk stays in advancedEnvRows and not envRows`() async {
        let envFile = BrewEnvFile(lines: [.entry(key: "HOMEBREW_CASK_OPTS", value: "--no-quarantine")])
        let (viewModel, _) = makeViewModel(envFile: envFile)
        await viewModel.load()

        #expect(!envRows(viewModel).contains { $0.key == "HOMEBREW_CASK_OPTS" })
        let advancedRow = advancedEnvRows(viewModel).first { $0.key == "HOMEBREW_CASK_OPTS" }
        #expect(advancedRow?.value == "--no-quarantine")
        #expect(advancedRow?.provenance == .envFile)
    }

    // MARK: - Custom row add / confirm / cancel

    @Test @MainActor func `addCustomRow accepts a fresh HOMEBREW key`() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        let outcome = viewModel.addCustomRow(key: "HOMEBREW_SOMETHING_EXOTIC", value: "yes")

        #expect(outcome == .added)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_SOMETHING_EXOTIC") == "yes")
        #expect(envRows(viewModel).contains { $0.key == "HOMEBREW_SOMETHING_EXOTIC" && $0.provenance == .custom })
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

    @Test @MainActor func `addCustomRow trims surrounding whitespace from the key`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "  HOMEBREW_PASTED_KEY  ", value: "x")

        #expect(outcome == .added)
        #expect(viewModel.draft.value(forKey: "HOMEBREW_PASTED_KEY") == "x")
    }

    @Test @MainActor func `addCustomRow rejects the bare HOMEBREW_ prefix with no suffix`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "HOMEBREW_", value: "x")

        #expect(outcome == .rejected)
        #expect(!viewModel.isDirty)
    }

    @Test @MainActor func `addCustomRow rejects install-time keys`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        let outcome = viewModel.addCustomRow(key: "HOMEBREW_PREFIX", value: "/somewhere")

        #expect(outcome == .rejected)
        #expect(!viewModel.isDirty)
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

    // MARK: - Cask opts advisory

    @Test @MainActor func `caskOptsAdvisory is nil when the draft value is unset`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        #expect(viewModel.caskOptsAdvisory() == nil)
    }

    @Test @MainActor func `caskOptsAdvisory is nil when every token is recognised and safe`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setString(forKey: "HOMEBREW_CASK_OPTS", to: "--appdir=/Applications --require-sha")

        #expect(viewModel.caskOptsAdvisory() == nil)
    }

    @Test @MainActor func `caskOptsAdvisory surfaces no-quarantine and unrecognised flags`() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()

        viewModel.setString(forKey: "HOMEBREW_CASK_OPTS", to: "--no-quarantine --made-up-flag")

        let advisory = viewModel.caskOptsAdvisory()
        #expect(advisory?.hasNoQuarantine == true)
        #expect(advisory?.unrecognisedFlags == ["--made-up-flag"])
    }
}
