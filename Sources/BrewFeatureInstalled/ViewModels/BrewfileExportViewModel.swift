//
//  BrewfileExportViewModel.swift
//  BrewFeatureInstalled
//

import BrewCore
import Foundation
import Observation

@Observable
@MainActor
final class BrewfileExportViewModel {
    enum Presentation: Equatable {
        case awaitingDestination
        case ready(BrewfileExportItem)
        case exporting(BrewfileExportItem)
        case exported(BrewfileExportItem)
        case failed(BrewfileExportItem, message: String)
    }

    @ObservationIgnored private let brewCommandCenter: any BrewCommandCenter
    @ObservationIgnored private let commandFactory: any BrewMutatingCommandFactory
    @ObservationIgnored private var exportTask: Task<Void, Never>?

    private(set) var presentation: Presentation = .awaitingDestination
    private(set) var isSheetPresented = false

    init(
        brewCommandCenter: any BrewCommandCenter,
        commandFactory: any BrewMutatingCommandFactory,
    ) {
        self.brewCommandCenter = brewCommandCenter
        self.commandFactory = commandFactory
    }

    isolated deinit {
        exportTask?.cancel()
    }

    var currentItem: BrewfileExportItem? {
        switch presentation {
        case .awaitingDestination:
            nil
        case let .ready(item), let .exporting(item), let .exported(item), let .failed(item, _):
            item
        }
    }

    var isRunning: Bool {
        if case .exporting = presentation {
            return true
        }
        return false
    }

    var canChooseLocation: Bool {
        switch presentation {
        case .awaitingDestination, .ready, .failed:
            true
        case .exporting, .exported:
            false
        }
    }

    var canSubmit: Bool {
        switch presentation {
        case .ready, .failed:
            true
        case .awaitingDestination, .exporting, .exported:
            false
        }
    }

    var canDismiss: Bool {
        !isRunning
    }

    var canRevealInFinder: Bool {
        if case .exported = presentation {
            return true
        }
        return false
    }

    var failureMessage: String? {
        if case let .failed(_, message) = presentation {
            return message
        }
        return nil
    }

    var dismissButtonTitle: String {
        if case .exported = presentation {
            return String(localized: "Done", comment: "Brewfile export sheet dismiss button after success")
        }
        return String(localized: "Cancel", comment: "Brewfile export sheet dismiss button before success")
    }

    func openSheet() {
        presentation = .awaitingDestination
        isSheetPresented = true
    }

    func requestDismiss() {
        guard canDismiss else {
            return
        }
        isSheetPresented = false
        presentation = .awaitingDestination
        exportTask?.cancel()
        exportTask = nil
    }

    func acceptDestination(_ url: URL) {
        guard canChooseLocation else {
            return
        }
        presentation = .ready(BrewfileExportItem(destinationURL: url))
    }

    func export() {
        let item: BrewfileExportItem
        switch presentation {
        case let .ready(readyItem):
            item = readyItem
        case let .failed(failedItem, _):
            item = failedItem
        case .awaitingDestination, .exporting, .exported:
            return
        }
        presentation = .exporting(item)
        exportTask?.cancel()
        exportTask = Task { @MainActor [weak self] in
            await self?.performExport(item)
        }
    }

    private func performExport(_ item: BrewfileExportItem) async {
        let command = commandFactory.bundleDumpCommand(filePath: item.destinationPath)
        do {
            try await brewCommandCenter.perform(command, id: item.operationID)
            guard !Task.isCancelled else {
                revertExportIfCurrent(item)
                return
            }
            presentation = .exported(item)
        } catch is CancellationError {
            revertExportIfCurrent(item)
        } catch {
            guard !Task.isCancelled else {
                revertExportIfCurrent(item)
                return
            }
            let latestPhase = await brewCommandCenter.phase(for: item.operationID)
            let message: String = if case let .failed(reason) = latestPhase {
                reason.userFacingMessage
            } else {
                OperationFailure(catching: error).userFacingMessage
            }
            presentation = .failed(item, message: message)
        }
    }

    private func revertExportIfCurrent(_ item: BrewfileExportItem) {
        guard case let .exporting(current) = presentation, current == item else {
            return
        }
        presentation = .ready(item)
    }
}
