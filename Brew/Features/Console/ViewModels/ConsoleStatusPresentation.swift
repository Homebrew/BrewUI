//
//  ConsoleStatusPresentation.swift
//  Brew
//

import Foundation

/// View-facing snapshot of "what does the collapsed status bar render right now" — keeps the view passive.
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

    @MainActor
    static func from(registry: JobRegistry) -> ConsoleStatusPresentation {
        if let active = registry.activeJob {
            return ConsoleStatusPresentation(
                dotState: .running,
                summary: .running(command: active.command, shortLabel: active.phase.shortLabel),
                isRunning: true,
            )
        }
        if let lastID = registry.orderedIDs.last,
           let last = registry.jobs[lastID],
           last.isTerminal
        {
            return ConsoleStatusPresentation(
                dotState: last.succeeded ? .succeeded : .failed,
                summary: .completed(
                    command: last.command,
                    succeeded: last.succeeded,
                    exitCode: last.exitCode ?? -1,
                ),
                isRunning: false,
            )
        }
        return ConsoleStatusPresentation(dotState: .idle, summary: .idle, isRunning: false)
    }
}

nonisolated extension BrewOperationPhase {
    /// Plain-English label for surfaces (status bar, inline card).
    /// The center's phase enum is coarser than brew's stdout (`fetching`/`pouring`/`linking`) so this
    /// stays at the operation-lifecycle level. Sub-phase granularity would require stdout parsing.
    var shortLabel: String {
        switch self {
        case .idle:
            "done"
        case .running:
            "running"
        case .failed:
            "failed"
        }
    }
}
