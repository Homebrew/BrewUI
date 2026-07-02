//
//  CommandBlockView.swift
//  BrewUIComponents
//

import AppKit
import SwiftUI

/// Terminal-style copyable card for one or more shell commands, with a copy button and an optional
/// footer summary. The single-command form mirrors the existing detail-pane usage; the sequence form
/// renders a numbered list with one "Copy all" affordance instead of N loose buttons.
public struct CommandBlockView: View {
    let commands: [String]
    let summaryText: String?
    let title: String?
    let collapsible: Bool

    public init(command: String, summaryText: String? = nil, title: String? = nil, collapsible: Bool = false) {
        commands = [command]
        self.summaryText = summaryText
        self.title = title
        self.collapsible = collapsible
        _isExpanded = State(initialValue: !collapsible)
    }

    public init(commands: [String], summaryText: String? = nil, title: String? = nil, collapsible: Bool = false) {
        self.commands = commands
        self.summaryText = summaryText
        self.title = title
        self.collapsible = collapsible
        _isExpanded = State(initialValue: !collapsible)
    }

    @State private var copied = false
    @State private var copyTask: Task<Void, Never>?
    @State private var isExpanded: Bool

    public var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                commandsBlock
                if let summaryText {
                    footer(summaryText)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private var header: some View {
        HStack {
            if collapsible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(title ?? headerTitle, systemImage: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
                .buttonStyle(.plain)
            } else {
                Label(title ?? headerTitle, systemImage: "terminal")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()
            Button(copied ? "Copied" : copyTitle, systemImage: copied ? "checkmark" : "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(commands.joined(separator: "\n"), forType: .string)
                copied = true
                copyTask?.cancel()
                copyTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled {
                        copied = false
                    }
                }
            }
            .font(.brewCaption)
            .foregroundStyle(Color.brewTextSecondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, BrewSpacing.md)
        .padding(.vertical, BrewSpacing.sm)
        .background(Color.brewSurfaceRecessed)
    }

    private var headerTitle: String {
        commands.count > 1 ? "Terminal commands" : "Terminal command"
    }

    private var copyTitle: String {
        commands.count > 1 ? "Copy all" : "Copy"
    }

    @ViewBuilder
    private var commandsBlock: some View {
        if commands.count <= 1, let command = commands.first {
            Text(command)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                    HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
                        Text("\(index + 1).")
                            .font(.brewCode)
                            .foregroundStyle(Color.brewTextTertiary)
                        Text(command)
                            .font(.brewCode)
                            .foregroundStyle(Color.brewCodeDefault)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(BrewSpacing.md)
            .background(Color.brewTerminal)
        }
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.brewCaption)
            .foregroundStyle(Color.brewTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .background(Color.brewSurfaceRecessed)
    }
}

#if DEBUG

    #Preview("Single") {
        CommandBlockView(
            command: "brew upgrade --formula git",
            summaryText: "Upgrades this package to the latest available version",
        )
        .frame(width: 360)
        .padding()
    }

    #Preview("Sequence") {
        CommandBlockView(
            commands: [
                "rm -rf /usr/local/Library",
                "brew tap homebrew/core",
            ],
            summaryText: "Re-establishes the Homebrew/core tap",
        )
        .frame(width: 360)
        .padding()
    }
#endif
