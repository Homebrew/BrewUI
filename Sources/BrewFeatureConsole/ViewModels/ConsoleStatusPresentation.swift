//
//  ConsoleStatusPresentation.swift
//  Brew
//

import BrewCore
import Foundation

/// View-facing snapshot of "what does the collapsed status bar render right now" — keeps the view passive.
/// Derived by ``ConsoleViewModel/statusPresentation``.
struct ConsoleStatusPresentation: Equatable {
    let dotState: DotState
    let summary: Summary
    let isRunning: Bool

    enum DotState: Equatable {
        case running
        case succeeded
        case failed
        case idle
    }

    enum Summary: Equatable {
        case running(command: String, shortLabel: String)
        case completed(command: String, succeeded: Bool, exitCode: Int32)
        case idle
    }
}

extension BrewOperationPhase {
    /// Plain-English label for surfaces (status bar, inline card).
    /// The center's phase enum is coarser than brew's stdout (`fetching`/`pouring`/`linking`) so this
    /// stays at the operation-lifecycle level. Sub-phase granularity would require stdout parsing.
    var shortLabel: String {
        switch self {
        case .idle:
            String(localized: "done", bundle: #bundle, comment: "Console status bar: operation finished")
        case .running:
            String(localized: "running", bundle: #bundle, comment: "Console status bar: operation in progress")
        case .reconciling:
            String(
                localized: "refreshing",
                bundle: #bundle,
                comment: "Console status bar: command finished, refreshing the installed package list",
            )
        case .failed:
            String(localized: "failed", bundle: #bundle, comment: "Console status bar: operation failed")
        }
    }
}
