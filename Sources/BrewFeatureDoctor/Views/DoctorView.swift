//
//  DoctorView.swift
//  BrewFeatureDoctor
//

import BrewAccessibilityID
import BrewCore
import BrewUIComponents
import SwiftUI

/// Middle column of the Doctor surface: a header plus the current diagnostics state — initial loading,
/// healthy, the issues list, or an error. A background re-check keeps the prior content on screen and shows
/// a small "checking" spinner in the header.
struct DoctorView: View {
    @Bindable var viewModel: DoctorViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .contain)
        .axid(.doctorScreen)
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
                if viewModel.rawDoctorOutput != nil {
                    Button("Copy brew doctor output") {
                        viewModel.copyDoctorOutput()
                    }
                    .controlSize(.small)
                }
                Button("Run Again") {
                    Task { await viewModel.load(forceRefresh: true) }
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
            onRetry: { Task { await viewModel.load(forceRefresh: true) } },
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
        VStack(alignment: .leading, spacing: 0) {
            DoctorReassuranceNote()
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            DoctorIssueRowView(item: item)
                                .id(item.id)
                                .contentShape(Rectangle())
                                .listRowBackground(
                                    RoundedRectangle(
                                        cornerRadius: BrewRadius.lg,
                                        style: .continuous,
                                    )
                                    .fill(
                                        viewModel.selectedIssueID == item.id ? Color.brewBrandTint : Color.clear,
                                    )
                                    .padding(.horizontal, BrewSpacing.sm),
                                )
                                .onTapGesture {
                                    // Needed to suppress the default ugly blue macOS highlight state
                                    viewModel.setSelection(item.id)
                                }
                        }
                    } header: {
                        DoctorSeveritySectionHeader(severity: group.severity)
                    }
                }
            }
            .task(id: viewModel.shouldFocusList) {
                isFocused = viewModel.shouldFocusList
            }
            .focused($isFocused)
            .listStyle(.inset)
            .accessibilityLabel("Doctor issues")
            .onKeyPress(.upArrow) {
                viewModel.selectPrevious()
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.selectNext()
                return .handled
            }
        }
    }
}

private struct DoctorSeveritySectionHeader: View {
    let severity: DoctorSeverity

    var body: some View {
        Text(DoctorSeverityStyle.displayName(severity))
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(DoctorSeverityStyle.foreground(severity))
    }
}

private struct DoctorReassuranceNote: View {
    var body: some View {
        NoteCallout(DoctorCopy.warningPreamble, tone: .info)
            .padding(.horizontal, BrewSpacing.lg)
            .padding(.bottom, BrewSpacing.sm)
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
