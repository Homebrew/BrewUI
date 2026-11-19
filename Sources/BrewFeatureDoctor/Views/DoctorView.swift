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
        PaneHeader {
            Text(viewModel.subtitle)
                .font(.brewTitle2)
                .foregroundStyle(Color.brewTextPrimary)
                .brewPaneHeadingAnchor()
        } actions: {
            headerControls
        } metadata: {
            if let lastCheckedAt = viewModel.lastCheckedAt {
                LastUpdatedLabel(lead: LocalizedStringResource(
                    "Last checked",
                    bundle: #bundle,
                    comment: "Doctor header: lead-in before a relative time, e.g. “Last checked 5 minutes ago”",
                ), date: lastCheckedAt, font: .brewSubheadline, color: .brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityLabel(Text("Doctor", bundle: #bundle, comment: "Doctor tab heading"))
        .accessibilityHeading(.h1)
    }

    @ViewBuilder
    private var headerControls: some View {
        if viewModel.showsHeaderControls {
            HStack(alignment: .top, spacing: BrewSpacing.sm) {
                refreshingIndicator
                PaneHeaderActions {
                    if viewModel.rawDoctorOutput != nil {
                        Button(String(localized: "Copy output", bundle: #bundle, comment: "Doctor header: copy raw brew doctor output")) {
                            viewModel.copyDoctorOutput()
                        }
                        .accessibilityLabel(String(localized: "Copy brew doctor output", bundle: #bundle, comment: "VoiceOver: Doctor copy-output button"))
                    }
                    Button(String(localized: "Run Again", bundle: #bundle, comment: "Doctor header: re-run brew doctor")) {
                        Task { await viewModel.load(forceRefresh: true) }
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
        }
    }

    @ViewBuilder
    private var refreshingIndicator: some View {
        if viewModel.isRefreshing {
            ProgressView()
                .controlSize(.small)
                .frame(minHeight: BrewLayout.headerActionHeight)
                .accessibilityLabel(String(localized: "Re-checking", bundle: #bundle, comment: "VoiceOver: Doctor re-check spinner"))
        }
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
                .font(.system(size: BrewLayout.successBadgeSize))
                .foregroundStyle(Color.brewStatusSuccess)
            Text("Your system is ready to brew", bundle: #bundle, comment: "Doctor healthy state title")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text("brew doctor found no problems.", bundle: #bundle, comment: "Doctor healthy state body")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, BrewLayout.paneContentInset)
        .padding(.vertical, BrewSpacing.xl)
    }

    private func issuesList(groups: [DoctorIssueGroup]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DoctorReassuranceNote()
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            DoctorIssueRowView(item: item)
                                .brewPaneListRowInsets()
                                .id(item.id)
                                .contentShape(Rectangle())
                                .brewPaneListRowSelection(isSelected: viewModel.selectedIssueID == item.id)
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
            .accessibilityLabel(String(localized: "Doctor issues", bundle: #bundle, comment: "VoiceOver: the Doctor issues list"))
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
            .brewPlainListSectionHeader()
    }
}

private struct DoctorReassuranceNote: View {
    var body: some View {
        NoteCallout(verbatim: DoctorCopy.warningPreamble, tone: .info)
            .axid(.doctorWarningGuidance)
            .padding(.horizontal, BrewLayout.paneContentInset)
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
