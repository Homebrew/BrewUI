//
//  ConsoleToolbar.swift
//  Brew
//

import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Expanded-console toolbar: selected-job pill on the left, Save/Copy/Clear + collapse chevron on the right.
struct ConsoleToolbar: View {
    @Binding var expanded: Bool
    @Bindable var viewModel: ConsoleViewModel

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
            .accessibilityLabel("Hide console")
            .axid(.consoleToggle)
        }
        .padding(.horizontal, BrewSpacing.md)
        .frame(height: BrewLayout.consoleToolbarHeight)
        .background(Color.brewSurface)
    }

    @ViewBuilder
    private var jobPills: some View {
        let selectedID = viewModel.selectedJob?.id
        let orderedJobs = viewModel.orderedJobs
        if orderedJobs.isEmpty {
            Text("No activity")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.brewTextSecondary)
                .padding(.leading, BrewSpacing.xs)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewSpacing.xs) {
                    ForEach(orderedJobs) { job in
                        JobPill(
                            job: job,
                            isSelected: job.id == selectedID,
                            onSelect: { viewModel.select(id: job.id) },
                            onDismiss: { viewModel.dismiss(id: job.id) },
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let job = viewModel.selectedJob {
            // Saving ends in a save panel, which is its own confirmation.
            BrewActionButton("Save", systemImage: "square.and.arrow.down", help: "Save output to file") {
                ConsoleOutputExport.save(job)
            }
            BrewActionButton(
                "Copy",
                systemImage: "doc.on.doc",
                confirmationTitle: "Copied",
                help: "Copy output to clipboard",
            ) {
                ConsoleOutputExport.copy(job)
            }
        }
        BrewActionButton(
            "Clear",
            systemImage: "trash",
            confirmationTitle: "Cleared",
            help: "Clear completed jobs",
        ) {
            viewModel.clearCompleted()
        }
    }
}

private struct JobPill: View {
    let job: CommandJob
    let isSelected: Bool
    let onSelect: () -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: BrewSpacing.xs) {
            Button(action: onSelect) {
                HStack(spacing: BrewSpacing.xs) {
                    ConsoleStatusDot(state: job.dotState)
                    Text(job.command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.brewTextPrimary : Color.brewTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(job.command)

            if isHovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.brewTextSecondary)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
        }
        .padding(.horizontal, BrewSpacing.sm)
        .padding(.vertical, BrewSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: BrewRadius.sm)
                .fill(isSelected ? Color.brewBrandTint : Color.brewSurfaceElevated),
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.sm)
                .strokeBorder(isSelected ? Color.clear : Color.brewBorderDefault, lineWidth: 1),
        )
        .onHover { isHovered = $0 }
    }
}
