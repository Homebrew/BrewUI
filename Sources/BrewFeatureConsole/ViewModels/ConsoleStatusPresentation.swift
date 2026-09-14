/*
 * [INPUT]: 依赖命令阶段与当前语言快照
 * [OUTPUT]: 生成控制台生命周期短标签
 * [POS]: 控制台展示映射，不解释或翻译 stdout
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  ConsoleStatusPresentation.swift
//  Brew
//

import BrewCore
import BrewUIComponents
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
    func shortLabel(localization: AppLocalization = AppLocalization()) -> String {
        switch self {
        case .idle:
            localization.string("done")
        case .running:
            localization.string("running")
        case .failed:
            localization.string("failed")
        }
    }
}
