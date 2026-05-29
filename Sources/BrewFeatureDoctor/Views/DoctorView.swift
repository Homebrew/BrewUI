//
//  DoctorView.swift
//  BrewFeatureDoctor
//

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
                Text(subtitle)
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer(minLength: 0)
            if showsHeaderControls {
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
        .accessibilityElement(children: .combine)
        .accessibilityHeading(.h1)
    }

    private var showsHeaderControls: Bool {
        switch viewModel.presentation {
        case .healthy, .issues:
            true
        case .loading, .failed:
            false
        }
    }

    private var subtitle: String {
        switch viewModel.presentation {
        case .loading:
            "Running brew doctor…"
        case .healthy:
            viewModel.isRefreshing ? "Re-checking…" : "No problems found"
        case .issues:
            viewModel.isRefreshing ? "Re-checking…" : viewModel.issueCountSubtitle
        case .failed:
            "The check could not be completed"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.presentation {
        case .loading:
            loadingState
        case .healthy:
            healthyState
        case .issues:
            issuesList
        case let .failed(message):
            failedState(message)
        }
    }

    private var loadingState: some View {
        centeredState {
            ProgressView()
                .controlSize(.large)
            Text("Running brew doctor…")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
        }
    }

    private var healthyState: some View {
        centeredState {
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
    }

    private func failedState(_ message: String) -> some View {
        centeredState {
            Image(systemName: "exclamationmark.triangle")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewStatusError)
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewStatusError)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Try Again") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var issuesList: some View {
        List {
            ForEach(viewModel.issueItems) { item in
                DoctorIssueRowView(item: item)
                    .id(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.setSelection(item.id)
                    }
                    .listRowBackground(
                        viewModel.activeSelectedIssueID == item.id ? Color.brewBrandTint : Color.clear,
                    )
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Doctor issues")
    }

    private func centeredState(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: BrewSpacing.md) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.xl)
    }
}

#if DEBUG
    import BrewCore
    import BrewRepositoryInterfaces

    @MainActor
    func makeDoctorPreviewViewModel(report: DoctorReport) -> DoctorViewModel {
        DoctorViewModel(
            doctorRepository: PreviewSupport.makeDoctorRepository(report: report),
            brewCommandCenter: PreviewSupport.commandCenter,
            commandFactory: PreviewSupport.mutatingCommandFactory,
        )
    }

    #Preview("Doctor - issues") {
        DoctorView(viewModel: makeDoctorPreviewViewModel(report: PreviewSupport.doctorReport))
            .frame(width: 420, height: 480)
    }

    #Preview("Doctor - healthy") {
        DoctorView(viewModel: makeDoctorPreviewViewModel(report: PreviewSupport.healthyDoctorReport))
            .frame(width: 420, height: 480)
    }
#endif
