//
//  InstalledViewModelPresentationTests.swift
//  BrewTests
//

@testable import Brew
import Foundation
import Testing

private struct SectionVisibilitySnapshot: Equatable {
    var formulae: Bool
    var casks: Bool
}

@MainActor
private func sectionVisibility(_ vm: InstalledViewModel) -> SectionVisibilitySnapshot {
    guard case let .loaded(content) = vm.state else {
        return SectionVisibilitySnapshot(formulae: false, casks: false)
    }
    return SectionVisibilitySnapshot(
        formulae: content.shouldShowFormulaeSection,
        casks: content.shouldShowCasksSection,
    )
}

struct InstalledViewModelPresentationTests {
    @Test @MainActor func `selectedPackageID is nil for initial loading state`() {
        let vm = InstalledViewModel(
            repository: StubInstalledPackagesRepository(snapshot: .empty),
        )
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is true when loading with no rows and no error`() {
        let vm = InstalledViewModel(
            repository: StubInstalledPackagesRepository(snapshot: .empty),
        )
        #expect(vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false after successful load`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `shouldShowInitialLoadingIndicator is false when load has user error`() async {
        let vm = InstalledViewModel(
            repository: FailingInstalledRepository(error: BrewLookupError.executableNotFound),
        )
        await vm.load()
        #expect(!vm.shouldShowInitialLoadingIndicator)
    }

    @Test @MainActor func `section visibility shows both sections when formulae and casks present`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "f", kind: .formula)],
            casks: [.fixture(name: "c", kind: .cask)],
        )
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: true, casks: true))
    }

    @Test @MainActor func `section visibility shows only formulae when no casks`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "f", kind: .formula)],
        )
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: true, casks: false))
    }

    @Test @MainActor func `section visibility hides all sections when empty loaded snapshot`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel()
        #expect(sectionVisibility(vm) == SectionVisibilitySnapshot(formulae: false, casks: false))
    }

    @Test @MainActor func `totalPackageCount sums formula and cask rows`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "f", kind: .formula)],
            casks: [.fixture(name: "c", kind: .cask)],
        )
        #expect(vm.totalPackageCount == 2)
    }

    @Test @MainActor func `packageCountSubtitle shows localized loading text when initial loading`() {
        let vm = InstalledViewModel(
            repository: StubInstalledPackagesRepository(snapshot: .empty),
        )
        let expected = String(localized: "Loading packages…", comment: "Installed tab subtitle while fetching")
        #expect(vm.packageCountSubtitle == expected)
    }

    @Test @MainActor func `packageCountSubtitle is singular for one package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        #expect(vm.packageCountSubtitle == "1 package")
    }

    @Test @MainActor func `packageCountSubtitle is plural for multiple packages`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [
                .fixture(name: "a", kind: .formula),
                .fixture(name: "b", kind: .formula),
            ],
        )
        #expect(vm.packageCountSubtitle == "2 packages")
    }

    @Test @MainActor func `toggleSelection selects row when nothing selected`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: row.id)
        #expect(vm.selectedPackageID == row.id)
    }

    @Test @MainActor func `toggleSelection clears selection when tapping selected row`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: row.id)
        vm.toggleSelection(for: row.id)
        #expect(vm.selectedPackageID == nil)
    }

    @Test @MainActor func `clearSelection clears selected package`() async {
        let vm = await InstalledFeatureTestSupport.loadedViewModel(
            formulae: [.fixture(name: "a", kind: .formula)],
        )
        guard let row = selectedFormulaRow(from: vm) else {
            Issue.record("expected row in loaded state")
            return
        }
        vm.toggleSelection(for: row.id)
        vm.clearSelection()
        #expect(vm.selectedPackageID == nil)
    }
}

private struct FailingInstalledRepository: InstalledPackagesRepository {
    let error: Error

    func loadInstalledPackages() async throws -> [BrewPackage] {
        throw error
    }
}

@MainActor
private func selectedFormulaRow(from vm: InstalledViewModel) -> BrewPackage? {
    guard case let .loaded(content) = vm.state else {
        return nil
    }
    return content.formulaPackages.first
}
