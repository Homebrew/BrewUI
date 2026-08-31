//
//  ConsoleBodyContent.swift
//  BrewFeatureConsole
//

import BrewCore
import BrewRepositoryInterfaces

/// What the expanded console body shows.
///
/// One value rather than a selected job the body reaches into, so the body binds and renders instead of
/// composing selection and output itself. The job's identity travels with its lines because the text
/// view treats a different job as a different document.
enum ConsoleBodyContent: Equatable {
    case noActivity
    case output(jobID: CommandJobID, lines: [BrewCommandOutputLine])
}
