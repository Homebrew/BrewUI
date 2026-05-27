//
//  ConsoleStatusBar.swift
//  Brew
//

import SwiftUI

/// Always-visible collapsed strip showing the active (or most recent) brew operation
/// with status dot, copyable command, phase label, and an expand affordance.
struct ConsoleStatusBar: View {
    @Binding var expanded: Bool
    let viewModel: ConsoleViewModel

    var body: some View {
        let presentation = viewModel.statusPresentation
        HStack(spacing: BrewSpacing.md) {
            ConsoleStatusDot(state: presentation.dotState)
            summaryText(presentation.summary)
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
            .help(expanded ? "Hide console" : "Show console")
        }
        .padding(.horizontal, BrewSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
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
