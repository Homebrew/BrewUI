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

    private(set) var formulaRows: [InstalledPackageRow] = []
    private(set) var caskRows: [InstalledPackageRow] = []
    var selectedPackageID: InstalledPackageRow.ID?
    private(set) var isLoading = false
    private(set) var userFacingError: String?

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
    init(repository: InstalledPackagesRepository) {
        self.repository = repository
    }

    /// SwiftUI previews and tests: fixed rows, `load()` is a no-op.
    init(previewFormulae: [InstalledPackageRow], previewCasks: [InstalledPackageRow]) {
        repository = nil
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
        } catch {
            formulaRows = []
            caskRows = []
            selectedPackageID = nil
            userFacingError = Self.userMessage(for: error)
        }
    }

    func ensureValidSelection() {
        let ids = Set(allRows.map(\.id))
        if let selectedPackageID, ids.contains(selectedPackageID) {
            return
        }
        selectedPackageID = nil
    }

    func toggleSelection(for rowID: InstalledPackageRow.ID) {
        if selectedPackageID == rowID {
            selectedPackageID = nil
        } else {
            selectedPackageID = rowID
        }
    }

    func clearSelection() {
        selectedPackageID = nil
    }

    private var allRows: [InstalledPackageRow] {
        formulaRows + caskRows
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
