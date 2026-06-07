//
//  DoctorView.swift
//  BrewFeatureDoctor
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the Doctor surface: a header plus the current diagnostics state — initial loading,
/// healthy, the issues list, or an error. A background re-check keeps the prior content on screen and shows
/// a small "checking" spinner in the header.
struct DoctorView: View {
    @Bindable var viewModel: DoctorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.sm) {
            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Doctor")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(viewModel.subtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer(minLength: 0)
            if viewModel.showsHeaderControls {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Re-checking")
                }
                Button("Run Again") {
                    Task { await viewModel.load() }
                }
                .controlSize(.small)
                .disabled(viewModel.isRefreshing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityHeading(.h1)
    }

    private var content: some View {
        AsyncContentView(
            state: viewModel.state,
            onRetry: { Task { await viewModel.load() } },
            loaded: { report in
                if report.isHealthy {
                    healthyState
                } else {
                    issuesList(groups: DoctorIssueGroup.grouped(from: report))
                }
            },
        )
    }

    private var healthyState: some View {
        VStack(spacing: BrewSpacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brewStatusSuccess)
            Text("Your system is ready to brew")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text("brew doctor found no problems.")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.xl)
    }

    private func issuesList(groups: [DoctorIssueGroup]) -> some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        DoctorIssueRowView(item: item)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.setSelection(item.id)
                            }
                            .listRowBackground(
                                viewModel.selectedIssueID == item.id ? Color.brewBrandTint : Color.clear,
                            )
                    }
                } header: {
                    DoctorSeveritySectionHeader(severity: group.severity, issueCount: group.items.count)
                }
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Doctor issues")
    }
}

private struct DoctorSeveritySectionHeader: View {
    let severity: DoctorSeverity
    let issueCount: Int

    var body: some View {
        HStack(spacing: BrewSpacing.xs) {
            Text(DoctorSeverityStyle.displayName(severity))
                .font(.brewSubheadline.weight(.semibold))
                .foregroundStyle(DoctorSeverityStyle.foreground(severity))
            Text("(\(issueCount))")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(DoctorSeverityStyle.displayName(severity)), \(issueCount) issues")
    }
}

#if DEBUG
    import BrewRepositoryInterfaces

    #Preview("Doctor - issues") {
        DoctorView(viewModel: DoctorViewModel(
            doctorRepository: PreviewSupport.makeDoctorRepository(report: PreviewSupport.doctorReport),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        ))
        .frame(width: 420, height: 480)
    }

    #Preview("Doctor - healthy") {
        DoctorView(viewModel: DoctorViewModel(
            doctorRepository: PreviewSupport.makeDoctorRepository(report: PreviewSupport.healthyDoctorReport),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        ))
        .frame(width: 420, height: 480)
    }
#endif
