//
//  DoctorView.swift
//  BrewFeatureDoctor
//

import BrewUIComponents
import SwiftUI

/// Middle column of the Doctor surface: a header plus the current run state — idle CTA, running,
/// healthy, the issues list, or an error.
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
            if case .issues = viewModel.presentation {
                Button("Run Again") {
                    viewModel.run()
                }
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityHeading(.h1)
    }

    private var subtitle: String {
        switch viewModel.presentation {
        case .idle:
            "Check your Homebrew installation for problems"
        case .running:
            "Running brew doctor…"
        case .healthy:
            "No problems found"
        case .issues:
            viewModel.issueCountSubtitle
        case .failed:
            "The check could not be completed"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.presentation {
        case .idle:
            idleState
        case .running:
            runningState
        case .healthy:
            healthyState
        case .issues:
            issuesList
        case let .failed(message):
            failedState(message)
        }
    }

    private var idleState: some View {
        centeredState {
            Image(systemName: "stethoscope")
                .font(.system(size: 40))
                .foregroundStyle(Color.brewBrandPrimary)
            Text("Run a health check")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text(
                "Doctor runs brew doctor to find common problems with your Homebrew setup "
                    + "and suggests fixes you can run.",
            )
            .font(.brewCallout)
            .foregroundStyle(Color.brewTextSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
            Button("Run Diagnostics") {
                viewModel.run()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var runningState: some View {
        centeredState {
            ProgressView()
                .controlSize(.large)
            Text("Running brew doctor…")
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Button("Cancel") {
                viewModel.cancel()
            }
            .buttonStyle(.bordered)
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
            Button("Run Again") {
                viewModel.run()
            }
            .buttonStyle(.bordered)
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
                viewModel.run()
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
        let viewModel = makeDoctorPreviewViewModel(report: PreviewSupport.doctorReport)
        DoctorView(viewModel: viewModel)
            .task { viewModel.run() }
            .frame(width: 420, height: 480)
    }

    #Preview("Doctor - healthy") {
        let viewModel = makeDoctorPreviewViewModel(report: PreviewSupport.healthyDoctorReport)
        DoctorView(viewModel: viewModel)
            .task { viewModel.run() }
            .frame(width: 420, height: 480)
    }

    #Preview("Doctor - idle") {
        DoctorView(viewModel: makeDoctorPreviewViewModel(report: PreviewSupport.healthyDoctorReport))
            .frame(width: 420, height: 480)
    }
#endif
