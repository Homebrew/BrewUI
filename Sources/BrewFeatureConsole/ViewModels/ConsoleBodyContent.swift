//
//  ConsoleBodyContent.swift
//  BrewFeatureConsole
//

import BrewCore
import BrewRepositoryInterfaces

/// What the expanded console body shows. The job's identity travels with its lines because the text
/// view treats a different job as a different document.
enum ConsoleBodyContent: Equatable {
    case noActivity
    case output(jobID: CommandJobID, lines: [BrewCommandOutputLine], standardErrorIsNormalOutput: Bool)
}
