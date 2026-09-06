//
//  BrewApp.swift
//  Brew
//
//  Created by Graeme Arthur on 6/3/2026.
//

import BrewAppEnvironment
import BrewCLI
import BrewCore
import BrewCrashReporting
import BrewFeatureConsole
import BrewNetworking
import BrewRepositories
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

@main
struct BrewApp: App {
    private static let documentationURL = URL(string: "https://docs.brew.sh/")!
    private static let reportIssueURL = URL(string: "https://github.com/Homebrew/BrewUI/issues/new")!

    @Environment(\.scenePhase) private var scenePhase

    private let commandCenter: SerialBrewCommandCenter
    private let commandFactory: LiveBrewMutatingCommandFactory
    private let installedInventoryCache: InstalledInventoryCache
    private let catalogueCache: CatalogueCache
    private let discoverAnalyticsCache: DiscoverAnalyticsCache
    private let installedPackagesRepository: BrewInstalledPackagesRepository
    private let commandJobsRepository: BrewCommandJobsRepository
    private let installedDependentsRepository: BrewInstalledDependentsRepository
    private let catalogueRepository: BrewCatalogueRepository
    private let discoverPackagesRepository: BrewDiscoverPackagesRepository
    private let doctorRepository: BrewDoctorRepository
    private let configRepository: BrewConfigRepository
    private let crashReportController: CrashReportController

    init() {
        // Install crash capture before any other launch work so startup crashes are recorded.
        let crashReportStore = CrashReportStore()
        CrashReportInstaller.install(store: crashReportStore, environment: .current())
        crashReportController = CrashReportController(store: crashReportStore)

        let inventoryCache = InstalledInventoryCache()
        // nil in every production launch, so both process-boundary seams below fall through to the
        // live wiring untouched.
        let uiTesting = BrewUITestingLaunchConfiguration.current()
        // Writes this run's fixture tree into the app's own temp directory, before anything reads it.
        let fixtures = Self.installFixtures(uiTesting: uiTesting)
        let catalogue = Self.makeCatalogueCache(fixtures: fixtures)
        let discoverAnalytics = Self.makeDiscoverAnalyticsCache(fixtures: fixtures)
        // One context for every brew invocation: command center, installed inventory and `brew config`.
        let executionContext = Self.executionContext(uiTesting: uiTesting, fixtures: fixtures)
        let center = SerialBrewCommandCenter(executionContext: executionContext)
        let apiClient = Self.makeAPIClient(uiTesting: uiTesting)
        let catalogueRepo = BrewCatalogueRepository(apiClient: apiClient, cache: catalogue)

        installedInventoryCache = inventoryCache
        catalogueCache = catalogue
        discoverAnalyticsCache = discoverAnalytics
        commandCenter = center
        commandFactory = LiveBrewMutatingCommandFactory()
        installedPackagesRepository = BrewInstalledPackagesRepository(
            executionContext: executionContext,
            cache: inventoryCache,
            commandCenter: center,
        )
        commandJobsRepository = BrewCommandJobsRepository(commandCenter: center)
        installedDependentsRepository = BrewInstalledDependentsRepository(cache: inventoryCache)
        catalogueRepository = catalogueRepo
        discoverPackagesRepository = BrewDiscoverPackagesRepository(
            apiClient: apiClient,
            catalogueRepository: catalogueRepo,
            cache: discoverAnalytics,
            defaultsKeyPrefix: Self.defaultsKeyPrefix(base: "DiscoverAnalytics", fixtures: fixtures),
        )
        doctorRepository = BrewDoctorRepository(commandCenter: center, executionContext: executionContext)
        configRepository = BrewConfigRepository(executionContext: executionContext)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// Cleared at launch, so a previous run's ETag or refresh timestamp cannot decide this run's fetches.
    private static let uiTestingDefaultsPrefix = "UITesting."

    /// Fatal on failure by design: continuing without fixtures would surface later as a product bug.
    private static func installFixtures(
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> BrewUITestingFixtureInstaller.Installation? {
        guard let uiTesting else {
            return nil
        }
        do {
            return try BrewUITestingFixtureInstaller.install(
                payload: uiTesting.payload,
                scenario: uiTesting.scenario,
            )
        } catch {
            fatalError("UI-test fixtures could not be installed: \(error)")
        }
    }

    /// Network seam. Under `-uiTesting` with a scenario, requests are served in-process by
    /// ``BrewUITestingStubURLProtocol`` on a private ephemeral session; otherwise this is `live()`.
    private static func makeAPIClient(uiTesting: BrewUITestingLaunchConfiguration?) -> any BrewAPIClient {
        guard let uiTesting, uiTesting.scenario != nil else {
            return URLSessionBrewAPIClient.live()
        }
        return URLSessionBrewAPIClient.stubbed(protocolClasses: [BrewUITestingStubURLProtocol.self])
    }

    /// Catalogue cache seam. Under `-uiTesting` the bytes land in the run's container, so fixtures
    /// cannot outlive the run or overwrite a real install's cache.
    private static func makeCatalogueCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> CatalogueCache {
        guard let fixtures else {
            return CatalogueCache()
        }
        clearUITestingDefaults()
        return CatalogueCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "CatalogueCache",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "CatalogueCache", fixtures: fixtures),
        )
    }

