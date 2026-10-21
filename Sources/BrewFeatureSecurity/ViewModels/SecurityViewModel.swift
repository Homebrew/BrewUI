//
//  SecurityViewModel.swift
//  BrewFeatureSecurity
//

import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import Foundation
import Observation

/// Coarse view-facing projection of the scan state, so the view binds to one decision per state.
enum SecurityPresentation: Equatable {
    case loading
    case clean
    case findings
    case failed(String)
}

@Observable
@MainActor
final class SecurityViewModel {
    @ObservationIgnored private let repository: any SecurityAdvisoryRepository

    private(set) var selectedPackageID: HomebrewPackageID?

    init(repository: any SecurityAdvisoryRepository) {
        self.repository = repository
    }

    // MARK: - Derived state

    var state: LoadState<SecurityAdvisoryReport, String> {
        switch repository.state {
        case .loading:
            .loading
        case let .loaded(report):
            .loaded(report)
        case let .failed(error):
            .failed(BrewErrorCopy.message(
                for: error,
                fallback: BrewErrorCopy.message(for: OperationFailure(catching: error)),
            ))
        }
    }

    var presentation: SecurityPresentation {
        switch state {
        case .loading:
            .loading
        case let .loaded(report):
            report.affectedPackages.isEmpty ? .clean : .findings
        case let .failed(message):
            .failed(message)
        }
    }

    var isRefreshing: Bool {
        repository.isRefreshing
    }

    var showsHeaderControls: Bool {
        switch presentation {
        case .clean, .findings:
            true
        case .loading, .failed:
            false
        }
    }

    var shouldFocusList: Bool {
        presentation == .findings
    }

    var subtitle: LocalizedStringResource {
        let rescanning = LocalizedStringResource("Re-scanning…", bundle: #bundle, comment: "Security subtitle while a re-scan runs")
        switch presentation {
        case .loading:
            return LocalizedStringResource("Scanning installed formulae…", bundle: #bundle, comment: "Security subtitle during the first scan")
        case .clean:
            return isRefreshing ? rescanning : LocalizedStringResource("No known vulnerabilities", bundle: #bundle, comment: "Security subtitle when no open advisories matched")
        case .findings:
            return isRefreshing ? rescanning : LocalizedStringResource("Open advisories found", bundle: #bundle, comment: "Security subtitle when open advisories are listed")
        case .failed:
            return LocalizedStringResource("The scan could not be completed", bundle: #bundle, comment: "Security subtitle when brew vulns failed")
        }
    }

    var lastScannedAt: Date? {
        guard state.isLoaded else {
            return nil
        }
        return repository.scannedAt
    }

    var items: [SecurityPackageItem] {
        guard case let .loaded(report) = state else {
            return []
        }
        return report.affectedPackages.map(SecurityPackageItem.init(package:))
    }

    var selectedItem: SecurityPackageItem? {
        guard let selectedPackageID else {
            return nil
        }
        return items.first { $0.id == selectedPackageID }
    }

    /// One line on what the scan covered, so a clean result is never read as a guarantee.
    var coverageSummary: String? {
        guard case let .loaded(report) = state else {
            return nil
        }
        let coverage = report.coverage
        var parts: [String] = []
        if let checked = coverage.checkedCount {
            parts.append(checked == 1
                ? String(localized: "1 formula checked", bundle: #bundle, comment: "Security coverage: one formula scanned")
                : String(localized: "\(checked) formulae checked", bundle: #bundle, comment: "Security coverage: formulae scanned; %lld is the count"))
        }
        let patched = report.resolvedByPatchCount
        if patched > 0 {
            parts.append(patched == 1
                ? String(localized: "1 advisory already patched by Homebrew", bundle: #bundle, comment: "Security coverage: one advisory a formula patch resolves")
                : String(
                    localized: "\(patched) advisories already patched by Homebrew",
                    bundle: #bundle,
                    comment: "Security coverage: advisories formula patches resolve; %lld is the count",
                ))
        }
        parts.append(String(localized: "Casks are not scanned", bundle: #bundle, comment: "Security coverage: brew vulns checks formulae only"))
        return parts.joined(separator: " · ")
    }

    /// A short note on what the scan could not cover, or `nil` when it covered everything. Homebrew's own
    /// warnings can run to a line per keg, so they are summarised here and left in full in the console.
    var scanNote: String? {
        guard case let .loaded(report) = state else {
            return nil
        }
        let coverage = report.coverage
        var sentences: [String] = []
        let skipped = coverage.skipped.count + coverage.unscanned.count
        if skipped == 1 {
            sentences.append(String(localized: "1 formula wasn’t scanned.", bundle: #bundle, comment: "Security note: one formula could not be scanned"))
        } else if skipped > 1 {
            sentences.append(String(
                localized: "\(skipped) formulae weren’t scanned.",
                bundle: #bundle,
                comment: "Security note: formulae that could not be scanned; %lld is the count",
            ))
        }
        if !coverage.outdatedWithoutSBOM.isEmpty {
            let names = coverage.outdatedWithoutSBOM.sorted().joined(separator: ", ")
            sentences.append(String(
                localized: "Results for \(names) reflect the current formula, not the installed version.",
                bundle: #bundle,
                comment: "Security note: brew vulns could not tell which source was installed; %@ is a list of formula names",
            ))
        }
        if !coverage.diagnostics.isEmpty {
            sentences.append(String(
                localized: "Homebrew reported warnings; see the console for details.",
                bundle: #bundle,
                comment: "Security note: brew vulns printed warnings, shown in full in the console",
            ))
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    // MARK: - Selection

    func setSelection(_ id: HomebrewPackageID?) {
        selectedPackageID = id
    }

    func selectNext() {
        let ids = items.map(\.id)
        guard let current = selectedPackageID, let index = ids.firstIndex(of: current) else {
            selectedPackageID = ids.first
            return
        }
        if index + 1 < ids.count {
            selectedPackageID = ids[index + 1]
        }
    }

    func selectPrevious() {
        let ids = items.map(\.id)
        guard let current = selectedPackageID, let index = ids.firstIndex(of: current) else {
            selectedPackageID = ids.last
            return
        }
        if index > 0 {
            selectedPackageID = ids[index - 1]
        }
    }

    // MARK: - Intents

    func load(forceRefresh: Bool) async {
        await repository.load(forceRefresh: forceRefresh)
        synchronizeSelection()
    }

    /// Keeps the selection on the same formula across scans, falling back to the most severe one.
    private func synchronizeSelection() {
        let ids = items.map(\.id)
        if let selectedPackageID, ids.contains(selectedPackageID) {
            return
        }
        selectedPackageID = ids.first
    }
}
