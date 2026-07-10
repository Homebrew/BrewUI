//
//  CrashReportSheet.swift
//  Brew
//

import BrewCrashReporting
import SwiftUI

/// Loads any crash reports left by a previous launch and presents
/// ``CrashReportDialog`` for them one at a time.
///
/// Lives as a `ViewModifier` so `BrewApp` can attach it to the main window with
/// a single call while keeping observation of the `@Observable` controller
/// anchored inside a real view body.
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

    /// Bridges the controller's read-only `currentReport` to the `Binding` that
    /// `sheet(item:)` needs. Dismissing the sheet (e.g. via the report/discard
    /// buttons or the window) discards the current report, which advances the
    /// queue to the next one — or closes the sheet when none remain.
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
    /// Presents the post-crash reporting dialog for `controller`'s pending reports.
    func crashReportSheet(controller: CrashReportController) -> some View {
        modifier(CrashReportSheetModifier(controller: controller))
    }
}
