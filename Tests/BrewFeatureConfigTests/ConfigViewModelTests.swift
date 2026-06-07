import BrewCore
@testable import BrewFeatureConfig
import BrewRepositoryInterfaces
import Foundation
import Testing

struct ConfigViewModelTests {
    private static let snapshot = BrewConfigSnapshot(
        entries: [
            BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0"),
            BrewConfigEntry(key: "HOMEBREW_PREFIX", value: "/opt/homebrew"),
            BrewConfigEntry(key: "HOMEBREW_MAKE_JOBS", value: "16"),
            BrewConfigEntry(key: "CPU", value: "16-core"),
            BrewConfigEntry(key: "macOS", value: "15.4-arm64"),
            BrewConfigEntry(key: "Metal Toolchain", value: "N/A"),
        ],
        environment: [
            BrewConfigEntry(key: "HOMEBREW_NO_ANALYTICS", value: "1"),
        ],
    )

    @Test @MainActor func `load groups entries into homebrew, system and build cards`() async {
        let viewModel = ConfigViewModel(repository: StubConfigRepository(snapshot: Self.snapshot))

        await viewModel.load()

        guard case .loaded = viewModel.state else {
            Issue.record("expected loaded state")
            return
        }
        let sections = viewModel.sections
        #expect(sections.map(\.title) == ["Homebrew", "System", "Build settings", "Environment (HOMEBREW_*)"])

        let homebrew = sections.first { $0.id == "homebrew" }
        #expect(homebrew?.rows.map(\.label) == ["HOMEBREW_VERSION", "HOMEBREW_PREFIX"])

        // Unknown keys (Metal Toolchain) fall through to System so nothing is dropped.
        let system = sections.first { $0.id == "system" }
        #expect(system?.rows.map(\.label) == ["CPU", "macOS", "Metal Toolchain"])

        let build = sections.first { $0.id == "build" }
        #expect(build?.rows.map(\.label) == ["HOMEBREW_MAKE_JOBS"])
    }

    @Test @MainActor func `environment card surfaces the merged HOMEBREW variables`() async {
        let viewModel = ConfigViewModel(repository: StubConfigRepository(snapshot: Self.snapshot))

        await viewModel.load()

        let environment = viewModel.sections.first { $0.id == "environment" }
        #expect(environment?.rows.map(\.label) == ["HOMEBREW_NO_ANALYTICS"])
    }

    @Test @MainActor func `copy report contains grouped key value lines`() async {
        let viewModel = ConfigViewModel(repository: StubConfigRepository(snapshot: Self.snapshot))

        await viewModel.load()

        let report = viewModel.copyReport
        #expect(report.contains("Homebrew\nHOMEBREW_VERSION: 4.3.0"))
        #expect(report.contains("Environment (HOMEBREW_*)\nHOMEBREW_NO_ANALYTICS: 1"))
        #expect(viewModel.canCopyReport)
    }

    @Test @MainActor func `empty environment keeps the card with an empty-state message`() async {
        let snapshot = BrewConfigSnapshot(
            entries: [BrewConfigEntry(key: "HOMEBREW_VERSION", value: "4.3.0")],
            environment: [],
        )
        let viewModel = ConfigViewModel(repository: StubConfigRepository(snapshot: snapshot))

        await viewModel.load()

        let environment = viewModel.sections.first { $0.id == "environment" }
        #expect(environment?.rows.isEmpty == true)
        #expect(environment?.emptyMessage != nil)
        // The empty environment block reports "(none)" in the copy report rather than being omitted.
        #expect(viewModel.copyReport.contains("Environment (HOMEBREW_*)\n(none)"))
    }

    @Test @MainActor func `missing brew executable surfaces the brew-not-found state`() async {
        let viewModel = ConfigViewModel(
            repository: ThrowingConfigRepository(error: BrewLookupError.executableNotFound),
        )

        await viewModel.load()

        guard case .failed = viewModel.state else {
            Issue.record("expected failed state")
            return
        }
        #expect(viewModel.isBrewNotFound)
        #expect(viewModel.sections.isEmpty)
        #expect(!viewModel.canCopyReport)
    }

    @Test @MainActor func `command failures surface the stderr message and are not brew-not-found`() async {
        let viewModel = ConfigViewModel(
            repository: ThrowingConfigRepository(
                error: BrewCommandError.failed(exitCode: 1, stderr: "something broke"),
            ),
        )

        await viewModel.load()

        #expect(!viewModel.isBrewNotFound)
        #expect(viewModel.errorMessage == "something broke")
    }

    @Test @MainActor func `unknown errors map to a generic message`() async {
        let viewModel = ConfigViewModel(repository: ThrowingConfigRepository(error: ConfigOddError()))

        await viewModel.load()

        #expect(viewModel.errorMessage == "Couldn't read the Homebrew configuration.")
    }
}

private struct ThrowingConfigRepository: ConfigRepository {
    let error: any Error

    func loadConfig() async throws -> BrewConfigSnapshot {
        throw error
    }
}

private struct ConfigOddError: Error {}
