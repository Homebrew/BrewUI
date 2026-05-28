//
//  ConsoleOutputExport.swift
//  Brew
//

import AppKit
import BrewCore
import BrewDesignSystem
import BrewRepositories

/// View-layer AppKit bridge for saving/copying a command job's output. Lives at the view layer so the
/// console view model stays AppKit-free; views call these static methods with the data already shaped by
/// ``CommandJob/formattedOutputForExport()`` / ``CommandJob/suggestedExportFilename()``.
enum ConsoleOutputExport {
    @MainActor
    static func save(_ job: CommandJob) {
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

    @MainActor
    static func copy(_ job: CommandJob) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(job.formattedOutputForExport(), forType: .string)
    }
}
