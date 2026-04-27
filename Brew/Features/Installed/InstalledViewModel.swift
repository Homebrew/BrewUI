//
//  InstalledViewModel.swift
//  Brew
//

import Foundation
import Observation

@Observable
@MainActor
final class InstalledViewModel {
    private let repository: InstalledPackagesRepository?
    private let detailsRepository: (any PackageDetailsRepository)?

    private(set) var formulaRows: [InstalledPackageRow] = []
    private(set) var caskRows: [InstalledPackageRow] = []
    var selectedPackageID: InstalledPackageRow.ID?
    private(set) var isLoading = false
    private(set) var userFacingError: String?
    private(set) var detailsViewModel: InstalledDetailsViewModel?

    var totalPackageCount: Int {
        formulaRows.count + caskRows.count
    }

    /// Initial fetch with no rows yet — show blocking spinner (unit-tested via `init(testing…)`).
    var shouldShowInitialLoadingIndicator: Bool {
        isLoading && totalPackageCount == 0 && userFacingError == nil
    }

    var shouldShowFormulaeSection: Bool {
        !formulaRows.isEmpty
    }

    var shouldShowCasksSection: Bool {
        !caskRows.isEmpty
    }

    var packageCountSubtitle: String {
        if shouldShowInitialLoadingIndicator {
            return String(localized: "Loading packages…", comment: "Installed tab subtitle while fetching")
        }
        if totalPackageCount == 1 {
            return "1 package"
        }
        return "\(totalPackageCount) packages"
    }

    var selectedPackageRow: InstalledPackageRow? {
        allRows.first(where: { $0.id == selectedPackageID })
    }

    /// Loads from Homebrew via the repository (`ARCHITECTURE.md`: View → ViewModel → Repository → Service).
    init(repository: InstalledPackagesRepository, detailsRepository: (any PackageDetailsRepository)? = nil) {
        self.repository = repository
        self.detailsRepository = detailsRepository
    }

    /// SwiftUI previews and tests: fixed rows, `load()` is a no-op.
    init(previewFormulae: [InstalledPackageRow], previewCasks: [InstalledPackageRow]) {
        repository = nil
        detailsRepository = nil
        formulaRows = previewFormulae
        caskRows = previewCasks
        ensureValidSelection()
    }

    /// Unit tests for presentation flags (`@testable import Brew`).
    init(
        testingFormulaRows: [InstalledPackageRow] = [],
        testingCaskRows: [InstalledPackageRow] = [],
        isLoading: Bool = false,
        userFacingError: String? = nil,
    ) {
        repository = nil
        detailsRepository = nil
        formulaRows = testingFormulaRows
        caskRows = testingCaskRows
        self.isLoading = isLoading
        self.userFacingError = userFacingError
        ensureValidSelection()
    }

    func load() async {
        guard let repository else {
            return
        }
        isLoading = true
        userFacingError = nil
        defer { isLoading = false }
        do {
            let snapshot = try await repository.loadInstalledPackages()
            formulaRows = snapshot.formulae.map { Self.row(from: $0, kind: .formula) }
            caskRows = snapshot.casks.map { Self.row(from: $0, kind: .cask) }
            ensureValidSelection()
            startDetailsLoadForCurrentSelection()
        } catch {
            formulaRows = []
            caskRows = []
            selectedPackageID = nil
            clearDetailsState()
            userFacingError = Self.userMessage(for: error)
        }
    }

    func ensureValidSelection() {
        let ids = Set(allRows.map(\.id))
        if let selectedPackageID, ids.contains(selectedPackageID) {
            return
        }
        selectedPackageID = nil
        detailsViewModel = nil
    }

    func toggleSelection(for rowID: InstalledPackageRow.ID) {
        if selectedPackageID == rowID {
            selectedPackageID = nil
        } else {
            selectedPackageID = rowID
        }
        startDetailsLoadForCurrentSelection()
    }

    func clearSelection() {
        selectedPackageID = nil
        startDetailsLoadForCurrentSelection()
    }

    private var allRows: [InstalledPackageRow] {
        formulaRows + caskRows
    }

    private func startDetailsLoadForCurrentSelection() {
        guard let selectedRow = selectedPackageRow else {
            detailsViewModel = nil
            return
        }

        guard let detailsRepository else {
            detailsViewModel = nil
            return
        }

        let detailsViewModel = InstalledDetailsViewModel(
            selectedRow: selectedRow,
            repository: detailsRepository,
        )
        self.detailsViewModel = detailsViewModel
        detailsViewModel.load()
    }

    private func clearDetailsState() {
        detailsViewModel = nil
    }

    private static func row(from info: InstalledPackageInfo, kind: InstalledPackageKind) -> InstalledPackageRow {
        let trimmed = info.version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let versionLabel: String = if trimmed.isEmpty {
            "—"
        } else {
            displayVersion(trimmed)
        }
        return InstalledPackageRow(
            name: info.name,
            kind: kind,
            description: "",
            installedVersion: versionLabel,
            updateVersion: nil,
        )
    }

    private static func displayVersion(_ raw: String) -> String {
        if raw.hasPrefix("v") || raw.hasPrefix("V") {
            return raw
        }
        return "v\(raw)"
    }

    private static func userMessage(for error: Error) -> String {
        switch error {
        case BrewLookupError.executableNotFound:
            return String(
                localized: "Could not find Homebrew. Install it or ensure brew is in the default location.",
                comment: "Installed tab error when brew binary missing",
            )
        case let BrewCommandError.failed(_, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
            return String(localized: "Homebrew command failed.", comment: "Installed tab error generic brew failure")
        case let BrewCommandError.launchFailed(underlying):
            return underlying
        default:
            return String(localized: "Something went wrong loading packages.", comment: "Installed tab generic error")
        }
    }

}
