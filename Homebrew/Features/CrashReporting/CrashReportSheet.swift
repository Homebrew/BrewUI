//
//  CrashReportSheet.swift
//  Brew
//

import BrewCrashReporting
import SwiftUI

/// Loads any crash reports left by a previous launch and presents
/// ``CrashReportDialog`` for them one at a time.
private struct CrashReportSheetModifier: ViewModifier {
    @Bindable var controller: CrashReportController

    func body(content: Content) -> some View {
        content
            .task { await controller.loadPendingReports() }
            .sheet(item: currentReport) { report in
                CrashReportDialog(
                    report: report,
                    issueURL: controller.issueURL(for: report),
                    onDismiss: { controller.discard(report) },
                )
                .interactiveDismissDisabled()
            }
    }

    /// Bridges the read-only `currentReport` to the `Binding` `sheet(item:)`
    /// needs. Any dismissal discards the current report, advancing the queue.
    private var currentReport: Binding<CrashReport?> {
        Binding(
            get: { controller.currentReport },
            set: { newValue in
                if newValue == nil, let current = controller.currentReport {
                    controller.discard(current)
                }
            },
        )
    }
}

extension View {
    func crashReportSheet(controller: CrashReportController) -> some View {
        modifier(CrashReportSheetModifier(controller: controller))
    }
}
