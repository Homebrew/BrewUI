//
//  DoctorColumns.swift
//  BrewFeatureDoctor
//

import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Dependency-composition boundary for the Doctor surface: reads app-level dependencies from the
/// environment and constructs the feature view model (`CONVENTIONS.md` — root-view ownership).
public struct DoctorColumnsRoot: View {
    @Environment(\.doctorRepository) private var doctorRepository
    @Environment(\.brewCommandCenter) private var brewCommandCenter
    @Environment(\.mutatingCommandFactory) private var mutatingCommandFactory

    public init() {}

    public var body: some View {
        DoctorColumns(
            doctorRepository: doctorRepository,
            brewCommandCenter: brewCommandCenter,
            mutatingCommandFactory: mutatingCommandFactory,
        )
    }
}

/// Feature-owned content/detail columns for the Doctor surface, mirroring the Installed split.
struct DoctorColumns: View {
    @State private var viewModel: DoctorViewModel

    init(
        doctorRepository: any DoctorRepository,
        brewCommandCenter: any BrewCommandCenter,
        mutatingCommandFactory: any BrewMutatingCommandFactory,
    ) {
        _viewModel = State(
            initialValue: DoctorViewModel(
                doctorRepository: doctorRepository,
                brewCommandCenter: brewCommandCenter,
                commandFactory: mutatingCommandFactory,
            ),
        )
    }

    var body: some View {
        HSplitView {
            DoctorView(viewModel: viewModel)
                .frame(
                    minWidth: BrewLayout.installedListColumnMinWidth,
                    idealWidth: BrewLayout.installedListColumnIdealWidth,
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading,
                )

            Group {
                if let issue = viewModel.selectedIssue {
                    DoctorIssueDetailView(viewModel: viewModel, item: issue)
                } else {
                    DoctorDetailPlaceholder()
                }
            }
            .frame(
                minWidth: BrewLayout.inspectorWidth,
                idealWidth: BrewLayout.installedDetailColumnIdealWidth,
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Run the check on arrival; the repository keeps a prior report on screen and refreshes in the background.
        .task {
            await viewModel.load()
        }
    }
}

#if DEBUG

    #Preview("Doctor - issues") {
        DoctorColumns(
            doctorRepository: PreviewSupport.makeDoctorRepository(),
            brewCommandCenter: PreviewSupport.commandCenter,
            mutatingCommandFactory: PreviewSupport.mutatingCommandFactory,
        )
        .frame(minWidth: 700, minHeight: 480)
    }
#endif
