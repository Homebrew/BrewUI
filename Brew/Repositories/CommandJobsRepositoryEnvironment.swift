//
//  CommandJobsRepositoryEnvironment.swift
//  Brew
//

import SwiftUI

extension EnvironmentValues {
    /// App-scoped projection of command-center operations. Injected at the app root with the live instance;
    /// read with `@Environment(\.commandJobsRepository)` from the console root view, which constructs
    /// the ``ConsoleViewModel`` that downstream console views consume.
    /// The default is an inert placeholder for previews and unscoped subtrees.
    @Entry var commandJobsRepository = BrewCommandJobsRepository.placeholder()
}
