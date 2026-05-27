//
//  ConsoleToolbar.swift
//  Brew
//

import AppKit
import SwiftUI

/// Expanded-console toolbar: selected-job pill on the left, Save/Copy/Clear + collapse chevron on the right.
struct ConsoleToolbar: View {
    @Binding var expanded: Bool
    @Environment(\.jobRegistry) private var registry

    var body: some View {
        HStack(spacing: BrewSpacing.xs) {
            jobPills
            Spacer(minLength: BrewSpacing.sm)
            actionButtons
            Divider().frame(height: 14)
            Button {
                expanded = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.brewTextSecondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .help("Hide console")
        }
        .padding(.horizontal, BrewSpacing.md)
        .frame(height: BrewLayout.consoleToolbarHeight)
    }

    @ViewBuilder
    private var jobPills: some View {
        let selectedID = registry.selectedJob?.id
        let orderedJobs = registry.orderedIDs.compactMap { registry.jobs[$0] }
        if orderedJobs.isEmpty {
            Text("No activity")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.brewTextSecondary)
                .padding(.leading, BrewSpacing.xs)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewSpacing.xs) {
                    ForEach(orderedJobs) { job in
                        jobPill(for: job, isSelected: job.id == selectedID)
                    }
                }
            }
        }
    }

    private func jobPill(for job: CommandJob, isSelected: Bool) -> some View {
        Button {
            registry.selectedID = job.id
        } label: {
            HStack(spacing: BrewSpacing.xs) {
                ConsoleStatusDot(state: dotState(for: job))
                Text(job.command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.brewCodeDefault : Color.brewTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .fill(isSelected ? Color.brewBrandTint : Color.clear),
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrewRadius.sm)
                    .strokeBorder(isSelected ? Color.clear : Color.brewBorderDefault, lineWidth: 1),
            )
            .contentShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
        }
        .buttonStyle(.plain)
        .help(job.command)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let job = registry.selectedJob {
            toolbarAction(
                systemImage: "square.and.arrow.down",
                label: "Save",
                help: "Save output to file",
            ) {
                saveOutput(job)
            }
            toolbarAction(
                systemImage: "doc.on.doc",
                label: "Copy",
                help: "Copy output to clipboard",
            ) {
                copyOutput(job)
            }
        }
        toolbarAction(
            systemImage: "trash",
            label: "Clear",
            help: "Clear completed jobs",
        ) {
            registry.clearCompleted()
        }
    }

    private func toolbarAction(
        systemImage: String,
        label: String,
        help: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(Color.brewTextSecondary)
            .padding(.horizontal, BrewSpacing.sm)
            .padding(.vertical, BrewSpacing.xxs)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func dotState(for job: CommandJob) -> ConsoleStatusPresentation.DotState {
        if !job.isTerminal {
            return .running
        }
        return job.succeeded ? .succeeded : .failed
    }

    private func saveOutput(_ job: CommandJob) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = job.suggestedExportFilename()
        panel.directoryURL = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask,
        ).first
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let text = job.formattedOutputForExport()
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func copyOutput(_ job: CommandJob) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(job.formattedOutputForExport(), forType: .string)
    }
}
