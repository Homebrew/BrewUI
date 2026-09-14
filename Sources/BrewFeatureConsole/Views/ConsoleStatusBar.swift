/*
 * [INPUT]: 依赖控制台模型、展开 Binding 与当前语言环境
 * [OUTPUT]: 展示实时翻译的执行状态和控制台控件
 * [POS]: 控制台展示边界；保留命令原文及展开状态
 * [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
 */
//
//  ConsoleStatusBar.swift
//  Brew
//

import BrewAccessibilityID
import BrewUIComponents
import SwiftUI

/// Always-visible collapsed strip showing the active (or most recent) brew operation
/// with status dot, copyable command, phase label, and an expand affordance.
struct ConsoleStatusBar: View {
    @Environment(\.brewLocalization) private var localization
    @Binding var expanded: Bool
    let viewModel: ConsoleViewModel

    var body: some View {
        let presentation = viewModel.statusPresentation(localization: localization)
        HStack(spacing: BrewSpacing.md) {
            // Combined into one element so the whole "<command> — done" / "— failed · exit N"
            // sentence reads as a single string to VoiceOver and to UI tests.
            HStack(spacing: BrewSpacing.md) {
                ConsoleStatusDot(state: presentation.dotState)
                summaryText(presentation.summary)
            }
            .accessibilityElement(children: .combine)
            .axid(.consoleStatus)
            Spacer(minLength: BrewSpacing.sm)
            if presentation.isRunning {
                ProgressView()
                    .controlSize(.small)
            }
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: expanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .buttonStyle(.borderless)
            .help(localization.string(expanded ? "Hide console" : "Show console"))
            .accessibilityLabel(localization.string(expanded ? "Hide console" : "Show console"))
            .axid(.consoleToggle)
        }
        .padding(.horizontal, BrewSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.brewSurface)
        .contentShape(Rectangle())
        .onTapGesture {
            expanded.toggle()
        }
    }

    @ViewBuilder
    private func summaryText(_ summary: ConsoleStatusPresentation.Summary) -> some View {
        switch summary {
        case let .running(command, shortLabel):
            commandText(command)
            Text("— \(shortLabel)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.brewTextSecondary)

        case let .completed(command, succeeded, exitCode):
            commandText(command)
            if succeeded {
                Text("— done")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                Text("— failed · exit \(exitCode)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.brewStatusError)
            }

        case .idle:
            Text("Ready")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.brewTextSecondary)
        }
    }

    private func commandText(_ command: String) -> some View {
        Text(command)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Color.brewTextPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
