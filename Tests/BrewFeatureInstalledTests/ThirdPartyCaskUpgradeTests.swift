import BrewCore
import BrewCoreTestSupport
@testable import BrewFeatureInstalled
import BrewRepositoryInterfaces
import Testing

@MainActor
struct ThirdPartyCaskUpgradeTests {
    @Test(arguments: [
        ("stablyai/orca", "orca", "stablyai/orca/orca"),
        ("homebrew/cask", "orca", "orca"),
        (nil, "orca", "orca"),
        ("", "orca", "orca"),
        ("stablyai/orca", "stablyai/orca/orca", "stablyai/orca/orca"),
    ])
    func `single upgrade preserves the source cask tap`(tap: String?, name: String, expected: String) async {
        let package = InstalledBrewPackage.fixture(name: name, kind: .cask, outdated: true, tap: tap)
        let center = SubmitRecordingCommandCenter()
        let viewModel = makeInstalledDetailsViewModel(package: package, brewCommandCenter: center)

        viewModel.upgradeSelectedPackage()
        await center.waitForSubmitCallCount(1)

        #expect(await center.recordedCommands.first?.arguments == ["upgrade", "--cask", expected])
        #expect(viewModel.upgradeItem.displayCommand == "brew upgrade --cask \(expected)")
        #expect(await center.recordedSubmitEntries.first?.id == .package(package.id))
    }

    @Test func `searched batch preserves a third-party cask alongside a same-named formula`() async {
        let center = SubmitRecordingCommandCenter()
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                .fixture(name: "orca", kind: .formula, outdated: true),
                .fixture(name: "orca", kind: .cask, outdated: true, tap: "stablyai/orca"),
            ]),
            brewCommandCenter: center,
            commandFactory: StubMutatingCommandFactory(),
        )
        viewModel.searchQuery = "orca"

        viewModel.upgradeAll()
        await center.waitForSubmitCallCount(1)

        #expect(await center.recordedCommands.first?.arguments == ["upgrade", "orca", "stablyai/orca/orca"])
        #expect(viewModel.bulkUpgradeDisplayCommand == "brew upgrade orca stablyai/orca/orca")
    }

    @Test func `self-upgrade exclusion preserves third-party cask names in the batch`() {
        let viewModel = UpgradesViewModel(
            repository: StubInstalledPackagesRepository(packages: [
                .fixture(name: "orca", kind: .cask, outdated: true, tap: "stablyai/orca"),
                .fixture(name: "homebrew-app", kind: .cask, outdated: true),
            ]),
            brewCommandCenter: StubBrewCommandCenter(),
            commandFactory: StubMutatingCommandFactory(),
        )

        #expect(viewModel.upgradeSelection == .explicit(["stablyai/orca/orca"]))
    }

    @Test func `qualified batch marks only the matching cask source busy`() {
        let thirdParty = InstalledBrewPackage.fixture(
            name: "orca", kind: .cask, outdated: true, tap: "stablyai/orca",
        )
        let official = InstalledBrewPackage.fixture(
            name: "orca", kind: .cask, outdated: true, tap: "homebrew/cask",
        )
        let operation = BrewOperationID.bulkUpgrade(.explicit(["stablyai/orca/orca"]))
        let detail = makeInstalledDetailsViewModel(package: thirdParty)
        let row = InstalledListRowViewModel(package: thirdParty, brewCommandCenter: StubBrewCommandCenter())
        let otherDetail = makeInstalledDetailsViewModel(package: official)

        #expect(detail.operationSubject.includes(operation))
        #expect(row.operationSubject.includes(operation))
        #expect(!otherDetail.operationSubject.includes(operation))
    }
}