    /// Analytics cache seam. Same isolation rationale as ``makeCatalogueCache(fixtures:)``.
    private static func makeDiscoverAnalyticsCache(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> DiscoverAnalyticsCache {
        guard let fixtures else {
            return DiscoverAnalyticsCache()
        }
        return DiscoverAnalyticsCache(
            cacheDirectoryURL: fixtures.containerURL.appendingPathComponent(
                "DiscoverAnalytics",
                isDirectory: true,
            ),
            defaultsKeyPrefix: defaultsKeyPrefix(base: "DiscoverAnalytics", fixtures: fixtures),
        )
    }

    private static func defaultsKeyPrefix(
        base: String,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> String {
        fixtures == nil ? base : uiTestingDefaultsPrefix + base
    }

    private static func clearUITestingDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(uiTestingDefaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Shell seam. A UI-test launch that installed no fake resolves nothing, rather than falling back
    /// to the machine's real Homebrew.
    private static func executionContext(
        uiTesting: BrewUITestingLaunchConfiguration?,
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> BrewCommandExecutionContext {
        guard uiTesting != nil else {
            return .live()
        }
        return .uiTesting(brewURL: fixtures?.fakeBrewURL)
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(\.brewCommandCenter, commandCenter)
                .environment(\.mutatingCommandFactory, commandFactory)
                .environment(\.installedPackagesRepository, installedPackagesRepository)
                .environment(\.commandJobsRepository, commandJobsRepository)
                .environment(\.installedDependentsRepository, installedDependentsRepository)
                .environment(\.catalogueRepository, catalogueRepository)
                .environment(\.discoverPackagesRepository, discoverPackagesRepository)
                .environment(\.doctorRepository, doctorRepository)
                .environment(\.configRepository, configRepository)
                .task {
                    async let catalogue: Void = catalogueCache.prepare()
                    async let analytics: Void = discoverAnalyticsCache.prepare()
                    _ = await (catalogue, analytics)
                    await discoverPackagesRepository.load()
                }
                .task { await installedPackagesRepository.load() }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Mark the config + brew.env caches stale on return-to-foreground so the next visit
                    // to the Configuration tab triggers a silent revalidation (stale value stays on
                    // screen during the refetch). No work is done if the user never opens the tab.
                    guard oldPhase == .background, newPhase == .active else {
                        return
                    }
                    configRepository.invalidate()
                }
                .frame(
                    minWidth: BrewLayout.minWindowWidth,
                    minHeight: BrewLayout.minWindowHeight,
                )
                .crashReportSheet(controller: crashReportController)
        }
        .defaultSize(
            width: BrewLayout.defaultWindowWidth,
            height: BrewLayout.defaultWindowHeight,
        )
        .commands {
            SearchCommands()
            SidebarCommands()
            RefreshCommands()
            ConsoleCommands()

            // Replace the default "Homebrew Help" item (which points at a
            // non-existent help book) with a link to the online documentation.
            CommandGroup(replacing: .help) {
                Link("Homebrew Documentation", destination: Self.documentationURL)
                Link("Report an Issue…", destination: Self.reportIssueURL)
            }
        }
        #if DEBUG
        .commands {
                DebugMenuCommands()
            }
        #endif
    }
}
