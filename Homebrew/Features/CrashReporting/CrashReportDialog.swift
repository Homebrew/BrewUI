//
//  CrashReportDialog.swift
//  Brew
//

import BrewCrashReporting
import SwiftUI

/// The dialog shown on the launch after a crash, offering to file the report as
/// a GitHub issue or discard it. Passive (per `CONVENTIONS.md`): it renders the
/// report and forwards report/dismiss intents to its owner.
struct CrashReportDialog: View {
    let report: CrashReport
    let issueURL: URL
    /// Called after the user reports or discards; the report is removed either way.
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text("A report was saved after the app quit unexpectedly. You can send it " +
                "to the Homebrew team on GitHub to help fix the problem, or discard it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                ScrollView {
                    Text(report.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .padding(24)
        .frame(width: 540, height: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("The Homebrew app quit unexpectedly")
                .font(.title2)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Discard", role: .cancel, action: onDismiss)
            Button("Report on GitHub…") {
                openURL(issueURL)
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

#if DEBUG
    #Preview {
        CrashReportDialog(
            report: CrashReport(
                id: "crash-1.log",
                capturedAt: .now,
                text: """
                Homebrew.app crash report
                =========================
                Date: 2026-07-10T09:41:00Z
                App version: 1.0 (1)
                macOS: Version 26.0 (Build 26A1)
                Signal: SIGSEGV

                Call stack:
                0   Homebrew    0x0000000102a4c1b0 main + 42
                """,
            ),
            issueURL: URL(string: "https://github.com/Homebrew/BrewUI/issues/new")!,
            onDismiss: {},
        )
    }
#endif
