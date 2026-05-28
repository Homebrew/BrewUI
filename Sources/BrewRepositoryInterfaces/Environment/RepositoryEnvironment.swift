//
//  RepositoryEnvironment.swift
//  BrewRepositoryInterfaces
//

import BrewCore
import SwiftUI

public extension EnvironmentValues {
    /// App-scoped installed-inventory source of truth, injected at the nearest common ancestor of the
    /// installed-aware features. The default traps — the composition root must inject a live instance.
    @Entry var installedPackagesRepository: any InstalledPackagesRepository = UnimplementedInstalledPackagesRepository()

    /// Discover top-packages source, injected by the composition root.
    @Entry var discoverPackagesRepository: any DiscoverPackagesRepository = UnimplementedDiscoverPackagesRepository()

    /// Catalogue lookups/search, injected by the composition root.
    @Entry var catalogueRepository: any CatalogueRepository = UnimplementedCatalogueRepository()

    /// Live projection of command-center operations for the console, injected by the composition root.
    @Entry var commandJobsRepository: any CommandJobsObserving = UnimplementedCommandJobsObserving()

    /// Reverse-dependency lookups over the installed inventory, injected by the composition root.
    @Entry var installedDependentsRepository: any InstalledDependentsRepository = UnimplementedDependentsRepository()

    /// Mutating `brew` coordinator, injected by the composition root.
    @Entry var brewCommandCenter: any BrewCommandCenter = UnimplementedBrewCommandCenter()

    /// Builds mutating `brew` commands for view models, injected by the composition root.
    @Entry var mutatingCommandFactory: any BrewMutatingCommandFactory = UnimplementedMutatingCommandFactory()
}
