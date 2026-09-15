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
    @Binding var expanded: Bool
    let viewModel: ConsoleViewModel

    var body: some View {
        let presentation = viewModel.statusPresentation
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
            .help(toggleLabel)
            .accessibilityLabel(toggleLabel)
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

    private var toggleLabel: String {
        expanded
            ? String(localized: "Hide console", bundle: #bundle, comment: "Console status bar: collapse button")
            : String(localized: "Show console", bundle: #bundle, comment: "Console status bar: expand button")
    }

    @ViewBuilder
    private func summaryText(_ summary: ConsoleStatusPresentation.Summary) -> some View {
        switch summary {
        case let .running(command, shortLabel):
            commandText(command)
            Text(verbatim: "— \(shortLabel)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.brewTextSecondary)

        case let .completed(command, succeeded, exitCode):
            commandText(command)
            if succeeded {
                Text("— done", bundle: #bundle, comment: "Console status bar suffix after a command succeeded")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.brewTextSecondary)
            } else {
                Text("— failed · exit \(exitCode)", bundle: #bundle, comment: "Console status bar suffix after a command failed; %lld is the exit code")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.brewStatusError)
            }

        case .idle:
            Text("Ready", bundle: #bundle, comment: "Console status bar when nothing has run")
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
