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
import BrewFeatureSelfUpdate
import BrewNetworking
import BrewRepositories
import BrewRepositoryInterfaces
import BrewSelfUpdateContract
import BrewUIComponents
import BrewUITestContract
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
    private let selfUpdateCoordinator: SelfUpdateCoordinator
    #if DEBUG
        private let selfUpdateDebugControl = SelfUpdateDebugControl()
    #endif

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
        let selfUpdateKeyPrefix = Self.defaultsKeyPrefix(base: "selfUpdate", fixtures: fixtures)
        // Consumed *before* the caches are built: `makeCatalogueCache` sweeps every `UITesting.`-prefixed
        // default, which under `-uiTesting` includes the notice the update helper just wrote.
        let launchOutcome = SelfUpdateLaunchNotice(defaultsKeyPrefix: selfUpdateKeyPrefix).consume()
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

        let selfUpdateContext = SelfUpdateLaunchContext(
            installedPackagesRepository: installedPackagesRepository,
            executionContext: executionContext,
            selfUpdateKeyPrefix: selfUpdateKeyPrefix,
            uiTesting: uiTesting,
            fixtures: fixtures,
            launchOutcome: launchOutcome,
        )
        #if DEBUG
            selfUpdateCoordinator = Self.makeSelfUpdateCoordinator(selfUpdateContext, debugControl: selfUpdateDebugControl)
        #else
            selfUpdateCoordinator = Self.makeSelfUpdateCoordinator(selfUpdateContext)
        #endif

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

    /// A UI-test relaunch has to carry the launch flag forward, or the new process comes up pointed at the
    /// real Homebrew mid-test.
    private static func relaunchArguments(uiTesting: BrewUITestingLaunchConfiguration?) -> [String] {
        guard uiTesting != nil else {
            return []
        }
        return [BrewUITestingEnvironmentKey.launchArgument, "YES"]
    }

    /// `fixturesRoot` is omitted: the relaunched app reinstalls the fixture tree into its own temp directory.
    private static func relaunchEnvironment(uiTesting: BrewUITestingLaunchConfiguration?) -> [String: String] {
        guard let uiTesting else {
            return [:]
        }
        var environment: [String: String] = [:]
        environment[BrewUITestingEnvironmentKey.scenario] = uiTesting.scenario
        environment[BrewUITestingEnvironmentKey.payload] = uiTesting.payload
        return environment
    }

    /// The fake `brew` reads the fixture tree out of its environment, and the helper is spawned by this
    /// process but outlives it — so what `setenv` published here has to travel in the spec. Empty in
    /// production, where the real `brew` needs nothing pinned.
    private static func upgradeEnvironment(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
        uiTesting: BrewUITestingLaunchConfiguration?,
    ) -> [String: String] {
        guard let fixtures, let scenario = uiTesting?.scenario else {
            return [:]
        }
        return [
            BrewUITestingEnvironmentKey.fixturesRoot: fixtures.rootURL.path,
            BrewUITestingEnvironmentKey.scenario: scenario,
        ]
    }

    /// Under `-uiTesting` the transcript lands in the run's container, so a test cannot overwrite the log
    /// of a real install's last self-update.
    private static func selfUpdateLogFileURL(
        fixtures: BrewUITestingFixtureInstaller.Installation?,
    ) -> URL {
        guard let fixtures else {
            return SelfUpdateHandoffDefaults.productionLogFileURL()
        }
        return fixtures.containerURL.appendingPathComponent("self-update.log")
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
                .environment(\.selfUpdateCoordinator, selfUpdateCoordinator)
                .task {
                    async let catalogue: Void = catalogueCache.prepare()
                    async let analytics: Void = discoverAnalyticsCache.prepare()
                    _ = await (catalogue, analytics)
                    await discoverPackagesRepository.load()
                }
                .task {
                    await installedPackagesRepository.load()
                }
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
                DebugMenuCommands(selfUpdateControl: selfUpdateDebugControl)
            }
        #endif
    }
}

/// Bundled rather than passed field-by-field: `BrewApp.init` builds one of these before the `#if DEBUG`
/// split, and the two `makeSelfUpdateCoordinator` overloads would otherwise carry six or seven parameters
/// apiece.
private struct SelfUpdateLaunchContext {
    let installedPackagesRepository: BrewInstalledPackagesRepository
    let executionContext: BrewCommandExecutionContext
    let selfUpdateKeyPrefix: String
    let uiTesting: BrewUITestingLaunchConfiguration?
    let fixtures: BrewUITestingFixtureInstaller.Installation?
    let launchOutcome: SelfUpdateOutcome?
}

extension BrewApp {
    #if DEBUG
        /// A dev build never has its own cask outdated, so DEBUG wraps the status provider with the
        /// simulator, and wraps the handoff so the simulated banner cannot reach it — see
        /// ``DebugSelfUpdateHandoff``.
        private static func makeSelfUpdateCoordinator(
            _ context: SelfUpdateLaunchContext,
            debugControl: SelfUpdateDebugControl,
        ) -> SelfUpdateCoordinator {
            let statusProvider = DebugSelfUpdateStatusProvider(
                base: BrewSelfUpdateStatusProvider(
                    inventory: context.installedPackagesRepository,
                    versionReader: BundleAppVersionReader(),
                ),
                control: debugControl,
            )
            let handoff = DebugSelfUpdateHandoff(
                base: makeHelperHandoff(context),
                isSimulatingUpdate: { debugControl.simulateUpdateAvailable },
            )
            return makeCoordinator(statusProvider: statusProvider, handoff: handoff, context)
        }
    #else
        private static func makeSelfUpdateCoordinator(_ context: SelfUpdateLaunchContext) -> SelfUpdateCoordinator {
            let statusProvider = BrewSelfUpdateStatusProvider(
                inventory: context.installedPackagesRepository,
                versionReader: BundleAppVersionReader(),
            )
            let handoff = makeHelperHandoff(context)
            return makeCoordinator(statusProvider: statusProvider, handoff: handoff, context)
        }
    #endif

    /// The same locator every other brew invocation goes through, so under `-uiTesting` the helper
    /// upgrades through the fake `brew` rather than the machine's real one.
    private static func makeHelperHandoff(_ context: SelfUpdateLaunchContext) -> HelperSelfUpdateHandoff {
        HelperSelfUpdateHandoff(
            brewExecutableURL: { try context.executionContext.brewExecutableURL() },
            defaultsKeyPrefix: context.selfUpdateKeyPrefix,
            relaunchArguments: relaunchArguments(uiTesting: context.uiTesting),
            relaunchEnvironment: relaunchEnvironment(uiTesting: context.uiTesting),
            upgradeEnvironment: upgradeEnvironment(fixtures: context.fixtures, uiTesting: context.uiTesting),
            logFileURL: selfUpdateLogFileURL(fixtures: context.fixtures),
        )
    }

    private static func makeCoordinator(
        statusProvider: any SelfUpdateStatusProviding,
        handoff: any SelfUpdateHandoff,
        _ context: SelfUpdateLaunchContext,
    ) -> SelfUpdateCoordinator {
        let coordinator = SelfUpdateCoordinator(
            statusProvider: statusProvider,
            preferences: UserDefaultsSelfUpdatePreferences(defaultsKeyPrefix: context.selfUpdateKeyPrefix),
            handoff: handoff,
        )
        coordinator.registerLaunchOutcome(context.launchOutcome)
        return coordinator
    }
}
