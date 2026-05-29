//
//  DoctorIssueDetailView.swift
//  BrewFeatureDoctor
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Right-hand column: full detail for the selected `brew doctor` issue, including the runnable fix.
///
/// No inline console — fix output streams in the app's bottom console once the command center starts it.
struct DoctorIssueDetailView: View {
    @Bindable var viewModel: DoctorViewModel
    let item: DoctorIssueItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.xl) {
                heroSection
                if !item.details.isEmpty {
                    detailsSection
                }
                if !item.affectedItems.isEmpty {
                    affectedItemsSection
                }
                fixSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrewSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewStatusWarning)
            Text(item.title)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .textSelection(.enabled)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "What this means")
            Text(item.details)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
                .textSelection(.enabled)
        }
    }

    private var affectedItemsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            PackageDetailSectionHeading(title: "Affected")
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                ForEach(item.affectedItems, id: \.self) { affected in
                    Text(affected)
                        .font(.brewCode)
                        .foregroundStyle(Color.brewTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var fixSection: some View {
        if let fix = item.suggestedFix {
            VStack(alignment: .leading, spacing: BrewSpacing.md) {
                PackageDetailSectionHeading(title: "Suggested fix")
                PackageDetailCommandConsole(
                    command: fix.displayCommand,
                    summaryText: "Runs this command, then re-checks your system",
                )
                Button {
                    viewModel.runFix(for: item)
                } label: {
                    if viewModel.isFixRunning(item) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 120)
                    } else {
                        Text("Run Fix")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isFixRunning(item))
                .accessibilityLabel("Run Fix")

                if let fixError = viewModel.fixError(item) {
                    Text(fixError)
                        .font(.brewCallout)
                        .foregroundStyle(Color.brewStatusError)
                        .textSelection(.enabled)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: BrewSpacing.sm) {
                PackageDetailSectionHeading(title: "How to fix")
                Text(
                    "Homebrew didn't suggest a command for this warning. Follow the guidance above — "
                        + "any commands it printed can be selected and copied.",
                )
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            }
        }
    }
}

/// Placeholder shown in the detail column when no issue is selected (idle, running, or healthy).
struct DoctorDetailPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Text("No selection")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
            Text("Run diagnostics, then choose an issue to see details and fixes.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(BrewSpacing.xl)
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Doctor issue detail") {
        let report = PreviewSupport.doctorReport
        let viewModel = makeDoctorPreviewViewModel(report: report)
        Group {
            if let issue = report.issues.first {
                DoctorIssueDetailView(viewModel: viewModel, item: DoctorIssueItem(id: 0, issue: issue))
            }
        }
        .task { viewModel.run() }
        .frame(width: 380, height: 480)
    }
#endif
